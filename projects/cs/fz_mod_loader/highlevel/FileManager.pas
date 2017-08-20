unit FileManager;

{$mode delphi}

interface
uses
  Classes, LogMgr;

type
  //////////////////////////////////////////
  FZActualizingStatus=(FZ_ACTUALIZING_BEGIN, FZ_ACTUALIZING_IN_PROGRESS, FZ_ACTUALIZING_FINISHED );

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

  FZFileItemData = record
    name:string;
    required_action:FZFileItemAction;
    crc32_real:cardinal;
    size_real:cardinal;
    compression_type:cardinal;

    url:string;             // учитывается только при FZ_FILE_ACTION_DOWNLOAD
    crc32_target:cardinal;  // учитывается только при FZ_FILE_ACTION_DOWNLOAD
    size_target:cardinal;   // учитывается только при FZ_FILE_ACTION_DOWNLOAD
  end;
  pFZFileItemData = ^FZFileItemData;

  { FZFiles }

  FZFiles = class
  protected
    _parent_path:string;
    _files:TList;
    _callback:FZFileActualizingCallback;
    _cb_userdata:pointer;

    function _ScanDir(dir_path:string):boolean;                                                                 //сканирует поддиректорию
    function _CreateFileData(name:string; need_size:cardinal; need_crc32:cardinal; url:string; compression:cardinal):pFZFileItemData; //создает новую запись о файле и добавляет в список
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Clear();                                                                                          //полная очистка данных списка
    procedure Dump(severity:FZLogMessageSeverity=FZ_LOG_INFO);                                                  //вывод текущего состояния списка, отладочная опция
    function ScanPath(dir_path:string):boolean;                                                                 //построение списка файлов в указанной директории и ее поддиректориях для последующей актуализации
    function UpdateFileInfo(filename:string; need_crc32:cardinal; need_size:cardinal; url:string; compression_type:cardinal):boolean;      //обновить сведения о целевых параметрах файла
    function ActualizeFiles():boolean;                                                                          //актуализировать игровые данные
    function AddIgnoredFile(filename:string):boolean;                                                           //добавить игнорируемый файл; вызывать после того, как все UpdateFileInfo выполнены
    procedure SetCallback(cb:FZFileActualizingCallback; userdata:pointer);                                      //добавить колбэк на обновление состояния синхронизации

    function EntriesCount():integer;                                                                            //число записей о синхронизируемых файлах
    function GetEntry(i:cardinal):FZFileItemData;                                                               //получить копию информации об указанном файле
    procedure DeleteEntry(i:cardinal);                                                                          //удалить запись об синхронизации
    procedure UpdateEntryAction(i:cardinal; action:FZFileItemAction );                                          //обновить действие для файла
  end;

function GetFileCrc32(path:string; var out_crc32:cardinal; var out_size:cardinal):boolean;

implementation
uses global_functions, sysutils, windows, HttpDownloader;

function GetFileCrc32(path:string; var out_crc32:cardinal; var out_size:cardinal):boolean;
var
  file_handle, mapping_handle:cardinal;
  ptr:pointer;
begin
  FZLogMgr.Get.Write('Calculating CRC32 for '+path, FZ_LOG_DBG);
  result:=false;
  file_handle:=CreateFile(PAnsiChar(path), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (file_handle<>INVALID_HANDLE_VALUE) then begin
    out_size:=GetFileSize(file_handle, nil);
  end else begin
    FZLogMgr.Get.Write('Cannot read file, exiting', FZ_LOG_DBG);
    exit;
  end;

  if out_size = 0 then begin
    CloseHandle(file_handle);
    result:=true;
    out_crc32:=0;
    exit;
  end;

  mapping_handle:=CreateFileMapping(file_handle, nil, PAGE_READONLY, 0, 0, nil);
  if mapping_handle = INVALID_HANDLE_VALUE then begin
     FZLogMgr.Get.Write('Cannot create file mapping for '+path, FZ_LOG_ERROR);
    CloseHandle(file_handle);
    exit;
  end;

  ptr:=MapViewOfFile(mapping_handle, FILE_MAP_READ, 0, 0, 0);
  if (ptr=nil) then begin
    FZLogMgr.Get.Write('Cannot map view for '+path, FZ_LOG_ERROR);
    CloseHandle(mapping_handle);
    CloseHandle(file_handle);
    exit;
  end;

  FZLogMgr.Get.Write('Running algo...', FZ_LOG_DBG);
  out_crc32:=crc32(ptr, out_size);
  result:=true;
  FZLogMgr.Get.Write('File size is '+inttostr(out_size)+', crc32='+inttohex(out_crc32,8), FZ_LOG_DBG);

  UnmapViewOfFile(ptr);
  CloseHandle(mapping_handle);
  CloseHandle(file_handle);
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
      _CreateFileData(dir_path+name, 0, 0, '', 0);
      FZLogMgr.Get.Write(dir_path+name, FZ_LOG_DBG);
    end;
  until not FindNextFile(hndl, @data);

  FindClose(hndl);
end;

function FZFiles._CreateFileData(name: string; need_size: cardinal; need_crc32: cardinal; url: string; compression:cardinal): pFZFileItemData;
begin
  New(result);
  result.name:=trim(name);
  result.required_action:=FZ_FILE_ACTION_UNDEFINED;
  result.crc32_real:=0;
  result.size_real:=0;
  result.crc32_target:=need_crc32;
  result.size_target:=need_size;
  result.url:=trim(url);
  result.compression_type:=compression;
  _files.Add(result);
end;

constructor FZFiles.Create;
begin
  inherited Create();
  _files:=TList.Create();
  _callback:=nil;
  _cb_userdata:=nil;
end;

destructor FZFiles.Destroy;
begin
  Clear();
  _files.Free();
  inherited;
end;

procedure FZFiles.Clear;
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
  FZLogMgr.Get.Write('=======File list dump start=======', severity);
  for i:=0 to _files.Count-1 do begin
    if _files.Items[i] <> nil then begin
      ptr:=_files.Items[i];
      FZLogMgr.Get.Write(ptr.name+', action='+inttostr(cardinal(ptr.required_action))+
                         ', size '+inttostr(ptr.size_real)+'('+inttostr(ptr.size_target)+'), crc32 '+inttohex(ptr.crc32_real,8)+'('+inttohex(ptr.crc32_target,8)+'), url='+ptr.url, severity);
    end;
  end;
  FZLogMgr.Get.Write('=======File list dump end=======', severity);
end;

function FZFiles.ScanPath(dir_path: string):boolean;
begin
  result:=true;
  Clear();

  FZLogMgr.Get.Write('=======Scanning directory=======', FZ_LOG_DBG);
  if (dir_path[length(dir_path)]<>'\') and (dir_path[length(dir_path)]<>'/') then begin
    dir_path:=dir_path+'\';
  end;
  _parent_path := dir_path;
  _ScanDir('');
  FZLogMgr.Get.Write('=======Scanning finished=======', FZ_LOG_DBG);
end;

function FZFiles.UpdateFileInfo(filename: string; need_crc32: cardinal; need_size:cardinal; url: string; compression_type:cardinal):boolean;
var
  i:integer;
  filedata:pFZFileItemData;
begin
  FZLogMgr.Get.Write('Updating file info for '+filename+', size='+inttostr(need_size)+', crc='+inttohex(need_crc32, 8)+', url='+url+', compression '+inttostr(compression_type), FZ_LOG_DBG);
  result:=false;
  filename:=trim(filename);

  if Pos('..', filename)>0 then begin
    FZLogMgr.Get.Write('File path cannot contain ".."', FZ_LOG_ERROR);
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

  //Если файл есть в списке - посчитаем его CRC32, если ранее не считался
  if (filedata<>nil) and (filedata.crc32_real=0) and (filedata.size_real=0) then begin
    if not GetFileCrc32(_parent_path+filedata.name, filedata.crc32_real, filedata.size_real) then begin
      filedata.crc32_real:=0;
      filedata.size_real:=0;
    end;
    FZLogMgr.Get.Write('Current file info: CRC32='+inttostr(filedata.crc32_real)+', size='+inttostr(filedata.size_real), FZ_LOG_DBG );
  end;

  if (filedata=nil) then begin
    //Файла нет в списке. Однозначно надо качать.
    filedata:=_CreateFileData(filename, need_size, need_crc32, url, compression_type);
    filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
    FZLogMgr.Get.Write('Created new file list entry', FZ_LOG_DBG );
  end else begin
    //Файл есть в списке. Проверяем.
    if (filedata.crc32_real=need_crc32) and (filedata.size_real=need_size) and (need_size<>0) then begin
      filedata.required_action:=FZ_FILE_ACTION_NO;
      FZLogMgr.Get.Write('Entry exists, file up-to-date', FZ_LOG_DBG );
    end else begin
      filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
      FZLogMgr.Get.Write('Entry exists, file outdated', FZ_LOG_DBG );
    end;
    filedata.crc32_target:=need_crc32;
    filedata.size_target:=need_size;
    filedata.url:=url;
    filedata.compression_type:=compression_type;
  end;
  result:=true;
end;

function FZFiles.ActualizeFiles: boolean;
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
      FZLogMgr.Get.Write('Deleting file '+filedata.name, FZ_LOG_DBG);
      if not SysUtils.DeleteFile(_parent_path+filedata.name)then begin
        FZLogMgr.Get.Write('Failed to delete '+filedata.name, FZ_LOG_ERROR);
        exit;
      end;
      Dispose(filedata);
      _files.Delete(i);
    end else if filedata.required_action=FZ_FILE_ACTION_DOWNLOAD then begin
      total_dl_size:=total_dl_size+filedata.size_target;
      str:=_parent_path+filedata.name;
      while (str[length(str)]<>'\') and (str[length(str)]<>'/') do begin
        str:=leftstr(str,length(str)-1);
      end;
      if not ForceDirectories(str) then begin
        FZLogMgr.Get.Write('Cannot create directory '+str, FZ_LOG_ERROR);
        exit;
      end;
    end else if filedata.required_action=FZ_FILE_ACTION_NO then begin
      total_actual_size:=total_actual_size+filedata.size_target;
    end else if filedata.required_action=FZ_FILE_ACTION_IGNORE then begin
      FZLogMgr.Get.Write('Ignoring file '+filedata.name, FZ_LOG_DBG);
    end else begin
      FZLogMgr.Get.Write('Unknown action for '+filedata.name, FZ_LOG_ERROR);
      exit;
    end;
  end;
  FZLogMgr.Get.Write('Total up-to-date size '+inttostr(total_actual_size), FZ_LOG_DBG);
  FZLogMgr.Get.Write('Total downloads size '+inttostr(total_dl_size), FZ_LOG_DBG);


  FZLogMgr.Get.Write('Starting downloads', FZ_LOG_DBG);
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
  thread:=FZDownloaderThread.Create();
  setlength(downloaders, MAX_ACTIVE_DOWNLOADERS);
  last_file_index:=_files.Count-1;
  finished:=false;
  downloaded_total:=0;
  cb_info.status:=FZ_ACTUALIZING_IN_PROGRESS;
  while ( not finished ) do begin
    if not result then begin
      //Загрузка прервана.
      FZLogMgr.Get.Write('Actualizing cancelled', FZ_LOG_ERROR);
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
            FZLogMgr.Get.Write('Starting download of '+filedata.url, FZ_LOG_DBG);
            finished:=false;
            downloaders[i]:=FZFileDownloader.Create(filedata.url, _parent_path+filedata.name, filedata.compression_type, thread);
            result:=downloaders[i].StartAsyncDownload();
            if not result then begin
              FZLogMgr.Get.Write('Cannot start download for '+filedata.url, FZ_LOG_ERROR);
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
        FZLogMgr.Get.Write('Download finished for '+downloaders[i].GetFilename(), FZ_LOG_DBG);
        result:=downloaders[i].IsSuccessful();
        downloaded_total:=downloaded_total+downloaders[i].DownloadedBytes();
        if not result then begin
          FZLogMgr.Get.Write('Download failed for '+downloaders[i].GetFilename(), FZ_LOG_ERROR);
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
  for i:=0 to length(downloaders)-1 do begin
    if downloaders[i]<>nil then begin
      downloaders[i].RequestStop();
    end;
  end;

  //и удаляем их
  for i:=0 to length(downloaders)-1 do begin
    if downloaders[i]<>nil then begin
      downloaders[i].Free();
    end;
  end;
  setlength(downloaders,0);
  thread.Free();

  //вызываем колбэк окончания
  if result then begin
    cb_info.status:=FZ_ACTUALIZING_FINISHED;
    cb_info.total_downloaded:=downloaded_total;
    result := _callback(cb_info, _cb_userdata)
  end;

  if result then begin
    //убедимся, что все требуемое скачалось корректно
    if (total_dl_size>0) then begin
      for i:=_files.Count-1 downto 0 do begin
        filedata:=_files.Items[i];
        if (filedata<>nil) and (filedata.required_action=FZ_FILE_ACTION_VERIFY) then begin
          if GetFileCrc32(_parent_path+filedata.name, filedata.crc32_real, filedata.size_real) then begin
            if (filedata.crc32_real <> filedata.crc32_target) or (filedata.size_real <> filedata.size_target) then begin
              FZLogMgr.Get.Write('File NOT synchronized: '+filedata.name, FZ_LOG_ERROR);
              filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
              result:=false;
            end;
          end else begin
            FZLogMgr.Get.Write('Cannot check '+filedata.name, FZ_LOG_ERROR);
            filedata.required_action:=FZ_FILE_ACTION_DOWNLOAD;
            result:=false;
          end;
        end else if (filedata<>nil) and (filedata.required_action=FZ_FILE_ACTION_DOWNLOAD) then begin
          FZLogMgr.Get.Write('File '+filedata.name+' has FZ_FILE_ACTION_DOWNLOAD state after successful synchronization??? A bug suspected!', FZ_LOG_ERROR);
          result:=false;
        end;
      end;
    end;

    FZLogMgr.Get.Write('All downloads finished', FZ_LOG_DBG);
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

function FZFiles.EntriesCount: integer;
begin
  result:=_files.Count;
end;

function FZFiles.GetEntry(i: cardinal): FZFileItemData;
var
  filedata:pFZFileItemData;
begin
  if (i<_files.Count) then begin
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
  if (i<_files.Count) then begin
    filedata:=_files.Items[i];
    Dispose(filedata);
    _files.Delete(i);
  end;
end;

procedure FZFiles.UpdateEntryAction(i: cardinal; action: FZFileItemAction);
var
  filedata:pFZFileItemData;
begin
  if (i<_files.Count) then begin
    filedata:=_files.Items[i];
    filedata.required_action:=action;
  end;
end;

end.

