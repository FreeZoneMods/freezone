unit Readers;

{$mode objfpc}{$H+}

interface
uses srcCalls;

type
  IReaderBase = packed record
    _vftable:pointer;
    m_last_pos:cardinal;
  end;

  IReader = packed record
    base_IReaderBase:IReaderBase;
    data:PAnsiChar;
    Pos:integer;
    Size:integer;
    iterpos:integer;
  end;
  pIReader = ^IReader;

  function Init():boolean; stdcall;

var
  IReader__open_chunk:srcECXCallFunction;
  IReader__find_chunk:srcECXCallFunction;
  IReader__close:srcECXCallFunction;

implementation
uses windows, basedefs;

function Init():boolean; stdcall;
var
  ptr:pointer;
begin
  ptr:=GetProcAddress(xrCore, '?open_chunk@IReader@@QAEPAV1@I@Z');
  IReader__open_chunk:=srcECXCallFunction.Create(ptr, [vtPointer, vtInteger], 'open_chunk', 'IReader');

  ptr:=GetProcAddress(xrCore, '?close@IReader@@QAEXXZ');
  IReader__close:=srcECXCallFunction.Create(ptr, [vtPointer], 'close', 'IReader');

  ptr:=GetProcAddress(xrCore, '?find_chunk@IReader@@QAEIIPAH@Z');
  IReader__find_chunk:=srcECXCallFunction.Create(ptr, [vtPointer, vtInteger, vtPointer], 'find_chunk', 'IReader');

  result:=true;
end;

end.

