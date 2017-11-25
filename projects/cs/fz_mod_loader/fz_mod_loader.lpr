library fz_mod_loader;

{$mode delphi}{$H+}

uses
  xrfilesystem, basedefs, global_functions, LogMgr, srcBase, sysutils, windows,
  FileManager, HttpDownloader, IniFile, Level, Servers, GamePersistent,
  MainMenu, xrstrings, GameSpySystem, UI, RenderDevice, UIWindows, Fonts,
  Synchro, Console, Statistics, safesync, GameCore, Decompressor,
  CommandLineParser, mutexhunter;

type
  FZMasterLinkListAddr = array of string;

var
  _mod_rel_path:PChar;
  _mod_name:PChar;
  _mod_params:PChar;
  _dll_handle:HINST;
  _lock:LongInt;

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

procedure ShowMpMainMenu({%H-}junk:pCMainMenu);
var
  main_menu:pCMainMenu;
const
  MP_MENU_CMD:cardinal = 2;
  MP_MENU_PARAM:cardinal = 1;
begin
  //Включим главное меню на вкладке мультиплеера(ползунок загрузки есть только там)
  main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
  if (main_menu<>nil) then begin
    virtual_IMainMenu__Activate.Call([@main_menu.base_IMainMenu, false]);
    virtual_IMainMenu__Activate.Call([@main_menu.base_IMainMenu, true]);
    virtual_CUIDialogWnd__Dispatch.Call([main_menu.m_startDialog, MP_MENU_CMD, MP_MENU_PARAM]);
  end;
end;

procedure AssignStatus(str:PChar);
var
  main_menu:pCMainMenu;
begin
  main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
  if main_menu <> nil then begin
    assign_string(@main_menu.m_sPDProgress.FileName, str);
    assign_string(@main_menu.m_sPDProgress.Status, str);
  end;
end;

function CreateDownloaderThreadForUrl(url:PAnsiChar):FZDownloaderThread;
begin
  if IsGameSpyDlForced(_mod_params) and (leftstr(url, length('https')) <> 'https') then begin
    FZLogMgr.Get.Write('Creating GS dl thread', FZ_LOG_DBG);
    result:=FZGameSpyDownloaderThread.Create();
  end else begin
    FZLogMgr.Get.Write('Creating CURL dl thread', FZ_LOG_DBG);
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

function DownloadAndParseMasterModsList(root_dir:string; modname:string; var binlist:string; var gamelist:string):boolean;
var
  master_links:FZMasterLinkListAddr;
  list_downloaded:boolean;
  th:FZDownloaderThread;
  dl:FZFileDownloader;
  i:integer;
  full_path:string;
  cfg:FZIniFile;
  params_approved:boolean;
  params_binlist, params_gamelist:string;
  core_params:string;
const
  DEBUG_MODE_KEY:string='-fz_customlists';
  MASTERLINKS_BINLIST_KEY = 'binlist';
  MASTERLINKS_GAMELIST_KEY = 'gamelist';
begin
  result:=false;

  PushToArray(master_links, 'https://raw.githubusercontent.com/FreeZoneMods/modmasterlinks/master/links.ini');
  PushToArray(master_links, 'http://stalker.gamepolis.ru/mods_clear_sky/links.ini');

  list_downloaded:=false;
  full_path:= root_dir+master_mods_list_name;

  th:=CreateDownloaderThreadForUrl(PAnsiChar(master_links[0]));
  for i:=0 to length(master_links)-1 do begin
    dl:=th.CreateDownloader(master_links[i], full_path, 0);
    list_downloaded:=dl.StartSyncDownload();
    dl.Free;
    if list_downloaded then break;
  end;

  params_binlist:=GetCustomBinUrl(_mod_params);
  params_gamelist:=GetCustomGamedataUrl(_mod_params);
  params_approved:=false;
  if list_downloaded then begin
    // Мастер-список успешно скачался, будем парсить его содержимое
    cfg:=FZIniFile.Create(full_path);
    for i:=0 to cfg.GetSectionsCount()-1 do begin
      if cfg.GetSectionName(i) = modname then begin
        if (length(params_binlist) > 0) and (params_binlist <> cfg.GetStringDef(modname, MASTERLINKS_BINLIST_KEY, '')) then begin
          FZLogMgr.Get.Write('Master binlist link differs from specified in mod parameters', FZ_LOG_ERROR);
          params_approved:=false;
          break;
        end else if (length(params_gamelist)>0) and (params_gamelist <> cfg.GetStringDef(modname, MASTERLINKS_GAMELIST_KEY, '')) then begin
          FZLogMgr.Get.Write('Master gamelist link differs from specified in mod parameters', FZ_LOG_ERROR);
          params_approved:=false;
          break;
        end;
        params_gamelist := cfg.GetStringDef(modname, MASTERLINKS_GAMELIST_KEY, '');
        params_binlist  := cfg.GetStringDef(modname, MASTERLINKS_BINLIST_KEY,  '');
        params_approved := true;
        break;
      end else if (not params_approved) and ( (length(params_binlist) = 0) or (params_binlist = cfg.GetStringDef(cfg.GetSectionName(i), MASTERLINKS_BINLIST_KEY, ''))) then begin
        // Ссылка на движок нас удовлетворяет, но надо продолжать проверять остальные секции
        params_approved:=true;
      end;
    end;
    cfg.Free;
  end else begin
    //Список почему-то не скачался. Ограничимся геймдатными модами.
    params_approved:=( length(params_binlist) = 0);
  end;

  core_params:=PAnsiChar(@Core.Params[0]);
  if params_approved or (Pos(DEBUG_MODE_KEY, core_params)>0) then begin
    binlist:=params_binlist;
    gamelist:=params_gamelist;
    result:=true;
  end;

end;

function DownloadAndApplyFileList(url:string; list_filename:string; root_dir:string; fileList:FZFiles):boolean;
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
  starttime:cardinal;
begin
  result:=false;
  if length(url)=0 then begin
    FZLogMgr.Get.Write('No list URL specified', FZ_LOG_ERROR);
    exit;
  end;

  filepath:=root_dir+list_filename;
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

  cfg:=FZIniFile.Create(filepath);
  files_count:=cfg.GetIntDef('main', 'files_count', 0);
  if files_count = 0 then begin
    FZLogMgr.Get.Write('No files in file list', FZ_LOG_ERROR);
    exit;
  end;

  starttime:=GetCurrentTime();
  result:=false;
  for i:=0 to files_count-1 do begin
    section:='file_'+inttostr(i);
    FZLogMgr.Get.Write('Parsing section '+section, FZ_LOG_DBG);
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
  end;
  FZLogMgr.Get.Write('File list "'+list_filename+'" processed, time '+inttostr(GetCurrentTime()-starttime)+' ms', FZ_LOG_INFO);

  cfg.Free;
  result:=true;
end;

function DownloadCallback(info:FZFileActualizingProgressInfo; userdata:pointer):boolean;
var
  main_menu:pCMainMenu;
  progress:single;
  ready:int64;
  last_downloaded_bytes:pcardinal;
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
    FZLogMgr.Get.Write('Downloaded '+inttostr(info.total_downloaded)+', state '+inttostr(cardinal(info.status)));
    last_downloaded_bytes^:=info.total_downloaded;
  end;

  main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
  if main_menu<>nil then begin
    main_menu.m_sPDProgress.Progress:=progress;
    result:=(main_menu.m_sPDProgress.IsInProgress<>0);
  end else begin
    result:=false;
  end;
end;

function BuildFsGame(filename:string):boolean;
var
  f:textfile;
  opened:boolean;
begin
  result:=false;
  opened:=false;
  try
    assignfile(f, filename);
    rewrite(f);
    opened:=true;

    writeln(f,'$app_data_root$=false |false |$fs_root$|'+userdata_dir_name);
    writeln(f,'$parent_app_data_root$=false |false|'+UpdatePath('$app_data_root$', ''));
    writeln(f,'$arch_dir$=false| false|'+UpdatePath('$arch_dir$', ''));

    //SACE3 обладает нехорошей привычкой писать сюда db-файлы, одна ошибка - и неработоспособный клиент
    //У нас "безопасное" место для записи - это юзердата (даже в случае ошибки - брикнем мод, не игру)
    //Маппим $game_arch_mp$ в юзердату, а чтобы игра подхватывала оригинальные файлы с картами -
    //создадим еще одну запись
    writeln(f,'$game_arch_mp$=false| false|$app_data_root$');
    writeln(f,'$game_arch_mp_parent$=false| false|'+UpdatePath('$game_arch_mp$', ''));

    writeln(f,'$arch_dir_levels$=false| false|'+UpdatePath('$arch_dir_levels$', ''));
    writeln(f,'$arch_dir_resources$=false| false|'+UpdatePath('$arch_dir_resources$', ''));
    writeln(f,'$arch_dir_localization$=false| false|'+UpdatePath('$arch_dir_localization$', ''));
    writeln(f,'$arch_dir_patches$=false|false|$fs_root$|patches\');
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
    writeln(f,'$game_config$=true|false|$game_data$|configs\');
    writeln(f,'$game_weathers$=true|false|$game_config$|environment\weathers');
    writeln(f,'$game_weather_effects$=true|false|$game_config$|environment\weather_effects');
    writeln(f,'$textures$=true|true|$game_data$|textures\');
    writeln(f,'$level$=false|false|$game_levels$');
    writeln(f,'$game_scripts$=true|false|$game_data$|scripts\|*.script|Game script files');
    writeln(f,'$logs$=true|false|$app_data_root$|logs\');
    writeln(f,'$screenshots$=true|false|$app_data_root$|screenshots\');
    writeln(f,'$game_saves$=true|false|$app_data_root$|savedgames\');
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
        FZLogMgr.Get.Write('Copied '+src_path+' to '+dst_path, FZ_LOG_DBG);
        result:=true;
      end else begin
        FZLogMgr.Get.Write('Cannot copy file '+src_path+' to '+dst_path, FZ_LOG_ERROR);
      end;
    end else begin
      FZLogMgr.Get.Write('Checksum or size not equal to target', FZ_LOG_DBG);
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
  disable_preload:=(Pos(NO_PRELOAD, Core.Params) > 0);

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
        core_root:=Core.ApplicationPath;
        filename:=e.name;
        delete(filename,1,length(engine_dir_name));
        src:=core_root+filename;
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end else if (leftstr(e.name, length(patches_dir_name))=patches_dir_name) and (e.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
      if not disable_preload then begin
        //Проверим, есть ли уже такой файл в текущей копии игры
        filename:=e.name;
        delete(filename,1,length(patches_dir_name));
        src:=UpdatePath('$arch_dir_patches$', filename);
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end else if (leftstr(e.name, length(mp_dir_name))=mp_dir_name) and (e.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
      if not disable_preload then begin
        //Проверим, есть ли уже такой файл в текущей копии игры
        filename:=e.name;
        delete(filename,1,length(mp_dir_name));
        src:=UpdatePath('$game_arch_mp$', filename);
        dst:=mod_root+e.name;
        if CopyFileIfValid(src, dst, e.target) then begin
          files.UpdateEntryAction(i, FZ_FILE_ACTION_NO);
        end;
      end;
    end;
  end;
end;

function DoWork(modname:string; modpath:string):boolean; //Выполняется в отдельном потоке
var
  path, ip:string;
  port:integer;
  files:FZFiles;
  last_downloaded_bytes:int64;
  main_menu:pCMainMenu;

  cmdline, cmdapp, workingdir:string;
  si:TStartupInfo;
  pi:TProcessInformation;
  tmp:cardinal;
  srcname, dstname:string;

  gamelist_url, binlist_url:string;

  fullPathToCurEngine:PAnsiChar;
  sz:cardinal;

begin
  result:=false;
  //Пока идет коннект(существует уровень) - не начинаем работу
  while pCLevel(g_ppGameLevel^)<>nil do begin
    Sleep(10);
  end;

  main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
  if main_menu=nil then begin
    FZLogMgr.Get.Write('Main menu is nil', FZ_LOG_ERROR);
    exit;
  end;

  repeat
    Sleep(10);
    //Атомарно выставим активность загрузки и получим предыдущее значение (только в младшем байте, остальное мусор!)
    tmp:=AtomicExchange(@main_menu.m_sPDProgress.IsInProgress, 1) and $FF;
    //Убедимся, что загрузку до нас никто еще не стартовал, пока мы ждали захват мьютекса
  until tmp=0;

  main_menu.m_sPDProgress.Progress:=0;

  //На случай нажатия кнопки отмена - укажем, что активного запроса о загрузке не было
  main_menu.m_pGameSpyFull.m_pGS_HTTP.m_LastRequest:=cardinal(-1);

  //Включим главное меню на вкладке мультиплеера(ползунок загрузки есть только там)
  SafeExec(@ShowMpMainMenu);

  //Получим путь к корневой (установочной) диектории мода
  path:=UpdatePath('$app_data_root$', modpath);
  if (path[length(path)]<>'\') and (path[length(path)]<>'/') then begin
    path:=path+'\';
  end;
  FZLogMgr.Get.Write('Path to mod is ' + path, FZ_LOG_DBG);

  if not ForceDirectories(path) then begin
    FZLogMgr.Get.Write('Cannot create root directory', FZ_LOG_ERROR);
    exit;
  end;

  SafeExec(@AssignStatus, PChar('Parsing master links list...'));
  if not DownloadAndParseMasterModsList(path, modname, binlist_url, gamelist_url) then begin
    FZLogMgr.Get.Write('Parsing master links list failed!', FZ_LOG_ERROR);
    exit;
  end;


  SafeExec(@AssignStatus, PChar('Scanning directory...'));
  //Просканируем корневую директорию на содержимое
  files := FZFiles.Create();
  if IsGameSpyDlForced(_mod_params) then begin
    files.SetDlMode(FZ_DL_MODE_GAMESPY);
  end else begin
    files.SetDlMode(FZ_DL_MODE_CURL);
  end;
  last_downloaded_bytes:=0;
  files.SetCallback(@DownloadCallback, @last_downloaded_bytes);
  if not files.ScanPath(path) then begin
    FZLogMgr.Get.Write('Scanning root directory failed!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  SafeExec(@AssignStatus, PChar('Verifying installation...'));
  //Загрузим с сервера требуемую конфигурацию корневой директории и сопоставим ее с текущей
  FZLogMgr.Get.Write('=======Processing game resources list=======', FZ_LOG_INFO);
  if length(gamelist_url)=0 then begin
    FZLogMgr.Get.Write('Empty game files list URL found!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  if not DownloadAndApplyFileList(gamelist_url, gamedata_files_list_name, path, files) then begin
    FZLogMgr.Get.Write('Applying game files list failed!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  if length(binlist_url)>0 then begin
    if not DownloadAndApplyFileList(binlist_url, engine_files_list_name, path, files) then begin
      FZLogMgr.Get.Write('Applying engine files list failed!', FZ_LOG_ERROR);
      files.Free;
      exit;
    end;
  end;

  //удалим файлы из юзердаты из списка синхронизируемых; скопируем доступные файлы вместо загрузки их
  FZLogMgr.Get.Write('=======Preprocessing files=======', FZ_LOG_INFO);
  SafeExec(@AssignStatus, PChar('Preprocessing files...'));
  PreprocessFiles(files, path);
  files.Dump(FZ_LOG_INFO);

  SafeExec(@AssignStatus, PChar('Downloading content...'));
  //Выполним синхронизацию файлов
  FZLogMgr.Get.Write('=======Actualizing game data=======', FZ_LOG_INFO);
  if not files.ActualizeFiles() then begin
    FZLogMgr.Get.Write('Actualizing files failed!', FZ_LOG_ERROR);
    files.Free;
    exit;
  end;

  //Готово
  files.Free;

  SafeExec(@AssignStatus, PChar('Building fsltx...'));
  FZLogMgr.Get.Write('Building fsltx', FZ_LOG_DBG);
  main_menu.m_sPDProgress.Progress:=100;

  //Обновим fsgame
  if not (BuildFsGame(path+fsltx_name)) then begin
    FZLogMgr.Get.Write('Building fsltx failed!', FZ_LOG_ERROR);
    exit;
  end;

  SafeExec(@AssignStatus, PChar('Building userltx...'));
  //если user.ltx отсутствует в userdata - нужно сделать его там
  if not FileExists(path+userdata_dir_name+userltx_name) then begin
    FZLogMgr.Get.Write('Building userltx', FZ_LOG_DBG);
    //в случае с SACE команда на сохранение не срабатывает, поэтому сначала скопируем файл
    dstname:=path+userdata_dir_name;
    ForceDirectories(dstname);
    dstname:=dstname+userltx_name;
    srcname:=UpdatePath('$app_data_root$', 'user.ltx');
    FZLogMgr.Get.Write('Copy from '+srcname+' to '+dstname, FZ_LOG_DBG);
    CopyFile(PAnsiChar(srcname), PAnsiChar(dstname), false);
    ExecuteConsoleCommand(PAnsiChar('cfg_save '+dstname));
  end;

  SafeExec(@AssignStatus, PChar('Running game...'));
  //Надо стартовать игру с модом
  ip:=GetServerIp(_mod_params);
  if length(ip)=0 then begin
    FZLogMgr.Get.Write('Cannot determine IP address of the server', FZ_LOG_ERROR);
    exit;
  end;

  //Подготовимся к перезапуску
  FZLogMgr.Get.Write('Prepare to restart client '+cmdapp+' '+cmdline);
  port:=GetServerPort(_mod_params);
  if (port<0) or (port>65535) then begin
    FZLogMgr.Get.Write('Cannot determine port', FZ_LOG_ERROR);
    exit;
  end;

  if length(binlist_url) > 0 then begin
    // Нестандартный двиг мода
    cmdapp:=path+'bin\xrEngine.exe';
    //-fzmod - показывает имя мода; -fz_nomod - тключает загрузку модов (чтобы не впасть в рекурсию/старая версия)
    //так как проверка на имя мода идет первой, то все должно работать
    cmdline:= 'xrEngine.exe -fz_nomod -fzmod '+modname+' -start client('+ip+'/port='+inttostr(port)+')';
    workingdir:=path;
  end else begin
    // Используем текущий двиг
    sz :=128;
    fullPathToCurEngine:=nil;
    repeat
      if fullPathToCurEngine <> nil then FreeMem(fullPathToCurEngine, sz);
      sz:=sz*2;
      GetMem(fullPathToCurEngine, sz);
      if fullPathToCurEngine = nil then exit;
    until GetModuleFileName(xrEngine, fullPathToCurEngine, sz) < sz-1;
    cmdapp:=fullPathToCurEngine;
    workingdir:=path;
    cmdline:= 'xrEngine.exe -fz_nomod -fzmod '+modname+' -wosace -start client('+ip+'/port='+inttostr(port)+')';
    FreeMem(fullPathToCurEngine, sz);
  end;

  FillMemory(@si, sizeof(si),0);
  FillMemory(@pi, sizeof(pi),0);
  si.cb:=sizeof(si);

  //Прибьем блокирующий запуск нескольких копий сталкера мьютекс
  KillMutex();

  //Запустим клиента
  if (not CreateProcess(PAnsiChar(cmdapp), PAnsiChar(cmdline), nil, nil, false, CREATE_SUSPENDED, nil, PAnsiChar(workingdir),si, pi)) then begin
    FZLogMgr.Get.Write('cmdapp: '+cmdapp, FZ_LOG_ERROR);
    FZLogMgr.Get.Write('cmdline: '+cmdline, FZ_LOG_ERROR);
    FZLogMgr.Get.Write('Cannot run application', FZ_LOG_ERROR);
  end else begin
    ResumeThread(pi.hThread);
    result:=true;

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    ExecuteConsoleCommand(PAnsiChar('flush'));

    //Отдадим команду на выход из игры
    //FZLogMgr.Get.Write('Exiting game', FZ_LOG_DBG);
    //ExecuteConsoleCommand(PAnsiChar('quit'));
  end;
end;

procedure ThreadBody(); stdcall;
var
  main_menu:pCMainMenu;
begin
  FZLogMgr.Get.Write('Starting working thread', FZ_LOG_DBG);
  if not DoWork(_mod_name, _mod_rel_path) then begin
    FZLogMgr.Get.Write('Loading failed!', FZ_LOG_ERROR);
    SafeExec(@AssignStatus, PChar('Downloading failed. Try again.'));
    Sleep(4000);
    main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
    if main_menu<>nil then begin
      main_menu.m_sPDProgress.IsInProgress:=0;
    end;
  end else begin
    TerminateProcess(GetCurrentProcess, 0);
  end;
  InterlockedDecrement(_lock);
end;


function InitModLoad(mod_name:PAnsiChar):boolean;
var
  path:string;
begin
  if _dll_handle=0 then begin
    result:=true;
    srcKit.Get().SwitchDebugMode(false);
    // Init engine framework
    result:=result and basedefs.Init();
    result:=result and xrfilesystem.Init();
    result:=result and Level.Init();
    result:=result and GamePersistent.Init();
    result:=result and xrstrings.Init();
    result:=result and MainMenu.Init();
    result:=result and UI.Init();
    result:=result and RenderDevice.Init();
    result:=result and Console.Init();
    result:=result and GameCore.Init();
    // Init low-level
    result:=result and global_functions.Init();
    result:=result and Decompressor.Init();
    // Init high-level
    result:=result and LogMgr.Init();

    //Выходим, если все плохо
    if not result then exit;

    //Теперь нам надо предотвратить потенциальную выгрузку ДЛЛ из памяти после завершения ModLoad
    result:=false;
    path:=UpdatePath('$app_data_root$', mod_name);
    _dll_handle:=LoadLibrary(PAnsiChar(path+'.mod'));
    if _dll_handle = 0 then begin
      FZLogMgr.Get.Write('Cannot acquire dll '+path+'.mod', FZ_LOG_ERROR);
      exit;
    end;

    //И выделить память под аргументы
    _mod_name:=VirtualAlloc(nil, MAX_NAME_SIZE, MEM_COMMIT, PAGE_READWRITE);
    _mod_rel_path:=VirtualAlloc(nil, MAX_NAME_SIZE, MEM_COMMIT, PAGE_READWRITE);
    _mod_params:=VirtualAlloc(nil, MAX_PARAMS_SIZE, MEM_COMMIT, PAGE_READWRITE);
    if (_mod_rel_path = nil) or (_mod_params=nil) then begin
      FZLogMgr.Get.Write('Cannot allocate memory', FZ_LOG_ERROR);
      FreeLibrary(_dll_handle);
      _dll_handle:=0;
      exit;
    end;
  end;

  result:=true;
end;

function RunModLoad(mod_name:PAnsiChar; mod_params:PAnsiChar):boolean;
var
  main_menu:pCMainMenu;
begin
  result:=false;

  // Start work
  FZLogMgr.Get.Write( 'FreeZone Mod Loader for STCS 1.5.10', FZ_LOG_INFO );
  FZLogMgr.Get.Write( 'Build date: ' + {$INCLUDE %DATE}, FZ_LOG_INFO );
  FZLogMgr.Get.Write( 'Mod name is "'+mod_name+'"', FZ_LOG_INFO );
  FZLogMgr.Get.Write( 'Mod params "'+mod_params+'"', FZ_LOG_INFO );

  //g_ppGamePersistent не nil, проверять не надо - уже проверено на инициализации
  main_menu:=pCMainMenu(g_ppGamePersistent^.m_pMainMenu);
  if (main_menu=nil) then begin
    FZLogMgr.Get.Write( 'Main menu is nil', FZ_LOG_ERROR);
    exit;
  end;

  FZLogMgr.Get.Write( 'g_pGamePersistent '+inttohex(PtrInt(g_ppGamePersistent^), 8), FZ_LOG_DBG );
  FZLogMgr.Get.Write( 'main_menu '+inttohex(PtrInt(main_menu), 8), FZ_LOG_DBG );
  FZLogMgr.Get.Write( 'main_menu.IsInProgress '+inttohex(PtrInt(@main_menu.m_sPDProgress.IsInProgress), 8), FZ_LOG_DBG );


  if (main_menu.m_sPDProgress.FileName.p_ = nil) then begin
    //Назначим строку-пояснение над индикатором загрузки (там что-то должно быть перед
    //назначением IsInProgress, иначе вероятность вылета при попытке отрисовки)
    AssignStatus('Preparing synchronization...');
  end;

  //Начинаем синхронизацию файлов мода в отдельном потоке
  fz_thread_spawn(@ThreadBody, nil);

  result:=true;
end;

procedure AbortConnection();
begin
  if (pCLevel(g_ppGameLevel^)<>nil) then begin
    //Прерываем коннект. Гонок быть не должно.
    FZLogMgr.Get.Write( 'Aborting connection', FZ_LOG_DBG );
    pCLevel(g_ppGameLevel^).m_bConnectResult:=0;
    pCLevel(g_ppGameLevel^).m_bConnectResultReceived:=1;
    pCLevel(g_ppGameLevel^).m_connect_server_err:=xrServer__ErrNoErr;
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
//-port<number> - порт сервера
//-gamespymode - стараться использовать загрузку средствами GameSpy

procedure ModLoad(mod_name:PAnsiChar; mod_params:PAnsiChar); stdcall;
var
  i:integer;
const
  mod_dir_prefix:PChar='.svn\';
  allowed_symbols_in_mod_name:string='1234567890abcdefghijklmnopqrstuvwxyz_';
begin
  //Убедимся, что процесс загрузки из нашей длл не находится в активной фазе, и заблочим повторный запуск до завершения
  if InterlockedExchangeAdd(@_lock, 1)<>0 then begin
    AbortConnection();
    InterlockedDecrement(_lock);
    exit;
  end;

  //Инициализируем глобальные вещи
  if not (InitModLoad(mod_name)) then begin
    InterlockedDecrement(_lock);
    exit;
  end;
  AbortConnection();

  //Работаем
  if Int64(length(mod_name))+Int64(length(mod_dir_prefix))>=Int64(MAX_NAME_SIZE-1) then begin
    FZLogMgr.Get.Write('Too long mod name, exiting', FZ_LOG_ERROR);
    InterlockedDecrement(_lock);
    exit;
  end;
  if length(mod_params)>=MAX_PARAMS_SIZE-1 then begin
    FZLogMgr.Get.Write('Too long mod params, exiting', FZ_LOG_ERROR);
    InterlockedDecrement(_lock);
    exit;
  end;

  i:=0;
  while(mod_name[i]<>chr(0)) do begin
    if pos(mod_name[i], allowed_symbols_in_mod_name) = 0 then begin
      FZLogMgr.Get.Write('Invalid mod name, exiting', FZ_LOG_ERROR);
      InterlockedDecrement(_lock);
      exit;
    end;
    i:=i+1;
  end;


  StrCopy(_mod_name, mod_name);

  //Благодаря этому хаку с префиксом, игра не полезет подгружать файлы мода при запуске оригинального клиента
  StrCopy(_mod_rel_path, mod_dir_prefix);
  StrCopy(@_mod_rel_path[length(mod_dir_prefix)], mod_name);

  StrCopy(_mod_params, mod_params);
  if not RunModLoad(_mod_rel_path, _mod_params) then begin
    InterlockedDecrement(_lock);
    exit;
  end;

  //Все отлично, загрузка пошла
  //Декрементить _lock тут не надо - это произойдет после окончания загрузки.
end;

{$IFNDEF RELEASE}
procedure ModLoadTest(); stdcall;
begin
  ModLoad({'guns_cs'}{'fz_mod_loader'}'sace3', ' -srvname localhost -srvport 5449 ');
end;
{$ENDIF}

exports
{$IFNDEF RELEASE}
  ModLoadTest,
{$ENDIF}
  ModLoad;

begin
  _lock:=0;
  _dll_handle:=0;
end.

