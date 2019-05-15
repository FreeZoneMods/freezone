unit AdminCommands;

{$mode delphi}

interface
uses Clients, Packets, MatVectors;

type

{ FZAdminCommandInfoReporter }
FZAdminCommandInfoReporter = class
public
  procedure Report(s:string; iserror:boolean); virtual; abstract;
end;

{ FZConsoleReporter }
FZConsoleReporter = class(FZAdminCommandInfoReporter)
  _raid:cardinal;
public
  constructor Create(raid:cardinal);
  procedure Report(s:string; iserror:boolean); override;
end;

{ FZAdminCommand }
FZAdminCommand = class
  _reporter:FZAdminCommandInfoReporter;
  _name:string;
  //Одна консольная команда может выдавать последовательность FZAdminCommand
  //Чтобы при неуспехе одной стадии в последовательности абортить все последующие стадии, мы сохраняем ссылку на следующую
  //Почему на следующую? Потому что предыдущей может уже не существовать в памяти, когда мы попробуем к ней обратиться
  //При взведенном флаге неуспеха каждая стадия сетит флаг неуспеха у следующей
  _next_command:FZAdminCommand;
  _previous_command_failed:boolean;

  procedure Report(s:string; iserror:boolean);
  procedure OnCommandFailed();

protected
  function Execute_internal():boolean; virtual; abstract;
public
  constructor Create(reporter:FZAdminCommandInfoReporter);
  destructor Destroy(); override;
  function Execute():boolean;
  function GetName():string;
  procedure SetNextStageCommand(cmd:FZAdminCommand);
end;

{ FZSimpleConsoleCmd }
FZSimpleConsoleCmd = class (FZAdminCommand)
  _cmd:string;

protected
  function Execute_internal():boolean; override;
public
  constructor Create(cmd:string; reporter:FZAdminCommandInfoReporter);
end;

{ FZReportPlayersCommand }
FZReportPlayersCommand = class (FZAdminCommand)
  _first_symbs:string;

protected
  function Execute_internal():boolean; override;
public
  constructor Create(first_symbs:string; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminBanHwidCommand }
FZAdminBanHwidCommand = class (FZAdminCommand)
  _id:cardinal;
  _raid:cardinal;
  _time:cardinal;
  _reason:string;

protected
  function Execute_internal():boolean; override;
public
  constructor Create(id:cardinal; radmin_id:cardinal; time:cardinal; reason:string; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminSinglePlayerAction }
FZAdminSinglePlayerAction = class(FZAdminCommand)
  _id:cardinal;
protected
  function DoAction(player:pxrClientData):boolean; virtual; abstract;

  function Execute_internal():boolean; override;
public
  constructor Create(id:cardinal; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminRankChangeCommand }
FZAdminRankChangeCommand = class (FZAdminSinglePlayerAction)
  _delta:integer;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; delta:integer; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminAddMoneyCommand }
FZAdminAddMoneyCommand = class (FZAdminSinglePlayerAction)
  _amount:integer;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; amount:integer; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminMutePlayerCommand }
FZAdminMutePlayerCommand = class(FZAdminSinglePlayerAction)
  _time:integer;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; time:integer; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminKillPlayerCommand }
FZAdminKillPlayerCommand = class(FZAdminSinglePlayerAction)
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminSetUpdrateCommand }
FZAdminSetUpdrateCommand = class(FZAdminSinglePlayerAction)
  _updrate:cardinal;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; updrate:cardinal; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminTeleportPlayerCommand }
FZAdminTeleportPlayerCommand = class(FZAdminSinglePlayerAction)
  _pos:FVector3;
  _dir:FVector3;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; pos:FVector3; dir:FVector3; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminPacketSenderCommand }
FZAdminPacketSenderCommand = class(FZAdminSinglePlayerAction)
  _packet:NET_Packet;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  function GetPacket():pNET_Packet;
  constructor Create(id:cardinal; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminKickPlayerCommand }
FZAdminKickPlayerCommand = class(FZAdminSinglePlayerAction)
  _reason:string;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; reason:string; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminChangeTeamCommand }
FZAdminChangeTeamCommand = class(FZAdminSinglePlayerAction)
  _team:integer;
  _printstatus:boolean;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; team:integer; printstatus:boolean; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminBlockChangeTeamCommand }
FZAdminBlockChangeTeamCommand = class(FZAdminSinglePlayerAction)
  _time:integer;
  _printstatus:boolean;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; time:integer; printstatus:boolean; reporter:FZAdminCommandInfoReporter);
end;

{ FZAdminForceInvincibilityCommand }
FZAdminForceInvincibilityCommand = class(FZAdminSinglePlayerAction)
  _status:integer;
  _printhelp:boolean;
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; status:integer; printhelp:boolean; reporter:FZAdminCommandInfoReporter);
end;

function Init():boolean;
procedure Free();
function AddAdminCommandToQueue(cmd:FZAdminCommand):boolean;
procedure ProcessAdminCommands(); stdcall;
function GetConsoleReporter(raid:cardinal):FZConsoleReporter;

//******************************************************************************************************************************************************************************
implementation

uses syncobjs, basedefs, xr_debug, LogMgr, Servers, sysutils, strutils, Players, Banned, TranslationMgr, Games, xrstrings, xr_time, dynamic_caster, Console;

type

{ FZAdminCommandsProcessor }
FZAdminCommandsProcessor = class
  _commands:array of FZAdminCommand;
  _count:integer;
  _cs:TCriticalSection;

  procedure _ResizeCommandsQueue(sz:integer);
  procedure _ClearCommands();
public
  constructor Create();
  function AddCommand(cmd:FZAdminCommand):boolean;
  function GetCommand():FZAdminCommand;
  destructor Destroy(); override;
end;

{ FZAdminCommandsProcessor }
procedure FZAdminCommandsProcessor._ResizeCommandsQueue(sz:integer);
begin
  R_ASSERT(sz >= length(_commands), 'Decreasing queue size not supported', 'FZAdminCommandsProcessor._ResizeCommandsQueue');
  setlength(_commands, sz);
end;

procedure FZAdminCommandsProcessor._ClearCommands();
var
  i:integer;
begin
  for i:=0 to _count-1 do begin
    _commands[i].Free();
  end;
  _count:=0;
end;

constructor FZAdminCommandsProcessor.Create();
begin
  inherited;
  _cs:=TCriticalSection.Create();
  _ResizeCommandsQueue(1);
  _count:=0;
end;

function FZAdminCommandsProcessor.AddCommand(cmd: FZAdminCommand): boolean;
begin
  _cs.Enter;
  if _count >= length(_commands) then begin
    _ResizeCommandsQueue(length(_commands) * 2);
  end;

  _commands[_count]:=cmd;
  _count:=_count+1;
  _cs.Leave;
  result:=true;
end;

function FZAdminCommandsProcessor.GetCommand(): FZAdminCommand;
var
  i:integer;
begin
  result:=nil;
  _cs.Enter();
  if _count > 0 then begin
    result:=_commands[0];
    for i:=1 to _count-1 do begin
      _commands[i-1]:=_commands[i];
    end;
    _count:=_count-1;
  end;
  _cs.Leave();
end;

destructor FZAdminCommandsProcessor.Destroy();
begin
  _ClearCommands();
  setlength(_commands, 0);
  _cs.Free();
  inherited;
end;

{ FZConsoleReporter }
constructor FZConsoleReporter.Create(raid: cardinal);
begin
  inherited Create();
  _raid:=raid;
end;

procedure FZConsoleReporter.Report(s: string; iserror: boolean);
var
  p:NET_Packet;
  tmp:string;
begin
  if _raid<>0 then begin
    tmp:='[To radmin '+inttostr(_raid)+'] '+s;
  end else begin
    tmp:=s;
  end;

  if _raid<>0 then begin
    FZLogMgr.Get().Write(tmp, FZ_LOG_INFO);
  end else if iserror then begin
    FZLogMgr.Get().Write(tmp, FZ_LOG_ERROR);
  end else begin
    FZLogMgr.Get().Write(tmp, FZ_LOG_USEROUT);
  end;

  if (_raid<>0) and (ID_to_client(_raid)<>nil) then begin
    if iserror then begin
      tmp:='ERROR: '+s;
    end else begin
      tmp:=s;
    end;
    MakeRadminCmdPacket(@p, tmp);
    SendPacketToClient(GetPureServer(), _raid, @p);
  end;
end;

{ FZAdminCommand }
constructor FZAdminCommand.Create(reporter: FZAdminCommandInfoReporter);
begin
  inherited Create();
  _reporter:=reporter;
  _previous_command_failed:=false;
  _next_command:=nil;
end;

procedure FZAdminCommand.Report(s: string; iserror: boolean);
begin
  R_ASSERT(_reporter<>nil, 'No reporter', 'FZAdminCommand.Log');
  _reporter.Report(s, iserror);
end;

procedure FZAdminCommand.OnCommandFailed();
begin
  if _next_command<>nil then begin
    _next_command._previous_command_failed:=true;
  end;
end;

destructor FZAdminCommand.Destroy();
begin
  _reporter.Free();
  inherited;
end;

function FZAdminCommand.Execute(): boolean;
begin
  result:=true;

  if _previous_command_failed then begin
    FZLogMgr.Get().Write('Admin cmd '+GetName()+' cancelled - previous stage failed', FZ_LOG_DBG);
    result:=false;
  end;

  if result then begin
    result:=Execute_internal();
  end;

  if not result then begin
    OnCommandFailed();
  end;
end;

function FZAdminCommand.GetName(): string;
begin
  result:=_name;
end;

procedure FZAdminCommand.SetNextStageCommand(cmd: FZAdminCommand);
begin
  _next_command:=cmd;
end;

{ FZSimpleConsoleCmd }
constructor FZSimpleConsoleCmd.Create(cmd: string; reporter: FZAdminCommandInfoReporter);
begin
  _cmd:=cmd;
  _name:='CONSOLE_CMD';
end;

function FZSimpleConsoleCmd.Execute_internal(): boolean;
begin
  ExecuteConsoleCommand(PAnsiChar(_cmd));
  result:=true;
end;

{ FZReportPlayersCommand }
function PrintID_callback(player:pointer{pIClient}; parameter:pointer=nil; {%H-}parameter2:pointer=nil):boolean stdcall;
var
  cl:pIClient;
  cld:pxrClientData;
  str:string;
  id_str:string;
begin
  result:=false;
  cl:=pIClient(player);
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  str:=PAnsiChar(parameter);
  str:=trim(str);
  id_str:= inttostr(cl.ID.id);
  if (length(str)=0) or (leftstr(id_str, length(str))=str) then begin
    R_ASSERT(parameter2<>nil, 'parameter2 should be a command', 'PrintID_callback');
    FZReportPlayersCommand(parameter2).Report(id_str+' : ' + get_string_value(@cl.name) + ' - [' + GetHwId(cld, false)+']', false);
    SetLastPrintedID(cl.ID.id);
  end;
  result:=true;
end;

constructor FZReportPlayersCommand.Create(first_symbs: string; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(reporter);
  _first_symbs:=first_symbs;
  _name:='REPORT_PLAYERS';
end;

function FZReportPlayersCommand.Execute_internal(): boolean;
begin
  Report('--- FZ players list start ---', false);
  ForEachClientDo(@PrintID_callback, nil, PAnsiChar(_first_symbs), self);
  Report('--- FZ players list end ---', false);
  result:=true;
end;

{ FZAdminBanHwidCommand }
constructor FZAdminBanHwidCommand.Create(id: cardinal; radmin_id: cardinal; time: cardinal; reason: string; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(reporter);
  _id:=id;
  _raid:=radmin_id;
  _time:=time;
  _reason:=reason;
  _name:='BAN_HWID';
end;

function FZAdminBanHwidCommand.Execute_internal(): boolean;
var
  client, radmin:pxrClientData;
  hwid, tmp:string;
  banned_cl:pbanned_client;
begin
  result:=false;
  client:=ID_to_client(_id);
  radmin:=ID_to_client(_raid);

  if client = nil then begin
    Report('Cannot find client with ID '+inttostr(_id), true);
    exit;
  end else if IsLocalServerClient(@client.base_IClient) or client.m_admin_rights__m_has_admin_rights then begin
    Report('Cannot ban client "'+PAnsiChar(@client.ps.name[0])+'" with admin rights', true);
    exit;
  end;

  hwid:=GetHwId(client, false);
  if length(hwid) = 0 then begin
    Report('Client "'+PAnsiChar(@client.ps.name[0])+'" has no HWID', true);
    exit;
  end;

  banned_cl:=BanPlayerByDigest(@GetCurrentGame.m_cdkey_ban_list, hwid, _time, radmin);
  if banned_cl = nil then begin
    Report('Error banning client "'+PAnsiChar(@client.ps.name[0])+'" with ID '+inttostr(_id), true);
    exit;
  end;

  _reason:=StringReplace(trim(_reason), ' ', '_', [rfReplaceAll]);

  tmp:=FZTranslationMgr.Get().TranslateSingle('fz_player_banned')+' '+get_string_value(@banned_cl.admin_name);
  if length(_reason) > 0 then begin
    tmp:=tmp+', ('+FZTranslationMgr.Get().TranslateSingle('fz_ban_for')+' '+_reason+')';
  end;
  tmp:=tmp+', '+FZTranslationMgr.Get().TranslateSingle('fz_expiration_date')+' '+TimeToString(banned_cl.ban_end_time);

  assign_string(@banned_cl.client_name, @client.ps.name[0]);
  if length(_reason) > 0 then begin
    assign_string(@banned_cl.admin_name, PAnsiChar(get_string_value(@banned_cl.admin_name)+'('+FZTranslationMgr.Get().TranslateSingle('fz_ban_for')+':'+_reason+')'));
  end;
  SaveBanList(@GetCurrentGame.m_cdkey_ban_list);

  IPureServer__DisconnectClient(GetPureServer(), @client.base_IClient, tmp);

  result:=true;
end;

{ FZAdminSinglePlayerAction }
constructor FZAdminSinglePlayerAction.Create(id: cardinal; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(reporter);
  _id:=id;
end;

function FZAdminSinglePlayerAction.Execute_internal():boolean;
var
  cld:pxrClientData;
begin
  result:=false;
  LockServerPlayers();
  cld:=ID_to_client(_id);
  if cld<>nil then begin
    result:=DoAction(cld);
  end else begin
    Report('Can''t find client with ID '+inttostr(_id), true);
  end;
  UnlockServerPlayers();
end;

{ FZAdminRankChangeCommand }
constructor FZAdminRankChangeCommand.Create(id: cardinal; delta:integer; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _delta:=delta;
  _name:='RANK_CHANGE';
end;

function FZAdminRankChangeCommand.DoAction(player: pxrClientData): boolean;
begin
  result:=ChangePlayerRank(player, _delta);
  if not result then begin
    Report('Error changing rank for client '+inttostr(_id), true);
  end;
end;

{ FZAdminAddMoneyCommand }
constructor FZAdminAddMoneyCommand.Create(id: cardinal; amount: integer; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _amount:=amount;
  _name:='ADD_MONEY';
end;

function FZAdminAddMoneyCommand.DoAction(player: pxrClientData): boolean;
begin
  AddMoney(player, _amount);
  result:=true;
end;

{ FZAdminMutePlayerCommand }
constructor FZAdminMutePlayerCommand.Create(id: cardinal; time: integer; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _time:=time;
  _name:='MUTE_PLAYER';
end;

function FZAdminMutePlayerCommand.DoAction(player: pxrClientData): boolean;
begin
  if _time > 0 then begin
    result:=MutePlayer(player, _time);
    if not result then begin
      Report('Error muting client '+inttostr(_id), true);
    end;
  end else if _time < 0 then begin
    result:=UnmutePlayer(player);
    if not result then begin
      Report('Error unmuting client '+inttostr(_id), true);
    end;
  end else begin
    result:=false;
    Report('0 is invalid time to mute player', true);
  end;
end;

{ FZAdminKillPlayerCommand }
constructor FZAdminKillPlayerCommand.Create(id: cardinal; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _name:='KILL_PLAYER';
end;

function FZAdminKillPlayerCommand.DoAction(player: pxrClientData): boolean;
begin
  KillPlayer(player);
  result:=true;
end;

{ FZAdminSetUpdrateCommand }
constructor FZAdminSetUpdrateCommand.Create(id: cardinal; updrate: cardinal; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _updrate:=updrate;
  _name:='SET_UPDRATE';
end;

function FZAdminSetUpdrateCommand.DoAction(player: pxrClientData): boolean;
begin
  SetUpdRate(player, _updrate);
  result:=true;
end;

{ FZAdminTeleportPlayerCommand }
constructor FZAdminTeleportPlayerCommand.Create(id: cardinal; pos: FVector3; dir: FVector3; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _pos:=pos;
  _dir:=dir;
  _name:='TELEPORT_PLAYER';
end;

function FZAdminTeleportPlayerCommand.DoAction(player: pxrClientData): boolean;
begin
  result:=false;
  if (GetPureServer()<>nil) then begin
    SendTeleportPlayerPacket(player, @_pos, @_dir);
    result:=true;
  end;
end;

{ FZAdminPacketSenderCommand }
constructor FZAdminPacketSenderCommand.Create(id: cardinal; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _name:='SEND_PACKET';
end;

function FZAdminPacketSenderCommand.DoAction(player: pxrClientData): boolean;
begin
  result:=false;
  if (GetPureServer()<>nil) then begin
    SendPacketToClient(GetPureServer(), _id, @_packet);
    result:=true;
  end;
end;

function FZAdminPacketSenderCommand.GetPacket(): pNET_Packet;
begin
  result:=@_packet;
end;

{ FZAdminKickPlayerCommand }
constructor FZAdminKickPlayerCommand.Create(id: cardinal; reason: string; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _reason:=reason;
  _name:='KICK_PLAYER';
end;

function FZAdminKickPlayerCommand.DoAction(player: pxrClientData): boolean;
begin
  result:=false;
  if length(_reason) = 0 then begin
    Report('Can''t kick player without the reason', true);
    exit;
  end;

  if (GetPureServer()<>nil) then begin
    DisconnectPlayer(@player.base_IClient, PAnsiChar(_reason));
    result:=true;
  end;
end;

{ FZAdminChangeTeamCommand }
constructor FZAdminChangeTeamCommand.Create(id: cardinal; team: integer; printstatus:boolean; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _team:=team;
  _printstatus:=printstatus;
  _name:='CHANGE_TEAM';
end;

function FZAdminChangeTeamCommand.DoAction(player: pxrClientData): boolean;
var
  game:pgame_sv_mp;
  curteam:integer;
begin
  result:=false;
  game:=GetCurrentGame();
  if _printstatus then begin
    curteam:=player.ps.team;
    //В CTA команды имеют номера 0 и 1 - учитываем это
    if dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_CaptureTheArtefact, false) <> nil then begin
      curteam:=curteam+1;
    end;

    Report(GenerateMessageForClientId(_id, 'is currently member of team '+inttostr(curteam)), false);
    result:=true;
  end else if (_team < 1) or (_team > 2) then begin
    Report('Invalid team index '+inttostr(_team), true);
  end else if IsLocalServerClient(@player.base_IClient) then begin
    Report('Can''t change team for local server client '+inttostr(player.base_IClient.ID.id), true);
  end else if (player.net_Ready=0) or IsSlotsBlocked(player) then begin
    Report('Can''t change team for this player now, try to do it later', true);
  end else if game<>nil then begin
    //В CTA команды имеют номера 0 и 1 - учитываем это
    if dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_CaptureTheArtefact, false) <> nil then begin
      _team:=_team - 1;
    end;

    if (player.ps.team <> _team) then begin
      game_OnPlayerSelectTeam(game, player.base_IClient.ID.id, _team);
      //Выберем скин, чтобы не беспокоить игрока лишними экранами
      game_OnPlayerSelectSkin(game, player.base_IClient.ID.id, player.ps.skin);
      result:=true;
    end else begin
      Report('Player is a member of the specified team!', true);
    end;
  end;
end;

{ FZAdminBlockChangeTeamCommand }
constructor FZAdminBlockChangeTeamCommand.Create(id: cardinal; time: integer; printstatus:boolean; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _time:=time;
  _printstatus:=printstatus;
  _name:='BLOCK_TEAMCHANGE';
end;

function FZAdminBlockChangeTeamCommand.DoAction(player: pxrClientData): boolean;
begin
  if _printstatus then begin
    if IsPlayerTeamChangeBlocked(player) then begin
      Report(GenerateMessageForClientId(_id, 'is currently NOT allowed to change team'), false);
    end else begin
      Report(GenerateMessageForClientId(_id, 'is currently ALLOWED to change team'), false);
    end;
    result:=true;
  end else if _time > 0 then begin
    result:=BlockPlayerTeamChange(player, _time);
    if not result then begin
      Report('Error while blocking team change for client '+inttostr(_id), true);
    end else begin
      Report('Team successfully locked for client '+inttostr(_id), false);
    end;
  end else if _time < 0 then begin
    result:=UnBlockPlayerTeamChange(player);
    if not result then begin
      Report('Error while unblocking team change for client '+inttostr(_id), true);
    end else begin
      Report('Team successfully unlocked for client '+inttostr(_id), false);
    end;
  end else begin
    result:=false;
    Report('0 is invalid time for blocking team change', true);
  end;
end;

{ FZAdminForceInvincibilityCommand }
constructor FZAdminForceInvincibilityCommand.Create(id: cardinal; status: integer; printhelp:boolean; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _status:=status;
  _printhelp:=printhelp;
  _name:='FORCE_INVINCIBILITY';
end;

function FZAdminForceInvincibilityCommand.DoAction(player: pxrClientData): boolean;
var
  transformed_status:FZPlayerInvincibleStatus;
  str:string;
begin
  if _printhelp then begin
    str:=GenerateMessageForClientId(player.base_IClient.ID.id, 'has invincibility status ');
    case GetForceInvincibilityStatus(player) of
      FZ_INVINCIBLE_DEFAULT:       str:=str+'-1 (original behavior)';
      FZ_INVINCIBLE_FORCE_DISABLE: str:=str+'0 (always disabled)';
      FZ_INVINCIBLE_FORCE_ENABLE:  str:=str+'1 (always enabled)';
    else
      str:=str+'(unknown)';
    end;

    Report(str, false);
    result:=true
  end else begin
    result:=true;
    case _status of
      -1: transformed_status:=FZ_INVINCIBLE_DEFAULT;
       0: transformed_status:=FZ_INVINCIBLE_FORCE_DISABLE;
       1: transformed_status:=FZ_INVINCIBLE_FORCE_ENABLE;
    else
      Report('Invalid argument "'+inttostr(_status)+'" - expected 1, 0 or -1', true);
      result:=false;
    end;

    if result then begin
      result:=SetForceInvincibilityStatus(player, transformed_status);
    end;

    if not result then begin
      Report('Can''t change force invincibility status for player '+inttostr(_id)+' to '+inttostr(_status), true);
    end;
  end;
end;

{ Global functions }
var
  _commandsprocessor:FZAdminCommandsProcessor;

function AddAdminCommandToQueue(cmd: FZAdminCommand): boolean;
begin
  result:=_commandsprocessor.AddCommand(cmd);
end;

procedure ProcessAdminCommands(); stdcall;
var
  cmd:FZAdminCommand;
begin
  cmd:=_commandsprocessor.GetCommand();
  while cmd<>nil do begin
    FZLogMgr.Get().Write('Processing admin cmd '+cmd.GetName(), FZ_LOG_DBG);
    cmd.Execute();
    cmd.Free;
    cmd:=_commandsprocessor.GetCommand();
  end;
end;

function GetConsoleReporter(raid:cardinal): FZConsoleReporter;
begin
  result:=FZConsoleReporter.Create(raid);
end;

function Init(): boolean;
begin
  _commandsprocessor:=FZAdminCommandsProcessor.Create();
  result:=true;
end;

procedure Free();
begin
  _commandsprocessor.Free();
end;

end.

