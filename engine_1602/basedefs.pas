unit basedefs;
{$mode delphi}
{$I _pathes.inc}

interface

function Init():boolean; stdcall;
procedure Free(); stdcall;

function xrGameDllType():cardinal;

var
  xrGame:cardinal;
  xrGameSpy:cardinal;
  xrEngine:cardinal;
  xrCore:cardinal;
  xrNetServer:cardinal;
  xrAPI:cardinal;

const
  difficulty_gdNovice:integer=0;
  difficulty_gdStalker:integer=1;
  difficulty_gdVeteran:integer=2;
  difficulty_gdMaster:integer=3;

  badchars:PAnsiChar = '~!@#$%^&?*/\|"+- ';

  XENGINE_EXE:PAnsiChar='xrEngine.exe';
  XRGAME_DLL:PAnsiChar='xrGame';
  XRGAMESPY_DLL:PAnsiChar='xrGameSpy';
  XRCORE_DLL:PAnsiChar='xrCore';
  XRNETSERVER_DLL:PAnsiChar='xrNetServer';
  XRAPI_DLL:PAnsiChar='xrAPI';

  //xrGame types for patching
  XRGAME_1602:cardinal = 0;
  XRGAME_UNKNOWN:cardinal = $FFFFFFFF;

implementation
uses Windows;

function xrGameDllType():cardinal;
var
  b:byte;
begin
  //todo:switch
  result:=XRGAME_1602;
end;

function InitModule(var dest:cardinal; name:PAnsiChar; reload:boolean):boolean; stdcall;
begin
  result:=false;
  if reload then begin
    dest:=LoadLibrary(name);
  end else begin
    dest:=GetModuleHandle(name);
  end;

  if dest = 0 then begin
    MessageBox(0, PAnsiChar('Module "'+name+'" cannot be found'), 'FreeZone', MB_ICONERROR or MB_OK);
    exit;
  end;
  result:=true;
end;

function Init():boolean; stdcall;
begin
  result:=false;
  if not InitModule(xrEngine, XENGINE_EXE, false) then exit;
  if not InitModule(xrGame, XRGAME_DLL, true) then exit;
  if not InitModule(xrGameSpy, XRGAMESPY_DLL, true) then exit;
  if not InitModule(xrCore, XRCORE_DLL, true) then exit;
  if not InitModule(xrNetServer, XRNETSERVER_DLL, true) then exit;
  if not InitModule(xrAPI, XRAPI_DLL, true) then exit;
  result:=true;
end;

procedure Free(); stdcall;
begin
  FreeLibrary(xrGame);
  FreeLibrary(xrGameSpy);
  FreeLibrary(xrCore);
  FreeLibrary(xrNetServer);
  FreeLibrary(xrAPI);  
end;

end.
