unit basedefs;
{$mode delphi}
{$I _pathes.inc}

interface

function Init():boolean; stdcall;
procedure Free(); stdcall;

function xrGameDllType():cardinal;
function InitSymbol(var dest:pointer; module:cardinal; symbolname:PAnsiChar):boolean; stdcall;

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

const
  difficulty_gdNovice:integer=0;
  difficulty_gdStalker:integer=1;
  difficulty_gdVeteran:integer=2;
  difficulty_gdMaster:integer=3;

  XENGINE_EXE:PAnsiChar='xr_3DA.exe';
  XRGAME_DLL:PAnsiChar='xrGame';
  XRGAMESPY_DLL:PAnsiChar='xrGameSpy';
  XRCORE_DLL:PAnsiChar='xrCore';
  XRNETSERVER_DLL:PAnsiChar='xrNetServer';

  //xrGame types for patching
  XRGAME_SV_10006:cardinal = 0;
  XRGAME_UNKNOWN:cardinal = $FFFFFFFF;

implementation
uses Windows, sysutils;

function xrGameDllType():cardinal;
begin
  //todo:Switch
  result:=XRGAME_SV_10006;
end;

function InitSymbol(var dest:pointer; module:cardinal; symbolname:PAnsiChar):boolean; stdcall;
var
  module_name:string;
begin
  result:=false;
  dest:=GetProcAddress(module, symbolname);
  if dest = nil then begin
    if module = xrEngine then begin
      module_name:=XENGINE_EXE;
    end else if module = xrGame then begin
      module_name:=XRGAME_DLL;
    end else if module = xrGameSpy then begin
      module_name:=XRGAMESPY_DLL;
    end else if module = xrCore then begin
      module_name:=XRCORE_DLL;
    end else if module = xrNetServer then begin
      module_name:=XRNETSERVER_DLL;
    end else begin
      module_name:='[unknown]';
    end;
    MessageBox(0, PAnsiChar('Module "'+module_name+'" [0x'+inttohex(module,8)+'] doesn''t export symbol "'+symbolname+'"'), 'FreeZone', MB_ICONERROR or MB_OK);
    exit;
  end;
  result:=true;
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
  result:=true;
end;

procedure Free(); stdcall;
begin
  if xrGame_need_free then FreeLibrary(xrGame);
  if xrGameSpy_need_free then FreeLibrary(xrGameSpy);
  if xrCore_need_free then FreeLibrary(xrCore);
  if xrNetServer_need_free then FreeLibrary(xrNetServer);
end;

end.
