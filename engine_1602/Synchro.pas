unit Synchro;
{$mode delphi}
{$I _pathes.inc}

interface
uses Windows;

type
xrCriticalSection = packed record
  pmutex:PRTLCriticalSection;
end;
pxrCriticalSection=^xrCriticalSection;


procedure xrCriticalSection__Enter(cs:pxrCriticalSection); stdcall;
procedure xrCriticalSection__Leave(cs:pxrCriticalSection); stdcall;

function AtomicExchange(addr:pcardinal; val:cardinal):cardinal;

implementation


procedure xrCriticalSection__Enter(cs:pxrCriticalSection); stdcall;
begin
  EnterCriticalSection(cs^.pmutex^);
end;

procedure xrCriticalSection__Leave(cs:pxrCriticalSection); stdcall;
begin
  LeaveCriticalSection(cs^.pmutex^);
end;

function AtomicExchange(addr:pcardinal; val:cardinal):cardinal;
var
  tmpptr:plongint;
  tmp:longint;
begin
  tmpptr:=plongint(addr);
  tmp:=InterlockedExchange(tmpptr^, val);
  result:=cardinal(tmp);
end;

end.
