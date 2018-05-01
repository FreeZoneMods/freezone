unit IniFile;

{$mode delphi}

interface

type
  { FZIniFile }
  FZIniFile = class
  public
    constructor Create(filename:string);
    destructor Destroy(); override;
    function GetIntDef(section:string; key:string; def:integer):integer;
    function GetStringDef(section:string; key:string; def:string):string;
    function GetHex(section: string; key: string; var val:cardinal): boolean;
    function GetBoolDef(section: string; Key:string; default:boolean = false):boolean;
    function GetSectionsCount():integer;
    function GetSectionName(i:integer):string;

  protected
    _filename:string;
    _sections:array of string;

    function _GetData(section:string; key:string; var value:string):boolean;
  end;

implementation
uses windows, CommonHelper, SysUtils;

{ FZIniFile }

constructor FZIniFile.Create(filename: string);
var
  i, j, res:cardinal;
  arr, start:PAnsiChar;
  flag:boolean;
begin
  _filename:=filename;

  i:=128;
  repeat
    i:=i*2;
    GetMem(arr, i);
    if arr=nil then exit;
    res:=GetPrivateProfileString(nil, nil, nil, @arr[0], i, PAnsiChar(_filename));
    flag:= (res=i-1);
    if flag then FreeMem(arr, i);
  until not flag;

  j:=0;
  start:=arr;
  while start[0]<>chr(0) do begin
    j:=j+1;
    setlength(_sections, j);
    _sections[j-1]:=start;
    start:=@start[length(_sections[j-1])+1];
  end;

  FreeMem(arr, i);
end;

destructor FZIniFile.Destroy;
begin

end;

function FZIniFile.GetIntDef(section: string; key: string; def: integer): integer;
var
  val:string;
  found:boolean;
begin
  result:=def;
  found:=_GetData(section, key, val);
  if not found then exit;
  result:=strtointdef(val, def);
end;

function FZIniFile.GetStringDef(section: string; key: string; def: string): string;
var
  val:string;
  found:boolean;
begin
  found:=_GetData(section, key, val);
  if not found then result:=def else result:=val;
end;

function FZIniFile.GetHex(section: string; key: string; var val:cardinal): boolean;
var
  str:string;
  outval:cardinal;
begin
  result:=_GetData(section, key, str);
  if not result then begin
    exit;
  end else begin
    outval:=0;
    result:=FZCommonHelper.TryHexToInt(str, outval);
    if result then val:=outval;
  end;
end;

function FZIniFile.GetBoolDef(section: string; Key:string; default:boolean = false):boolean;
var
  temp:string;
begin
  result:=default;
  if _GetData(section, key, temp) then begin
    if (lowercase(temp)='true') or (lowercase(temp)='on') or (lowercase(temp)='1') then
      result:=true
    else
      result:=false;
  end;
end;

function FZIniFile.GetSectionsCount: integer;
begin
  result:=length(_sections);
end;

function FZIniFile.GetSectionName(i: integer): string;
begin
  assert(i<GetSectionsCount(), 'Invalid section index');
  result:=_sections[i];
end;

function FZIniFile._GetData(section: string; key: string; var value: string): boolean;
var
  arr:PAnsiChar;
  i, res:cardinal;
  flag:boolean;
  tmp:string;
begin
  result:=false;
  i:=128;
  repeat
    i:=i*2;
    GetMem(arr, i);
    if arr=nil then exit;
    res:=GetPrivateProfileString(PAnsiChar(section), PAnsiChar(Key),nil, @arr[0], i, PAnsiChar(_filename));
    flag:= (res=i-1);
    if flag then FreeMem(arr, i);
  until not flag;

  tmp:=string(arr)+';';
  FZCommonHelper.GetNextParam(tmp, value, ';');
  value:=trim(value);

  result:=(res>0);

  FreeMem(arr, i);
end;

end.

