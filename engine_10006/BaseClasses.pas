unit BaseClasses;
{$mode delphi}
{$I _pathes.inc}

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

CRandom = packed record
  holdrand:cardinal;
end;

implementation
function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
