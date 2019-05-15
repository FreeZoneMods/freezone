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
  next:pointer;
  value:char; //really array here
end;

pstr_value = ^str_value;

shared_str = packed record
  p_:pstr_value;
end;

pshared_str = ^shared_str;
ppshared_str = ^pshared_str;

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
function get_string_value(str:pshared_str):PAnsiChar; stdcall;
function GetGlobalUndockedEmptyStr():pshared_str; stdcall;

implementation
uses srcCalls, basedefs, windows;
var
  g_pStringContainer:ppstr_container;
  dock:srcECXCallFunction;

  // "Неучтенные" игрой строки, на которые можно ссылаться
  global_undocked_empty_shared_str_value:str_value;
  global_undocked_empty_shared_str:shared_str;

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

function GetGlobalUndockedEmptyStr: pshared_str; stdcall;
begin
  result:=@global_undocked_empty_shared_str;
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
  addr:pointer;
begin
  result:=false;

  //1.6.02: expected xrCore+BE98C
  g_pStringContainer:=GetProcAddress(xrCore, '?g_pStringContainer@@3PAVstr_container@@A');
  if g_pStringContainer=nil then exit;

  //1.6.02: expected xrCore+20690
  addr:=GetProcAddress(xrCore, '?dock@str_container@@QAEPAUstr_value@@PBD@Z');
  if addr=nil then exit;
  dock:=srcECXCallFunction.Create(addr, [vtPointer, vtPChar], 'dock', 'str_container');

  global_undocked_empty_shared_str_value.value:=chr(0);
  global_undocked_empty_shared_str_value.dwCRC:=0;
  global_undocked_empty_shared_str_value.dwReference:=1;
  global_undocked_empty_shared_str_value.length:=0;
  global_undocked_empty_shared_str_value.next:=nil;
  global_undocked_empty_shared_str.p_:=@global_undocked_empty_shared_str_value;

  result:=true;
end;

end.

