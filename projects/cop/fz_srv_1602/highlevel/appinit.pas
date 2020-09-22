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
    Censor,
    Chat,
    ChatCommands,
    ConfigMgr,
    ConfigCache,
    sysmsgs,
    fz_injections,
    Players,
    PlayersConnectionLog,
    Bans,
    SubnetBanList,
    ServerStuff,
    DownloadMgr,
    TranslationMgr,
    GameSpy,
    Voting,
    MapGametypes;

function Init():boolean; stdcall;
var
  tp:cardinal;
  cfg:FZCacheData;
  old_severity:cardinal;
begin
  result:=false;

  if not BaseEngineFrameworkFunctions.InitFramework() then exit;

  ////////////////////////////////////
  //Не трогать!
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
  FZLogMgr.Get.Write('Version info: FreeZone v3.0-CoP', FZ_LOG_IMPORTANT_INFO);

  FZLogMgr.Get.Write('Build date: ' + {$INCLUDE %DATE}, FZ_LOG_IMPORTANT_INFO);
  FZLogMgr.Get.Write('Sysmsgs module info: ' + sysmsgs.GetModuleVer(), FZ_LOG_IMPORTANT_INFO);

  tp:=xrGameDllType();
  if tp = XRGAME_1602 then begin
    FZLogMgr.Get.Write('xrGame.dll is 1.6.02', FZ_LOG_IMPORTANT_INFO);
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

  //if not ItemsCfgMgr.Init then exit;
  //if not TeleportMgr.Init then exit;
  //if not HitMgr.Init then exit;
  //if not whitehashes.Init then exit;
  if not mapgametypes.Init then exit;

  //if not Emergency.Init then exit;
  if not TranslationMgr.Init then exit;
  if not DownloadMgr.Init then exit;

  //if not SACE_Interface.Init then exit;
  ////////////////////////////////////

//  if not PacketFilter.Init then exit;

  if not ServerStuff.Init then exit;

//  if not UpdateRate.Init then exit;

  if not Players.Init() then exit;
  if not PlayersConnectionLog.Init then exit;
  if not Bans.Init then exit;
  if not SubnetBanList.Init then exit;
  if not Censor.Init then exit;
  if not ChatCommands.Init then exit;
  if not Chat.Init then exit;

  if not fz_injections.Init then exit;
//  if not ControlGUI.Init then exit;
//  if not Compressor.Init then exit;

//  if not SACE_Hacks.Init then exit;
//  if not ge_filter.Init then exit;
  if not Voting.Init then exit;
//  if not PlayersConsole.Init then exit;
//  if not AdminCommands.Init() then exit;
  if not GameSpy.Init() then exit;

  result:=true;
end;

function Free():boolean; stdcall;
begin
  //не нарушать порядок!
  result:=true;

  Players.Clean();
  ServerStuff.Clean;
  FZChatCommandList.Get.Free;

  FZConfigCache.Get.Free;
  FZConfigMgr.Get.Free;
  FZLogMgr.Get.Free;
  sysmsgs.Free();

  BaseEngineFrameworkFunctions.FreeFramework();
end;

end.

