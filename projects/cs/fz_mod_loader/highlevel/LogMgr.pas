unit LogMgr;
{$mode delphi}
interface
{$IFNDEF TESTS}
uses srcCalls;
{$ENDIF}
type
  FZLogMessageSeverity = ( FZ_LOG_DBG, FZ_LOG_INFO, FZ_LOG_IMPORTANT_INFO, FZ_LOG_ERROR, FZ_LOG_SILENT );

  { FZLogMgr }

  FZLogMgr = class
  private
{$IFNDEF TESTS}
    _logfun:srcBaseFunction;
    _is_log_enabled:boolean;
    _lock:TRTLCriticalSection;
{$ENDIF}
    {%H-}constructor Create();
  public
    class function Get():FZLogMgr;
    procedure Write(data:string; {%H-}severity:FZLogMessageSeverity = FZ_LOG_INFO);
    destructor Destroy(); override;
  end;

  function Init():boolean;
  function Free():boolean;

implementation
{$IFNDEF TESTS}
uses srcBase, windows;
{$ENDIF}

var
  Mgr:FZLogMgr;

{FZLogMgr}

constructor FZLogMgr.Create();
{$IFNDEF TESTS}
var
  f:textfile;
{$ENDIF}
begin
  inherited;
{$IFNDEF TESTS}
  _is_log_enabled := true;
  InitializeCriticalSection(_lock);
  {$IFNDEF RELEASE}
  {assignfile(f, 'fz_loader_log.txt');
  rewrite(f);
  closefile(f);}
  {$ENDIF}
{$ENDIF}
end;

class function FZLogMgr.Get(): FZLogMgr;
begin
  result:=Mgr;
end;

procedure FZLogMgr.Write(data:string; severity:FZLogMessageSeverity);
{$IFNDEF TESTS}
var
  f:textfile;
{$ENDIF}
begin
{$IFNDEF TESTS}
  {$IFDEF RELEASE}
//  if severity = FZ_LOG_DBG then exit;
  {$ENDIF}
  EnterCriticalSection(_lock);
  try
    if _logfun=nil then begin
      //Первое сообщение. Пробуем закешировать функцию.
      _logfun:=srcKit.Get.FindEngineCall('Log');
    end;

    {$IFNDEF RELEASE}
{
      assignfile(f, 'fz_loader_log.txt');
      try
        append(f);
      except
        rewrite(f);
      end;
      writeln(f, data);
      closefile(f);
}
    {$ENDIF}

    if _logfun<>nil then begin
      if severity = FZ_LOG_ERROR then
        _logfun.Call(['! FZ: '+data])
      else
        _logfun.Call(['~ FZ: '+data]);
    end;

  finally
    LeaveCriticalSection(_lock);
  end;
{$ELSE}
  if severity = FZ_LOG_ERROR then
    writeln('[LogMgr][ERROR] '+data)
  else
     writeln('[LogMgr] '+data);
{$ENDIF}
end;

destructor FZLogMgr.Destroy();
begin
{$IFNDEF TESTS}
  DeleteCriticalSection(_lock);
  inherited;
{$ENDIF}
end;

function Init():boolean;
begin
  Mgr:=FZLogMgr.Create();
  result:=true;
end;

function Free: boolean;
begin
  result:=true;
  Mgr.Free();
  Mgr:=nil;
end;

end.
