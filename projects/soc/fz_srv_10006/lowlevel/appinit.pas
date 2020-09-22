unit appinit;
{$mode delphi}
interface

function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses
  sysutils,
  windows,
////////////
  BaseEngineFrameworkFunctions,
  basedefs,
////////////
  LogMgr,
  sysmsgs,
  ConfigMgr,
  ConfigCache,
  TranslationMgr,
  DownloadMgr,
  ServerStuff,
  UpdateRate,
  fz_injections,
  Compressor,
  administration,
  ReloadCmd,
  PlayersConsole,
  ItemsCfgMgr,
  TeleportMgr,
  HitMgr,
  MapGametypes,
  Censor,
  ChatCommands,
  SubnetBanList,
  Bans,
  PlayersConnectionLog,
  ge_filter,
  Voting,
  AdminCommands,
  GameSpy,
  Timersmgr,
  PeriodicExecutionMgr;

function Init():boolean; stdcall;
var
  cfg:FZCacheData;
  old_severity:cardinal;
begin
  result:=false;

  if not BaseEngineFrameworkFunctions.InitFramework() then exit;

  ////////////////////////////////////
  // These ones should be in the beginning (for protection)
  if not LogMgr.Init then exit;
  if not sysmsgs.Init then exit;
  if not ConfigMgr.Init then exit;
  if not ConfigCache.Init then exit;
  ////////////////////////////////////
  //Принудительно распечатаем инициализационную инфу в лог
  cfg:=FZConfigCache.Get().GetDataCopy();
  old_severity:=cfg.log_severity;
  cfg.log_severity := 0;
  FZConfigCache.Get().OverrideConfig(cfg);
  FZLogMgr.Get.Write('Initializing...', FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write('Version info: FreeZone v3.0-SoC', FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write('Build date: ' + {$INCLUDE %DATE}, FZ_LOG_IMPORTANT_INFO );
  FZLogMgr.Get.Write('Sysmsgs module info: ' + sysmsgs.GetModuleVer(), FZ_LOG_IMPORTANT_INFO);

  FZLogMgr.Get.Write('Base addresses of important modules:', FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('freezone.dll - '+inttohex(GetModuleHandle('freezone'), 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrCore.dll - '+inttohex(xrCore, 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrGame.dll - '+inttohex(xrGame, 8), FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('xrNetServer.dll - '+inttohex(xrNetServer, 8), FZ_LOG_IMPORTANT_INFO);

  cfg.log_severity:=old_severity;
  FZConfigCache.Get().OverrideConfig(cfg);

  if not TranslationMgr.Init then exit;
  if not DownloadMgr.Init then exit;
  if not ServerStuff.Init then exit;
  if not UpdateRate.Init then exit;
  if not fz_injections.Init then exit;
  if not Compressor.Init then exit;

  if not administration.Init then exit;
  if not ReloadCmd.Init then exit;
  if not PlayersConsole.Init then exit;
  if not TimersMgr.Init() then exit;
  if not ItemsCfgMgr.Init then exit;
  if not TeleportMgr.Init then exit;
  if not HitMgr.Init then exit;
  if not MapGametypes.Init then exit;

  if not Censor.Init then exit;
  if not ChatCommands.Init then exit;

  if not SubnetBanList.Init() then exit;
  if not Bans.Init() then exit;
  if not PlayersConnectionLog.Init then exit;
  if not ge_filter.Init then exit;
  if not Voting.Init then exit;
  if not AdminCommands.Init() then exit;
  if not GameSpy.Init() then exit;
  if not PeriodicExecutionMgr.Init then exit;

  result:=true;
end;

function Free():boolean; stdcall;
begin
  PeriodicExecutionMgr.Free();
  AdminCommands.Free();
  ge_filter.Free;
  ServerStuff.Clean;
  MapGametypes.Free;
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
  result:=true;
end;

end.
