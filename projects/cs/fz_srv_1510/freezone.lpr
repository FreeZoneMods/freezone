library freezone;
{$MODE Delphi}
uses
  Interfaces, Forms, lazcontrols,
  ControlGUI in 'fz_srv_1510\ControlGUI.pas' {FZControlGUI},
  SysUtils,
  windows,
  srcCalls in 'tools\SourceKit\srcCalls.pas',
  srcInjections in 'tools\SourceKit\srcInjections.pas',
  srcInjectMgr in 'tools\SourceKit\srcInjectMgr.pas',
  srcBase in 'tools\SourceKit\srcBase.pas',
  srcLogging in 'tools\SourceKit\srcLogging.pas',
  srcFunctionsMgr in 'tools\SourceKit\srcFunctionsMgr.pas',
  basedefs in 'tools\src_data\basedefs.pas',
  global_functions in 'tools\src_data\global_functions.pas',
  ConfigBase in 'shared\ConfigBase.pas',
  ConfigMgr in 'fz_srv_1510\ConfigMgr.pas',
  ConfigCache in 'fz_srv_1510\ConfigCache.pas',
  LogMgr in 'fz_srv_1510\LogMgr.pas',
  TranslationMgr in 'shared\TranslationMgr.pas',
  DownloadMgr in 'fz_srv_1510\DownloadMgr.pas',
  Console in 'tools\src_typedefs\Console.pas',
  fz_injections in 'tools\src_data\fz_injections.pas',


  dynamic_caster in 'tools\src_data\dynamic_caster.pas',

  CommonHelper in 'shared\CommonHelper.pas',



  Packets in 'tools\src_typedefs\Packets.pas',
  BaseClasses in 'tools\src_typedefs\BaseClasses.pas',
  xrstrings in 'tools\src_typedefs\xrstrings.pas',
  Clients in 'tools\src_typedefs\Clients.pas',
  Time in 'tools\src_typedefs\Time.pas',
  PureServer in 'tools\src_typedefs\PureServer.pas',
  CSE in 'tools\src_typedefs\CSE.pas',
  MatVectors in 'tools\src_typedefs\MatVectors.pas',
  Vector in 'tools\src_typedefs\Vector.pas',
  GameMessages in 'tools\src_typedefs\GameMessages.pas',
  GameSpy in 'fz_srv_1510\GameSpy.pas',
  misc_stuff in 'tools\src_typedefs\misc_stuff.pas',
  Voting in 'fz_srv_1510\Voting.pas',

  BasicProtection in 'fz_srv_1510\BasicProtection.pas',
  Games in 'tools\src_typedefs\Games.pas',
  Servers in 'tools\src_typedefs\Servers.pas',
  Items in 'tools\src_typedefs\Items.pas',
  Banned in 'tools\src_typedefs\Banned.pas',
  Objects in 'tools\src_typedefs\Objects.pas',
  Chat in 'fz_srv_1510\Chat.pas',
  Players in 'fz_srv_1510\Players.pas',
  Bans in 'fz_srv_1510\Bans.pas',
  PacketFilter in 'fz_srv_1510\PacketFilter.pas',
  PlayerSkins in 'fz_srv_1510\PlayerSkins.pas',
  Gametypes in 'tools\src_typedefs\Gametypes.pas',
  SACE_interface in 'fz_srv_1510\SACE_interface.pas',
  SubnetBanList in 'fz_srv_1510\SubnetBanList.pas',
  Synchro in 'tools\src_typedefs\Synchro.pas',
  Emergency in 'fz_srv_1510\Emergency.pas',
  Level in 'tools\src_typedefs\Level.pas',
  Cameras in 'tools\src_typedefs\Cameras.pas',
  CDB in 'tools\src_typedefs\CDB.pas',
  Opcode in 'tools\src_typedefs\Opcode.pas',
  HUD in 'tools\src_typedefs\HUD.pas',
  PureClient in 'tools\src_typedefs\PureClient.pas',
  NET_Common in 'tools\src_typedefs\NET_Common.pas',
  Physics in 'tools\src_typedefs\Physics.pas',
  Battleye in 'tools\src_typedefs\Battleye.pas',
  Schedule in 'tools\src_typedefs\Schedule.pas',
  AnticheatStuff in 'tools\src_typedefs\AnticheatStuff.pas',
  Keys in 'tools\src_typedefs\Keys.pas',
  ChatCommands in 'fz_srv_1510\ChatCommands.pas',
  RegExpr in 'tools\3rdparty\RegExpr.pas',

  Lua in 'tools\3rdparty\lua\Lua.pas',
  LuaLib in 'tools\3rdparty\lua\LuaLib.pas',


  Censor in 'fz_srv_1510\Censor.pas',
  UpdateRate in 'fz_srv_1510\UpdateRate.pas',
  badpackets in 'tools\src_data\badpackets.pas', Compressor,
  ServerStuff in 'fz_srv_1510\ServerStuff.pas',
  Hits in 'tools\src_typedefs\Hits.pas', SACE_hacks, appinit, MapList;


{$R *.res}

function Init():boolean; stdcall;
var
c:char;
begin
  DecimalSeparator:='.';
  //вызвать Init'ы всех модулей
  if not appinit.Init() then begin
    TerminateProcess(GetCurrentProcess(), 13);
  end;

  if FZConfigMgr.Get.GetBool('new_votings_allowed_by_default', true) then begin
    //Hack - иначе новые голосования постоянно будут блочиться при перезапуске сервера, так как лимиты команды обрежут загруженное из конфига значение...
    c_sv_vote_enabled.value^:=c_sv_vote_enabled.value^+$300;
  end;

  result:=true
end;


procedure Cleanup(); stdcall;
begin
  //Вызывается на Application::Terminate
  //Вызываем очистку
  FZLogMgr.Get.Write('Cleanup...', FZ_LOG_INFO);
  appinit.Free;
  srcKit.Finish;
end;

exports
  Init;

begin
  randomize();

{$IFDEF RELEASE_BUILD}
  srcKit.Get.SwitchDebugMode(false);
  srcKit.Get.FullDbgLogStatus(false);
{$ELSE}
  srcKit.Get.SwitchDebugMode(true);
  srcKit.Get.FullDbgLogStatus(true);
{$ENDIF}

  Init();

  srcCleanupInjection.Create(pointer(xrEngine+$5f690), @Cleanup, 5);
  srcKit.Get.InjectAll;

  RequireDerivedFormResource:=True;
  Application.Initialize;
end.



