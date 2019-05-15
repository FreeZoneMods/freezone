unit BaseEngineFrameworkFunctions;

{$mode delphi}
{$I _pathes.inc}

interface
function InitFramework():boolean; stdcall;
procedure FreeFramework();

implementation

uses
	ai_sounds,
	AnticheatStuff,
	Banned,
	BaseClasses,
	basedefs,
	Battleye,
	buywnd,
	Cameras,
	CDB,
	Clients,
	clsids,
	collidable,
	Console,
	CSE,
	device,
	dynamic_caster,
	Fonts,
	GameCore,
	GameMessages,
	GamePersistent,
	Games,
	GameSpySystem,
	global_functions,
	Hits,
	HUD,
	inventoryitems,
	Keys,
	Level,
	MainMenu,
	MapList,
	MatVectors,
	misc_stuff,
	NET_Common,
	Objects,
	Opcode,
	Packets,
	Physics,
	PureClient,
	PureServer,
	renderable,
	Schedule,
	Servers,
	spatial,
	Statistics,
	Synchro,
	UI,
	UIWindows,
	Vector,
	weapons,
	xrfilesystem,
	xrstrings,
	xr_configs,
	xr_debug,
	xr_time;

function InitFramework():boolean;
begin
  result:=false;
  if not basedefs.Init then exit;

  //It's important to init debug features first
  if not xr_debug.Init then exit;
  if not global_functions.Init() then exit;
  if not dynamic_caster.Init then exit;
  if not xrstrings.Init() then exit;

  //"Regular" inits in alphabetical order
  if not Banned.Init() then exit;
  if not BaseClasses.Init() then exit;
  if not buywnd.Init() then exit;
  if not Clients.Init() then exit;
  if not clsids.Init() then exit;
  if not Console.Init() then exit;
  if not CSE.Init() then exit;
  if not device.Init() then exit;
  if not GameCore.Init() then exit;
  if not GameMessages.Init() then exit;
  if not GamePersistent.Init() then exit;
  if not Games.Init() then exit;
  if not Level.Init() then exit;
  if not MainMenu.Init() then exit;
  if not MapList.Init() then exit;
  if not MatVectors.Init() then exit;
  if not misc_stuff.Init() then exit;
  if not Objects.Init() then exit;
  if not Packets.Init() then exit;
  if not PureClient.Init() then exit;
  if not PureServer.Init() then exit;
  if not Servers.Init() then exit;
  if not UI.Init() then exit;
  if not Vector.Init() then exit;
  if not xrfilesystem.Init() then exit;
  if not xr_configs.Init() then exit;
  if not xr_time.Init() then exit;

  result:=true;
end;

procedure FreeFramework();
begin
  basedefs.Free;
end;

end.
