unit BaseClasses;
{$mode delphi}
interface
function Init():boolean; stdcall;

type

CLASS_ID = int64;

IIniFileStream = packed record
  vftable:pointer;
end;
pIIniFileStream = ^IIniFileStream;

CInifile = packed record
  //TODO:Fill;
end;
pCInifile = ^CInifile;

xrCriticalSection = packed record
  pmutex:pointer;
end;

DLL_Pure = packed record
  vftable:pointer;
  unknown:cardinal;  
  CLS_ID:CLASS_ID;
end;
pDLL_Pure=^DLL_Pure;

IInputReceiver = packed record
  vftable:pointer;
end;

pure_relcase = packed record
  vftable:pointer;
  m_id:integer;
end;
ppure_relcase=^pure_relcase;

pureRender = packed record
  vftable:pointer;
end;

pureFrame = packed record
  vftable:pointer;
end;

pureAppStart = packed record
  vftable:pointer;
end;

pureAppEnd = packed record
  vftable:pointer;
end;

pureAppActivate = packed record
  vftable:pointer;
end;

pureAppDeactivate = packed record
  vftable:pointer;
end;

pureDeviceReset = packed record
  vftable:pointer;
end;

IEventReceiver = packed record
  vftable:pointer;
end;

IWriter = packed record
  //todo:fill;
end;
pIWriter = ^IWriter;

CStreamReader = packed record
  //todo:fill;
end;
pCStreamReader=^CStreamReader;

implementation
function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
