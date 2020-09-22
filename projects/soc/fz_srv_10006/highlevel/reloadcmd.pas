unit ReloadCmd;

{$mode delphi}

interface

function Init():boolean; stdcall;

implementation

uses
  Console, ConfigCache, Sysutils, LogMgr, TranslationMgr, ItemsCfgMgr, SubnetBanList, PlayersConnectionLog, MapGametypes, GameSpy, TeleportMgr, HitMgr, PeriodicExecutionMgr;

procedure ReloadFZConfigs_info(info:PChar); stdcall;
begin
  strcopy(info, 'Updates data from the FreeZone configs in the run-time');
end;

procedure ReloadFZConfigs_execute({%H-}arg:PChar); stdcall;
begin
  FZConfigCache.Get.Reload;
  FZTranslationMgr.Get.Reload;
  FZHitMgr.Get.Reload();
  FZSubnetBanList.Get.ReloadDefaultFile();
  FZItemCfgMgr.Get.Reload;
  FZTeleportMgr.Get.Reload();
  FZMapGametypesMgr.Get.Reload;
  FZPlayersConnectionMgr.Get.Reset();
  FZPeriodicExecutionMgr.Get.Reload();
  GameSpy.OnConfigReloaded();
  FZLogMgr.Get.Write('Configs reloaded.', FZ_LOG_USEROUT);
end;

function Init():boolean; stdcall;
begin
  AddConsoleCommand('fz_reload_configs',@ReloadFZConfigs_execute, @ReloadFZConfigs_info);
  result:=true;
end;

end.

