unit srcInjectMgr;
{$mode delphi}
{$I _pathes.inc}

interface
uses srcInjections, SyncObjs;

type srcInjector = class
protected
  _lock:TCriticalSection;
  _injections:array of srcBaseInjection;

  procedure _UnInjectAll();
public
  constructor Create();
  destructor Destroy(); override;
  procedure RegisterInjection(injection:srcBaseInjection);
  procedure InjectAll();
end;

implementation
uses srcBase, sysutils;

{ srcInjector }

constructor srcInjector.Create;
begin
  inherited Create();
  _lock:=TCriticalSection.Create;
  setlength(self._injections, 0);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('srcInjector: Created');
end;

destructor srcInjector.Destroy;
begin
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('srcInjector: Destroying');
  self._UnInjectAll;
  setlength(self._injections, 0);
  _lock.Free;
  inherited;
end;

procedure srcInjector.InjectAll;
var
  i:integer;
begin
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('srcInjector: InjectAll');

  _lock.Enter;
  for i:=0 to length(self._injections)-1 do begin
    self._injections[i].Enable;
  end;
  _lock.Leave;

end;

procedure srcInjector.RegisterInjection(injection: srcBaseInjection);
var
  i:integer;
begin
  _lock.Enter;
  i:=length(self._injections);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('srcInjector: Registering injection #'+inttostr(i)+' '+injection.GetSignature);

  setlength(self._injections, i+1);
  self._injections[i]:=injection;
  _lock.Leave;
end;

procedure srcInjector._UnInjectAll;
var
  i:integer;
begin
  _lock.Enter;
  //идем в обратном порядке - на случай нескольких инъекций по одному адресу
  for i:=length(self._injections)-1 downto 0  do begin
    self._injections[i].Free;
  end;
  _lock.Leave;
end;

end.
