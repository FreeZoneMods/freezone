unit LogMgr;

interface
uses SyncObjs, SysUtils, basedefs, srcBase, srcCalls, Console;
type
  FZLogMgr = class
  private
    _logfun:srcBaseFunction;
    LogFile:textfile;
    FZLogEnabled:boolean;
    _WriteLock:TCriticalSection;
    constructor Create();


  public
    class function Get():FZLogMgr;
    procedure Write(data:string; IsError:boolean = false; JustInFile:boolean = false);
    destructor Destroy(); override;    
  end;


  procedure RenameGameLog(str:PChar; buf_sz:cardinal); stdcall;
  function Init():boolean;

  
implementation
uses CommonHelper, strutils, global_functions;
var
  Mgr:FZLogMgr;

{FZLogMgr}

class function FZLogMgr.Get(): FZLogMgr;
begin
  result:=Mgr;
end;

constructor FZLogMgr.Create();
begin
  inherited;
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


procedure FZLogMgr.Write(data:string; IsError:boolean = false; JustInFile:boolean = false);
begin
  _WriteLock.Enter;
  try
    if (JustInFile=false) then begin
      if _logfun=nil then begin
        //Первое сообщение. Пробуем закешировать функцию.
        _logfun:=srcKit.Get.FindEngineCall('Log');
      end;

      if (_logfun<>nil) then begin
        if IsError then
          _logfun.Call([PChar('! FZ: ' + data)])
        else
          _logfun.Call([PChar('~ FZ: ' + data)]);
      end;
    end;

    if FZLogEnabled then begin
      if IsError then
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
  fzlogmgr.Get.Write('Redirecting log to '+new_name);
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
