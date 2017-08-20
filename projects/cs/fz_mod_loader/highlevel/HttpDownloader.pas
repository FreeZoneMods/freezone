unit HttpDownloader;

{$mode delphi}

interface
type

  FZDownloaderThread = class;

  { FZFileDownloader }

  FZFileDownloader = class
  public
    constructor Create(url:string; filename:string; compression_type:cardinal; thread:FZDownloaderThread );
    destructor Destroy; override;
    function IsDownloading():boolean;
    function IsBusy():boolean;
    function GetUrl:string;
    function GetFilename:string;
    function GetCompressionType:cardinal;
    function StartAsyncDownload():boolean;
    function StartSyncDownload():boolean;
    function DownloadedBytes():cardinal;
    function IsSuccessful():boolean;
    function RequestStop():boolean;
  private
    _lock:TRTLCriticalSection;
    _request:cardinal;
    _url:string;
    _filename:string;
    _downloaded_bytes:cardinal;
    _compression_type:cardinal;
    _status:cardinal;
    _acquires_count:integer;
    _thread:FZDownloaderThread;
    _filesize:cardinal;
    procedure SetRequestId(id:cardinal);
    function GetRequestId():cardinal;
    procedure Acquire();
    procedure Release();
    procedure Lock();
    procedure Unlock();
    procedure SetStatus(status:cardinal);
    procedure SetFileSize(filesize:cardinal);
    procedure SetDownloadedBytesCount(count:cardinal);
  end;
  pFZFileDownloader=^FZFileDownloader;

  FZDownloaderThreadCmd = (FZDownloaderAdd, FZDownloaderStop);

  { FZDownloaderThreadInfo }

  FZDownloaderThreadInfo = record
    downloader:FZFileDownloader;
    cmd:FZDownloaderThreadCmd;
  end;

  FZDownloaderThread = class
    public
      constructor Create;
      function AddCommand(info:FZDownloaderThreadInfo):boolean;
      destructor Destroy; override;
    private
      _lock:TRTLCriticalSection;
      _commands:array of FZDownloaderThreadInfo;
      _downloaders:array of FZFileDownloader;
      _need_terminate:boolean;
      _thread_active:boolean;
      _good:boolean;

      _dll_handle:THandle;
      _xrGS_ghttpStartup:procedure(); cdecl;
      _xrGS_ghttpCleanup:procedure(); cdecl;
      _xrGS_ghttpThink:procedure(); cdecl;
      _xrGS_ghttpSave:function( url:PAnsiChar; filename:PAnsiChar; blocking:cardinal; completedCallback:pointer; param:pointer ):cardinal; cdecl;
      _xrGS_ghttpSaveEx:function( url:PAnsiChar; filename:PAnsiChar; headers:PAnsiChar; post:pointer; throttle:cardinal; blocking:cardinal; progressCallback:pointer; completedCallback:pointer; param:pointer ):cardinal; cdecl;
      _xrGS_ghttpCancelRequest:procedure( request:cardinal ); cdecl;

      procedure _WaitForThreadTermination();
      function _FindDownloader(dl:FZFileDownloader):integer;
      procedure _ProcessCommands();
  end;

implementation
uses windows, global_functions, LogMgr, sysutils, Decompressor;

const
  GHTTPSuccess:cardinal=0;
  GHTTPRequestError:cardinal=$FFFFFFFF;

{ Thread functions & Callbacks }

procedure DownloaderThreadBody(th:FZDownloaderThread); stdcall;
var
  need_stop:boolean;
  i,last:integer;
begin
  FZLogMgr.Get.Write('DL thread started', FZ_LOG_DBG);
  need_stop:=false;
  while (not need_stop) do begin
    th._ProcessCommands();

    EnterCriticalSection(th._lock);
    try
      for i:=length(th._downloaders)-1 downto 0 do begin
        if th._downloaders[i].GetRequestId() = GHTTPRequestError then begin
          FZLogMgr.Get.Write('Removing from active list DL '+th._downloaders[i].GetFilename(), FZ_LOG_DBG);
          th._downloaders[i].Release();
          last:=length(th._downloaders)-1;
          if i<last then begin
            th._downloaders[i]:=th._downloaders[last];
          end;
          setlength(th._downloaders, last);
          FZLogMgr.Get.Write('Active downloaders count '+inttostr(length(th._downloaders)), FZ_LOG_DBG);
        end;
      end;

      if length(th._downloaders)>0 then begin
        th._xrGS_ghttpThink();
      end;

      need_stop:=th._need_terminate and (length(th._downloaders)=0);
    finally
      LeaveCriticalSection(th._lock);
    end;

    Sleep(10);
  end;
  FZLogMgr.Get.Write('DL thread finished', FZ_LOG_DBG);
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
  FZLogMgr.Get.Write('Unpacker thread started', FZ_LOG_DBG);
  if (downloader.GetCompressionType()<>0) then begin
    size:=DecompressFile(downloader.GetFilename(), downloader.GetCompressionType());
    if size=0 then begin
      downloader.SetStatus(GHTTPRequestError);
    end else begin
      downloader.SetFileSize(size);
      downloader.SetDownloadedBytesCount(size);
    end;
  end;
  downloader.Release();
  FZLogMgr.Get.Write('Unpacker thread finished', FZ_LOG_DBG);
end;

procedure UnpackerThreadBodyWrapper(); cdecl;
asm
  pushad
    push ebx
    call UnpackerThreadBody
  popad
end;

procedure OnDownloadInProgress(request: cardinal; state:cardinal; buffer:PAnsiChar;
                               bufferLen_low: cardinal; bufferLen_high: cardinal;
                               bytesReceived_low: cardinal; bytesReceived_high: cardinal;
                               totalSize_low: cardinal; totalSize_high: cardinal;
                               param:pointer ); cdecl;
var
  downloader:FZFileDownloader;
begin
  downloader:=param;
  downloader.Lock();
  downloader.SetDownloadedBytesCount(bytesReceived_low);
  downloader.SetFileSize(totalSize_low);
  downloader.Unlock();
end;

function OnDownloadFinished(request: cardinal;
  requestResult: cardinal; buffer: PAnsiChar; bufferLen_low: cardinal;
  bufferLen_high: cardinal; param: pointer): cardinal; cdecl;
var
  downloader:FZFileDownloader;
begin
  downloader:=param;
  FZLogMgr.Get.Write('OnDownloadFinished', FZ_LOG_DBG);
  downloader.Lock();
  downloader.SetDownloadedBytesCount(bufferLen_low);
  downloader.SetFileSize(bufferLen_low);
  downloader.SetRequestId(GHTTPRequestError); //No downloading now
  downloader.SetStatus(requestResult);
  FZLogMgr.Get.Write('Download finished for '+downloader.GetFileName()+' with result '+inttostr(requestResult), FZ_LOG_DBG);

  if (requestResult=GHTTPSuccess) and (downloader.GetCompressionType()<>0) then begin
    downloader.Acquire();
    fz_thread_spawn(@UnpackerThreadBodyWrapper, downloader);
  end;
  downloader.Unlock();
  result:=1;
end;

{ FZFileDownloader }

constructor FZFileDownloader.Create(url: string; filename: string;
  compression_type: cardinal; thread:FZDownloaderThread);
begin
  InitializeCriticalSection(_lock);
  _request:=GHTTPRequestError;
  _url:=url;
  _filename:=filename;
  _compression_type:=compression_type;
  _downloaded_bytes:=0;
  _status:=GHTTPSuccess;
  _acquires_count:=0;
  _thread:=thread;
  FZLogMgr.Get.Write('Created downloader for '+_filename+', compression '+inttostr(_compression_type), FZ_LOG_DBG);
end;

destructor FZFileDownloader.Destroy;
begin
  FZLogMgr.Get.Write('Wait for DL finished for '+_filename, FZ_LOG_DBG);
  while IsBusy() do begin
    sleep(100);
  end;

  FZLogMgr.Get.Write('Destroying downloader for '+_filename, FZ_LOG_DBG);
  DeleteCriticalSection(_lock);
  inherited Destroy;
end;

function FZFileDownloader.IsDownloading: boolean;
begin
  Lock();
  result:=(_request<>GHTTPRequestError);
  Unlock();
end;

function FZFileDownloader.IsBusy: boolean;
begin
  Lock();
  result:=IsDownloading() or (_acquires_count > 0);
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
  info:FZDownloaderThreadInfo;
begin
  result:=false;
  Lock();
  if IsBusy() then begin
    FZLogMgr.Get.Write('Downloader is busy - cannot start async DL of '+_filename, FZ_LOG_DBG);
    Unlock();
    exit;
  end;

  FZLogMgr.Get.Write('Start async DL of '+_filename, FZ_LOG_DBG);
  Acquire();
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
var
  res:cardinal;
begin
  FZLogMgr.Get.Write('Start sync DL of '+_filename, FZ_LOG_DBG);
  result:=StartAsyncDownload();
  if result then begin
    FZLogMgr.Get.Write('Waiting for DL finished '+_filename, FZ_LOG_DBG);
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
  result:= _status=GHTTPSuccess;
  Unlock();
end;

function FZFileDownloader.RequestStop():boolean;
var
  info:FZDownloaderThreadInfo;
begin
  Lock();
  if IsDownloading() then begin
    info.downloader:=self;
    info.cmd:=FZDownloaderStop;
    result:=_thread.AddCommand(info);
  end;
  Unlock();
end;

procedure FZFileDownloader.SetRequestId(id: cardinal);
begin
  Lock();
  _request:=id;
  Unlock();
end;

function FZFileDownloader.GetRequestId: cardinal;
begin
  Lock();
  result:=_request;
  Unlock();
end;

procedure FZFileDownloader.Acquire;
begin
  FZLogMgr.Get.Write('Downloader acquired', FZ_LOG_DBG);
  InterlockedIncrement(_acquires_count);
end;

procedure FZFileDownloader.Release;
begin
  FZLogMgr.Get.Write('Downloader released', FZ_LOG_DBG);
  InterlockedDecrement(_acquires_count);
end;

procedure FZFileDownloader.Lock;
begin
  EnterCriticalSection(_lock);
end;

procedure FZFileDownloader.Unlock;
begin
  LeaveCriticalSection(_lock);
end;

procedure FZFileDownloader.SetStatus(status: cardinal);
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
  InitializeCriticalSection(_lock);

  _dll_handle := LoadLibrary('xrGameSpy.dll');
  _xrGS_ghttpStartup:=GetProcAddress( _dll_handle, 'xrGS_ghttpStartup');
  _xrGS_ghttpCleanup:=GetProcAddress( _dll_handle, 'xrGS_ghttpCleanup');
  _xrGS_ghttpThink:=GetProcAddress( _dll_handle, 'xrGS_ghttpThink');
  _xrGS_ghttpSave:=GetProcAddress( _dll_handle, 'xrGS_ghttpSave');
  _xrGS_ghttpSaveEx:=GetProcAddress( _dll_handle, 'xrGS_ghttpSaveEx');
  _xrGS_ghttpCancelRequest:=GetProcAddress( _dll_handle, 'xrGS_ghttpCancelRequest');

  _need_terminate:=false;
  _thread_active:=false;

  if ( @_xrGS_ghttpStartup<>nil ) and ( @_xrGS_ghttpCleanup<>nil ) and ( @_xrGS_ghttpThink<>nil ) and ( @_xrGS_ghttpSave<>nil ) and ( @_xrGS_ghttpSaveEx<>nil ) and ( @_xrGS_ghttpCancelRequest<>nil ) then begin
    _good:=true;
    _xrGS_ghttpStartup();
  end else begin
    _good:=false;
    FZLogMgr.Get.Write('Downloader thread in a bad state', FZ_LOG_ERROR);
    exit;
  end;

  FZLogMgr.Get.Write('Creating downloader thread', FZ_LOG_DBG);

  _thread_active:=true;
  fz_thread_spawn(@DownloaderThreadBodyWrapper, self);
end;

function FZDownloaderThread.AddCommand(info: FZDownloaderThreadInfo):boolean;
var
  i:integer;
begin
  result:=false;
  EnterCriticalSection(_lock);
  try
    FZLogMgr.Get.Write('Put command '+inttostr(cardinal(info.cmd))+' into DL queue for '+info.downloader.GetFilename(), FZ_LOG_DBG);
    if not _good then exit;
    i:=length(_commands);
    setlength(_commands, i+1);
    _commands[i]:=info;
  finally
    LeaveCriticalSection(_lock);
  end;
  result:=true;
end;

destructor FZDownloaderThread.Destroy;
begin
  FZLogMgr.Get.Write('Destroying downloader thread', FZ_LOG_DBG);

  EnterCriticalSection(_lock);
  _need_terminate:=true;
  LeaveCriticalSection(_lock);

  _WaitForThreadTermination();
  if _good then begin
    FZLogMgr.Get.Write('Turn off GS service', FZ_LOG_DBG);
    _xrGS_ghttpCleanup();
  end;
  FreeLibrary(_dll_handle);
  DeleteCriticalSection(_lock);
  inherited Destroy;
end;

procedure FZDownloaderThread._WaitForThreadTermination;
var
  active:boolean;
begin
  FZLogMgr.Get.Write('Waiting for DL thread termination', FZ_LOG_DBG);
  while(active) do begin
    EnterCriticalSection(_lock);
    active:=_thread_active;
    LeaveCriticalSection(_lock);
  end;
end;

function FZDownloaderThread._FindDownloader(dl: FZFileDownloader): integer;
var
  i:integer;
begin
  result:=-1;
  EnterCriticalSection(_lock);
  for i:=length(_downloaders)-1 downto 0 do begin
    if dl = _downloaders[i] then begin
      result:=i;
      break;
    end;
  end;
  LeaveCriticalSection(_lock);
end;

procedure FZDownloaderThread._ProcessCommands;
var
  i:integer;
  dl_i:integer;
  request:cardinal;
  progresscb, finishcb:pointer;
begin
  progresscb:=@OnDownloadInProgress;
  finishcb:=@OnDownloadFinished;

  EnterCriticalSection(_lock);
  if length(_commands)>0 then begin
    for i:=0 to length(_commands)-1 do begin
      case _commands[i].cmd of
        FZDownloaderAdd:begin
              FZLogMgr.Get.Write('Command "Add" for downloader '+_commands[i].downloader.GetFilename(), FZ_LOG_DBG);
              if not _good then begin
                _commands[i].downloader.SetRequestId(GHTTPRequestError);
              end;
              if _FindDownloader(_commands[i].downloader)<0 then begin
                _commands[i].downloader.Lock();
                try
                  dl_i:=length(_downloaders);
                  setlength(_downloaders, dl_i+1);
                  request:=_xrGS_ghttpSaveEx(PAnsiChar(_commands[i].downloader.GetUrl()),
                                             PAnsiChar(_commands[i].downloader.GetFilename()),
                                             nil, nil,0, 0, progresscb, finishcb, _commands[i].downloader);
                  if request<>GHTTPRequestError then begin
                    FZLogMgr.Get.Write('Download started, request '+inttostr(request), FZ_LOG_DBG);
                    _downloaders[dl_i]:=_commands[i].downloader;
                  end else begin
					FZLogMgr.Get.Write('Failed to start download', FZ_LOG_DBG);
		          end;
                  _commands[i].downloader.SetRequestId(request);
                finally
                  _commands[i].downloader.Unlock();
                end;
              end;
        end;
        FZDownloaderStop: begin
              dl_i:=_FindDownloader(_commands[i].downloader);
              if dl_i>=0 then begin
                _commands[i].downloader.Lock();
                try
                  FZLogMgr.Get.Write('Command "Stop" for downloader '+_commands[i].downloader.GetFilename(), FZ_LOG_DBG);
                  request:=_commands[i].downloader.GetRequestId();
                  if request<>GHTTPRequestError then begin
                    FZLogMgr.Get.Write('Cancelling request '+inttostr(request), FZ_LOG_DBG);
                    _xrGS_ghttpCancelRequest(request);
                    OnDownloadFinished(GHTTPRequestError, GHTTPRequestError, nil, 0, 0, _commands[i].downloader);
                  end;
                finally
                  _commands[i].downloader.Unlock();
                end;
              end else begin
                FZLogMgr.Get.Write('Downloader not found', FZ_LOG_DBG);
              end;
        end;
        else begin
              FZLogMgr.Get.Write('Unknown command!', FZ_LOG_ERROR);
        end;
      end;
      FZLogMgr.Get.Write('Command processed, active downloaders count '+inttostr(length(_downloaders)), FZ_LOG_DBG);
    end;
    setlength(_commands, 0);
    FZLogMgr.Get.Write('Reset command queue', FZ_LOG_DBG);
  end;
  LeaveCriticalSection(_lock);
end;

end.

