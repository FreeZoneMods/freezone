unit BaseClasses;
{$mode delphi}
{$I _pathes.inc}

interface
function Init():boolean; stdcall;

type

CLASS_ID = int64;

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

function GetClassId(id:string): CLASS_ID;

implementation

function GetClassId(id:string): CLASS_ID;
begin
 if length(id) < sizeof(result) then begin
   while length(id)<>sizeof(result) do id:=id+' ';
 end;

 //Cannot use R_ASSERT here - bot initialized yet
 assert(length(id) = sizeof(result));

 result := CLASS_ID(ord(id[8])) +
          (CLASS_ID(ord(id[7])) shl 8) +
          (CLASS_ID(ord(id[6])) shl 16) +
          (CLASS_ID(ord(id[5])) shl 24) +
          (CLASS_ID(ord(id[4])) shl 32) +
          (CLASS_ID(ord(id[3])) shl 40) +
          (CLASS_ID(ord(id[2])) shl 48) +
          (CLASS_ID(ord(id[1])) shl 56);
end;

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
