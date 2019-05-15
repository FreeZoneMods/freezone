unit xr_configs;

{$mode delphi}
{$I _pathes.inc}

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
  CInifile__section_exist:srcECXCallFunction;
  ppSettings:ppCIniFile;

function game_ini_line_exist(section:string; key:string):boolean;
function game_ini_section_exist(section:string):boolean;
function game_ini_read_string(section:string; key:string):string;
function game_ini_read_string_def(section:string; key:string; def:string = ''):string;
function game_ini_read_int_def(section:string; key:string; def:integer):integer;
function game_ini_read_float_def(section:string; key:string; def:single):single;

function Init():boolean;

implementation
uses basedefs, sysutils, CommonHelper;

function game_ini_line_exist(section:string; key:string):boolean;
begin
  result:=CInifile__line_exist.Call([ppSettings^, PAnsiChar(section), PAnsiChar(key)]).VBoolean;
end;

function game_ini_section_exist(section: string): boolean;
begin
  result:=CInifile__section_exist.Call([ppSettings^, PAnsiChar(section)]).VBoolean;
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

function game_ini_read_float_def(section:string; key:string; def:single):single;
begin
  result:=FZCommonHelper.StringToFloatDef(game_ini_read_string_def(section, key, ''), def);
end;

function Init():boolean;
var
  tmp:pointer;
begin
  result:=false;
  tmp:=nil;

  if not InitSymbol(ppSettings, xrCore, '?pSettings@@3PAVCInifile@@A') then exit;

  if not InitSymbol(tmp, xrCore, '?r_string@CInifile@@QAEPBDPBD0@Z') then exit;
  CInifile__r_string:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar, vtPChar], 'r_string', 'CInifile');

  if not InitSymbol(tmp, xrCore, '?line_exist@CInifile@@QAEHPBD0@Z') then exit;
  CInifile__line_exist:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar, vtPChar], 'line_exist', 'CInifile');

  if not InitSymbol(tmp, xrCore, '?section_exist@CInifile@@QAEHPBD@Z') then exit;
  CInifile__section_exist:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar], 'section_exist', 'CInifile');

  result:=true;
end;

end.

