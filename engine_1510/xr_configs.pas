unit xr_configs;

{$mode delphi}

interface
uses srcCalls;

type
IIniFileStream = packed record
  vftable:pointer;
end;
pIIniFileStream = ^IIniFileStream;

CInifile = packed record
  //todo:fill
end;
pCIniFile = ^CInifile;
ppCIniFile = ^pCInifile;

var
  CInifile__r_string:srcECXCallFunction;
  CInifile__line_exist:srcECXCallFunction;
  ppSettings:ppCIniFile;

function game_ini_line_exist(section:string; key:string):boolean;
function game_ini_read_string(section:string; key:string):string;
function game_ini_read_string_def(section:string; key:string; def:string = ''):string;
function game_ini_read_int_def(section:string; key:string; def:integer):integer;

function Init():boolean;

implementation
uses basedefs, windows, sysutils;

function game_ini_line_exist(section:string; key:string):boolean;
begin
  result:=CInifile__line_exist.Call([ppSettings^, PAnsiChar(section), PAnsiChar(key)]).VBoolean;
end;

function game_ini_read_string(section:string; key:string):string;
begin
  result:=CInifile__r_string.Call([ppSettings^, PAnsiChar(section), PAnsiChar(key)]).VPChar;
end;

function game_ini_read_string_def(section:string; key:string; def:string):string;
begin
  if game_ini_line_exist(section, key) then begin
    result:=game_ini_read_string(section, key);
  end else begin
    result:=def;
  end;
end;

function game_ini_read_int_def(section:string; key:string; def:integer):integer;
begin
  result:=strtointdef(game_ini_read_string_def(section, key, ''), def);
end;

function Init():boolean;
begin
  result:=false;
  ppSettings:=GetProcAddress(xrCore,'?pSettings@@3PAVCInifile@@A');
  CInifile__r_string:=srcECXCallFunction.Create(GetProcAddress(xrCore, '?r_string@CInifile@@QAEPBDPBD0@Z'), [vtPointer, vtPChar, vtPChar], 'r_string', 'CInifile');
  CInifile__line_exist:=srcECXCallFunction.Create(GetProcAddress(xrCore, '?line_exist@CInifile@@QAEHPBD0@Z'), [vtPointer, vtPChar, vtPChar], 'line_exist', 'CInifile');
  result:=(ppSettings<>nil) and (CInifile__r_string.GetMyAddress()<>nil) and (CInifile__line_exist.GetMyAddress()<>nil);
end;

end.

