unit HttpDownloader;

{$mode delphi}

interface
uses curl;

type

  FZDownloaderThread = class;

  { FZFileDownloader }

  FZDownloadResult = ( DOWNLOAD_SUCCESS, DOWNLOAD_ERROR );

  FZFileDownloader = class
  public
    constructor Create(url:string; filename:string; compression_type:cardinal; thread:FZDownloaderThread );
    destructor Destroy; override;
    function IsDownloading():boolean; virtual; abstract;
    function IsBusy():boolean;
    function GetUrl:string;
    function GetFilename:string;
    function GetCompressionType:cardinal;
    function StartAsyncDownload():boolean;
    function StartSyncDownload():boolean;
    function DownloadedBytes():cardinal;
    function IsSuccessful():boolean;
    function RequestStop():boolean;
    procedure Flush(); virtual; abstract;
  private
    _lock:TRTLCriticalSection;
    _request:uintptr;
    _url:string;
    _filename:string;
    _downloaded_bytes:cardinal;
    _compression_type:cardinal;
    _status:FZDownloadResult;
    _acquires_count:integer;
    _thread:FZDownloaderThread;
    _filesize:cardinal;
    procedure SetRequestId(id:uintptr);
    function GetRequestId():uintptr;
    procedure Acquire();
    procedure Release();
    procedure Lock();
    procedure Unlock();
    procedure SetStatus(status:FZDownloadResult);
    procedure SetFileSize(filesize:cardinal);
    procedure SetDownloadedBytesCount(count:cardinal);
  end;

  { FZGameSpyFileDownloader }

  FZGameSpyFileDownloader = class(FZFileDownloader)
    public
      constructor Create(url: string; filename: string; compression_type: cardinal; thread:FZDownloaderThread);
      function IsDownloading():boolean; override;
      procedure Flush(); override;
  end;

  { FZCurlFileDownloader }

  FZCurlFileDownloader = class(FZFileDownloader)
      _file_hndl:THandle;
    public
      constructor Create(url: string; filename: string; compression_type: cardinal; thread:FZDownloaderThread);
      function IsDownloading():boolean; override;
      destructor Destroy; override;
      procedure Flush(); override;
  end;


  FZDownloaderThreadCmdType = (FZDownloaderAdd, FZDownloaderStop);

  { FZDownloaderThreadInfo }

  FZDownloaderThreadCmd = record
    cmd:FZDownloaderThreadCmdType;
    downloader:FZFileDownloader;
  end;

  { FZDownloaderThreadInfoQueue }

  FZDownloaderThreadInfoQueue = class
    public
      constructor Create;
      destructor Destroy; override;
      function Add(item:FZDownloaderThreadCmd):boolean;
      procedure Flush();
      function Count(): integer;
      function Capacity(): integer;
      function Get(i:integer):FZDownloaderThreadCmd;
    private
      _queue:array of FZDownloaderThreadCmd;
      _cur_items_cnt:integer;
  end;

  { FZDownloaderThread }

  FZDownloaderThread = class
    public
      constructor Create;
      function AddCommand(cmd:FZDownloaderThreadCmd):boolean;
      function CreateDownloader(url:string; filename:string; compression_type:cardinal ):FZFileDownloader; virtual; abstract;

      function StartDownload(dl:FZFileDownloader): boolean; virtual; abstract;
      function ProcessDownloads():boolean; virtual; abstract;
      function CancelDownload(dl:FZFileDownloader): boolean; virtual; abstract;
      destructor Destroy; override;
    private
      _lock:TRTLCriticalSection;
      _commands_queue:FZDownloaderThreadInfoQueue;
      _downloaders:array of FZFileDownloader;
      _need_terminate:boolean;
      _thread_active:boolean;
      _good:boolean;


      procedure _WaitForThreadTermination();
      function _FindDownloader(dl:FZFileDownloader):integer;
      procedure _ProcessCommands();
  end;

  { FZGameSpyDownloaderThread }

  FZGameSpyDownloaderThread = class(FZDownloaderThread)
    private
      _dll_handle:THandle;
      _xrGS_ghttpStartup:procedure(); cdecl;
      _xrGS_ghttpCleanup:procedure(); cdecl;
      _xrGS_ghttpThink:procedure(); cdecl;
      _xrGS_ghttpSave:function( url:PAnsiChar; filename:PAnsiChar; blocking:cardinal; completedCallback:pointer; param:pointer ):cardinal; cdecl;
      _xrGS_ghttpSaveEx:function( url:PAnsiChar; filename:PAnsiChar; headers:PAnsiChar; post:pointer; throttle:cardinal; blocking:cardinal; progressCallback:pointer; completedCallback:pointer; param:pointer ):cardinal; cdecl;
      _xrGS_ghttpCancelRequest:procedure( request:cardinal ); cdecl;
    public
      constructor Create;
      destructor Destroy; override;
      function CreateDownloader(url:string; filename:string; compression_type:cardinal ):FZFileDownloader; override;
      function StartDownload(dl:FZFileDownloader): boolean; override;
      function ProcessDownloads(): boolean; override;
      function CancelDownload(dl:FZFileDownloader): boolean; override;
  end;

  { FZCurlDownloaderThread }

  FZCurlDownloaderThread = class(FZDownloaderThread)
    _multi_handle:pTCURLM;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateDownloader(url:string; filename:string; compression_type:cardinal ):FZFileDownloader; override;
    function StartDownload(dl:FZFileDownloader): boolean; override;
    function ProcessDownloads(): boolean; override;
    function CancelDownload(dl:FZFileDownloader): boolean; override;
  end;

implementation
uses
  abstractions, windows, LogMgr, sysutils, Decompressor;

const
  GHTTPSuccess:cardinal=0;
  GHTTPRequestError:cardinal=$FFFFFFFF;

  TH_LBL:string='[TH]';
  DL_LBL:string='[DL]';
  CB_LBL:string='[CB]';
  QUEUE_LBL:string='[Q]';

{ Thread functions & Callbacks }
procedure CreateThreadedFun(proc:pointer; param:pointer);
begin
  VersionAbstraction().ThreadSpawn(uintptr(proc), uintptr(param));
end;

procedure DownloaderThreadBody(th:FZDownloaderThread); stdcall;
var
  need_stop:boolean;
  i,last:integer;
  immediate_call:boolean;
begin
  FZLogMgr.Get.Write(TH_LBL+'DL thread started', FZ_LOG_INFO);
  need_stop:=false;
  while (not need_stop) do begin
    th._ProcessCommands();
    immediate_call:=false;

    windows.EnterCriticalSection(th._lock);
    try
      for i:=length(th._downloaders)-1 downto 0 do begin
        if not th._downloaders[i].IsDownloading() then begin
          FZLogMgr.Get.Write(TH_LBL+'Removing from active list DL '+th._downloaders[i].GetFilename(), FZ_LOG_INFO);
          th._downloaders[i].Release();
          last:=length(th._downloaders)-1;
          if i<last then begin
            th._downloaders[i]:=th._downloaders[last];
          end;
          setlength(th._downloaders, last);
          FZLogMgr.Get.Write(TH_LBL+'Active downloaders count '+inttostr(length(th._downloaders)), FZ_LOG_INFO);
        end;
      end;

      if length(th._downloaders)>0 then begin
        immediate_call:=th.ProcessDownloads();
      end;

      need_stop:=th._need_terminate and (length(th._downloaders)=0);
    finally
      windows.LeaveCriticalSection(th._lock);
    end;

    if not immediate_call then begin
      Sleep(1);
    end;
  end;
  FZLogMgr.Get.Write(TH_LBL+'DL thread finished', FZ_LOG_INFO);
  th._thread_active:=false;
end;

procedure DownloaderThreadBodyWrapper(); cdecl;
asm
  pushad
    push ebx
    call DownloaderThreadBody
  popad
end;

procedure UnpackerThreadBody(downloader:FZFileDownloader); stdcall;
var
  size:cardinal;
begin
  FZLogMgr.Get.Write(CB_LBL+'Unpacker thread started', FZ_LOG_INFO);
  if (downloader.GetCompressionType()<>0) then begin
    size:=DecompressFile(downloader.GetFilename(), downloader.GetCompressionType());
    if size=0 then begin
      downloader.SetStatus(DOWNLOAD_ERROR);
    end else begin
      downloader.SetFileSize(size);
      downloader.SetDownloadedBytesCount(size);
    end;
  end;
  downloader.Release();
  FZLogMgr.Get.Write(CB_LBL+'Unpacker thread finished', FZ_LOG_INFO);
end;

procedure UnpackerThreadBodyWrapper(); cdecl;
asm
  pushad
    push ebx
    call UnpackerThreadBody
  popad
end;

procedure OnDownloadInProgress(downloader:FZFileDownloader; filesize:cardinal; downloaded:cardinal);
begin
  downloader.Lock();
  downloader.SetDownloadedBytesCount(downloaded);
  downloader.SetFileSize(filesize);
  downloader.Unlock();
end;

procedure OnDownloadFinished(downloader:FZFileDownloader; dlresult:FZDownloadResult);
begin
  downloader.Lock();
  FZLogMgr.Get.Write(CB_LBL+'Download finished for '+downloader.GetFileName()+' with result '+inttostr(cardinal(dlresult)), FZ_LOG_INFO);
  downloader.SetStatus(dlresult);
  if (dlresult=DOWNLOAD_SUCCESS) and (downloader.GetCompressionType()<>0) then begin
    downloader.Acquire();
    CreateThreadedFun(@UnpackerThreadBodyWrapper, downloader);
  end;

  downloader.Unlock();
end;

{ FZCurlDownloaderThread }

constructor FZCurlDownloaderThread.Create;
begin
  inherited;
  _multi_handle:=curl_multi_init();
  if _multi_handle = nil then begin
     FZLogMgr.Get.Write(TH_LBL+'Cannot create multy handle!', FZ_LOG_ERROR);
    _good:=false;
  end;
end;

destructor FZCurlDownloaderThread.Destroy;
begin
  if _good then begin
    curl_multi_cleanup(_multi_handle);
  end;
  inherited Destroy;
end;

function FZCurlDownloaderThread.CreateDownloader(url: string; filename: string;
  compression_type: cardinal): FZFileDownloader;
begin
  result:=FZCurlFileDownloader.Create(url, filename, compression_type, self);
end;

function CurlWriteCb(ptr:PChar; size:cardinal; nitems:Cardinal; userdata:pointer):cardinal; cdecl;
var
  res:cardinal;
  dl:FZFileDownloader;
begin
  res:=0;
  dl:=userdata;
  if (FZCurlFileDownloader(dl)._file_hndl<>INVALID_HANDLE_VALUE) then begin
    WriteFile(FZCurlFileDownloader(dl)._file_hndl, ptr[0], nitems*size, res, nil);
  end;
  result:=nitems*size;
end;

function CurlProgressCb(clientp:pointer; dltotal:int64; dlnow:int64; {%H-}ultotal:int64; {%H-}ulnow:int64):integer; cdecl;
var
  downloader:FZFileDownloader;
begin
  downloader:=clientp;
  OnDownloadInProgress(downloader, dltotal, dlnow);
  result:=CURLE_OK;
end;

function FZCurlDownloaderThread.StartDownload(dl: FZFileDownloader): boolean;
var
  purl:pTCURL;
  dl_i:integer;
  fname:PAnsiChar;
  useragent:PAnsiChar;
begin
  dl.Lock();
  try
    if not _good then begin
      FZLogMgr.Get.Write(TH_LBL+'Thread is not in a good state', FZ_LOG_ERROR);
      dl.SetRequestId(0);
    end else if _FindDownloader(dl)<0 then begin
      fname:=PAnsiChar(dl.GetFilename());

      FZLogMgr.Get.Write(TH_LBL+'Opening file '+fname, FZ_LOG_INFO);

      FZCurlFileDownloader(dl)._file_hndl:=CreateFile(fname, GENERIC_WRITE, FILE_SHARE_READ, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
      if FZCurlFileDownloader(dl)._file_hndl = INVALID_HANDLE_VALUE then begin
        FZLogMgr.Get.Write(TH_LBL+'File creation failed for '+dl.GetFilename(), FZ_LOG_ERROR);
        exit;
      end;
      FZLogMgr.Get.Write(TH_LBL+'File '+fname+' opened, handle is '+inttostr(FZCurlFileDownloader(dl)._file_hndl), FZ_LOG_INFO);

      FZLogMgr.Get.Write(TH_LBL+'Setting up DL handle', FZ_LOG_INFO);
      purl:=curl_easy_init();
      if purl = nil then begin
        FZLogMgr.Get.Write(TH_LBL+'Failed to create dl handle!', FZ_LOG_ERROR );
        exit;
      end;

      useragent:=PAnsiChar('FreeZone Curl-Downloader, build '+{$INCLUDE %DATE});

      curl_easy_setopt(purl, CURLOPT_URL, uintptr(PAnsiChar(dl.GetUrl())));
      curl_easy_setopt(purl, CURLOPT_WRITEFUNCTION, uintptr(@CurlWriteCb) );
      curl_easy_setopt(purl, CURLOPT_WRITEDATA, uintptr(dl));
      curl_easy_setopt(purl, CURLOPT_NOPROGRESS, 0);
      curl_easy_setopt(purl, CURLOPT_FAILONERROR, 1);
      curl_easy_setopt(purl, CURLOPT_USERAGENT, uintptr(useragent));
      curl_easy_setopt(purl, CURLOPT_XFERINFODATA, uintptr(dl));
      curl_easy_setopt(purl, CURLOPT_XFERINFOFUNCTION, uintptr(@CurlProgressCb));
      dl.SetRequestId(uintptr(purl));
      curl_multi_add_handle(_multi_handle, purl);
      FZLogMgr.Get.Write(TH_LBL+'Download started for dl '+inttostr(cardinal(dl))+', handle '+inttostr(cardinal(purl)), FZ_LOG_INFO);

      dl_i:=length(_downloaders);
      setlength(_downloaders, dl_i+1);
      _downloaders[dl_i]:=dl;
      result:=true;
    end;
  finally
    dl.Unlock();
  end;
end;

function FZCurlDownloaderThread.ProcessDownloads():boolean;
var
  cnt, inprogress, i:integer;
  msg:pCURLMsg;
  dl:FZFileDownloader;

  dl_result:CURLcode;
  dl_handle:pTCURL;
begin
  result:=curl_multi_perform(_multi_handle, @inprogress) = CURLM_CALL_MULTI_PERFORM;

  repeat
    msg :=curl_multi_info_read(_multi_handle, @cnt);
    if (msg<>nil) then begin
      if (msg.msg = CURLMSG_DONE) then begin
        dl:=nil;
        for i:=length(_downloaders)-1 downto 0 do begin
          if _downloaders[i].GetRequestId() = uintptr(msg.easy_handle) then begin
            dl:=_downloaders[i];
            break;
          end;
        end;

        //Скопируем статус закачки и хендл (после закрытия хендла доступ к ним пропадет)
        dl_result:=msg.data.result;
        dl_handle:=msg.easy_handle;

        //Оптимизация - закрываем соединение, дабы оно не "висело" во время распаковки
        curl_multi_remove_handle(_multi_handle, msg.easy_handle);
        curl_easy_cleanup(msg.easy_handle);

        if dl<>nil then begin
          if (FZCurlFileDownloader(dl)<>nil) and (INVALID_HANDLE_VALUE<>FZCurlFileDownloader(dl)._file_hndl) then begin
            FZLogMgr.Get.Write(TH_LBL+'Close file handle '+inttostr(FZCurlFileDownloader(dl)._file_hndl), FZ_LOG_INFO);
            CloseHandle(FZCurlFileDownloader(dl)._file_hndl);
            FZCurlFileDownloader(dl)._file_hndl:=INVALID_HANDLE_VALUE;
          end;
          if dl_result = CURLE_OK then begin
            OnDownloadFinished(dl, DOWNLOAD_SUCCESS);
          end else begin
            FZLogMgr.Get.Write(TH_LBL+'Curl Download Error  ('+inttostr(dl_result)+')', FZ_LOG_ERROR);
            OnDownloadFinished(dl, DOWNLOAD_ERROR);
          end;
          dl.SetRequestId(0);
        end else begin
          FZLogMgr.Get.Write(TH_LBL+'Downloader not found for handle '+inttostr(uintptr(dl_handle)), FZ_LOG_ERROR);
        end;
      end;
    end;
  until cnt = 0 ;
end;

function FZCurlDownloaderThread.CancelDownload(dl: FZFileDownloader): boolean;
var
  purl:pTCURL;
  dl_i:integer;
  code:CURLMcode;
begin
  result:=false;
  dl_i:=_FindDownloader(dl);
  if dl_i>=0 then begin
    try
      dl.Lock();
      purl:=pointer(dl.GetRequestId());
      if purl<>nil then begin
        FZLogMgr.Get.Write(TH_LBL+'Cancelling request '+inttostr(uintptr(purl)), FZ_LOG_INFO);
        if (FZCurlFileDownloader(dl)<>nil) and (INVALID_HANDLE_VALUE<>FZCurlFileDownloader(dl)._file_hndl) then begin
          CloseHandle(FZCurlFileDownloader(dl)._file_hndl);
          FZCurlFileDownloader(dl)._file_hndl:=INVALID_HANDLE_VALUE;
        end;
        OnDownloadFinished(dl, DOWNLOAD_ERROR);
        code:=curl_multi_remove_handle(_multi_handle, purl);
        if code = CURLM_OK then begin
          curl_easy_cleanup(purl);
        end else begin
          FZLogMgr.Get.Write(TH_LBL+'Fail to remove from multi handle ('+inttostr(code)+')', FZ_LOG_ERROR);
        end;
        dl.SetRequestId(0);
        result:=true;
      end;
    finally
      dl.Unlock();
    end;
  end else begin
    FZLogMgr.Get.Write(TH_LBL+'Downloader not found', FZ_LOG_INFO);
  end;
end;

{ FZCurlFileDownloader }

constructor FZCurlFileDownloader.Create(url: string; filename: string;
  compression_type: cardinal; thread: FZDownloaderThread);
begin
  inherited;
  _request := 0;
  _file_hndl:=INVALID_HANDLE_VALUE;
end;

function FZCurlFileDownloader.IsDownloading: boolean;
begin
  Lock();
  result:=(_request<>0);
  Unlock();
end;

destructor FZCurlFileDownloader.Destroy;
begin
  inherited Destroy;
end;

procedure FZCurlFileDownloader.Flush;
begin
  Lock();
  if _file_hndl<>INVALID_HANDLE_VALUE then begin
    FZLogMgr.Get.Write(DL_LBL+'Flushing file '+_filename+' ('+inttostr(_file_hndl)+')', FZ_LOG_INFO);
    FlushFileBuffers(_file_hndl);
  end;
  Unlock();
end;

{ FZGameSpyFileDownloader }

constructor FZGameSpyFileDownloader.Create(url: string; filename: string;
  compression_type: cardinal; thread: FZDownloaderThread);
begin
  inherited;
  _request:=GHTTPRequestError;
end;

function FZGameSpyFileDownloader.IsDownloading: boolean;
begin
  Lock();
  result:=(_request<>GHTTPRequestError);
  Unlock();
end;

procedure FZGameSpyFileDownloader.Flush;
begin
  FZLogMgr.Get.Write(DL_LBL+'Flush request for '+_filename, FZ_LOG_INFO);
end;

{ FZGameSpyDownloaderThread }

constructor FZGameSpyDownloaderThread.Create;
begin
  inherited;

  _dll_handle := LoadLibrary('xrGameSpy.dll');
  _xrGS_ghttpStartup:=GetProcAddress( _dll_handle, 'xrGS_ghttpStartup');
  _xrGS_ghttpCleanup:=GetProcAddress( _dll_handle, 'xrGS_ghttpCleanup');
  _xrGS_ghttpThink:=GetProcAddress( _dll_handle, 'xrGS_ghttpThink');
  _xrGS_ghttpSave:=GetProcAddress( _dll_handle, 'xrGS_ghttpSave');
  _xrGS_ghttpSaveEx:=GetProcAddress( _dll_handle, 'xrGS_ghttpSaveEx');
  _xrGS_ghttpCancelRequest:=GetProcAddress( _dll_handle, 'xrGS_ghttpCancelRequest');

  if ( @_xrGS_ghttpStartup<>nil ) and ( @_xrGS_ghttpCleanup<>nil ) and ( @_xrGS_ghttpThink<>nil ) and ( @_xrGS_ghttpSave<>nil ) and ( @_xrGS_ghttpSaveEx<>nil ) and ( @_xrGS_ghttpCancelRequest<>nil ) then begin
    _xrGS_ghttpStartup();
  end else begin
    _good:=false;
    FZLogMgr.Get.Write(TH_LBL+'Downloader thread in a bad state', FZ_LOG_ERROR);
  end;
end;

destructor FZGameSpyDownloaderThread.Destroy;
begin
  FZLogMgr.Get.Write(TH_LBL+'Destroying GS downloader thread', FZ_LOG_INFO);

  windows.EnterCriticalSection(_lock);
  _need_terminate:=true;
  windows.LeaveCriticalSection(_lock);

  _WaitForThreadTermination();
  if _good then begin
    FZLogMgr.Get.Write(TH_LBL+'Turn off GS service', FZ_LOG_INFO);
    _xrGS_ghttpCleanup();
  end;
  FreeLibrary(_dll_handle);

  inherited Destroy;
end;

procedure OnGameSpyDownloadInProgress({%H-}request: cardinal; {%H-}state:cardinal; {%H-}buffer:PAnsiChar;
                                      {%H-}bufferLen_low: cardinal; {%H-}bufferLen_high: cardinal;
                                      bytesReceived_low: cardinal; {%H-}bytesReceived_high: cardinal;
                                      totalSize_low: cardinal; {%H-}totalSize_high: cardinal;
                                      param:pointer ); cdecl;
var
  downloader:FZFileDownloader;
begin
  downloader:=param;
  OnDownloadInProgress(downloader, totalSize_low, bytesReceived_low);
end;

function OnGamespyDownloadFinished({%H-}request: cardinal;
  requestResult: cardinal; {%H-}buffer: PAnsiChar; bufferLen_low: cardinal;
  {%H-}bufferLen_high: cardinal; param: pointer): cardinal; cdecl;
var
  downloader:FZFileDownloader;
begin
  downloader:=param;
  if requestResult = GHTTPSuccess then begin
    FZLogMgr.Get.Write(CB_LBL+'OnGamespyDownloadFinished ('+inttostr(requestResult)+')', FZ_LOG_INFO);
  end else begin
    FZLogMgr.Get.Write(CB_LBL+'OnGamespyDownloadFinished ('+inttostr(requestResult)+')', FZ_LOG_ERROR);
  end;
  downloader.Lock();
  downloader.SetDownloadedBytesCount(bufferLen_low);
  downloader.SetFileSize(bufferLen_low);
  downloader.SetRequestId(GHTTPRequestError); //Not downloading now

  if (requestResult=GHTTPSuccess) then begin
    OnDownloadFinished(downloader, DOWNLOAD_SUCCESS);
  end else begin
    OnDownloadFinished(downloader, DOWNLOAD_ERROR);
  end;
  downloader.Unlock();
  result:=1;
end;

function FZGameSpyDownloaderThread.CreateDownloader(url: string;
  filename: string; compression_type: cardinal): FZFileDownloader;
begin
  result:=FZGameSpyFileDownloader.Create(url, filename, compression_type, self);
end;

function FZGameSpyDownloaderThread.StartDownload(dl: FZFileDownloader): boolean;
var
  request:cardinal;
  progresscb, finishcb:pointer;
  dl_i:integer;
begin
  progresscb:=@OnGameSpyDownloadInProgress;
  finishcb:=@OnGamespyDownloadFinished;

  result:=false;
  dl.Lock();
  try
    if not _good then begin
      FZLogMgr.Get.Write(TH_LBL+'Thread is not in a good state', FZ_LOG_ERROR);
      dl.SetRequestId(GHTTPRequestError);
    end else if _FindDownloader(dl)<0 then begin
      request:=_xrGS_ghttpSaveEx(PAnsiChar(dl.GetUrl()),
                                 PAnsiChar(dl.GetFilename()),
                                 nil, nil,0, 0, progresscb, finishcb, dl);
      if request<>GHTTPRequestError then begin
        FZLogMgr.Get.Write(TH_LBL+'Download started, request '+inttostr(request), FZ_LOG_INFO);
        dl_i:=length(_downloaders);
        setlength(_downloaders, dl_i+1);
        _downloaders[dl_i]:=dl;
        result:=true;
      end else begin
        FZLogMgr.Get.Write(TH_LBL+'Failed to start download', FZ_LOG_INFO);
      end;

      dl.SetRequestId(request);
    end;
  finally
    dl.Unlock();
  end;
end;

function FZGameSpyDownloaderThread.ProcessDownloads:boolean;
begin
  _xrGS_ghttpThink();
  result:=false; //Don't call immediately
end;

function FZGameSpyDownloaderThread.CancelDownload(dl: FZFileDownloader): boolean;
var
  dl_i:integer;
  request:cardinal;
begin
  result:=false;
  dl_i:=_FindDownloader(dl);
  if dl_i>=0 then begin
    dl.Lock();
    request:=dl.GetRequestId();
    //Несмотря на то, что пока очередь не очищена, удаления не произойдет - все равно защитим от этого на всякий
    dl.Acquire();
    //Анлок необходим тут, так как во время работы функции отмены реквеста может начать работу колбэк прогресса (из потока мейнменю) и зависнуть на получении мьютекса - дедлок
    dl.Unlock();
    if request<>GHTTPRequestError then begin
      FZLogMgr.Get.Write(TH_LBL+'Cancelling request '+inttostr(request), FZ_LOG_INFO);
      _xrGS_ghttpCancelRequest(request);
      //Автоматически не вызывается при отмене - приходится вручную
      OnGamespyDownloadFinished(GHTTPRequestError, GHTTPRequestError, nil, 0, 0, dl);
    end;
    dl.Release();
    result:=true;
  end else begin
    FZLogMgr.Get.Write(TH_LBL+'Downloader not found', FZ_LOG_INFO);
  end;
end;

{ FZDownloaderThreadInfoQueue }

constructor FZDownloaderThreadInfoQueue.Create;
begin
  inherited;
  setlength(_queue, 0);
  _cur_items_cnt:=0;
end;

destructor FZDownloaderThreadInfoQueue.Destroy;
begin
  Flush();
  inherited;
end;

function FZDownloaderThreadInfoQueue.Add(item: FZDownloaderThreadCmd): boolean;
var
  i, cap:integer;
begin
  result:=true;
  item.downloader.Acquire();
  item.downloader.Lock();
  FZLogMgr.Get.Write(QUEUE_LBL+'Put command '+inttostr(cardinal(item.cmd))+' into DL queue for '+item.downloader.GetFilename(), FZ_LOG_INFO);
  cap:=Capacity();
  i:=Count();
  if (i+1>=cap) then begin
    setlength(_queue, i+1);
  end;
  _queue[i]:=item;
  _cur_items_cnt:=_cur_items_cnt+1;
  FZLogMgr.Get.Write(QUEUE_LBL+'Command in queue, count='+inttostr(_cur_items_cnt)+', capacity='+inttostr(length(_queue)), FZ_LOG_INFO);
  item.downloader.Unlock();
end;

procedure FZDownloaderThreadInfoQueue.Flush;
var
  i, cnt:integer;
begin
  cnt:=Count();
  FZLogMgr.Get.Write(QUEUE_LBL+'Flush commands', FZ_LOG_INFO);
  if cnt > 0 then begin
    for i:=0 to cnt-1 do begin
      _queue[i].downloader.Release();
    end;
    _cur_items_cnt:=0;
  end;
end;

function FZDownloaderThreadInfoQueue.Count: integer;
begin
  result:=_cur_items_cnt;
end;

function FZDownloaderThreadInfoQueue.Capacity: integer;
begin
  result:=length(_queue);
end;

function FZDownloaderThreadInfoQueue.Get(i: integer): FZDownloaderThreadCmd;
begin
  assert(i<Count(), QUEUE_LBL+'Invalid item index');
  result:=_queue[i];
end;

{ FZFileDownloader }

constructor FZFileDownloader.Create(url: string; filename: string;
  compression_type: cardinal; thread:FZDownloaderThread);
begin
  windows.InitializeCriticalSection(_lock);
  _url:=url;
  _filename:=filename;
  _compression_type:=compression_type;
  _downloaded_bytes:=0;
  _status:=DOWNLOAD_SUCCESS;
  _acquires_count:=0;
  _thread:=thread;
  FZLogMgr.Get.Write(DL_LBL+'Created downloader for '+_filename+' from '+url+', compression '+inttostr(_compression_type), FZ_LOG_INFO);
end;

destructor FZFileDownloader.Destroy;
begin
  FZLogMgr.Get.Write(DL_LBL+'Wait for DL finished for '+_filename, FZ_LOG_INFO);
  while IsBusy() do begin
    sleep(100);
  end;

  FZLogMgr.Get.Write(DL_LBL+'Destroying downloader for '+_filename, FZ_LOG_INFO);
  windows.DeleteCriticalSection(_lock);
  inherited Destroy;
end;

function FZFileDownloader.IsBusy: boolean;
begin
  Lock();
  result:=(_acquires_count > 0) or IsDownloading();
  Unlock();
end;

function FZFileDownloader.GetUrl: string;
begin
  Lock();
  result:=_url;
  Unlock();
end;

function FZFileDownloader.GetFilename: string;
begin
  Lock();
  result:=_filename;
  Unlock();
end;

function FZFileDownloader.GetCompressionType: cardinal;
begin
  Lock();
  result:=_compression_type;
  Unlock();
end;

function FZFileDownloader.StartAsyncDownload():boolean;
var
  info:FZDownloaderThreadCmd;
begin
  result:=false;
  Lock();
  if IsBusy() then begin
    FZLogMgr.Get.Write(DL_LBL+'Downloader is busy - cannot start async DL of '+_filename, FZ_LOG_INFO);
    Unlock();
    exit;
  end;

  FZLogMgr.Get.Write(DL_LBL+'Start async DL of '+_filename, FZ_LOG_INFO);
  Acquire(); //вызов показывает, что даунлоадер приписан к треду, тред зарелизит его перед удалением из списка
  try
    info.downloader:=self;
    info.cmd:=FZDownloaderAdd;
    result:=_thread.AddCommand(info);
  finally
    Unlock();
    if not result then Release();
  end;
end;

function FZFileDownloader.StartSyncDownload: boolean;
begin
  FZLogMgr.Get.Write(DL_LBL+'Start sync DL of '+_filename, FZ_LOG_INFO);
  result:=StartAsyncDownload();
  if result then begin
    FZLogMgr.Get.Write(DL_LBL+'Waiting for DL finished '+_filename, FZ_LOG_INFO);
    while(IsBusy()) do begin
      Sleep(100);
    end;
    result:= IsSuccessful();
  end;
end;

function FZFileDownloader.DownloadedBytes: cardinal;
begin
  Lock();
  result:=_downloaded_bytes;
  Unlock();
end;

function FZFileDownloader.IsSuccessful: boolean;
begin
  Lock();
  result:= _status=DOWNLOAD_SUCCESS;
  Unlock();
end;

function FZFileDownloader.RequestStop():boolean;
var
  info:FZDownloaderThreadCmd;
begin
  result:=true;
  Lock();
  FZLogMgr.Get.Write(DL_LBL+'RequestStop for downloader '+GetFilename()+', request='+inttostr(self._request), FZ_LOG_INFO);
  Acquire(); //To avoid removing before command is sent
  info.downloader:=self;
  info.cmd:=FZDownloaderStop;
  Unlock(); //Unlock to avoid deadlock between downloader's and thread's mutexes
  result:=_thread.AddCommand(info);
  Release();
end;

procedure FZFileDownloader.SetRequestId(id: uintptr);
begin
  Lock();
  FZLogMgr.Get.Write(DL_LBL+'Set request id='+inttostr(id)+' for '+GetFileName(), FZ_LOG_INFO);
  _request:=id;
  Unlock();
end;

function FZFileDownloader.GetRequestId: uintptr;
begin
  Lock();
  result:=_request;
  Unlock();
end;

procedure FZFileDownloader.Acquire;
var
  i:cardinal;
begin
  i:=InterlockedIncrement(_acquires_count);
  FZLogMgr.Get.Write(DL_LBL+'Downloader acquired (cnt='+inttostr(i)+') '+GetFileName(), FZ_LOG_INFO);
end;

procedure FZFileDownloader.Release;
var
  i:cardinal;
  name:string;
begin
  name:=GetFileName();
  i:=InterlockedDecrement(_acquires_count);
  FZLogMgr.Get.Write(DL_LBL+'Downloader released (cnt='+inttostr(i)+') '+name, FZ_LOG_INFO);
end;

procedure FZFileDownloader.Lock;
begin
  windows.EnterCriticalSection(_lock);
end;

procedure FZFileDownloader.Unlock;
begin
  windows.LeaveCriticalSection(_lock);
end;

procedure FZFileDownloader.SetStatus(status: FZDownloadResult);
begin
  Lock();
  _status:=status;
  Unlock();
end;

procedure FZFileDownloader.SetFileSize(filesize:cardinal);
begin
  Lock();
  _filesize:=filesize;
  Unlock();
end;

procedure FZFileDownloader.SetDownloadedBytesCount(count:cardinal);
begin
  Lock();
  _downloaded_bytes:=count;
  Unlock();
end;

{ FZDownloaderThread }
constructor FZDownloaderThread.Create;
begin
  inherited Create();
  windows.InitializeCriticalSection(_lock);
  _commands_queue:= FZDownloaderThreadInfoQueue.Create();

  _need_terminate:=false;
  _thread_active:=false;
  _good:=true;

  FZLogMgr.Get.Write(TH_LBL+'Creating downloader thread fun', FZ_LOG_INFO);
  _thread_active:=true;
  CreateThreadedFun(@DownloaderThreadBodyWrapper, self);
end;

function FZDownloaderThread.AddCommand(cmd: FZDownloaderThreadCmd):boolean;
begin
  result:=false;
  windows.EnterCriticalSection(_lock);
  try
    if not _good then exit;
    result:=_commands_queue.Add(cmd);
  finally
    windows.LeaveCriticalSection(_lock);
  end;
end;

destructor FZDownloaderThread.Destroy;
begin
  FZLogMgr.Get.Write(TH_LBL+'Destroying base downloader thread', FZ_LOG_INFO);

  //Make sure that thread is terminated
  windows.EnterCriticalSection(_lock);
  _need_terminate:=true;
  windows.LeaveCriticalSection(_lock);
  _WaitForThreadTermination();

  _commands_queue.Free();
  windows.DeleteCriticalSection(_lock);
  inherited Destroy;
end;

procedure FZDownloaderThread._WaitForThreadTermination;
var
  active:boolean;
begin
  active:=true;
  FZLogMgr.Get.Write(TH_LBL+'Waiting for DL thread termination', FZ_LOG_INFO);
  while(active) do begin
    windows.EnterCriticalSection(_lock);
    active:=_thread_active;
    windows.LeaveCriticalSection(_lock);
  end;
end;

function FZDownloaderThread._FindDownloader(dl: FZFileDownloader): integer;
var
  i:integer;
begin
  result:=-1;
  windows.EnterCriticalSection(_lock);
  for i:=length(_downloaders)-1 downto 0 do begin
    if dl = _downloaders[i] then begin
      result:=i;
      break;
    end;
  end;
  windows.LeaveCriticalSection(_lock);
end;

procedure FZDownloaderThread._ProcessCommands;
var
  i:integer;
  queue_cnt:integer;
  command:FZDownloaderThreadCmd;
begin
  windows.EnterCriticalSection(_lock);
  queue_cnt:=_commands_queue.Count();
  if queue_cnt>0 then begin
    FZLogMgr.Get.Write(TH_LBL+'Start processing commands ('+inttostr(queue_cnt)+')', FZ_LOG_INFO);
    for i:=0 to queue_cnt-1 do begin
      command:=_commands_queue.Get(i);
      case command.cmd of
        FZDownloaderAdd:begin
              FZLogMgr.Get.Write(TH_LBL+'Command "Add" for downloader '+command.downloader.GetFilename(), FZ_LOG_INFO);
              StartDownload(command.downloader);
        end;
        FZDownloaderStop: begin
              FZLogMgr.Get.Write(TH_LBL+'Command "Stop" for downloader '+command.downloader.GetFilename(), FZ_LOG_INFO);
              CancelDownload(command.downloader);
        end;
        else begin
          FZLogMgr.Get.Write(TH_LBL+'Unknown command!', FZ_LOG_ERROR);
        end;
      end;
      FZLogMgr.Get.Write(TH_LBL+'Command processed, active downloaders count '+inttostr(length(_downloaders)), FZ_LOG_INFO);
    end;
    _commands_queue.Flush();
    FZLogMgr.Get.Write(TH_LBL+'Processing commands finished', FZ_LOG_INFO);
  end;
  windows.LeaveCriticalSection(_lock);
end;

end.

