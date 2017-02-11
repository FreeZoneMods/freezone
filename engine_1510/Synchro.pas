unit Synchro;
{$mode delphi}
interface
uses Windows;

type
xrCriticalSection = packed record
  pmutex:PRTLCriticalSection;
end;
pxrCriticalSection=^xrCriticalSection;


procedure xrCriticalSection__Enter(cs:pxrCriticalSection); stdcall;
procedure xrCriticalSection__Leave(cs:pxrCriticalSection); stdcall;

implementation


procedure xrCriticalSection__Enter(cs:pxrCriticalSection); stdcall;
begin
  EnterCriticalSection(cs^.pmutex^);
end;

procedure xrCriticalSection__Leave(cs:pxrCriticalSection); stdcall;
begin
  LeaveCriticalSection(cs^.pmutex^);
end;

end.
