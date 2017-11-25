unit LogMgr;
{$mode delphi}
interface
uses SyncObjs, SysUtils, srcBase, srcCalls, Console;
type
  FZLogMessageSeverity = ( FZ_LOG_DBG, FZ_LOG_INFO, FZ_LOG_IMPORTANT_INFO, FZ_LOG_ERROR, FZ_LOG_SILENT );

  { FZLogMgr }

  FZLogMgr = class
  private
    _logfun:srcBaseFunction;
    LogFile:textfile;
    FZLogEnabled:boolean;
    _WriteLock:TCriticalSection;
    {%H-}constructor Create();

  public
    class function Get():FZLogMgr;
    class function NumberForSeverity(severity:FZLogMessageSeverity):cardinal;

    procedure Write(data:string; severity:FZLogMessageSeverity; JustInFile:boolean = false);
    procedure SetTargetSeverityLevel(severity:cardinal);
    destructor Destroy(); override;    
  end;


  procedure RenameGameLog(str:PChar; buf_sz:cardinal); stdcall;
  function Init():boolean;

  const FZ_LOG_DEFAULT_SEVERITY: cardinal = 1;

implementation
uses CommonHelper, strutils;
var
  Mgr:FZLogMgr;
  _target_severity:cardinal; //DO NOT make class member!

{FZLogMgr}

class function FZLogMgr.Get(): FZLogMgr;
begin
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

  FZLogEnabled:=true;
  _logfun:=nil;
  _WriteLock:=TCriticalSection.Create;
  if FZLogEnabled then begin
    try
      assignfile(logfile, 'fz_events.log');
      try
        append(LogFile);
      except
        rewrite(LogFile);
      end;
      writeln(LogFile, 'Log started '+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime);
    except
    end;
  end;
end;

procedure FZLogMgr.SetTargetSeverityLevel(severity: cardinal);
begin
  _target_severity:=severity;
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

    if FZLogEnabled then begin
      if severity = FZ_LOG_ERROR then
        writeln(LogFile, '['+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime+'] ERROR: '+data)
      else
        writeln(LogFile, '['+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime+'] '+data);
      flush(LogFile);
    end;
  finally
    _WriteLock.Leave;
  end;
end;

destructor FZLogMgr.Destroy();
begin
  writeln(LogFile, 'Log finished '+ FZCommonHelper.GetCurDate+' '+FZCommonHelper.GetCurTime);
  closefile(LogFile);
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
