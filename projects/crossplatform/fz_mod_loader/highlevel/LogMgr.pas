unit LogMgr;
{$mode delphi}
interface
type
  FZLogMessageSeverity = ( FZ_LOG_DBG, FZ_LOG_INFO, FZ_LOG_IMPORTANT_INFO, FZ_LOG_ERROR, FZ_LOG_SILENT );

  { FZLogMgr }

  FZLogMgr = class
  private
    _is_log_enabled:boolean;
    _severity:FZLogMessageSeverity;
    _lock:TRTLCriticalSection;

    {%H-}constructor Create();
  public
    class function Get():FZLogMgr;
    procedure Write(data:string; severity:FZLogMessageSeverity);
    procedure SetSeverity(sev:FZLogMessageSeverity);
    destructor Destroy(); override;
  end;
  pFZLogMgr = ^FZLogMgr;

  function Init():boolean;
  function Free():boolean;

implementation
uses abstractions, windows, sysutils;
var
  Mgr:FZLogMgr;

{FZLogMgr}

constructor FZLogMgr.Create();
begin
  inherited;
  InitializeCriticalSection(_lock);
  _is_log_enabled := false;
  _severity:=FZ_LOG_DBG;
end;

class function FZLogMgr.Get(): FZLogMgr;
begin
  assert(Mgr<>nil);
  result:=Mgr;
end;

procedure FZLogMgr.Write(data:string; severity:FZLogMessageSeverity);
var
  s:string;
begin
  EnterCriticalSection(_lock);
  try
    if (not _is_log_enabled) or (severity < _severity) then exit;

    data:='('+inttostr(GetThreadId())+') ('+inttostr(GetCurrentTime())+') '+data;
    if severity = FZ_LOG_ERROR then
      s:='! FZ: '+data
    else
      s:='~ FZ: '+data;

    VersionAbstraction().Log(PAnsiChar(s));
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZLogMgr.SetSeverity(sev: FZLogMessageSeverity);
begin
  _is_log_enabled:=true;
  _severity:=sev;
end;

destructor FZLogMgr.Destroy();
begin
  DeleteCriticalSection(_lock);
  inherited;
end;

function Init():boolean;
begin
  Mgr:=FZLogMgr.Create();
  result:=true;
end;

function Free: boolean;
begin
  result:=true;
  if Mgr<>nil then begin
    Mgr.Free();
    Mgr:=nil;
  end;
end;

end.
