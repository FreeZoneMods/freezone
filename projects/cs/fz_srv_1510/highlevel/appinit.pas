unit appinit;

{$mode delphi}

interface

function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses
  sysutils,
  windows,
/////////
  BaseEngineFrameworkFunctions,
  basedefs,
/////////
  LogMgr,
  sysmsgs,
  ConfigMgr,
  ConfigCache,
  ItemsCfgMgr,
  TeleportMgr,
  HitMgr,
  whitehashes,
  mapgametypes,
  Emergency,
  TranslationMgr,
  DownloadMgr,
  SACE_Interface,
  PacketFilter,
  ServerStuff,
  UpdateRate,
  PlayersConnectionLog,
  Bans,
  SubnetBanList,
  Censor,
  ChatCommands,
  Chat,
  fz_injections,
  ControlGUI,
  Compressor,
  SACE_Hacks,
  ge_filter,
  Voting,
  PlayersConsole,
  AdminCommands,
  GameSpy,
  Timersmgr,
  PeriodicExecutionMgr;


function Init():boolean; stdcall;
var
  tp:cardinal;
  cfg:FZCacheData;
  old_severity:cardinal;
begin
  result:=false;

  if not BaseEngineFrameworkFunctions.InitFramework() then exit;

  if not LogMgr.Init then exit;
  if not sysmsgs.Init then exit;
  if not ConfigMgr.Init then exit;
  if not ConfigCache.Init then exit;

  //Принудительно распечатаем инициализационную инфу в лог
  cfg:=FZConfigCache.Get().GetDataCopy();
  old_severity:=cfg.log_severity;
  cfg.log_severity := 0;
  FZConfigCache.Get().OverrideConfig(cfg);

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

  FZLogMgr.Get.Write('Base addresses of important modules:', FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('freezone.dll - '+inttohex(GetModuleHandle('freezone'), 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrCore.dll - '+inttohex(xrCore, 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrGame.dll - '+inttohex(xrGame, 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrNetServer.dll - '+inttohex(xrNetServer, 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrApi.dll - '+inttohex(xrAPI, 8), FZ_LOG_IMPORTANT_INFO);

  cfg.log_severity:=old_severity;
  FZConfigCache.Get().OverrideConfig(cfg);

  if not TimersMgr.Init() then exit;
  if not ItemsCfgMgr.Init then exit;
  if not TeleportMgr.Init then exit;
  if not HitMgr.Init then exit;
  if not whitehashes.Init then exit;
  if not mapgametypes.Init then exit;

  if not Emergency.Init then exit;
  if not TranslationMgr.Init then exit;
  if not DownloadMgr.Init then exit;

  if not SACE_Interface.Init then exit;
  ////////////////////////////////////

  if not PacketFilter.Init then exit;

  if not ServerStuff.Init then exit;

  if not UpdateRate.Init then exit;

  if not PlayersConnectionLog.Init then exit;
  if not Bans.Init then exit;
  if not SubnetBanList.Init then exit;
  if not Censor.Init then exit;
  if not ChatCommands.Init then exit;
  if not Chat.Init then exit;

  if not fz_injections.Init then exit;
  if not ControlGUI.Init then exit;
  if not Compressor.Init then exit;

  if not SACE_Hacks.Init then exit;
  if not ge_filter.Init then exit;
  if not Voting.Init then exit;
  if not PlayersConsole.Init then exit;
  if not AdminCommands.Init() then exit;
  if not GameSpy.Init() then exit;
  if not PeriodicExecutionMgr.Init then exit;

  result:=true;
end;

function Free():boolean; stdcall;
begin
  //не нарушать порядок!
  result:=true;
  PeriodicExecutionMgr.Free();
  AdminCommands.Free();
  ControlGUI.Clean;
  SACE_Hacks.Free();
  ge_filter.Free;
  ServerStuff.Clean;
  FZChatCommandList.Get.Free;
  FZSubnetBanList.Get.Free;
  FZCensor.Get.Free;

  MapGametypes.Free;
  whitehashes.Free;
  HitMgr.Free();
  TeleportMgr.Free;
  ItemsCfgMgr.Free;
  TimersMgr.Free();
  FZTranslationMgr.Get.Free;
  FZDownloadMgr.Get.Free;

  FZConfigCache.Get.Free;
  FZConfigMgr.Get.Free;
  FZLogMgr.Get.Free;
  sysmsgs.Free();

  BaseEngineFrameworkFunctions.FreeFramework();
end;

end.

