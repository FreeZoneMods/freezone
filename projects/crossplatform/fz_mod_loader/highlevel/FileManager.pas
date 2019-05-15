unit FileManager;

{$mode delphi}

interface
uses
  Classes, LogMgr;

type
  //////////////////////////////////////////
  FZActualizingStatus=(FZ_ACTUALIZING_BEGIN, FZ_ACTUALIZING_IN_PROGRESS, FZ_ACTUALIZING_VERIFYING_START, FZ_ACTUALIZING_VERIFYING, FZ_ACTUALIZING_FINISHED, FZ_ACTUALIZING_FAILED );

  FZFileActualizingProgressInfo = record
    status:FZActualizingStatus;
    total_mod_size:int64;
    total_up_to_date_size:int64;
    estimated_dl_size:int64;
    total_downloaded:int64;
  end;

  FZFileActualizingCallback=function(info:FZFileActualizingProgressInfo; userdata:pointer):boolean; //return false if need to stop downloading

  //////////////////////////////////////////

  //FZ_FILE_ACTION_UNDEFINED - неопределенное состояние, при актуализации удаляется
  //FZ_FILE_ACTION_NO - файл находится в списке синхронизируемых, после проверки состояние признано не требующим обновления
  //FZ_FILE_ACTION_DOWNLOAD - файл в списке синхронизируемых, требуется перезагрузка файла
  //FZ_FILE_ACTION_IGNORE - файл не участвует в синхронизации, никакие действия с ним не производятся

  FZFileItemAction = ( FZ_FILE_ACTION_UNDEFINED, FZ_FILE_ACTION_NO, FZ_FILE_ACTION_DOWNLOAD, FZ_FILE_ACTION_IGNORE, FZ_FILE_ACTION_VERIFY );

  FZDlMode = (FZ_DL_MODE_CURL, FZ_DL_MODE_GAMESPY);

  FZCheckParams = record
    size:cardinal;
    crc32:cardinal;
    md5:string;
  end;
  pFZCheckParams = ^FZCheckParams;

  FZFileItemData = record
    name:string;
    url:string; // учитывается только при FZ_FILE_ACTION_DOWNLOAD
    compression_type:cardinal;
    required_action:FZFileItemAction;
    real:FZCheckParams;
    target:FZCheckParams; // учитывается только при FZ_FILE_ACTION_DOWNLOAD
  end;
  pFZFileItemData = ^FZFileItemData;

  { FZFiles }

  FZFiles = class
  protected
    _parent_path:string;
    _files:TList;
    _callback:FZFileActualizingCallback;
    _cb_userdata:pointer;

    _mode:FZDlMode;

    function _ScanDir(dir_path:string):boolean;                                                                 //сканирует поддиректорию
    function _CreateFileData(name: string; url: string; compression:cardinal; need_checks:FZCheckParams): pFZFileItemData; //создает новую запись о файле и добавляет в список
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Clear();                                                                                          //полная очистка данных списка
    procedure Dump(severity:FZLogMessageSeverity=FZ_LOG_INFO);                                                  //вывод текущего состояния списка, отладочная опция
    function ScanPath(dir_path:string):boolean;                                                                 //построение списка файлов в указанной директории и ее поддиректориях для последующей актуализации
    function UpdateFileInfo(filename: string; url: string; compression_type:cardinal; targetParams:FZCheckParams):boolean;      //обновить сведения о целевых параметрах файла
    function ActualizeFiles():boolean;                                                                          //актуализировать игровые данные
    procedure SortBySize();                                                                                     //отсортировать (по размеру) для оптимизации скорости скачивания
    function AddIgnoredFile(filename:string):boolean;                                                           //добавить игнорируемый файл; вызывать после того, как все UpdateFileInfo выполнены
    procedure SetCallback(cb:FZFileActualizingCallback; userdata:pointer);                                      //добавить колбэк на обновление состояния синхронизации

    function EntriesCount():integer;                                                                            //число записей о синхронизируемых файлах
    function GetEntry(i:cardinal):FZFileItemData;                                                               //получить копию информации об указанном файле
    procedure DeleteEntry(i:cardinal);                                                                          //удалить запись об синхронизации
    procedure UpdateEntryAction(i:cardinal; action:FZFileItemAction );                                          //обновить действие для файла

    procedure SetDlMode(mode:FZDlMode);

    procedure Copy(from:FZFiles);
  end;

function GetFileChecks(path:string; out_check_params:pFZCheckParams; needMD5:boolean):boolean;
function IsDummy(c:FZCheckParams):boolean;
function GetDummyChecks():FZCheckParams;
function CompareFiles(c1:FZCheckParams; c2:FZCheckParams):boolean;

implementation
uses sysutils, windows, HttpDownloader, FastMd5, FastCrc;

const
  FM_LBL:string='[FM]';

function GetDummyChecks():FZCheckParams;
begin
  result.crc32:=0;
  result.size:=0;
  result.md5:='';
end;

function IsDummy(c:FZCheckParams):boolean;
begin
  result:=(c.crc32=0) and (c.size=0) and (length(c.md5)=0);
end;

function CompareFiles(c1:FZCheckParams; c2:FZCheckParams):boolean;
begin
  result:=(c1.crc32=c2.crc32) and (c1.size=c2.size) and (c1.md5=c2.md5);
end;

function GetFileChecks(path:string; out_check_params:pFZCheckParams; needMD5:boolean):boolean;
var
  file_handle:cardinal;
  ptr:PChar;

  readbytes:cardinal;
  md5_ctx:TMD5Context;
  crc32_ctx:TCRC32Context;
const
  WORK_SIZE:cardinal=1*1024*1024;
begin
  FZLogMgr.Get.Write('Calculating checks for '+path, FZ_LOG_DBG);
  result:=false;
  out_check_params.crc32:=0;
  out_check_params.md5:='';
  readbytes:=0;

  file_handle:=CreateFile(PAnsiChar(path), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if (file_handle<>INVALID_HANDLE_VALUE) then begin
    out_check_params.size:=GetFileSize(file_handle, nil);
  end else begin
    FZLogMgr.Get.Write('Cannot read file, exiting', FZ_LOG_DBG);
    exit;
  end;

  if out_check_params.size = 0 then begin
    CloseHandle(file_handle);
    result:=true;
    exit;
  end;

  GetMem(ptr, WORK_SIZE);
  if (ptr<>nil) then begin
    md5_ctx:=MD5Start();
    crc32_ctx:=CRC32Start();
    while ReadFile(file_handle, ptr[0], WORK_SIZE, readbytes, nil) and (WORK_SIZE=readbytes) do begin
      if needMD5 then MD5Next(md5_ctx, ptr, WORK_SIZE div MD5BlockSize());
      CRC32Update(crc32_ctx, ptr, WORK_SIZE);
    end;
    if needMD5 then out_check_params.md5:=MD5End(md5_ctx, ptr, readbytes);
    out_check_params.crc32:=CRC32End(crc32_ctx, ptr, readbytes);
    FreeMem(ptr);
  end else begin
    FZLogMgr.Get.Write('Cannot allocate memory, exiting', FZ_LOG_ERROR);
    exit;
  end;

  FZLogMgr.Get.Write('File size is '+inttostr(out_check_params.size)+', crc32='+inttohex(out_check_params.crc32,8)+', md5=['+out_check_params.md5+']', FZ_LOG_DBG);

  CloseHandle(file_handle);
  result:=true;
end;

{ FZFiles }

function FZFiles._ScanDir(dir_path: string): boolean;
var
  hndl:THandle;
  data:WIN32_FIND_DATA;
  name:string;
begin
  result:=false;
  name:=_parent_path+dir_path+'*.*';
  hndl:=FindFirstFile(PAnsiChar(name), @data);
  if hndl = INVALID_HANDLE_VALUE then exit;

  result:=true;
  repeat
    name := PAnsiChar(@data.cFileName[0]);
    if  (name = '.') or (name='..') then continue;

    if (data.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0) then begin
      _ScanDir(dir_path+name+'\');
    end else begin
      _CreateFileData(dir_path+name, '', 0, GetDummyChecks());
      FZLogMgr.Get.Write(FM_LBL+dir_path+name, FZ_LOG_DBG);
    end;
  until not FindNextFile(hndl, @data);

  FindClose(hndl);
end;

function FZFiles._CreateFileData(name: string; url: string; compression:cardinal; need_checks:FZCheckParams): pFZFileItemData;
begin
  New(result);
  result.name:=trim(name);
  result.url:=trim(url);
  result.compression_type:=compression;
  result.required_action:=FZ_FILE_ACTION_UNDEFINED;
  result.target:=need_checks;
  result.real:=GetDummyChecks();
  _files.Add(result);
end;

constructor FZFiles.Create();
begin
  inherited Create();
  _files:=TList.Create();
  _callback:=nil;
  _cb_userdata:=nil;
  _mode:=FZ_DL_MODE_CURL;
end;

destructor FZFiles.Destroy();
begin
  Clear();
  _files.Free();
  inherited;
end;

procedure FZFiles.Clear();
var
  ptr:pFZFileItemData;
  i:integer;
begin
  _parent_path:='';
  for i:=0 to _files.Count-1 do begin
    if _files.Items[i] <> nil then begin
      ptr:=_files.Items[i];
      _files.Items[i]:=nil;
      Dispose(ptr);
    end;
  end;
  _files.Clear();
end;

procedure FZFiles.Dump(severity:FZLogMessageSeverity=FZ_LOG_INFO);
var
  ptr:pFZFileItemData;
  i:integer;
begin
  FZLogMgr.Get.Write(FM_LBL+'=======File list dump start=======', severity);
  for i:=0 to _files.Count-1 do begin
    if _files.Items[i] <> nil then begin
      ptr:=_files.Items[i];
      FZLogMgr.Get.Write(FM_LBL+ptr.name+', action='+inttostr(cardinal(ptr.required_action))+
                         ', size '+inttostr(ptr.real.size)+'('+inttostr(ptr.target.size)+
                         '), crc32 '+inttohex(ptr.real.crc32,8)+'('+inttohex(ptr.target.crc32,8)+
                         '), url='+ptr.url, severity);
    end;
  end;
  FZLogMgr.Get.Write(FM_LBL+'=======File list dump end=======', severity);
end;

function FZFiles.ScanPath(dir_path: string):boolean;
begin
  result:=true;
  Clear();

  FZLogMgr.Get.Write(FM_LBL+'=======Scanning directory=======', FZ_LOG_DBG);
  if (dir_path[length(dir_path)]<>'\') and (dir_path[length(dir_path)]<>'/') then begin
    dir_path:=dir_path+'\';
  end;
  _parent_path := dir_path;
  _ScanDir('');
  FZLogMgr.Get.Write(FM_LBL+'=======Scanning finished=======', FZ_LOG_DBG);
end;

function FZFiles.UpdateFileInfo(filename: string; url: string; compression_type:cardinal; targetParams:FZCheckParams):boolean;
var
  i:integer;
  filedata:pFZFileItemData;
begin
  FZLogMgr.Get.Write(FM_LBL+'Updating file info for '+filename+
                     ', size='+inttostr(targetParams.size)+
                     ', crc='+inttohex(targetParams.crc32, 8)+
                     ', md5=['+targetParams.md5+']'+
                     ', url='+url+
                     ', compression '+inttostr(compression_type), FZ_LOG_INFO);
  result:=false;
  filename:=trim(filename);

  if Pos('..', filename)>0 then begin
    FZLogMgr.Get.Write(FM_LBL+'File path cannot contain ".."', FZ_LOG_ERROR);
    exit;
  end;

  //Пробуем найти файл среди существующих
  filedata:=nil;
  for i:=0 to _files.Count-1 do begin
    if (_files.Items[i]<>nil) and (pFZFileItemData(_files.Items[i]).name=filename) then begin
      filedata:=_files.Items[i];
      break;
    end;
  end;

  if (filedata=nil) then begin
    //Файла нет в списке. Однозначно надо качать.
    filedata:=_CreateFileData(filename, url, compression_type, targetParams);
    filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
    FZLogMgr.Get.Write(FM_LBL+'Created new file list entry', FZ_LOG_INFO );
  end else begin
    //Файл есть в списке. Проверяем.
    if IsDummy(filedata.real) then begin
      //посчитаем его CRC32, если ранее не считался
      if not GetFileChecks(_parent_path+filedata.name, @filedata.real, length(targetParams.md5)>0 ) then begin
        filedata.real.crc32:=0;
        filedata.real.size:=0;
        filedata.real.md5:='';
      end;
      FZLogMgr.Get.Write(FM_LBL+'Current file info: CRC32='+inttohex(filedata.real.crc32, 8)+', size='+inttostr(filedata.real.size)+', md5=['+filedata.real.md5+']', FZ_LOG_INFO );
    end;

    if  CompareFiles(filedata.real, targetParams) then begin
      filedata.required_action:=FZ_FILE_ACTION_NO;
      FZLogMgr.Get.Write(FM_LBL+'Entry exists, file up-to-date', FZ_LOG_INFO );
    end else begin
      filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
      FZLogMgr.Get.Write(FM_LBL+'Entry exists, file outdated', FZ_LOG_INFO );
    end;
    filedata.target:=targetParams;
    filedata.url:=url;
    filedata.compression_type:=compression_type;
  end;
  result:=true;
end;

procedure FZFiles.SortBySize();
var
  i,j,max:integer;
  tmp:pFZFileItemData;
begin
  if _files.Count<2 then exit;
  //сортируем так, чтобы самые большие файлы оказались в конце

  for i:=_files.Count-1 downto 1 do begin
    max:=i;
  	for j:=i-1 downto 0 do begin
      //Ищем самый большой файл
  		if (_files.Items[j]=nil) then continue;
  		if (_files.Items[max] = nil) or (pFZFileItemData(_files.Items[max]).target.size < (pFZFileItemData(_files.Items[j])).target.size) then begin
        max:=j;
      end;
    end;

    if i <> max then begin
      tmp:=_files.Items[i];
      _files.Items[i]:=_files.items[max];
      _files.Items[max]:=tmp;
    end;
  end;
end;

function FZFiles.ActualizeFiles(): boolean;
var
  i, last_file_index:integer;
  filedata:pFZFileItemData;
  downloaders:array of FZFileDownloader;
  total_dl_size, total_actual_size, downloaded_now, downloaded_total:int64;
  finished:boolean;
  str:string;

  thread:FZDownloaderThread;
  cb_info:FZFileActualizingProgressInfo;
const
  MAX_ACTIVE_DOWNLOADERS:cardinal=4;  //for safety
begin
  filedata:=nil;
  total_dl_size:=0;
  total_actual_size:=0;
  downloaded_total:=0;
  result:=false;

  for i:=_files.Count-1 downto 0 do begin
    filedata:=_files.Items[i];
    if filedata=nil then continue;
    if filedata.required_action=FZ_FILE_ACTION_UNDEFINED then begin
      //такого файла не было в списке. Сносим.
      FZLogMgr.Get.Write(FM_LBL+'Deleting file '+filedata.name, FZ_LOG_INFO);
      if not SysUtils.DeleteFile(_parent_path+filedata.name)then begin
        FZLogMgr.Get.Write(FM_LBL+'Failed to delete '+filedata.name, FZ_LOG_ERROR);
        exit;
      end;
      Dispose(filedata);
      _files.Delete(i);
    end else if filedata.required_action=FZ_FILE_ACTION_DOWNLOAD then begin
      total_dl_size:=total_dl_size+filedata.target.size;
      str:=_parent_path+filedata.name;
      while (str[length(str)]<>'\') and (str[length(str)]<>'/') do begin
        str:=leftstr(str,length(str)-1);
      end;
      if not ForceDirectories(str) then begin
        FZLogMgr.Get.Write(FM_LBL+'Cannot create directory '+str, FZ_LOG_ERROR);
        exit;
      end;
    end else if filedata.required_action=FZ_FILE_ACTION_NO then begin
      total_actual_size:=total_actual_size+filedata.target.size;
    end else if filedata.required_action=FZ_FILE_ACTION_IGNORE then begin
      FZLogMgr.Get.Write(FM_LBL+'Ignoring file '+filedata.name, FZ_LOG_INFO);
    end else begin
      FZLogMgr.Get.Write(FM_LBL+'Unknown action for '+filedata.name, FZ_LOG_ERROR);
      exit;
    end;
  end;
  FZLogMgr.Get.Write(FM_LBL+'Total up-to-date size '+inttostr(total_actual_size), FZ_LOG_INFO);
  FZLogMgr.Get.Write(FM_LBL+'Total downloads size '+inttostr(total_dl_size), FZ_LOG_INFO);

  FZLogMgr.Get.Write(FM_LBL+'Starting downloads', FZ_LOG_INFO);
  result:=true;

  //Вызовем колбэк для сообщения о начале стадии загрузки
  cb_info.total_downloaded:=0;
  cb_info.status:=FZ_ACTUALIZING_BEGIN;
  cb_info.estimated_dl_size:=total_dl_size;
  cb_info.total_up_to_date_size:=total_actual_size;
  cb_info.total_mod_size:=total_dl_size+total_actual_size;
  if (@_callback<>nil) then begin
    result := _callback(cb_info, _cb_userdata)
  end;

  //Начнем загрузку
  if _mode=FZ_DL_MODE_GAMESPY then begin
    thread:=FZGameSpyDownloaderThread.Create();
  end else begin
    thread:=FZCurlDownloaderThread.Create();
  end;
  setlength(downloaders, MAX_ACTIVE_DOWNLOADERS);
  last_file_index:=_files.Count-1;
  finished:=false;
  downloaded_total:=0;
  cb_info.status:=FZ_ACTUALIZING_IN_PROGRESS;
  while ( not finished ) do begin
    if not result then begin
      //Загрузка прервана.
      FZLogMgr.Get.Write(FM_LBL+'Actualizing cancelled', FZ_LOG_ERROR);
      break;
    end;

    finished:=true; //флаг сбросится при активной загрузке
    downloaded_now:=0;
    //смотрим на текущий статус слотов загрузки
    for i:=0 to length(downloaders)-1 do begin
      if (downloaders[i]=nil) then begin
        //Слот свободен. Поставим туда что-нибудь, если найдем
        while last_file_index>=0 do begin
          filedata:=_files.Items[last_file_index];
          last_file_index:=last_file_index-1; //сдвигаем индекс на необработанный файл
          if (filedata<>nil) and (filedata.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
            //файл для загрузки найден, помещаем его в слот.
            FZLogMgr.Get.Write(FM_LBL+'Starting download of '+filedata.url, FZ_LOG_INFO);
            finished:=false;
            downloaders[i]:=thread.CreateDownloader(filedata.url, _parent_path+filedata.name, filedata.compression_type);
            result:=downloaders[i].StartAsyncDownload();
            if not result then begin
              FZLogMgr.Get.Write(FM_LBL+'Cannot start download for '+filedata.url, FZ_LOG_ERROR);
            end else begin
              filedata.required_action:=FZ_FILE_ACTION_VERIFY;
            end;
            break;
          end;
        end;
      end else if downloaders[i].IsBusy() then begin
        //Слот активен. Обновим информацию о прогрессе
        finished:=false;
        downloaded_now:=downloaded_now+downloaders[i].DownloadedBytes();
      end else begin
        //Слот завершил работу. Освободим его.
        FZLogMgr.Get.Write(FM_LBL+'Need free slot contained '+downloaders[i].GetFilename(), FZ_LOG_INFO);
        result:=downloaders[i].IsSuccessful();
        downloaded_total:=downloaded_total+downloaders[i].DownloadedBytes();
        if not result then begin
          FZLogMgr.Get.Write(FM_LBL+'Download failed for '+downloaders[i].GetFilename(), FZ_LOG_ERROR);
        end;
        downloaders[i].Free();
        downloaders[i]:=nil;
        //но могут быть еще файлы в очереди на загрузку, поэтому, не спешим выставлять в true
        finished:=false;
      end;
    end;

    //Вызовем колбэк прогресса
    cb_info.total_downloaded:=downloaded_now+downloaded_total;
    if (@_callback<>nil) then begin
      result := _callback(cb_info, _cb_userdata);
    end;
    if result then Sleep(100);
  end;

  //Останавливаем всех их
  FZLogMgr.Get.Write(FM_LBL+'Request stop', FZ_LOG_INFO);
  for i:=0 to length(downloaders)-1 do begin
    if downloaders[i]<>nil then begin
      downloaders[i].RequestStop();
    end;
  end;

  //и удаляем их
  FZLogMgr.Get.Write(FM_LBL+'Delete downloaders', FZ_LOG_INFO);
  for i:=0 to length(downloaders)-1 do begin
    if downloaders[i]<>nil then begin
      downloaders[i].Free();
    end;
  end;
  setlength(downloaders,0);
  thread.Free();

  if result then begin
    //убедимся, что все требуемое скачалось корректно
    if (total_dl_size>0) then begin
      FZLogMgr.Get.Write(FM_LBL+'Verifying downloaded', FZ_LOG_INFO);

      cb_info.status:=FZ_ACTUALIZING_VERIFYING_START;
      cb_info.total_downloaded:=0;
      result := _callback(cb_info, _cb_userdata);

      for i:=_files.Count-1 downto 0 do begin
        if not result then break;

        filedata:=_files.Items[i];
        if (filedata<>nil) and (filedata.required_action=FZ_FILE_ACTION_VERIFY) then begin
          if GetFileChecks(_parent_path+filedata.name, @filedata.real, length(filedata.target.md5)>0) then begin
            if not CompareFiles(filedata.real, filedata.target) then begin
              FZLogMgr.Get.Write(FM_LBL+'File NOT synchronized: '+filedata.name, FZ_LOG_ERROR);
              filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
              result:=false;
            end;
          end else begin
            FZLogMgr.Get.Write(FM_LBL+'Cannot check '+filedata.name, FZ_LOG_ERROR);
            filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
            result:=false;
          end;
        end else if (filedata<>nil) and (filedata.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
          FZLogMgr.Get.Write(FM_LBL+'File '+filedata.name+' has FZ_FILE_ACTION_DOWNLOAD state after successful synchronization??? A bug suspected!', FZ_LOG_ERROR);
          result:=false;
        end;

        if result then begin
          cb_info.status:=FZ_ACTUALIZING_VERIFYING;
          cb_info.total_downloaded:=cb_info.total_downloaded+filedata.target.size;
          result := _callback(cb_info, _cb_userdata)
        end;
      end;
    end;

    //вызываем колбэк окончания
    if result then begin
      FZLogMgr.Get.Write(FM_LBL+'Run finish callback', FZ_LOG_INFO);
      cb_info.status:=FZ_ACTUALIZING_FINISHED;
      cb_info.total_downloaded:=downloaded_total;
      result := _callback(cb_info, _cb_userdata)
    end else begin
      FZLogMgr.Get.Write(FM_LBL+'Run fail callback', FZ_LOG_INFO);
      cb_info.status:=FZ_ACTUALIZING_FAILED;
      cb_info.total_downloaded:=0;
      _callback(cb_info, _cb_userdata)
    end;

    FZLogMgr.Get.Write(FM_LBL+'All downloads finished', FZ_LOG_INFO);
  end;
end;

function FZFiles.AddIgnoredFile(filename: string): boolean;
var
  i:integer;
  filedata:pFZFileItemData;
begin
  //Пробуем найти файл среди существующих
  filedata:=nil;
  for i:=0 to _files.Count-1 do begin
    if (_files.Items[i]<>nil) and (pFZFileItemData(_files.Items[i]).name=filename) then begin
      filedata:=_files.Items[i];
      break;
    end;
  end;
  if filedata<>nil then begin
    filedata.required_action:=FZ_FILE_ACTION_IGNORE;
  end;
  result:=true;
end;

procedure FZFiles.SetCallback(cb: FZFileActualizingCallback; userdata: pointer);
begin
  _cb_userdata:=userdata;
  _callback:=cb;
end;

function FZFiles.EntriesCount(): integer;
begin
  result:=_files.Count;
end;

function FZFiles.GetEntry(i: cardinal): FZFileItemData;
var
  filedata:pFZFileItemData;
begin
  if (int64(i)<int64(_files.Count)) then begin
    filedata:=_files.Items[i];
    if filedata<>nil then begin
      result:=filedata^;
    end;
  end;
end;

procedure FZFiles.DeleteEntry(i: cardinal);
var
  filedata:pFZFileItemData;
begin
  if (int64(i)<int64(_files.Count)) then begin
    filedata:=_files.Items[i];
    Dispose(filedata);
    _files.Delete(i);
  end;
end;

procedure FZFiles.UpdateEntryAction(i: cardinal; action: FZFileItemAction);
var
  filedata:pFZFileItemData;
begin
  if (int64(i)<int64(_files.Count)) then begin
    filedata:=_files.Items[i];
    filedata.required_action:=action;
  end;
end;

procedure FZFiles.SetDlMode(mode: FZDlMode);
begin
  _mode:=mode;
end;

procedure FZFiles.Copy(from: FZFiles);
var
  i:integer;
  filedata:pFZFileItemData;
begin
  Clear();
  _cb_userdata:=from._cb_userdata;
  _callback:=from._callback;
  _parent_path:=from._parent_path;
  _mode:=from._mode;

  for i:=0 to from._files.Count-1 do begin
    New(filedata);
    filedata^ := pFZFileItemData(from._files.Items[i])^;
    _files.Add(filedata);
  end;
end;

end.

