unit xrstrings;
{$mode delphi}
interface

function Init():boolean; stdcall;

type

str_value = packed record
  dwReference:cardinal;
  length:cardinal;
  dwCRC:cardinal;
  next:pointer;
  value:char; //really array here
end;

pstr_value = ^str_value;

shared_str = packed record
  p_:pstr_value;
end;

pshared_str = ^shared_str;

str_container=packed record
  //TODO:Fill
end;
pstr_container=^str_container;
ppstr_container=^pstr_container;

string_path=array [0..519] of Char;

xr_string = packed record
  _unknown1:array[0..$17] of Byte;
end;

procedure init_string(str:pshared_str); stdcall;
procedure assign_string(str:pshared_str; text:PChar); stdcall;

implementation
uses srcCalls, basedefs;
var
  g_pStringContainer:ppstr_container;
  dock:srcECXCallFunction;

procedure assign_string(str:pshared_str; text:PChar); stdcall;
var
  docked:pstr_value;
begin
  docked:= dock.Call([g_pStringContainer^, text]).VPointer;
  if docked<>nil then begin
    docked^.dwReference:=docked^.dwReference+1;
  end;

  if (str^.p_<>nil) then begin
    str^.p_^.dwReference:=str^.p_^.dwReference-1;
    if str^.p_^.dwReference=0 then str^.p_:=nil
  end;

  str^.p_:=docked;
end;

procedure init_string(str:pshared_str); stdcall;
begin
  str.p_:=nil;
end;

function Init():boolean; stdcall;
begin
  result:=false;
  g_pStringContainer := pointer(xrCore+$BE784);
  dock:=srcECXCallFunction.Create(pointer(xrCore+$1DDA0), [vtPointer, vtPChar], 'dock', 'str_container');

  if (g_pStringContainer=nil) or (dock=nil) then exit;
  result:=true;
end;

end.

