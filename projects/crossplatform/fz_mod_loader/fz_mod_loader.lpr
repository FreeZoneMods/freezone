library fz_mod_loader;

{$mode delphi}{$H+}

uses
  sysutils,
  windows,
  LogMgr,
  IniFile,
  CommandLineParser,
  FileManager,
  HttpDownloader,
  mutexhunter,
  abstractions,
  Decompressor;

type
  FZDllModFunResult = cardinal;
const
  {%H-}FZ_DLL_MOD_FUN_SUCCESS_LOCK: cardinal = 0;    //Мод успешно загрузился, требуется залочить клиента по name_lock
  FZ_DLL_MOD_FUN_SUCCESS_NOLOCK: cardinal = 1;  //Успех, лочить клиента (с использованием name_lock) пока не надо
  FZ_DLL_MOD_FUN_FAILURE: cardinal = 2;         //Ошибка загрузки мода

type
  FZMasterLinkListAddr = array of string;

  FZFsLtxBuilderSettings = record
    share_patches_dir:boolean;
    full_install:boolean;
    configs_dir:string;
  end;

  FZModSettings = record
    root_dir:string;
    exe_name:string;
    modname:string;
    binlist_url:string;
    gamelist_url:string;
    fsltx_settings:FZFsLtxBuilderSettings;
  end;

  FZModMirrorsSettings = record
    binlist_urls:FZMasterLinkListAddr;
    gamelist_urls:FZMasterLinkListAddr;
  end;

  FZConfigBackup = record
    filename:string;
    buf:pAnsiChar;
    sz:cardinal;
  end;

var
  _mod_rel_path:PChar;
  _mod_name:PChar;
  _mod_params:PChar;
  _dll_handle:HINST;
  _fz_loader_semaphore_handle:HANDLE;

const
  MAX_NAME_SIZE:cardinal=4096;
  MAX_PARAMS_SIZE:cardinal=4096;
  gamedata_files_list_name:string ='gamedata_filelist.ini';
  engine_files_list_name:string ='engine_filelist.ini';
  master_mods_list_name:string ='master_mods_filelist.ini';
  fsltx_name:string='fsgame.ltx';
  userltx_name:string='user.ltx';
  userdata_dir_name:string='userdata\';
  engine_dir_name:string='bin\';
  patches_dir_name:string='patches\';
  mp_dir_name:string='mp\';
  additional_keys_line_file:string='mod_key_line.txt';

  mod_dir_prefix:PChar='.svn\';
  allowed_symbols_in_mod_name:string='1234567890abcdefghijklmnopqrstuvwxyz_';
  fz_loader_semaphore_name:PAnsiChar='Local\FREEZONE_STK_MOD_LOADER_SEMAPHORE';
  fz_loader_modules_mutex_name:PAnsiChar='Local\FREEZONE_STK_MOD_LOADER_MODULES_MUTEX';

function CreateDownloaderThreadForUrl(url:PAnsiChar):FZDownloaderThread;
begin
  if IsGameSpyDlForced(_mod_params) and (leftstr(url, length('https')) <> 'https') then begin
    FZLogMgr.Get.Write('Creating GS dl thread', FZ_LOG_INFO);
    result:=FZGameSpyDownloaderThread.Create();
  end else begin
    FZLogMgr.Get.Write('Creating CURL dl thread', FZ_LOG_INFO);
    result:=FZCurlDownloaderThread.Create();
  end;
end;

procedure PushToArray(var a:FZMasterLinkListAddr; s:string);
var
  i:integer;
begin
  i:=length(a);
  setlength(a, i+1);
  a[i]:=s;
end;

procedure ClearModMirrors(var mirrors:FZModMirrorsSettings);
begin
  setlength(mirrors.binlist_urls, 0);
  setlength(mirrors.gamelist_urls, 0);
end;

procedure PushModMirror(var mirrors:FZModMirrorsSettings; binlist:string; gamelist:string);
begin
  PushToArray(mirrors.binlist_urls, binlist);
  PushToArray(mirrors.gamelist_urls, gamelist);
end;

function GenerateMirrorSuffixForIndex(index:integer):string;
const
  MASTERLINKS_MIRROR_SUFFIX = '_mirror_';
begin
  result:='';
  if index>0 then begin
    result:=MASTERLINKS_MIRROR_SUFFIX+inttostr(index);
  end;
end;

type
  FZMasterListApproveType = (FZ_MASTERLIST_NOT_APPROVED, FZ_MASTERLIST_APPROVED, FZ_MASTERLIST_ONLY_OLD_CONFIG);

function DownloadAndParseMasterModsList(var settings:FZModSettings; var mirrors:FZModMirrorsSettings):FZMasterListApproveType;
var
  master_links:FZMasterLinkListAddr;
  list_downloaded:boolean;
  dlThread:FZDownloaderThread;
  dl:FZFileDownloader;
  i, j:integer;
  full_path:string;
  cfg:FZIniFile;
  params_approved:FZMasterListApproveType;
  core_params:string;

  tmp_settings:FZModSettings;
  tmp1, tmp2:string;
  binlist_valid, gamelist_valid:boolean;
const
  DEBUG_MODE_KEY:string='-fz_customlists';
  MASTERLINKS_BINLIST_KEY = 'binlist';
  MASTERLINKS_GAMELIST_KEY = 'gamelist';
  MASTERLINKS_FULLINSTALL_KEY = 'fullinstall';
  MASTERLINKS_SHARED_PATCHES_KEY = 'sharedpatches';
  MASTERLINKS_CONFIGS_DIR_KEY = 'configsdir';
  MASTERLINKS_EXE_NAME_KEY = 'exename';
begin
  result:=FZ_MASTERLIST_NOT_APPROVED;

  PushToArray(master_links, 'https://raw.githubusercontent.com/FreeZoneMods/modmasterlinks/master/links.ini');
  PushToArray(master_links, 'http://www.gwrmod.tk/files/mods_links.ini');
  PushToArray(master_links, 'http://www.stalker-life.ru/mods_links/links.ini');
  PushToArray(master_links, 'http://stalker.stagila.ru:8080/stcs_emergency/mods_links.ini');
  PushToArray(master_links, 'http://www.gwrmod.tk/files/mods_links_low_priority.ini');

  list_downloaded:=false;
  full_path:= settings.root_dir+master_mods_list_name;

  dlThread:=CreateDownloaderThreadForUrl(PAnsiChar(master_links[0]));
  for i:=0 to length(master_links)-1 do begin
    dl:=dlThread.CreateDownloader(master_links[i], full_path, 0);
    list_downloaded:=dl.StartSyncDownload();
    dl.Free;
    if list_downloaded then break;
  end;
  dlThread.Free();

  ClearModMirrors(mirrors);

  tmp_settings:=settings;
  tmp_settings.binlist_url:=GetCustomBinUrl(_mod_params);
  tmp_settings.gamelist_url:=GetCustomGamedataUrl(_mod_params);
  tmp_settings.exe_name:=GetExeName(_mod_params, '');
  tmp_settings.fsltx_settings.full_install:=IsFullInstallMode(_mod_params);
  tmp_settings.fsltx_settings.share_patches_dir:=IsSharedPatches(_mod_params);
  tmp_settings.fsltx_settings.configs_dir:=GetConfigsDir(_mod_params, '');

  params_approved:=FZ_MASTERLIST_NOT_APPROVED;
  if list_downloaded then begin
    // Мастер-список успешно скачался, будем парсить его содержимое
    cfg:=FZIniFile.Create(full_path);
    for i:=0 to cfg.GetSectionsCount()-1 do begin
      if cfg.GetSectionName(i) = tmp_settings.modname then begin
        //Нашли в мастер-конфиге секцию, отвечающую за наш мод
        FZLogMgr.Get.Write('Mod '+tmp_settings.modname+' found in master list', FZ_LOG_INFO);
        params_approved:=FZ_MASTERLIST_NOT_APPROVED;

        //Заполняем список всех доступных зеркал, попутно ищем ссылки из binlist и gamelist в списке зеркал
        j:=0;
        if (length(tmp_settings.gamelist_url)=0) and (length(tmp_settings.binlist_url)=0) then begin
          //Юзер не заморачивается указыванием списков, выбираем их сами
          binlist_valid:=true;
          gamelist_valid:=true;
        end else begin
          binlist_valid:=false;
          gamelist_valid:=false;
        end;

        while (true) do begin
          //Конструируем имя параметров зеркала
          tmp1:=GenerateMirrorSuffixForIndex(j);
          tmp2:=MASTERLINKS_GAMELIST_KEY+tmp1;
          tmp1:=MASTERLINKS_BINLIST_KEY+tmp1;

          //Вычитываем параметры зеркала
          tmp1:=cfg.GetStringDef(tmp_settings.modname, tmp1, '');
          tmp2:=cfg.GetStringDef(tmp_settings.modname, tmp2, '');

          //Проверяем и сохраняем
          if (length(tmp1)=0) and (length(tmp2)=0) then begin
            break;
          end;
          FZLogMgr.Get.Write('Pushing mirror #'+inttostr(length(mirrors.binlist_urls))+': binlist '+tmp1+', gamelist '+tmp2, FZ_LOG_INFO);
          PushModMirror(mirrors, tmp1, tmp2);
          if tmp1=tmp_settings.binlist_url then binlist_valid:=true;
          if tmp2=tmp_settings.gamelist_url then gamelist_valid:=true;

          j:=j+1;
        end;

        //Убеждаемся, что пользователь не подсунул нам "левую" ссылку
        if (length(mirrors.binlist_urls) = 0) and (length(mirrors.gamelist_urls)=0) then begin
          FZLogMgr.Get.Write('Invalid mod parameters in master links', FZ_LOG_ERROR);
          break;
        end else if (not binlist_valid) then begin
          FZLogMgr.Get.Write('The binlist URL specified in mod parameters can''t be found in the master links list', FZ_LOG_ERROR);
          break;
        end else if (not gamelist_valid) then begin
          FZLogMgr.Get.Write('The gamelist URL specified in mod parameters can''t be found in the master links list', FZ_LOG_ERROR);
          break;
        end;

        //Если пользователь не передал нам в строке запуска ссылок - берем указанные в "основном" зеркале
        if (length(tmp_settings.gamelist_url)=0) and (length(tmp_settings.binlist_url)=0) then begin
          if (length(mirrors.gamelist_urls)>0) then begin
            tmp_settings.gamelist_url:=mirrors.gamelist_urls[0];
          end;

          if (length(mirrors.binlist_urls)>0) then begin
            tmp_settings.binlist_url:=mirrors.binlist_urls[0];
          end;

          for j:=0 to length(mirrors.binlist_urls)-2 do begin
            mirrors.gamelist_urls[j]:=mirrors.gamelist_urls[j+1];
            mirrors.binlist_urls[j]:=mirrors.binlist_urls[j+1];
          end;

          setlength(mirrors.gamelist_urls, length(mirrors.gamelist_urls)-1);
          setlength(mirrors.binlist_urls, length(mirrors.binlist_urls)-1);
        end;

        tmp_settings.fsltx_settings.full_install := cfg.GetBoolDef(tmp_settings.modname, MASTERLINKS_FULLINSTALL_KEY, false);
        tmp_settings.fsltx_settings.share_patches_dir:= cfg.GetBoolDef(tmp_settings.modname, MASTERLINKS_SHARED_PATCHES_KEY, false);
        tmp_settings.fsltx_settings.configs_dir:=cfg.GetStringDef(tmp_settings.modname, MASTERLINKS_CONFIGS_DIR_KEY, '');
        tmp_settings.exe_name:=cfg.GetStringDef(tmp_settings.modname, MASTERLINKS_EXE_NAME_KEY, '');
        params_approved := FZ_MASTERLIST_APPROVED;
        break;
      end else if (params_approved=FZ_MASTERLIST_NOT_APPROVED) then begin
        //Если ссылка на binlist пустая или находится в конфиге какого-либо мода - можно заапрувить ее
        //Однако заканчивать рано - надо перебирать и проверять также следующие секции, так как в них может найтись секция с модом, в которой будут другие движок и/или геймдата!
        binlist_valid:=length(tmp_settings.binlist_url) = 0;
        j:=0;
        tmp2:=cfg.GetSectionName(i);
        while (not binlist_valid) do begin
          tmp1:=cfg.GetStringDef(tmp2, MASTERLINKS_BINLIST_KEY + GenerateMirrorSuffixForIndex(j), '');
          if (length(tmp1) = 0) and (length(cfg.GetStringDef(tmp2, MASTERLINKS_GAMELIST_KEY + GenerateMirrorSuffixForIndex(j), '')) = 0) then break;
          binlist_valid := (tmp1=tmp_settings.binlist_url);
          j:=j+1;
        end;

        if binlist_valid then begin
          if (length(tmp_settings.binlist_url) = 0) then begin
            FZLogMgr.Get.Write('No engine mod, approved', FZ_LOG_INFO);
          end else begin
            FZLogMgr.Get.Write('Engine "'+tmp_settings.binlist_url+'" approved by mod "'+cfg.GetSectionName(i)+'"', FZ_LOG_INFO);
          end;
          params_approved:=FZ_MASTERLIST_APPROVED;
        end;
      end;
    end;
    cfg.Free;
  end else begin
    //Список почему-то не скачался. Ограничимся геймдатными и скачанными ранее модами.
    FZLogMgr.Get.Write('Cannot download master links!', FZ_LOG_ERROR);
    if (length(tmp_settings.binlist_url) = 0) and (length(tmp_settings.gamelist_url) <> 0) then begin
      FZLogMgr.Get.Write('Gamedata mod approved', FZ_LOG_INFO);
      params_approved:=FZ_MASTERLIST_APPROVED;
    end else begin
      params_approved:=FZ_MASTERLIST_ONLY_OLD_CONFIG;
      FZLogMgr.Get.Write('Only old mods approved', FZ_LOG_INFO);
    end;
  end;

  core_params:=VersionAbstraction().GetCoreParams();
  if (params_approved<>FZ_MASTERLIST_NOT_APPROVED) or (Pos(DEBUG_MODE_KEY, core_params)>0) then begin
    settings:=tmp_settings;
    settings.exe_name:=StringReplace(settings.exe_name, '\', '_', [rfReplaceAll]);
    settings.exe_name:=StringReplace(settings.exe_name, '/', '_', [rfReplaceAll]);
    settings.exe_name:=StringReplace(settings.exe_name, '..', '__', [rfReplaceAll]);
    if (Pos(DEBUG_MODE_KEY, core_params)>0) then begin
      FZLogMgr.Get.Write('Debug mode - force approve', FZ_LOG_INFO);
      result:=FZ_MASTERLIST_APPROVED;
    end else begin
      result:=params_approved;
    end;
  end;

end;

function DownloadAndApplyFileList(url:string; list_filename:string; root_dir:string; masterlinks_type:FZMasterListApproveType; fileList:FZFiles; update_progress:boolean):boolean;
var
  dl:FZFileDownloader;
  filepath:string;
  cfg:FZIniFile;
  i, files_count:integer;

  section:string;
  fileCheckParams:FZCheckParams;
  fileurl:string;
  filename:string;
  compression:cardinal;
  thread:FZDownloaderThread;
  starttime, last_update_time:cardinal;
const
  MAX_NO_UPDATE_DELTA = 5000;
begin
  result:=false;
  filepath:=root_dir+list_filename;

  if masterlinks_type = FZ_MASTERLIST_ONLY_OLD_CONFIG then begin
    //Не загружаем ничего! В параметрах URL вообще может ничего не быть
    //Просто пытаемся использовать старую конфигурацию
  end else if masterlinks_type = FZ_MASTERLIST_NOT_APPROVED then begin
    FZLogMgr.Get.Write('Master links don''t allow the mod', FZ_LOG_ERROR);
    exit;
  end else begin
    if length(url)=0 then begin
      FZLogMgr.Get.Write('No list URL specified', FZ_LOG_ERROR);
      exit;
    end;

    FZLogMgr.Get.Write('Downloading list '+url+' to '+filepath, FZ_LOG_INFO);

    thread:=CreateDownloaderThreadForUrl(PAnsiChar(url));
    dl:=thread.CreateDownloader(url, filepath, 0);
    result:=dl.StartSyncDownload();
    dl.Free();
    thread.Free();
    if not result then begin
      FZLogMgr.Get.Write('Downloading list failed', FZ_LOG_ERROR);
      exit;
    end;
  end;
  result:=false;

  cfg:=FZIniFile.Create(filepath);
  files_count:=cfg.GetIntDef('main', 'files_count', 0);
  if files_count = 0 then begin
    FZLogMgr.Get.Write('No files in file list', FZ_LOG_ERROR);
    exit;
  end;

  starttime:=GetCurrentTime();
  last_update_time:=starttime;
  for i:=0 to files_count-1 do begin
    section:='file_'+inttostr(i);
    FZLogMgr.Get.Write('Parsing section '+section, FZ_LOG_INFO);
    filename:=cfg.GetStringDef(section, 'path', '' );
    if (length(filename)=0) then begin
      FZLogMgr.Get.Write('Invalid name for file #'+inttostr(i), FZ_LOG_ERROR);
      exit;
    end;

    if cfg.GetBoolDef(section,'ignore', false) then begin
      if not fileList.AddIgnoredFile(filename) then begin
        FZLogMgr.Get.Write('Cannot add to ignored file #'+inttostr(i)+' ('+filename+')', FZ_LOG_ERROR);
        exit;
      end;
    end else begin
      fileurl:=cfg.GetStringDef(section, 'url', '' );
      if (length(fileurl)=0) then begin
        FZLogMgr.Get.Write('Invalid url for file #'+inttostr(i), FZ_LOG_ERROR);
        exit;
      end;

      compression:=cfg.GetIntDef(section, 'compression', 0);

      fileCheckParams.crc32:=0;
      if not cfg.GetHex(section, 'crc32', fileCheckParams.crc32) then begin
        FZLogMgr.Get.Write('Invalid crc32 for file #'+inttostr(i), FZ_LOG_ERROR);
        exit;
      end;

      fileCheckParams.size:=cfg.GetIntDef(section, 'size', 0);
      if fileCheckParams.size=0 then begin
        FZLogMgr.Get.Write('Invalid size for file #'+inttostr(i), FZ_LOG_ERROR);
        exit;
      end;
      fileCheckParams.md5:=LowerCase(cfg.GetStringDef(section, 'md5', ''));

      if not fileList.UpdateFileInfo(filename, fileurl, compression, fileCheckParams) then begin
        FZLogMgr.Get.Write('Cannot update file info #'+inttostr(i)+' ('+filename+')', FZ_LOG_ERROR);
        exit;
      end;
    end;

    if VersionAbstraction().CheckForUserCancelDownload() then begin
      FZLogMgr.Get.Write('Stop applying file list - user-cancelled', FZ_LOG_ERROR);
      exit;
    end else if update_progress then begin
      if GetCurrentTime() - last_update_time > MAX_NO_UPDATE_DELTA then begin
        VersionAbstraction().SetVisualProgress(100 * i / files_count);
        last_update_time:=GetCurrentTime();
      end;
    end;
  end;
  FZLogMgr.Get.Write('File list "'+list_filename+'" processed, time '+inttostr(GetCurrentTime()-starttime)+' ms', FZ_LOG_INFO);

  cfg.Free;
  result:=true;
end;

function DownloadCallback(info:FZFileActualizingProgressInfo; userdata:pointer):boolean;
var
  progress:single;
  ready:int64;
  last_downloaded_bytes:pint64;
begin
  progress:=0;
  if info.total_mod_size>0 then begin
    ready:=info.total_downloaded+info.total_up_to_date_size;
    if (ready>0) or (ready<=info.total_mod_size) then begin
      progress:=(ready/info.total_mod_size)*100;
    end;
  end;

  last_downloaded_bytes:=userdata;
  if (last_downloaded_bytes^<>info.total_downloaded) then begin
    if (info.status <> FZ_ACTUALIZING_VERIFYING_START) and (info.status <> FZ_ACTUALIZING_VERIFYING) then begin
      FZLogMgr.Get.Write('Downloaded '+inttostr(info.total_downloaded)+', state '+inttostr(cardinal(info.status)), FZ_LOG_DBG);
    end else begin
      if info.status = FZ_ACTUALIZING_VERIFYING_START then begin
        VersionAbstraction().AssignStatus('Verifying downloaded content...');
      end;
      FZLogMgr.Get.Write('Verified '+inttostr(info.total_downloaded)+', state '+inttostr(cardinal(info.status)), FZ_LOG_DBG);
    end;
    last_downloaded_bytes^:=info.total_downloaded;
  end;

  VersionAbstraction().SetVisualProgress(progress);
  result:=not VersionAbstraction().CheckForUserCancelDownload();
end;

function BuildFsGame(filename:string; settings:FZFsLtxBuilderSettings):boolean;
var
  f:textfile;
  opened:boolean;
  tmp:string;
begin
  result:=false;
  opened:=false;
  try
    assignfile(f, filename);
    rewrite(f);
    opened:=true;

    writeln(f,'$mnt_point$=false|false|$fs_root$|gamedata\');

    writeln(f,'$app_data_root$=false |false |$fs_root$|'+userdata_dir_name);
    writeln(f,'$parent_app_data_root$=false |false|'+VersionAbstraction().UpdatePath('$app_data_root$', ''));

    writeln(f,'$parent_game_root$=false|false|'+VersionAbstraction().UpdatePath('$fs_root$', ''));

    if (settings.full_install) then begin
      writeln(f,'$arch_dir$=false| false| $fs_root$');
      writeln(f,'$game_arch_mp$=false| false| $fs_root$| mp\');
      writeln(f,'$arch_dir_levels$=false| false| $fs_root$| levels\');
      writeln(f,'$arch_dir_resources$=false| false| $fs_root$| resources\');
      writeln(f,'$arch_dir_localization$=false| false| $fs_root$| localization\');
    end else begin
      if VersionAbstraction().PathExists('$arch_dir') then begin
        writeln(f,'$arch_dir$=false| false|'+VersionAbstraction().UpdatePath('$arch_dir$', ''));
      end;

      if VersionAbstraction().PathExists('$game_arch_mp$') then begin
        //SACE3 обладает нехорошей привычкой писать сюда db-файлы, одна ошибка - и неработоспособный клиент
        //У нас "безопасное" место для записи - это юзердата (даже в случае ошибки - брикнем мод, не игру)
        //Маппим $game_arch_mp$ в юзердату, а чтобы игра подхватывала оригинальные файлы с картами -
        //создадим еще одну запись
        writeln(f,'$game_arch_mp$=false| false|$app_data_root$');
        writeln(f,'$game_arch_mp_parent$=false| false|'+VersionAbstraction().UpdatePath('$game_arch_mp$', ''));
      end;

      if VersionAbstraction().PathExists('$arch_dir_levels$') then begin
        writeln(f,'$arch_dir_levels$=false| false|'+VersionAbstraction().UpdatePath('$arch_dir_levels$', ''));
      end;

      if VersionAbstraction().PathExists('$arch_dir_resources$') then begin
        writeln(f,'$arch_dir_resources$=false| false|'+VersionAbstraction().UpdatePath('$arch_dir_resources$', ''));
      end;

      if VersionAbstraction().PathExists('$arch_dir_localization$') then begin
       writeln(f,'$arch_dir_localization$=false| false|'+VersionAbstraction().UpdatePath('$arch_dir_localization$', ''));
      end;
    end;

    if VersionAbstraction().PathExists('$arch_dir_patches$') and settings.share_patches_dir then begin
      writeln(f,'$arch_dir_patches$=false| false|'+VersionAbstraction().UpdatePath('$arch_dir_patches$', ''));
      writeln(f,'$arch_dir_second_patches$=false|false|$fs_root$|patches\');
    end else begin
      writeln(f,'$arch_dir_patches$=false|false|$fs_root$|patches\');
    end;

    writeln(f,'$game_data$=false|true|$fs_root$|gamedata\');
    writeln(f,'$game_ai$=true|false|$game_data$|ai\');
    writeln(f,'$game_spawn$=true|false|$game_data$|spawns\');
    writeln(f,'$game_levels$=true|false|$game_data$|levels\');
    writeln(f,'$game_meshes$=true|true|$game_data$|meshes\|*.ogf;*.omf|Game Object files');
    writeln(f,'$game_anims$=true|true|$game_data$|anims\|*.anm;*.anms|Animation files');
    writeln(f,'$game_dm$=true|true|$game_data$|meshes\|*.dm|Detail Model files');
    writeln(f,'$game_shaders$=true|true|$game_data$|shaders\');
    writeln(f,'$game_sounds$=true|true|$game_data$|sounds\');
    writeln(f,'$game_textures$=true|true|$game_data$|textures\');

    if length(settings.configs_dir)>0 then begin
      writeln(f,'$game_config$=true|false|$game_data$|'+settings.configs_dir+'\');
    end else begin
      tmp:=VersionAbstraction().UpdatePath('$game_config$', '');
      if rightstr(tmp, length('config\')) = 'config\' then begin
        writeln(f,'$game_config$=true|false|$game_data$|config\');
      end else begin
        writeln(f,'$game_config$=true|false|$game_data$|configs\');
      end;
    end;
    writeln(f,'$game_weathers$=true|false|$game_config$|environment\weathers');
    writeln(f,'$game_weather_effects$=true|false|$game_config$|environment\weather_effects');
    writeln(f,'$textures$=true|true|$game_data$|textures\');
    writeln(f,'$level$=false|false|$game_levels$');
    writeln(f,'$game_scripts$=true|false|$game_data$|scripts\|*.script|Game script files');
    writeln(f,'$logs$=true|false|$app_data_root$|logs\');
    writeln(f,'$screenshots$=true|false|$app_data_root$|screenshots\');
    writeln(f,'$game_saves$=true|false|$app_data_root$|savedgames\');
    writeln(f,'$mod_dir$=false|false|$fs_root$|mods\');
    writeln(f,'$downloads$=false|false|$app_data_root$');
    result:=true;
  finally
    if (opened) then begin
      CloseFile(f);
    end;
  end;
end;

function CopyFileIfValid(src_path:string; dst_path:string; targetParams:FZCheckParams):boolean;
var
  fileCheckParams:FZCheckParams;
  dst_dir:string;
begin
  result:=false;
  if GetFileChecks(src_path, @fileCheckParams, length(targetParams.md5)>0) then begin
    if CompareFiles(fileCheckParams, targetParams) then begin
      dst_dir:=dst_path;
      while (dst_dir[length(dst_dir)]<>'\') and (dst_dir[length(dst_dir)]<>'/') do begin
        dst_dir:=leftstr(dst_dir,length(dst_dir)-1);
      end;
      ForceDirectories(dst_dir);

      if CopyFile(PAnsiChar(src_path), PAnsiChar(dst_path), false) then begin
        FZLogMgr.Get.Write('Copied '+src_path+' to '+dst_path, FZ_LOG_INFO);
        result:=true;
      end else begin
        FZLogMgr.Get.Write('Cannot copy file '+src_path+' to '+dst_path, FZ_LOG_ERROR);
      end;
    end else begin
      FZLogMgr.Get.Write('Checksum or size not equal to target', FZ_LOG_INFO);
    end;
  end;
end;

procedure PreprocessFiles(files:FZFiles; mod_root:string);
const
  NO_PRELOAD:string='-fz_nopreload';
var
  i:integer;
  e:FZFileItemData;
  core_root:string;
  filename:string;
  src, dst:string;
  disable_preload:boolean;
begin
  disable_preload:=(Pos(NO_PRELOAD, VersionAbstraction().GetCoreParams()) > 0);

  files.AddIgnoredFile(gamedata_files_list_name);
  files.AddIgnoredFile(engine_files_list_name);
  for i:=files.EntriesCount()-1 downto 0 do begin
    e:=files.GetEntry(i);
    if (leftstr(e.name, length(userdata_dir_name))=userdata_dir_name) and (e.required_action=FZ_FILE_ACTION_UNDEFINED) then begin
      //спасаем файлы юзердаты от удаления
      files.UpdateEntryAction(i, FZ_FILE_ACTION_IGNORE);
    end else if (leftstr(e.name, length(engine_dir_name))=engine_dir_name) and (e.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
      if not disable_preload then begin
        //Проверим, есть ли уже такой файл в текущем движке
        core_root:=VersionAbstraction().GetCoreApplicationPath();
        filename:=e.name;
        delete(filename,1,length(engine_dir_name));
        src:=core_root+filename;
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end else if (leftstr(e.name, length(patches_dir_name))=patches_dir_name) and (e.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
      if not disable_preload and VersionAbstraction().PathExists('$arch_dir_patches$') then begin
        //Проверим, есть ли уже такой файл в текущей копии игры
        filename:=e.name;
        delete(filename,1,length(patches_dir_name));
        src:=VersionAbstraction().UpdatePath('$arch_dir_patches$', filename);
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end else if (leftstr(e.name, length(mp_dir_name))=mp_dir_name) and (e.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
      if not disable_preload and VersionAbstraction().PathExists('$game_arch_mp$') then begin
        //Проверим, есть ли уже такой файл в текущей копии игры
        filename:=e.name;
        delete(filename,1,length(mp_dir_name));
        src:=VersionAbstraction().UpdatePath('$game_arch_mp$', filename);
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end;
  end;
end;

function CreateConfigBackup(filename:string):FZConfigBackup;
var
  f:handle;
  sz, readcnt:cardinal;
  success:boolean;
const
  MAX_LEN:cardinal = 1*1024*1024;
begin
  result.filename:='';
  result.buf:=nil;
  result.sz:=0;
  if length(filename) = 0 then exit;

  f:=CreateFile(PAnsiChar(filename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  FZLogMgr.Get.Write('Backup config '+filename+', handle '+inttostr(f), FZ_LOG_INFO);
  if f = INVALID_HANDLE_VALUE then begin
    FZLogMgr.Get.Write('Error opening file '+filename, FZ_LOG_ERROR);
    exit;
  end;

  try
    success:=false;
    readcnt:=0;

    sz:=GetFileSize(f, nil);
    FZLogMgr.Get.Write('Size of the config file '+filename+' is '+inttostr(sz), FZ_LOG_INFO);

    if sz > MAX_LEN then begin
      FZLogMgr.Get.Write('Config '+filename+' too large, skip it', FZ_LOG_ERROR);
      exit;
    end;

    result.buf:=VirtualAlloc(nil, sz, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
    if result.buf = nil then begin
      FZLogMgr.Get.Write('Error while allocating buffer for the config '+filename, FZ_LOG_ERROR);
      exit;
    end;

    if not ReadFile(f, result.buf[0], sz, readcnt, nil) or (sz <> readcnt) then begin
      FZLogMgr.Get.Write('Error reading file '+filename, FZ_LOG_ERROR);
      exit;
    end;

    result.sz:=sz;
    result.filename:=filename;
    success:=true;
  finally
    if not success then begin
      if result.buf<>nil then begin
        VirtualFree(result.buf, 0, MEM_RELEASE);
      end;

      result.filename:='';
      result.buf:=nil;
      result.sz:=0;
    end;
    CloseHandle(f);
  end;

end;

function FreeConfigBackup(backup:FZConfigBackup; need_restore:boolean):boolean;
var
  f:handle;
  writecnt:cardinal;
begin
  result:=false;
  if need_restore then begin
    f:=CreateFile(PAnsiChar(backup.filename), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    FZLogMgr.Get.Write('Restoring backup config '+backup.filename+', handle '+inttostr(f), FZ_LOG_INFO);

    if f = INVALID_HANDLE_VALUE then begin
      FZLogMgr.Get.Write('Error opening file '+backup.filename, FZ_LOG_ERROR);
    end else begin
      writecnt:=0;
      if not WriteFile(f, backup.buf[0], backup.sz, writecnt, nil) or (backup.sz<>writecnt) then begin
        FZLogMgr.Get.Write('Error writing file '+backup.filename, FZ_LOG_ERROR);
      end else begin
        result:=true;
      end;
      CloseHandle(f);
    end;
  end;

  if backup.buf<>nil then begin
    VirtualFree(backup.buf, 0, MEM_RELEASE);
  end;
end;

function DoWork(modname:string; modpath:string):boolean; //Выполняется в отдельном потоке
var
  ip:string;
  port:integer;
  files, files_cp:FZFiles;
  last_downloaded_bytes:int64;

  masterlinks_parse_result:FZMasterListApproveType;

  cmdline, cmdapp, workingdir:string;
  si:TStartupInfo;
  pi:TProcessInformation;
  srcname, dstname:string;

  fullPathToCurEngine:PAnsiChar;
  sz:cardinal;

  mod_settings:FZModSettings;
  mirrors:FZModMirrorsSettings;
  playername:string;

  message_initially_shown:boolean;

  add_params_file:textfile;
  add_params:string;
  mirror_id:integer;
  flag:boolean;
  old_gamelist, old_binlist:FZConfigBackup;
begin
  result:=false;

  message_initially_shown:=false;

  if ForceShowMessage(_mod_params) then begin
    message_initially_shown:=VersionAbstraction().IsMessageActive();
    FZLogMgr.Get.Write('Initial message status is ' + booltostr(message_initially_shown, true), FZ_LOG_INFO);
  end;

  //Пока идет коннект(существует уровень) - не начинаем работу
  while VersionAbstraction().CheckForLevelExist() do begin
    Sleep(10);
  end;

  //Пауза для нормального обновления мастер-листа
  Sleep(50); //Слип тут чтобы поток обновления гарантированно запустился - мало ли
  while VersionAbstraction().IsServerListUpdateActive() do begin
    Sleep(1);
  end;

  FZLogMgr.Get.Write('Starting visual download', FZ_LOG_INFO);
  if not VersionAbstraction().StartVisualDownload() then begin
    FZLogMgr.Get.Write('Cannot start visual download', FZ_LOG_ERROR);
    exit;
  end;

  VersionAbstraction().AssignStatus('Preparing synchronization...');
  VersionAbstraction().ResetMasterServerError();

  if ForceShowMessage(_mod_params) and message_initially_shown then begin
    //Ждем, пока исчезнет сообщение о коннекте к мастер-серверу
    while VersionAbstraction().IsServerListUpdateActive() do begin
      Sleep(1);
    end;

    //Дождемся подходящего для показа момента
    FZLogMgr.Get.Write('Prepare for message displaying', FZ_LOG_INFO);
    VersionAbstraction().PrepareForMessageShowing();

    //Включим его обратно
    FZLogMgr.Get.Write('Activating message', FZ_LOG_INFO);
    VersionAbstraction().TriggerMessage();
  end;

  //Получим путь к корневой (установочной) диектории мода
  mod_settings.modname:=modname;
  mod_settings.root_dir:=VersionAbstraction().UpdatePath('$app_data_root$', modpath);
  if (mod_settings.root_dir[length(mod_settings.root_dir)]<>'\') and (mod_settings.root_dir[length(mod_settings.root_dir)]<>'/') then begin
    mod_settings.root_dir:=mod_settings.root_dir+'\';
  end;
  FZLogMgr.Get.Write('Path to mod is ' + mod_settings.root_dir, FZ_LOG_INFO);

  if not ForceDirectories(mod_settings.root_dir) then begin
    FZLogMgr.Get.Write('Cannot create root directory', FZ_LOG_ERROR);
    exit;
  end;

  VersionAbstraction().AssignStatus('Parsing master links list...');

  ClearModMirrors(mirrors);
  masterlinks_parse_result:=DownloadAndParseMasterModsList(mod_settings, mirrors);
  if masterlinks_parse_result = FZ_MASTERLIST_NOT_APPROVED then begin
    FZLogMgr.Get.Write('Master links disallow running the mod!', FZ_LOG_ERROR);
    ClearModMirrors(mirrors);
    exit;
  end;

  VersionAbstraction().AssignStatus('Scanning directory...');

  //Просканируем корневую директорию на содержимое
  files := FZFiles.Create();
  if IsGameSpyDlForced(_mod_params) then begin
    files.SetDlMode(FZ_DL_MODE_GAMESPY);
  end else begin
    files.SetDlMode(FZ_DL_MODE_CURL);
  end;
  last_downloaded_bytes:=0;
  files.SetCallback(@DownloadCallback, @last_downloaded_bytes);
  if not files.ScanPath(mod_settings.root_dir) then begin
    FZLogMgr.Get.Write('Scanning root directory failed!', FZ_LOG_ERROR);
    files.Free;
    ClearModMirrors(mirrors);
    exit;
  end;

  //Создадим копию текущего состояния - пригодится при переборе зеркал
  files_cp:=FZFiles.Create();
  files_cp.Copy(files);
  //Также прочитаем и запомним содержимое binlist и gamelist - чтобы попробовать использовать старый конфиг, если ни одно из зеркал окажется недоступным.
  old_gamelist:=CreateConfigBackup(mod_settings.root_dir + gamedata_files_list_name);
  old_binlist:=CreateConfigBackup(mod_settings.root_dir + engine_files_list_name);

  mirror_id:=0;

  repeat
    files.Copy(files_cp);

    //Загрузим с сервера требуемую конфигурацию корневой директории и сопоставим ее с текущей
    FZLogMgr.Get.Write('=======Processing URLs combination #'+inttostr(mirror_id)+'=======', FZ_LOG_INFO);
    FZLogMgr.Get.Write('binlist: '+mod_settings.binlist_url, FZ_LOG_INFO);
    FZLogMgr.Get.Write('gamelist: '+mod_settings.gamelist_url, FZ_LOG_INFO);

    flag:=true;
    if (masterlinks_parse_result<>FZ_MASTERLIST_ONLY_OLD_CONFIG) and (length(mod_settings.gamelist_url)=0) then begin
      FZLogMgr.Get.Write('Empty game files list URL found!', FZ_LOG_ERROR);
      flag:=false;
    end;

    if (flag) then begin
      VersionAbstraction().AssignStatus('Verifying resources...');
      VersionAbstraction().SetVisualProgress(0);
      if not DownloadAndApplyFileList(mod_settings.gamelist_url, gamedata_files_list_name, mod_settings.root_dir, masterlinks_parse_result, files, true) then begin
        FZLogMgr.Get.Write('Applying game files list failed!', FZ_LOG_ERROR);
        flag:=false;
      end;
    end;

    if (flag) then begin
      VersionAbstraction().AssignStatus('Verifying engine...');
      if length(mod_settings.binlist_url)>0 then begin
        if not DownloadAndApplyFileList(mod_settings.binlist_url, engine_files_list_name, mod_settings.root_dir, masterlinks_parse_result, files, false) then begin
          FZLogMgr.Get.Write('Applying engine files list failed!', FZ_LOG_ERROR);
          flag:=false;
        end;
      end;
    end;

    if flag or (masterlinks_parse_result=FZ_MASTERLIST_ONLY_OLD_CONFIG) or IsMirrorsDisabled(_mod_params) then begin
      break;
    end;

    //Попытка использовать зеркало окончилась неудачей - пробуем следующее
    if (mirror_id < length(mirrors.binlist_urls)) then mod_settings.binlist_url:=mirrors.binlist_urls[mirror_id];
    if (mirror_id < length(mirrors.gamelist_urls)) then mod_settings.gamelist_url:=mirrors.gamelist_urls[mirror_id];

    mirror_id:=mirror_id+1;
  until (mirror_id > length(mirrors.binlist_urls)) or (mirror_id > length(mirrors.gamelist_urls));  //Внимание! Тут все верно! Не ставить больше либо равно - первая итерация берет ссылки не из mirrors!

  //Если не удалось скачать ни с одного из зеркал - пробуем запуститься с тем, что уже есть у нас
  if not flag and (masterlinks_parse_result<>FZ_MASTERLIST_ONLY_OLD_CONFIG) then begin
    FZLogMgr.Get.Write('Mirrors unavailable, trying to apply backup', FZ_LOG_INFO);
    files.Copy(files_cp);

    if FreeConfigBackup(old_gamelist, true) then begin
      flag:=DownloadAndApplyFileList('', gamedata_files_list_name, mod_settings.root_dir, FZ_MASTERLIST_ONLY_OLD_CONFIG, files, true);
    end;

    if flag and (old_binlist.sz<>0) then begin
      flag:=FreeConfigBackup(old_binlist, true) and DownloadAndApplyFileList('', engine_files_list_name, mod_settings.root_dir, FZ_MASTERLIST_ONLY_OLD_CONFIG, files, false);
    end else begin
      FreeConfigBackup(old_binlist, false);
    end;

  end else begin
    FreeConfigBackup(old_binlist, false);
    FreeConfigBackup(old_gamelist, false);
  end;

  ClearModMirrors(mirrors);
  files_cp.Free;

  if not flag then begin
    FZLogMgr.Get.Write('Cannot apply lists from the mirrors!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  //удалим файлы из юзердаты из списка синхронизируемых; скопируем доступные файлы вместо загрузки их
  FZLogMgr.Get.Write('=======Preprocessing files=======', FZ_LOG_INFO);

  VersionAbstraction().AssignStatus('Preprocessing files...');

  PreprocessFiles(files, mod_settings.root_dir);
  FZLogMgr.Get.Write('=======Sorting files=======', FZ_LOG_INFO);
  files.SortBySize();
  files.Dump(FZ_LOG_INFO);

  VersionAbstraction().AssignStatus('Downloading content...');

  //Выполним синхронизацию файлов
  FZLogMgr.Get.Write('=======Actualizing game data=======', FZ_LOG_INFO);
  if not files.ActualizeFiles() then begin
    FZLogMgr.Get.Write('Actualizing files failed!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  //Готово
  files.Free;

  VersionAbstraction().AssignStatus('Building fsltx...');

  FZLogMgr.Get.Write('Building fsltx', FZ_LOG_INFO);
  VersionAbstraction().SetVisualProgress(100);

  //Обновим fsgame
  FZLogMgr.Get.Write('full_install '+booltostr(mod_settings.fsltx_settings.full_install, true)+', shared patches '+booltostr(mod_settings.fsltx_settings.share_patches_dir, true), FZ_LOG_INFO);
  if not BuildFsGame(mod_settings.root_dir+fsltx_name, mod_settings.fsltx_settings) then begin
    FZLogMgr.Get.Write('Building fsltx failed!', FZ_LOG_ERROR);
    exit;
  end;

  VersionAbstraction().AssignStatus('Building userltx...');

  //если user.ltx отсутствует в userdata - нужно сделать его там
  if not FileExists(mod_settings.root_dir+userdata_dir_name+userltx_name) then begin
    FZLogMgr.Get.Write('Building userltx', FZ_LOG_INFO);
    //в случае с SACE команда на сохранение не срабатывает, поэтому сначала скопируем файл
    dstname:=mod_settings.root_dir+userdata_dir_name;
    ForceDirectories(dstname);
    dstname:=dstname+userltx_name;
    srcname:=VersionAbstraction().UpdatePath('$app_data_root$', 'user.ltx');
    FZLogMgr.Get.Write('Copy from '+srcname+' to '+dstname, FZ_LOG_INFO);
    CopyFile(PAnsiChar(srcname), PAnsiChar(dstname), false);
    VersionAbstraction().ExecuteConsoleCommand(PAnsiChar('cfg_save '+dstname));
  end;

  VersionAbstraction().AssignStatus('Running game...');

  //Надо стартовать игру с модом
  ip:=GetServerIp(_mod_params);
  if length(ip)=0 then begin
    FZLogMgr.Get.Write('Cannot determine IP address of the server', FZ_LOG_ERROR);
    exit;
  end;

  //Подготовимся к перезапуску
  FZLogMgr.Get.Write('Prepare to restart client', FZ_LOG_INFO);
  port:=GetServerPort(_mod_params);
  if (port<0) or (port>65535) then begin
    FZLogMgr.Get.Write('Cannot determine port', FZ_LOG_ERROR);
    exit;
  end;

  playername:='';
  if IsCmdLineNameNameNeeded(_mod_params) then begin
    playername:=VersionAbstraction().GetPlayerName();
    FZLogMgr.Get.Write('Using player name '+playername, FZ_LOG_INFO);
    playername:='/name='+playername;
  end;

  assignfile(add_params_file, additional_keys_line_file);
  try
    reset(add_params_file);
    try
      readln(add_params_file, add_params);
    finally
      closefile(add_params_file);
    end;
  except
    add_params:='';
  end;

  FZLogMgr.Get.Write('User-defined restart params: '+add_params, FZ_LOG_INFO);

  if length(mod_settings.binlist_url) > 0 then begin
    // Нестандартный двиг мода
    cmdapp:=mod_settings.root_dir+'bin\';
    if length(mod_settings.exe_name)>0 then begin
      cmdapp:=cmdapp+mod_settings.exe_name;
      cmdline:=mod_settings.exe_name;
    end else begin
      cmdapp:=cmdapp+VersionAbstraction().GetEngineExeFileName();
      cmdline:=VersionAbstraction().GetEngineExeFileName();
    end;

    //-fzmod - показывает имя мода; -fz_nomod - тключает загрузку модов (чтобы не впасть в рекурсию/старая версия)
    //так как проверка на имя мода идет первой, то все должно работать
    cmdline:= cmdline+' '+add_params+' -fz_nomod -fzmod '+mod_settings.modname+' -start client('+ip+'/port='+inttostr(port)+playername+')';
    workingdir:=mod_settings.root_dir;
  end else begin
    // Используем текущий двиг
    sz :=128;
    fullPathToCurEngine:=nil;
    repeat
      if fullPathToCurEngine <> nil then FreeMem(fullPathToCurEngine, sz);
      sz:=sz*2;
      GetMem(fullPathToCurEngine, sz);
      if fullPathToCurEngine = nil then exit;
    until GetModuleFileName(VersionAbstraction().GetEngineExeModuleAddress(), fullPathToCurEngine, sz) < sz-1;
    cmdapp:=fullPathToCurEngine;
    workingdir:=mod_settings.root_dir;
    cmdline:= VersionAbstraction().GetEngineExeFileName()+' '+add_params+' -fz_nomod -fzmod '+mod_settings.modname+' -wosace -start client('+ip+'/port='+inttostr(port)+playername+')';
    FreeMem(fullPathToCurEngine, sz);
  end;

  //Точка невозврата. Убедимся, что пользователь не отменил загрузку
  if VersionAbstraction().CheckForUserCancelDownload() then begin
    FZLogMgr.Get().Write('Cancelled by user', FZ_LOG_ERROR);
    exit;
  end;

  FZLogMgr.Get.Write('cmdapp: '+cmdapp, FZ_LOG_INFO);
  FZLogMgr.Get.Write('cmdline: '+cmdline, FZ_LOG_INFO);

  FillMemory(@si, sizeof(si),0);
  FillMemory(@pi, sizeof(pi),0);
  si.cb:=sizeof(si);

  //Прибьем блокирующий запуск нескольких копий сталкера мьютекс
  KillMutex();

  //Запустим клиента
  if (not CreateProcess(PAnsiChar(cmdapp), PAnsiChar(cmdline), nil, nil, false, CREATE_SUSPENDED, nil, PAnsiChar(workingdir),si, pi)) then begin
    FZLogMgr.Get.Write('Cannot run application', FZ_LOG_ERROR);
  end else begin
    ResumeThread(pi.hThread);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    result:=true;
  end;
end;

procedure DecompressorLogger(text:PAnsiChar); stdcall;
const
  DECOMPRESS_LBL:string='[DECOMPR]';
begin
  FZLogMgr.Get.Write(DECOMPRESS_LBL+text, FZ_LOG_INFO);
end;

function InitModules():boolean;
begin
  result:=true;
  // Init low-level
  result:=result and abstractions.Init();
  result:=result and Decompressor.Init(@DecompressorLogger);
  // Init high-level
  result:=result and LogMgr.Init();

  FZLogMgr.Get.SetSeverity(FZ_LOG_INFO);
  FZLogMgr.Get.Write('Modules inited', FZ_LOG_INFO);
end;

procedure FreeStringMemory();
begin
  if _mod_name <> nil then VirtualFree(_mod_name, 0, MEM_RELEASE);
  if _mod_rel_path <> nil then VirtualFree(_mod_rel_path, 0, MEM_RELEASE);
  if _mod_params <> nil then VirtualFree(_mod_params, 0, MEM_RELEASE);
end;

function AllocateStringMemory():boolean;
begin
  //Выделим память под аргументы
  _mod_name:=VirtualAlloc(nil, MAX_NAME_SIZE, MEM_COMMIT, PAGE_READWRITE);
  _mod_rel_path:=VirtualAlloc(nil, MAX_NAME_SIZE, MEM_COMMIT, PAGE_READWRITE);
  _mod_params:=VirtualAlloc(nil, MAX_PARAMS_SIZE, MEM_COMMIT, PAGE_READWRITE);

  result:=(_mod_rel_path <> nil) and (_mod_params<>nil) and (_mod_rel_path<>nil);
  if not result then begin
    FreeStringMemory();
  end;
end;

procedure FreeModules();
begin
  FZLogMgr.Get.Write('Free modules', FZ_LOG_INFO);
  Decompressor.Free();
  LogMgr.Free();
  abstractions.Free();
end;

function ThreadBody_internal():boolean; stdcall;
var
  mutex:HANDLE;
  i:cardinal;
begin
  result:=false;

  //Убедимся, что нам разрешено выделить ресурсы
  mutex:=CreateMutex(nil, FALSE, fz_loader_modules_mutex_name);
  if (mutex = 0) or (mutex = INVALID_HANDLE_VALUE) then begin
    exit;
  end;

  if WaitForSingleObject(mutex, INFINITE) <> WAIT_OBJECT_0 then begin
    CloseHandle(mutex);
    exit;
  end;

  if not InitModules() then begin
    ReleaseMutex(mutex);
    CloseHandle(mutex);
    exit;
  end;

  FZLogMgr.Get.SetSeverity(FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write( 'FreeZone Mod Loader', FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write( 'Build date: ' + {$INCLUDE %DATE}, FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write( 'Mod name is "'+_mod_name+'"', FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write( 'Mod params "'+_mod_params+'"', FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.SetSeverity(GetLogSeverity(_mod_params));
  FZLogMgr.Get.Write('Working thread started', FZ_LOG_INFO);

  result:=DoWork(_mod_name, _mod_rel_path);

  if not result then begin
    FZLogMgr.Get.Write('Loading failed!', FZ_LOG_ERROR);
    VersionAbstraction().SetVisualProgress(0);
    if VersionAbstraction().IsMessageActive() then begin
      VersionAbstraction().TriggerMessage();
    end;
    VersionAbstraction().AssignStatus('Downloading failed. Try again.');

    i:=0;
    while (i<10000) and (not VersionAbstraction.CheckForUserCancelDownload()) and (not VersionAbstraction.CheckForLevelExist()) do begin
      Sleep(1);
      i:=i+1;
    end;
    VersionAbstraction().StopVisualDownload();
  end;

  FZLogMgr.Get.Write('Releasing resources', FZ_LOG_INFO);
  VersionAbstraction().ExecuteConsoleCommand(PAnsiChar('flush'));

  FreeStringMemory();
  FreeModules();

  ReleaseMutex(mutex);
  CloseHandle(mutex);
end;

//Похоже, компиль не просекает, что FreeLibraryAndExitThread не возвращает управление. Из-за этого локальные переменные оказываются
//не зачищены, и это рушит нам приложение. Для решения вопроса делаем свой асмовый враппер, лишенный указанных недостатков.
function ThreadBody():dword; stdcall;
asm
  call ThreadBody_internal

  push [_dll_handle]
  push eax

  //Хэндл ДЛЛ надо занулить до освобождения семафора, но саму ДЛЛ выгрузить уже в самом конце - поэтому он сохранен в стеке
  mov _dll_handle, dword 0

  push [_fz_loader_semaphore_handle] // для вызова CloseHandle
  push dword 0
  push dword 1
  push [_fz_loader_semaphore_handle]
  mov [_fz_loader_semaphore_handle], 0
  call ReleaseSemaphore
  call CloseHandle

  pop eax //Результат работы
  pop ebx //сохраненный хэндл
  cmp al, 0
  je @error_happen
  push dword 0
  call dword GetCurrentProcess
  push eax
  call TerminateProcess

  @error_happen:
  push dword 0
  push ebx
  call FreeLibraryAndExitThread
end;

function RunModLoad():boolean;
var
  path:string;
begin
  result:=false;

  //Захватим ДЛЛ для предотвращения выгрузки во время работы потока загрузчика
  path:=SysUtils.GetModuleName(HInstance);
  FZLogMgr.Get.Write('Path to loader is: '+path, FZ_LOG_INFO);
  _dll_handle:=LoadLibrary(PAnsiChar(path));
  if _dll_handle = 0 then begin
    FZLogMgr.Get().Write('Cannot acquire DLL '+path, FZ_LOG_ERROR);
    exit;
  end;

  //Начинаем синхронизацию файлов мода в отдельном потоке
  FZLogMgr.Get().Write('Starting working thread', FZ_LOG_INFO);

  if not VersionAbstraction().ThreadSpawn(uintptr(@ThreadBody), 0) then begin
    FZLogMgr.Get().Write('Cannot start thread', FZ_LOG_ERROR);
    FreeLibrary(_dll_handle);
    _dll_handle:=0;
    exit;
  end;

  result:=true;
end;

procedure AbortConnection();
begin
  FZLogMgr.Get().Write('Aborting connection', FZ_LOG_DBG);
  VersionAbstraction.AbortConnection();
end;

function ValidateInput(mod_name:PAnsiChar; mod_params:PAnsiChar):boolean;
var
  i:cardinal;
begin
  result:=false;

  if Int64(length(mod_name))+Int64(length(mod_dir_prefix))>=Int64(MAX_NAME_SIZE-1) then begin
    FZLogMgr.Get.Write('Too long mod name, exiting', FZ_LOG_ERROR);
    exit;
  end;

  if length(mod_params)>=MAX_PARAMS_SIZE-1 then begin
    FZLogMgr.Get.Write('Too long mod params, exiting', FZ_LOG_ERROR);
    exit;
  end;

  i:=0;
  while(mod_name[i]<>chr(0)) do begin
    if pos(mod_name[i], allowed_symbols_in_mod_name) = 0 then begin
      FZLogMgr.Get.Write('Invalid mod name, exiting', FZ_LOG_ERROR);
      exit;
    end;
    i:=i+1;
  end;

  result:=true;
end;

function ModLoad_internal(mod_name:PAnsiChar; mod_params:PAnsiChar):FZDllModFunResult; stdcall;
var
  mutex:HANDLE;
begin
  result:=FZ_DLL_MOD_FUN_FAILURE;
  mutex:=CreateMutex(nil, FALSE, fz_loader_modules_mutex_name);
  if (mutex = 0) or (mutex = INVALID_HANDLE_VALUE) then begin
    exit;
  end;

  if WaitForSingleObject(mutex, 0) = WAIT_OBJECT_0 then begin
    //Отлично, основной поток закачки не стартует, пока мы не отпустим мьютекс
    if InitModules() then begin
      AbortConnection();

      if ValidateInput(mod_name, mod_params) then begin
        if AllocateStringMemory() then begin
          StrCopy(_mod_name, mod_name);
          StrCopy(_mod_params, mod_params);

          FZLogMgr.Get.SetSeverity(GetLogSeverity(mod_params));

          //Благодаря этому хаку с префиксом, игра не полезет подгружать файлы мода при запуске оригинального клиента
          StrCopy(_mod_rel_path, mod_dir_prefix);
          StrCopy(@_mod_rel_path[length(mod_dir_prefix)], mod_name);

          if RunModLoad() then begin
            // Не лочимся - загрузка может окончиться неудачно либо быть отменена
            // кроме того, повторный коннект при активной загрузке и выставленной инфе о моде приведет к неожиданным результатам
            result:=FZ_DLL_MOD_FUN_SUCCESS_NOLOCK
          end else begin
            FreeStringMemory();
          end;
        end else begin
          FZLogMgr.Get.Write('Cannot allocate string memory!', FZ_LOG_ERROR);
        end;
      end;

      //Основной поток закачки сам проинициализирует их заново - если не освобождать, происходит какая-то фигня при освобождении из другого потока.
      FreeModules();
    end;
    ReleaseMutex(mutex);
    CloseHandle(mutex);
  end;
end;

//Схема работы загрузчика с ипользованием с мастер-списка модов:
// 1) Скачиваем мастер-список модов
// 2) Если мастер-список скачан и мод с таким названием есть в списке - используем ссылки на движок и геймдату
//    из этого списка; если заданы кастомные и не совпадающие с теми, которые в списке - ругаемся и не работаем
// 3) Если мастер-список скачан, но мода с таким названием в нем нет - убеждаемся, что ссылка на движок либо не
//    задана (используется текущий), либо есть среди других модов, либо на клиенте активен дебаг-режим. Если не
//    выполняется ничего из этого - ругаемся и не работаем, если выполнено - используем указанные ссылки
// 4) Если мастер-список НЕ скачан - убеждаемся, что ссылка на движок либо не задана (надо использовать текущий),
//    либо активен дебаг-режим на клиенте. Если это не выполнено - ругаемся и не работаем, иначе используем
//    предоставленные пользователем ссылки.
// 5) Скачиваем сначала геймдатный список, затем движковый (чтобы не дать возможность переопределить в первом файлы второго)
// 6) Актуализируем файлы и рестартим клиент

//Доступные ключи запуска, передающиеся в mod_params:
//-binlist <URL> - ссылка на адрес, по которому берется список файлов движка (для работы требуется запуск клиента с ключлм -fz_custom_bin)
//-gamelist <URL> - ссылка на адрес, по которому берется список файлов мода (геймдатных\патчей)
//-srv <IP> - IP-адрес сервера, к которому необходимо присоединиться после запуска мода
//-srvname <domainname> - доменное имя, по которому располагается сервер. Можно использовать вместо параметра -srv в случае динамического IP сервера
//-port <number> - порт сервера
//-gamespymode - стараться использовать загрузку средствами GameSpy
//-fullinstall - мод представляет собой самостоятельную копию игры, связь с файлами оригинальной не требуется
//-sharedpatches - использовать общую с инсталляцией игры директорию патчей
//-logsev <number> - уровень серьезности логируемых сообщений, по умолчанию FZ_LOG_ERROR
//-configsdir <string> - директория конфигов
//-exename <string> - имя исполняемого файла мода
//-includename - включить в строку запуска мода параметр /name= с именем игрока
//-preservemessage - показывать окно с сообщением о загрузке мода
//-nomirrors - запретить скачивание списков файлов мода с URL, отличающихся от указанных в ключах -binlist/-gamelist

function ModLoad(mod_name:PAnsiChar; mod_params:PAnsiChar):FZDllModFunResult; stdcall;
var
  semaphore:HANDLE;
begin
  result:=FZ_DLL_MOD_FUN_FAILURE;
  semaphore := CreateSemaphore(nil, 1, 1, fz_loader_semaphore_name);
  if (semaphore = INVALID_HANDLE_VALUE) or ( semaphore = 0 ) then begin
    exit;
  end;

  if (WaitForSingleObject(semaphore, 0) = WAIT_OBJECT_0) then begin
    //Отлично, семафор наш. Сохраним хендл на него для последующего освобождения
    _fz_loader_semaphore_handle:=semaphore;

    _dll_handle:=0;
    result:=ModLoad_internal(mod_name, mod_params);

    //В случае успеха семафор будет разлочен в другом треде после окончания загрузки.
    if result = FZ_DLL_MOD_FUN_FAILURE then begin
      if _dll_handle <> 0 then begin
        FreeLibrary(_dll_handle);
        _dll_handle:=0;
      end;

      _fz_loader_semaphore_handle:=INVALID_HANDLE_VALUE;
      ReleaseSemaphore(semaphore, 1, nil);
      CloseHandle(semaphore);
    end;
  end else begin
    //Не повезло, сворачиваемся.
    CloseHandle(semaphore);
  end;

end;

{$IFNDEF RELEASE}
procedure ModLoadTest(); stdcall;
begin
  //ModLoad('sace3', ' -srvname localhost -srvport 5449 -includename'{ ' -srvname localhost -srvport 5449 '});
  ModLoad('fz_test', ' -srvname localhost -srvport 5449 -includename'{ ' -srvname localhost -srvport 5449 '});
end;
{$ENDIF}

exports
{$IFNDEF RELEASE}
  ModLoadTest,
{$ENDIF}
  ModLoad;

{$R *.res}

begin
  _dll_handle:=0;
end.

