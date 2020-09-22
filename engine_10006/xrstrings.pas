unit xrstrings;
{$mode delphi}
{$I _pathes.inc}

interface

function Init():boolean; stdcall;

type

str_value = packed record
  dwReference:cardinal;
  length:cardinal;
  dwCRC:cardinal;
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
  _unknown1:array[0..$1B] of Byte;
end;


procedure assign_string(str:pshared_str; text:PAnsiChar); stdcall;
procedure init_string(str:pshared_str); stdcall;
function get_string_value(str:pshared_str):PAnsiChar; stdcall;

implementation
uses srcCalls, basedefs, windows;
var
  g_pStringContainer:ppstr_container;
  dock:srcECXCallFunction;

procedure assign_string(str:pshared_str; text:PAnsiChar); stdcall;
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

function get_string_value(str:pshared_str):PAnsiChar; stdcall;
begin
  result:='';
  if str=nil then exit;
  if str.p_=nil then exit;
  result:=PAnsiChar(@str.p_.value);
end;

function Init():boolean; stdcall;
var
  tmp:pointer;
begin
  result:=false;
  tmp:=nil;

  //1.0006 - expected xrCore+BF3D4
  if not InitSymbol(g_pStringContainer, xrCore, '?g_pStringContainer@@3PAVstr_container@@A') then exit;

  //1.0006 - expected xrCore+1EDB0
  if not InitSymbol(tmp, xrCore, '?dock@str_container@@QAEPAUstr_value@@PBD@Z') then exit;
  dock:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar], 'dock', 'str_container');

  result:=true;
end;

end.

