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
  procedure Report(s:string; iserror:boolean);
public
  constructor Create(reporter:FZAdminCommandInfoReporter);
  destructor Destroy(); override;
  function Execute():boolean; virtual; abstract;
  function GetName():string;
end;

{ FZSimpleConsoleCmd }
FZSimpleConsoleCmd = class (FZAdminCommand)
  _cmd:string;
public
  constructor Create(cmd:string; reporter:FZAdminCommandInfoReporter);
  function Execute():boolean; override;
end;

{ FZReportPlayersCommand }
FZReportPlayersCommand = class (FZAdminCommand)
  _first_symbs:string;
public
  constructor Create(first_symbs:string; reporter:FZAdminCommandInfoReporter);
  function Execute():boolean; override;
end;

{ FZAdminBanHwidCommand }
FZAdminBanHwidCommand = class (FZAdminCommand)
  _id:cardinal;
  _raid:cardinal;
  _time:cardinal;
  _reason:string;
public
  constructor Create(id:cardinal; radmin_id:cardinal; time:cardinal; reason:string; reporter:FZAdminCommandInfoReporter);
  function Execute():boolean; override;
end;

{ FZAdminSinglePlayerAction }
FZAdminSinglePlayerAction = class(FZAdminCommand)
  _id:cardinal;
protected
  function DoAction(player:pxrClientData):boolean; virtual; abstract;
public
  constructor Create(id:cardinal; reporter:FZAdminCommandInfoReporter);
  function Execute():boolean; override;
end;

{ FZAdminRankChangeCommand }
FZAdminRankChangeCommand = class (FZAdminSinglePlayerAction)
  _id:cardinal;
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
protected
  function DoAction(player:pxrClientData):boolean; override;
public
  constructor Create(id:cardinal; team:integer; reporter:FZAdminCommandInfoReporter);
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
end;

procedure FZAdminCommand.Report(s: string; iserror: boolean);
begin
  R_ASSERT(_reporter<>nil, 'No reporter', 'FZAdminCommand.Log');
  _reporter.Report(s, iserror);
end;

destructor FZAdminCommand.Destroy();
begin
  _reporter.Free();
  inherited;
end;

function FZAdminCommand.GetName(): string;
begin
  result:=_name;
end;

{ FZSimpleConsoleCmd }
constructor FZSimpleConsoleCmd.Create(cmd: string; reporter: FZAdminCommandInfoReporter);
begin
  _cmd:=cmd;
  _name:='CONSOLE_CMD';
end;

function FZSimpleConsoleCmd.Execute(): boolean;
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

function FZReportPlayersCommand.Execute(): boolean;
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

function FZAdminBanHwidCommand.Execute(): boolean;
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

function FZAdminSinglePlayerAction.Execute():boolean;
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
constructor FZAdminChangeTeamCommand.Create(id: cardinal; team: integer; reporter: FZAdminCommandInfoReporter);
begin
  inherited Create(id, reporter);
  _team:=team;
  _name:='CHANGE_TEAM';
end;

function FZAdminChangeTeamCommand.DoAction(player: pxrClientData): boolean;
var
  game:pgame_sv_mp;
begin
  result:=false;
  game:=GetCurrentGame();

  if (_team < 1) or (_team > 2) then begin
    Report('Invalid team index '+inttostr(_team), true);
  end else if game<>nil then begin
    game_OnPlayerSelectTeam(game, player.base_IClient.ID.id, _team);
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

