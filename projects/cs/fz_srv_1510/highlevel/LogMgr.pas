unit LogMgr;
{$mode delphi}
interface
uses SyncObjs, SysUtils, srcBase, srcCalls, Console;
type
  FZLogMessageSeverity = ( FZ_LOG_DBG, FZ_LOG_INFO, FZ_LOG_IMPORTANT_INFO, FZ_LOG_ERROR, FZ_LOG_SILENT );

  { FZFileLogger }

  FZFileLogger = class
  private
    _enabled:boolean;
    _file:textfile;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure EnableLogging();
    procedure DisableLogging();
    procedure Log(msg:string; severity:FZLogMessageSeverity);
  end;

  { FZLogMgr }

  FZLogMgr = class
  private
    _target_severity:cardinal; //DO NOT make class member!
    _logfun:srcBaseFunction;
    _logfile:FZFileLogger;
    _WriteLock:TCriticalSection;
    {%H-}constructor Create();

  public
    class function Get():FZLogMgr;
    class function NumberForSeverity(severity:FZLogMessageSeverity):cardinal;

    procedure Write(data:string; severity:FZLogMessageSeverity; JustInFile:boolean = false);
    procedure SetTargetSeverityLevel(severity:cardinal);
    procedure SetFileLoggingStatus(status:boolean);
    destructor Destroy(); override;    
  end;


  procedure RenameGameLog(str:PChar; buf_sz:cardinal); stdcall;
  function Init():boolean;

  const FZ_LOG_DEFAULT_SEVERITY: cardinal = 1;

implementation
uses CommonHelper, strutils;
var
  Mgr:FZLogMgr;

{ FZFileLogger }

constructor FZFileLogger.Create;
begin
  _enabled := false;
end;

destructor FZFileLogger.Destroy;
begin
  DisableLogging();
  inherited;
end;

procedure FZFileLogger.EnableLogging;
var
  opened:boolean;
begin
  opened := false;
  if not _enabled then begin
    try
      assignfile(_file, 'fz_events.log');
      append(_file);
      opened := true;
    except
      opened := false;
    end;

    if not opened then begin
      try
        assignfile(_file, 'fz_events.log');
        rewrite(_file);
        opened := true;
      except
        opened := false;
      end;
    end;

    if opened then begin
      writeln(_file, 'Log started '+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime);
      _enabled:=true;
    end;
  end;
end;

procedure FZFileLogger.Log(msg: string; severity: FZLogMessageSeverity);
begin
  if _enabled then begin
    if severity = FZ_LOG_ERROR then
      writeln(_file, '['+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime+'] ERROR: '+ msg)
    else
      writeln(_file, '['+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime+'] '+ msg);
    flush(_file);
  end;
end;

procedure FZFileLogger.DisableLogging;
begin
  if _enabled then begin
    writeln(_file, 'Log finished '+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime);
    closefile(_file);
    _enabled := false;
  end;
end;

{FZLogMgr}

class function FZLogMgr.Get(): FZLogMgr;
begin
  assert(Mgr<>nil, 'Log mgr is not created yet');
  result:=Mgr;
end;

class function FZLogMgr.NumberForSeverity(severity:FZLogMessageSeverity):cardinal;
begin
  case severity of
    FZ_LOG_DBG:             result:=0;
    FZ_LOG_INFO:            result:=1;
    FZ_LOG_IMPORTANT_INFO:  result:=2;
    FZ_LOG_ERROR:           result:=3;
  else
    result:=1000;
  end;
end;

constructor FZLogMgr.Create();
begin
  inherited;
  _target_severity:=FZ_LOG_DEFAULT_SEVERITY;
  _WriteLock:=TCriticalSection.Create;
  _logfun:=nil;
  _logfile:=FZFileLogger.Create();
end;

procedure FZLogMgr.SetTargetSeverityLevel(severity: cardinal);
begin
  _target_severity:=severity;
end;

procedure FZLogMgr.SetFileLoggingStatus(status: boolean);
begin
  _WriteLock.Enter;
  try
    if (status) then begin
      _logfile.EnableLogging();
    end else begin
      _logfile.DisableLogging();
    end;
  finally
    _WriteLock.Leave;
  end;
end;

procedure FZLogMgr.Write(data:string; severity:FZLogMessageSeverity; JustInFile:boolean = false);
begin
  _WriteLock.Enter;
  try
    if (JustInFile=false) then begin
      if _logfun=nil then begin
        //Первое сообщение. Пробуем закешировать функцию.
        _logfun:=srcKit.Get.FindEngineCall('Log');
      end;

      if (_logfun<>nil) and (_target_severity<=NumberForSeverity(severity)) then begin
        if severity = FZ_LOG_ERROR then
          _logfun.Call([PChar('! FZ: ' + data)])
        else
          _logfun.Call([PChar('~ FZ: ' + data)]);
      end;
    end;

    _logfile.Log(data, severity);
  finally
    _WriteLock.Leave;
  end;
end;

destructor FZLogMgr.Destroy();
begin
  _logfile.Free();
  _WriteLock.Free();
  Mgr:=nil;
  inherited;
end;

procedure RenameGameLog(str:PChar; buf_sz:cardinal); stdcall;
var
  new_name:string;
  i:integer;
begin
  new_name:=leftstr(str, length(str)-4)+'_'+FZCommonHelper.GetCurDate()+'_'+FZCommonHelper.GetCurTime()+'.log';
  if length(new_name)>=integer(buf_sz) then new_name:=leftstr(new_name, buf_sz-1);
  new_name:=new_name+chr(0);
  fzlogmgr.Get.Write('Redirecting log to '+new_name, FZ_LOG_IMPORTANT_INFO);
  ExecuteConsoleCommand('flush');

  for i:=0 to length(new_name)-1 do begin
    str[i]:=new_name[i+1];
  end;
  ExecuteConsoleCommand('flush');
  
end;

function Init():boolean;
begin
  Mgr:=FZLogMgr.Create();
  result:=true;
end;

end.
