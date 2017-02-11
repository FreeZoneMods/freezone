unit basedefs;
{$mode delphi}
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
  difficulty_gdNovice:single=0;
  difficulty_gdStalker:single=1;
  difficulty_gdVeteran:single=2;
  difficulty_gdMaster:single=3;

  badchars:PAnsiChar = '~!@#$%^&?*/\|"+- ';

  XENGINE_EXE:PAnsiChar='xrEngine.exe';
  XRGAME_DLL:PAnsiChar='xrGame';
  XRGAMESPY_DLL:PAnsiChar='xrGameSpy';
  XRCORE_DLL:PAnsiChar='xrCore';
  XRNETSERVER_DLL:PAnsiChar='xrNetServer';
  XRAPI_DLL:PAnsiChar='xrAPI';

  //xrGame types for patching
  XRGAME_SV_1510:cardinal = 0;
  XRGAME_CL_1510:cardinal = 1;
  XRGAME_UNKNOWN:cardinal = $FFFFFFFF;

implementation
uses Windows, global_functions, LogMgr, ConfigMgr, Console, fz_injections, Packets, BaseClasses, Clients, Time, xrstrings, PureServer, CSE, Vector, MatVectors, GameMessages, misc_stuff, Servers, Items, Games, Banned, Objects, PacketFilter, Gametypes, Bans, ControlGUI, SubnetBanList, ConfigCache, Emergency, SACE_Interface, Level, ChatCommands, Censor, Chat, UpdateRate, DownloadMgr, TranslationMgr, ServerStuff, dynamic_caster, sysmsgs, Compressor, SACE_Hacks;

function xrGameDllType():cardinal;
var
  b:byte;
begin
  //todo:More reliable switch
  b:= pbyte(xrGame+$81)^;
  if b=$9f then begin
    result:=XRGAME_CL_1510;
  end else if b = $e1 then begin
    result:=XRGAME_SV_1510;
  end else begin
    result:=XRGAME_UNKNOWN;
  end;
end;

function Init():boolean; stdcall;
begin
  xrEngine:=GetModuleHandle(XENGINE_EXE);
  xrGame:=LoadLibrary(XRGAME_DLL);
  xrGameSpy:=LoadLibrary(XRGAMESPY_DLL);
  xrCore:=LoadLibrary(XRCORE_DLL);
  xrNetServer:=LoadLibrary(XRNETSERVER_DLL);
  xrAPI:=LoadLibrary(XRAPI_DLL);

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
