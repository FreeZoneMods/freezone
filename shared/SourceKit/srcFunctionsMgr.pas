unit srcFunctionsMgr;
{$mode delphi}
interface
uses srcCalls, SysUtils, SyncObjs;

type srcFunMgr = class
{$IFDEF USE_TMREWS}
  _lock:TMultiReadExclusiveWriteSynchronizer;
{$ELSE}
  _cs:TCriticalSection;
{$ENDIF}

  _functions:array of srcBaseFunction;
public
  constructor Create;
  destructor Destroy; override;
  procedure RegisterFunction(f:srcBaseFunction);
  function CallByName(args:array of const; name:string; visibility:string='global'):TVarRec;
  function SearchByName(var fun:srcBaseFunction; name:string; visibility:string='global'):boolean;
end;

implementation
uses srcBase;

{ srcFunMgr }

function srcFunMgr.SearchByName(var fun:srcBaseFunction; name:string; visibility:string='global'):boolean;
var
  i:integer;
begin
  //TODO: ОПТИМИЗИРОВАТЬ! Может, добавить кэш последних вызовов?
  result:=false;

{$IFDEF USE_TMREWS}
  _lock.BeginRead;
{$ELSE}
  _cs.Enter;
{$ENDIF}
  for i:=0 to length(self._functions)-1 do begin
    if self._functions[i].IsItMe(name, visibility) then begin
      result:=true;
      fun:=self._functions[i];
      break;
    end;
  end;
{$IFDEF USE_TMREWS}
  _lock.EndRead;
{$ELSE}
  _cs.Leave
{$ENDIF}
end;

function srcFunMgr.CallByName(args: array of const; name,
  visibility: string): TVarRec;
var
  f:srcBaseFunction;
begin
  if SearchByName(f, name, visibility) then begin
    result:=f.Call(args);
  end else begin
    srcKit.Get.DbgLog('srcFunMgr.CallByName: function: '+visibility+'::'+name+' not registered!', true);
  end;
end;

constructor srcFunMgr.Create;
begin

{$IFDEF USE_TMREWS}
  _lock:=TMultiReadExclusiveWriteSynchronizer.Create;
{$ELSE}
  _cs:=TCriticalSection.Create;
{$ENDIF}

  setlength(self._functions, 0);
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog('srcFunMgr: Created')
end;

destructor srcFunMgr.Destroy;
var
  i:integer;
begin
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog('srcFunMgr: Destroying');
  for i:=length(self._functions)-1 downto 0 do begin
    self._functions[i].Free;
  end;
  setlength(self._functions, 0);
{$IFDEF USE_TMREWS}
  _lock.Free;
{$ELSE}
  _cs.Free;
{$ENDIF}
  inherited;
end;

procedure srcFunMgr.RegisterFunction(f:srcBaseFunction);
var
  i:integer;
begin
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog('srcFunMgr: Registering function '+f.GetSignature);

{$IFDEF USE_TMREWS}
  _lock.BeginWrite;
{$ELSE}
  _cs.Enter;
{$ENDIF}
  i:=length(self._functions);
  setlength(self._functions, i+1);
  self._functions[i]:=f;

{$IFDEF USE_TMREWS}
  _lock.EndWrite;
{$ELSE}
  _cs.Leave;
{$ENDIF}

end;

end.
