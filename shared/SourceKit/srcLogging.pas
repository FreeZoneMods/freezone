unit srcLogging;
{$mode delphi}
interface
type
  srcLog = class
  private
    _lock:TRTLCriticalSection;
    _logfile:textfile;
    _logname:string;
  public
    constructor Create(logname:string; filename:string; recreate:boolean=false);
    procedure Write(data:string; IsError:boolean = false);
    function Name():string;
    destructor Destroy; override;
    class function GetCurTime():string;
    class function GetCurDate():string;
  end;

implementation
uses SysUtils, Windows;

constructor srcLog.Create(logname:string; filename:string; recreate:boolean=false);
begin
  inherited Create();
  windows.InitializeCriticalSection(_lock);
  windows.EnterCriticalSection(_lock);
  try
    assignfile(_logfile, filename);
    if recreate then
      rewrite(_logfile)
    else
      try
        append(_logfile);
      except
        rewrite(_logfile)
      end;
    Write('Log <'+logname+'> started.');
    _logname:=logname;
  except
  end;
  windows.LeaveCriticalSection(_lock);
end;

procedure srcLog.Write(data:string; IsError:boolean = false);
begin
    windows.EnterCriticalSection(_lock);
    if IsError then
      writeln(_logfile, '['+ GetCurDate+' '+ GetCurTime +'] ERROR: '+data)
    else
      writeln(_logfile, '['+ GetCurDate+' '+ GetCurTime +'] '+data);
    flush(_logfile);
    windows.LeaveCriticalSection(_lock);
end;

function srcLog.Name():string;
begin
  windows.EnterCriticalSection(_lock);
  result:=_logname;
  windows.LeaveCriticalSection(_lock);
end;

destructor srcLog.Destroy;
begin
  windows.EnterCriticalSection(_lock);
  Write('Log <'+_logname+'> finished.');
  closefile(_logfile);
  windows.LeaveCriticalSection(_lock);
  windows.DeleteCriticalSection(_lock);
  inherited;
end;


class function srcLog.GetCurTime():string;
var
  st:_SYSTEMTIME;
begin
  st.Day:=0; //suppress warning
  GetLocalTime(st);
  if st.wHour<10 then result:='0' else result:='';
  result:=result+inttostr(st.wHour)+':';
  if st.wMinute<10 then result:=result+'0';
  result:=result+inttostr(st.wMinute)+':';
  if st.wSecond<10 then result:=result+'0';
  result:=result+inttostr(st.wSecond);
end;

class function srcLog.GetCurDate():string;
var
  st:_SYSTEMTIME;
begin
  st.Day:=0; //suppress warning
  GetLocalTime(st);
  if st.wDay<10 then result:='0' else result:='';
  result:=result+inttostr(st.wDay)+'.';
  if st.wMonth<10 then result:=result+'0';
  result:=result+inttostr(st.wMonth)+'.';
  result:=result+inttostr(st.wYear);
end;

end.

