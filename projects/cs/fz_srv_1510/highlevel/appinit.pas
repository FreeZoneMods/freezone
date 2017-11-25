unit appinit;

{$mode delphi}

interface

function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses basedefs, dynamic_caster, global_functions, LogMgr, ConfigMgr, Console, Emergency, ConfigCache, TranslationMgr, DownloadMgr, SACE_Interface,
     ServerStuff, PacketFilter, UpdateRate, Bans, SubnetBanList, Censor, ChatCommands, Chat, fz_injections, ControlGUI, sysmsgs, Compressor, SACE_Hacks,
     BaseClasses, xrstrings, Packets, Clients, Time, PureServer, Level, CSE, Vector, MatVectors, GameMessages, misc_stuff, Banned, Servers, Items,
     Objects, Games, Gametypes, MapList, ItemsCfgMgr, clsids;

function Init():boolean; stdcall;
var
  tp:cardinal;
begin
  result:=false;

  ////////////////////////////////////
  //Не трогать!
  if not basedefs.Init then exit;
  if not dynamic_caster.Init then exit;

  if not global_functions.Init then exit;

  if not LogMgr.Init then exit;

  FZLogMgr.Get.Write('Initializing...', FZ_LOG_IMPORTANT_INFO);
{$IFDEF REVO}
  FZLogMgr.Get.Write('Version info: FreeZone v3.0b Revolution', FZ_LOG_IMPORTANT_INFO);
{$ELSE}
  FZLogMgr.Get.Write('Version info: FreeZone v3.0b Evolution', FZ_LOG_IMPORTANT_INFO);
{$ENDIF}

  FZLogMgr.Get.Write('Build date: ' + {$INCLUDE %DATE}, FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('Sysmsgs module info: ' + sysmsgs.GetModuleVer(), FZ_LOG_IMPORTANT_INFO);

  tp:=xrGameDllType();
  if tp = XRGAME_CL_1510 then begin
    FZLogMgr.Get.Write('xrGame.dll is CL 1.5.10', FZ_LOG_IMPORTANT_INFO);
  end else if tp = XRGAME_SV_1510 then begin
    FZLogMgr.Get.Write('xrGame.dll is SV 1.5.10', FZ_LOG_IMPORTANT_INFO);
  end else begin
    FZLogMgr.Get.Write('xrGame.dll - UNKNOWN version!', FZ_LOG_ERROR);
  end;

  if not ConfigMgr.Init then exit;
  if not ItemsCfgMgr.Init then exit;
  if not Console.Init then exit;
  if not ConfigCache.Init then exit;

  if not Emergency.Init then exit;
  if not TranslationMgr.Init then exit;
  if not DownloadMgr.Init then exit;

  if not SACE_Interface.Init then exit;
  ////////////////////////////////////


  if not BaseClasses.Init then exit;
  if not clsids.Init then exit;
  if not xrstrings.Init then exit;
  if not Packets.Init then exit;
  if not Clients.Init then exit;
  if not Time.Init then exit;
  if not PureServer.Init then exit;
  if not Level.Init then exit;
  if not CSE.Init then exit;
  if not Vector.Init then exit;
  if not MatVectors.Init then exit;
  if not GameMessages.Init then exit;

  if not misc_stuff.Init then exit;

  if not Banned.Init then exit;
  if not Servers.Init then exit;
  if not Items.Init then exit;
  if not Objects.Init then exit;
  if not Games.Init then exit;
  if not MapList.Init then exit;

  if not PacketFilter.Init then exit;

  if not ServerStuff.Init then exit;

  if not Gametypes.Init then exit;

  if not UpdateRate.Init then exit;

  if not Bans.Init then exit;
  if not SubnetBanList.Init then exit;
  if not Censor.Init then exit;
  if not ChatCommands.Init then exit;
  if not Chat.Init then exit;

  if not fz_injections.Init then exit;
  if not ControlGUI.Init then exit;
  if not sysmsgs.Init then exit;
  if not Compressor.Init then exit;

  if not SACE_Hacks.Init then exit;

  result:=true;
end;

function Free():boolean; stdcall;
begin
  //не нарушать порядок!
  result:=true;
  ControlGUI.Clean;
  sysmsgs.Free();
  SACE_Hacks.Free();
  ServerStuff.Clean;
  FZChatCommandList.Get.Free;
  FZSubnetBanList.Get.Free;
  FZCensor.Get.Free;

  FZTranslationMgr.Get.Free;
  FZDownloadMgr.Get.Free;

  FZConfigCache.Get.Free;
  FZConfigMgr.Get.Free;
  FZLogMgr.Get.Free;

  basedefs.Free;
end;

end.

