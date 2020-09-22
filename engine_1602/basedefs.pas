unit basedefs;
{$mode delphi}
{$I _pathes.inc}

interface

function Init():boolean; stdcall;
procedure Free(); stdcall;

function xrGameDllType():cardinal;

var
  xrGame:cardinal;
  xrGame_need_free:boolean;
  xrGameSpy:cardinal;
  xrGameSpy_need_free:boolean;
  xrEngine:cardinal;
  xrEngine_need_free:boolean;
  xrCore:cardinal;
  xrCore_need_free:boolean;
  xrNetServer:cardinal;
  xrNetServer_need_free:boolean;
  xrAPI:cardinal;
  xrAPI_need_free:boolean;

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

function InitModule(var dest:cardinal; name:PAnsiChar; reload:boolean; var reloaded:boolean):boolean; stdcall;
begin
  result:=false;
  reloaded:=false;
  dest:=GetModuleHandle(name);
  if (dest = 0) and reload then begin
    dest:=LoadLibrary(name);
    if dest <> 0 then begin
      reloaded:=true;
    end;
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
  if not InitModule(xrEngine, XENGINE_EXE, false, xrEngine_need_free) then exit;
  if not InitModule(xrGame, XRGAME_DLL, true, xrGame_need_free) then exit;
  if not InitModule(xrGameSpy, XRGAMESPY_DLL, true, xrGameSpy_need_free) then exit;
  if not InitModule(xrCore, XRCORE_DLL, true, xrCore_need_free) then exit;
  if not InitModule(xrNetServer, XRNETSERVER_DLL, true, xrNetServer_need_free) then exit;
  if not InitModule(xrAPI, XRAPI_DLL, true, xrAPI_need_free) then exit;
  result:=true;
end;

procedure Free(); stdcall;
begin
  if xrGame_need_free then FreeLibrary(xrGame);
  if xrGameSpy_need_free then FreeLibrary(xrGameSpy);
  if xrCore_need_free then FreeLibrary(xrCore);
  if xrNetServer_need_free then FreeLibrary(xrNetServer);
  if xrAPI_need_free then FreeLibrary(xrAPI);
end;

end.
