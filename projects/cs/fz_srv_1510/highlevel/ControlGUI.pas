unit ControlGUI;
{$mode Delphi}
interface

uses
  Interfaces, Classes, SysUtils, FileUtil,
  Forms, Controls, Graphics, Dialogs, Clients, ActnList, stdctrls, extctrls,
  Comctrls, windows, math, Types,LazUTF8,CLIPBrd;

const
  STR_PLAYER_LOADING:PChar = '(Loading...)';
  STR_REALLY_STOP_SERVER:PChar='Really stop the server?';

  //Названия опций в комбобоксе
  STR_CLOSE_WINDOW:PChar = 'Close window';
  STR_CONSOLE_CMD:PChar = 'Console command';
  STR_REFRESH:PChar = 'Refresh info';
  STR_KICK_PLAYER:PChar = 'Kick player';
  STR_MUTE_PLAYER:PChar = 'Mute player';
  STR_TEST_SACE_CHAT:PChar = 'SACE crash-test #1';
  STR_TEST_SACE_CHANGENAME:PChar = 'SACE crash-test #2';
  STR_BUG_PLAYER_UPDATE:PChar = 'Bug #1';
  STR_BUG_PLAYER_SPAWN:PChar = 'Bug #2';
  STR_BUG_PLAYER_SVCONFIG:PChar = 'Bug #3';
  STR_TELEPORT_PLAYER:PChar = 'Teleport player';

  STR_CHANGE_UPDRATE:PChar = 'Change update rate';
  STR_TEST_CENSOR:PChar = 'Check censor';
  STR_KILL_PLAYER:PChar = 'Kill player';
  STR_ADD_MONEY:PChar = 'Add money';
  STR_SET_TEAM:PChar = 'Change team';
  STR_BLOCK_TEAMCHANGE:PChar = 'Block teamchange';
  STR_RANK_UP:PChar = 'Rank Up';
  STR_RANK_DOWN:PChar = 'Rank Down';
  STR_INVINCIBILITY:PChar = 'Invincibility';

  STR_STOP_SERVER:PChar = 'Stop the server';
  STR_GENERATE_CDKEY:PChar = 'Generate CDKEY';

  //Строки для лейблов под комбобоксом
  STR_REASON:PChar = 'Reason:';
  STR_VALUE:PChar = 'Value:';
  STR_TIME:PChar = 'Time (min.): ';
  STR_RESULT:PChar='Result: ';
  STR_TEXT:PChar='Text: ';
  STR_INPUT:PChar='Input: ';
  STR_OUTPUT:PChar='Output: ';
  STR_POS:PChar = 'Position:';
  STR_DIR:PChar = 'Direction:';
  STR_COMMAND:PChar = 'Command:';   

  //Строки в области информации 
  INFO_ID:PChar = 'ID: ';
  INFO_IS_MUTED_CHAT:PChar =    'Muted chat: ';
  INFO_IS_MUTED_VOTINGS:PChar = 'Muted votings: ';
  INFO_IS_MUTED_SPEECH:PChar =  'Muted radio: ';
  INFO_BPS:PChar =              'BPS: ';
  INFO_SENT:PChar =             'Sent: ';
  INFO_RETRIED:PChar =          'Retried: ';
  INFO_DROPPED:PChar =          'Dropped: ';
  INFO_UPDRATE:PChar =          'Updrate: ';
  INFO_MONEY:PChar =            'Money: ';
  INFO_TEAM:PChar =             'Team: ';
  INFO_RANK:PChar =             'Rank: ';
  INFO_FRAGS:PChar =            'Frags: ';
  INFO_SELFKILLS:PChar =        'Selfkills: ';
  INFO_TEAMKILLS:PChar =        'Teamkills: ';
  INFO_DEATHES:PChar =          'Deathes: ';
  INFO_HWID:PChar =             'HWID: ';
  INFO_ORIG_CDKEY:PChar =       'KEY: ';
  INFO_SACE:PChar =             'SACE: ';
  INFO_INVINCIBILITY:PChar =    'Invincibility: ';
  INFO_TEAMCHANGE:PChar=        'Teamchange: ';

type
  TFZPlayerData = class
  public
    id:ClientID;
    game_id:word;
    name:string;
    sace_status:integer;
    sace_string:string;
    chat_muted:boolean;
    votings_muted:boolean;
    speech_muted:boolean;
    bps:cardinal;
    sent_ng:cardinal;
    sent_g:cardinal;
    retried:cardinal;
    dropped:cardinal;
    updrate:cardinal;
    money:integer;
    frags:integer;
    deathes:integer;
    selfkills:integer;
    teamkills:integer;
    rank:integer;
    team:integer;
    hwid:string;
    orig_cdkey:string;
    invincibility_string:string;
    teamchange_blocked:boolean;

    item_color:TColor;

    constructor Create(cl:pxrClientData);
    destructor Destroy(); override;
  end;

  FZOptionsItem = class
    public
    form_prepare:TAction;
    action:TAction;
    constructor Create(prep:TAction; act:TAction);
    destructor Destroy(); override;
  end;

  { TFZControlGUI }

  TFZControlGUI = class(TForm)
    ActBlockTeamchange: TAction;
    ActInvincibility: TAction;
    btn_clear_chat: TButton;
    btn_inverse_chat: TButton;
    btn_options_chat: TButton;
    check_autorefresh: TCheckBox;
    lbl_hwid: TLabel;
    lbl_teamchangeblock: TLabel;
    lbl_sace: TLabel;
    lbl_orig_cdkey: TLabel;
    lbl_invincibility: TLabel;
    ListPlayers: TListBox;
    ActList: TActionList;
    ActRefresh: TAction;
    ActStopServer: TAction;
    ActRankUp: TAction;
    ActRankDown: TAction;
    ActMoneyAdd: TAction;
    ActSetTeam: TAction;
    ActExperienceAdd: TAction;
    ActKick: TAction;
    ActBan: TAction;
    ActBanSubnet: TAction;
    ActBugTrap: TAction;
    ActKill: TAction;
    RefreshTimer: TTimer;
    ActKeyGen: TAction;
    ActMute: TAction;
    ActCheckCensor: TAction;
    ActOnSelectItems: TActionList;
    ActOptDisableAll: TAction;
    ActOptTimeReason: TAction;
    ActOptReason: TAction;
    group_options: TGroupBox;
    Edit1: TEdit;
    Edit2: TEdit;
    combo_options: TComboBox;
    btn_ok: TButton;
    Label1: TLabel;
    Label2: TLabel;
    ActOptTime: TAction;
    ActCheckSACE_Chat: TAction;
    group_info: TGroupBox;
    lbl_id: TLabel;
    lbl_chatmute: TLabel;
    lbl_mutedvotings: TLabel;
    lbl_mutedradio: TLabel;
    lbl_bps: TLabel;
    lbl_retry: TLabel;
    lbl_drop: TLabel;
    lbl_sent: TLabel;
    lbl_updrate: TLabel;
    ActChangeUpdrate: TAction;
    ActOptValue: TAction;
    ActOptInputOutput: TAction;
    ActClosePanel: TAction;
    btn_close: TButton;
    btn_minimize: TButton;
    Panel1: TPanel;
    lbl_fz_caption: TLabel;
    ActCheckSACE_Changename: TAction;
    ActBugUpdate: TAction;
    ActBugSpawn: TAction;
    ActBugSvconfig: TAction;
    ActTeleport: TAction;
    ActOptPosDir: TAction;
    group_chat: TGroupBox;
    ActConsoleCmd: TAction;
    ActOptCommand: TAction;
    edit_chatmsg: TEdit;
    btn_sendmsg: TButton;
    chatlog: TMemo;
    TrackChat: TTrackBar;
    lbl_money: TLabel;
    lbl_rank: TLabel;
    lbl_team: TLabel;
    lbl_frags: TLabel;
    lbl_selfkills: TLabel;
    lbl_teamkills: TLabel;
    lbl_deathes: TLabel;
    procedure ActBanExecute(Sender: TObject);
    procedure ActBlockTeamchangeExecute(Sender: TObject);
    procedure ActInvincibilityExecute(Sender: TObject);
    procedure ActRankDownExecute(Sender: TObject);
    procedure ActRankUpExecute(Sender: TObject);
    procedure ActRefreshExecute(Sender: TObject);
    procedure ActSetTeamExecute(Sender: TObject);
    procedure ActStopServerExecute(Sender: TObject);
    procedure btn_clear_chatClick(Sender: TObject);
    procedure btn_inverse_chatClick(Sender: TObject);
    procedure btn_options_chatClick(Sender: TObject);
    procedure chatlogContextPopup(Sender: TObject; {%H-}MousePos: TPoint;
      var Handled: Boolean);
    procedure FormShow(Sender: TObject);
    procedure SelectOnDblClick(Sender: TObject);
    procedure ListPlayersDrawItem({%H-}Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure RefreshTimerTimer(Sender: TObject);
    procedure ActKillExecute(Sender: TObject);
    procedure ActKickExecute(Sender: TObject);
    procedure ActKeyGenExecute(Sender: TObject);
    procedure check_autorefreshClick(Sender: TObject);
    procedure ActMuteExecute(Sender: TObject);
    procedure ActCheckCensorExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ActOptDisableAllExecute(Sender: TObject);
    procedure ActOptTimeReasonExecute(Sender: TObject);
    procedure ActOptReasonExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure combo_optionsSelect(Sender: TObject);
    procedure btn_okClick(Sender: TObject);
    procedure ActOptTimeExecute(Sender: TObject);
    procedure ActCheckSACE_ChatExecute(Sender: TObject);

    procedure ListPlayersClick(Sender: TObject);
    procedure ActChangeUpdrateExecute(Sender: TObject);
    procedure ActOptValueExecute(Sender: TObject);
    procedure ActOptInputOutputExecute(Sender: TObject);
    procedure ActClosePanelExecute(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; {%H-}Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure FormMouseUp(Sender: TObject; {%H-}Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure FormMouseMove(Sender: TObject; {%H-}Shift: TShiftState; {%H-}X,
      {%H-}Y: Integer);
    procedure btn_closeClick(Sender: TObject);
    procedure ActMoneyAddExecute(Sender: TObject);
    procedure btn_minimizeClick(Sender: TObject);
    procedure ActCheckSACE_ChangenameExecute(Sender: TObject);
    procedure ActBugUpdateExecute(Sender: TObject);
    procedure ActBugSpawnExecute(Sender: TObject);
    procedure ActBugMoveExecute(Sender: TObject);
    procedure ActBugSvconfigExecute(Sender: TObject);
    procedure ActTeleportExecute(Sender: TObject);
    procedure ActOptPosDirExecute(Sender: TObject);
    procedure ActConsoleCmdExecute(Sender: TObject);
    procedure ActOptCommandExecute(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure RefreshChat;
    procedure btn_sendmsgClick(Sender: TObject);
    procedure edit_chatmsgKeyPress(Sender: TObject; var Key: Char);
    procedure TrackChatChange(Sender: TObject);
  private
    { Private declarations }
    _mousedown:boolean;
    _mousepoint:TPoint;

    procedure _ClearListPlayers();
    procedure _ClearChat();
    procedure _InverseChat();
    procedure _ActualizeChatControlsPos();
    procedure ChatOptionsState(display:boolean);
  public
    { Public declarations }
    procedure RefreshSelectedInfo();    
  end;

function Init():boolean; stdcall;
procedure AddChatMessageToList(name:pchar; msg:pchar);stdcall;
procedure Clean();

var
  FZControlGUI: TFZControlGUI;
implementation
uses Console, dynamic_caster, basedefs, SACE_interface, Servers, Players, Keys, TranslationMgr, Censor, badpackets, MatVectors, CommonHelper, ConfigCache, LogMgr, SubnetBanlist, ItemsCfgMgr, DownloadMgr, PlayersConnectionLog, MapGametypes, AdminCommands, GameSpy, Games, whitehashes, TeleportMgr, HitMgr;

{$R *.lfm}

type
TFZChatDirectionMode = (FZ_CHAT_DIRECTION_NEW_UP, FZ_CHAT_DIRECTION_NEW_DOWN);

{ TFZChatMessagesContainer }

TFZChatMessagesContainer = class
private
  _chatdirection:TFZChatDirectionMode;
  _lock:TRTLCriticalSection;
  _messages: TStrings;

  procedure Lock();
  procedure Unlock();
public
  constructor Create();
  destructor Destroy(); override;
  procedure AddMessage(sender:string; msg:string);
  procedure UpdateMessages(dest:TMemo);
  procedure ClearMessages();
  function GetChatDir():TFZChatDirectionMode;
  procedure AssignDirection(mode:TFZChatDirectionMode);
end;

constructor TFZChatMessagesContainer.Create();
begin
  _messages:=TStringList.Create;
  InitializeCriticalSection(_lock);

  if FZConfigCache.Get().GetDataCopy().gui_chat_direction = 1 then begin
    _chatdirection:=FZ_CHAT_DIRECTION_NEW_DOWN;
  end else begin
    _chatdirection:=FZ_CHAT_DIRECTION_NEW_UP;
  end;
end;

destructor TFZChatMessagesContainer.Destroy();
begin
  DeleteCriticalSection(_lock);
  _messages.Free;
  inherited Destroy();
end;

procedure TFZChatMessagesContainer.AddMessage(sender: string; msg: string);
begin
  Lock();
  if _chatdirection = FZ_CHAT_DIRECTION_NEW_UP then begin
    _messages.Insert(0, '['+FZCommonHelper.GetCurTime+'] '+WinCPToUTF8(sender+': '+msg));
  end else begin
    _messages.Insert(_messages.Count, '['+FZCommonHelper.GetCurTime+'] '+WinCPToUTF8(sender+': '+msg));
  end;
  Unlock();
end;

procedure TFZChatMessagesContainer.UpdateMessages(dest:TMemo);
var
  i:integer;
begin
  Lock();
  if _chatdirection = FZ_CHAT_DIRECTION_NEW_UP then begin
    dest.Lines := _messages;
  end else begin
    for i:=dest.Lines.Count to _messages.Count-1 do begin
      dest.Lines.Add(_messages[i]);
    end;
  end;
  Unlock();
end;

procedure TFZChatMessagesContainer.ClearMessages();
begin
  Lock();
  _messages.Clear();
  Unlock();
end;

function TFZChatMessagesContainer.GetChatDir(): TFZChatDirectionMode;
begin
  Lock();
  result:=_chatdirection;
  Unlock();
end;

procedure TFZChatMessagesContainer.AssignDirection(mode: TFZChatDirectionMode);
var
  i:integer;
  tmp:string;
begin
  Lock();
  if _chatdirection<>mode then begin
    if _messages.Count > 1 then begin
      for i:=0 to _messages.Count div 2 do begin
        tmp:=_messages[i];
        _messages[i]:=_messages[_messages.Count-i-1];
        _messages[_messages.Count-i-1]:=tmp;
      end;
    end;
    _chatdirection:=mode;
  end;
  Unlock();
end;

procedure TFZChatMessagesContainer.Lock();
begin
  EnterCriticalSection(_lock);
end;

procedure TFZChatMessagesContainer.Unlock();
begin
  LeaveCriticalSection(_lock);
end;

var
  ChatMessagesContainer:TFZChatMessagesContainer;

procedure AddChatMessageToList(name:pAnsiChar; msg:pAnsiChar);stdcall;
begin
  if (name=nil) then name:='ServerAdmin';
  ChatMessagesContainer.AddMessage(name, msg);
end;

procedure GUIConsoleCommand_Execute(arg:PChar); stdcall;
begin
  if pos('raid:', arg)<>0 then exit;

  FZControlGUI.Free;
  FZControlGUI:=TFZControlGUI.Create(Application);
  FZControlGUI.Show();
end;

procedure GUIConsoleCommand_Info(info:PChar); stdcall;
begin
  strcopy(info, 'Show FreeZone GUI Control Panel');
end;

procedure CDKEYConsoleCommand_Execute({%H-}arg:PChar); stdcall;
var
  s:string;
begin
  s:=GenerateRandomKey(true);
  ExecuteConsoleCommand(PChar('chat ' +FZTranslationMgr.Get.TranslateSingle('fz_cdkey_suggestion')+' '+s));
end;

procedure CDKEYConsoleCommand_Info(info:PChar); stdcall;
begin
  strcopy(info, 'Generates random CDKEY and shows it in chat');
end;

procedure Clean();
begin
  ChatMessagesContainer.Free;
  FZControlGUI.Free;
end;

procedure ReloadFZConfigs_info(info:PChar); stdcall;
begin
  strcopy(info, 'Reparses data from all FreeZone ini configs in the run-time');
end;

procedure ReloadFZConfigs_execute({%H-}arg:PChar); stdcall;
begin
  FZConfigCache.Get.Reload;
  FZTranslationMgr.Get.Reload;
  FZHitMgr.Get.Reload();
  FZDownloadMgr.Get.Reload;
  FZCensor.Get.ReloadDefaultFile;
  FZSubnetBanList.Get.ReloadDefaultFile();
  FZItemCfgMgr.Get.Reload;
  FZTeleportMgr.Get.Reload();
  FZHashesMgr.Get.Reload;
  FZMapGametypesMgr.Get.Reload;
  FZPlayersConnectionMgr.Get.Reset;
  GameSpy.OnConfigReloaded();
  FZLogMgr.Get.Write('Configs reloaded.', FZ_LOG_USEROUT);
end;

function Init():boolean; stdcall;
begin
  ChatMessagesContainer:=TFZChatMessagesContainer.Create;
  FZControlGUI:=nil;
  AddConsoleCommand('fz_gui', @GUIConsoleCommand_Execute, @GUIConsoleCommand_Info);
  AddConsoleCommand('fz_reload_configs',@ReloadFZConfigs_execute, @ReloadFZConfigs_info);
{$IFDEF REVO}
    AddConsoleCommand('fz_cdkey', @CDKEYConsoleCommand_Execute, @CDKEYConsoleCommand_Info);
{$ENDIF}
  result:=true;
end;

function ProcessAddPlayerToListQuery(pl:pointer; {%H-}parameter:pointer; {%H-}parameter2:pointer):boolean; stdcall;
var
  pd:TFZPlayerData;
  cl_d:pxrClientData;
begin
  result:=true;
  cl_d:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cl_d = nil) or IsLocalServerClient(@cl_d.base_IClient) then exit;
  pd:=TFZPlayerData.Create(cl_d);
  FZControlGUI.ListPlayers.AddItem(WinCPToUTF8(pd.name), pd as TObject);
end;


{TFZControlGUI}

procedure TFZControlGUI._ClearListPlayers();
var
  i:integer;
begin
  for i:=0 to self.ListPlayers.Count-1 do begin
    self.ListPlayers.Items.Objects[i].Free;
  end;
  self.ListPlayers.Clear;
end;

procedure TFZControlGUI._ClearChat();
begin
  ChatMessagesContainer.ClearMessages();
  chatlog.Clear;
  RefreshChat();
end;

procedure TFZControlGUI._InverseChat();
begin
  if ChatMessagesContainer.GetChatDir() = FZ_CHAT_DIRECTION_NEW_UP then begin
    ChatMessagesContainer.AssignDirection(FZ_CHAT_DIRECTION_NEW_DOWN);
  end else begin
    ChatMessagesContainer.AssignDirection(FZ_CHAT_DIRECTION_NEW_UP);
  end;

  _ActualizeChatControlsPos();
  chatlog.Clear;
  RefreshChat();
end;

procedure TFZControlGUI._ActualizeChatControlsPos();
var
  dir:TFZChatDirectionMode;
  options_top, chatsend_top:integer;
begin
  dir:=ChatMessagesContainer.GetChatDir();
  options_top:=btn_options_chat.Top;
  chatsend_top:=btn_sendmsg.Top;

  if ((dir = FZ_CHAT_DIRECTION_NEW_UP) and (chatsend_top > options_top)) or ((dir = FZ_CHAT_DIRECTION_NEW_DOWN) and (chatsend_top < options_top)) then begin
    edit_chatmsg.Top:=options_top+3;
    btn_sendmsg.Top:=options_top;

    btn_inverse_chat.Top:=chatsend_top;
    btn_options_chat.Top:=chatsend_top;
    btn_clear_chat.Top:=chatsend_top;
  end;

end;

procedure TFZControlGUI.ChatOptionsState(display: boolean);
begin
  if display then begin
    btn_inverse_chat.Visible:=true;
    btn_clear_chat.Visible:=true;
  end else begin
    btn_inverse_chat.Visible:=false;
    btn_clear_chat.Visible:=false;
  end;
end;

procedure TFZControlGUI.RefreshSelectedInfo();
var
  sel:TFZPlayerData;
begin
  if listplayers.ItemIndex>=0 then begin
    sel:=listplayers.Items.Objects[listplayers.ItemIndex] as TFZPlayerData;
    lbl_id.Caption:=INFO_ID + inttostr(sel.id.id);
    lbl_chatmute.Caption:=INFO_IS_MUTED_CHAT + booltostr(sel.chat_muted, true);
    lbl_mutedradio.Caption:=INFO_IS_MUTED_SPEECH+booltostr(sel.speech_muted, true);
    lbl_mutedvotings.Caption:=INFO_IS_MUTED_VOTINGS+booltostr(sel.votings_muted, true);
    lbl_bps.Caption:=INFO_BPS+inttostr(sel.bps);
    lbl_retry.Caption:=INFO_RETRIED+inttostr(sel.retried);
    lbl_drop.Caption:=INFO_DROPPED+inttostr(sel.dropped);
    lbl_sent.Caption:=INFO_SENT+inttostr(sel.sent_g)+'+'+inttostr(sel.sent_ng);
    lbl_updrate.Caption:=INFO_UPDRATE + inttostr(sel.updrate);
    lbl_money.Caption:=INFO_MONEY+inttostr(sel.money);
    lbl_rank.Caption:=INFO_RANK+inttostr(sel.rank);

    if dynamic_cast(GetCurrentGame(), 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_CaptureTheArtefact, false) <> nil then begin
      lbl_team.Caption:=INFO_TEAM+inttostr(sel.team+1);
    end else begin
      lbl_team.Caption:=INFO_TEAM+inttostr(sel.team);
    end;

    lbl_frags.Caption:=INFO_FRAGS+inttostr(sel.frags);
    lbl_selfkills.Caption:=INFO_SELFKILLS+inttostr(sel.selfkills);
    lbl_teamkills.Caption:=INFO_TEAMKILLS+inttostr(sel.teamkills);
    lbl_deathes.Caption:=INFO_DEATHES+inttostr(sel.deathes);
    lbl_invincibility.Caption:=INFO_INVINCIBILITY+sel.invincibility_string;

    if sel.teamchange_blocked then begin
      lbl_teamchangeblock.Caption:=INFO_TEAMCHANGE+'blocked';
    end else begin
      lbl_teamchangeblock.Caption:=INFO_TEAMCHANGE+'allowed';
    end;

    lbl_hwid.visible:= length(sel.hwid) > 0;
    lbl_hwid.Caption:=INFO_HWID+sel.hwid;

    lbl_orig_cdkey.visible:= length(sel.orig_cdkey) > 0;
    lbl_orig_cdkey.Caption:=INFO_ORIG_CDKEY+sel.orig_cdkey;

    lbl_sace.visible:= length(sel.sace_string) > 0;
    lbl_sace.Caption:=INFO_SACE+sel.sace_string;
  end else begin
    lbl_id.Caption:=INFO_ID;
    lbl_chatmute.Caption:=INFO_IS_MUTED_CHAT;
    lbl_mutedradio.Caption:=INFO_IS_MUTED_SPEECH;
    lbl_mutedvotings.Caption:=INFO_IS_MUTED_VOTINGS;
    lbl_bps.Caption:=INFO_BPS;
    lbl_retry.Caption:=INFO_RETRIED;
    lbl_drop.Caption:=INFO_DROPPED;
    lbl_sent.Caption:=INFO_SENT;
    lbl_updrate.Caption:=INFO_UPDRATE;
    lbl_money.Caption:=INFO_MONEY;
    lbl_rank.Caption:=INFO_RANK;
    lbl_team.Caption:=INFO_TEAM;
    lbl_frags.Caption:=INFO_FRAGS;
    lbl_selfkills.Caption:=INFO_SELFKILLS;
    lbl_teamkills.Caption:=INFO_TEAMKILLS;
    lbl_deathes.Caption:=INFO_DEATHES;
    lbl_invincibility.Caption:=INFO_INVINCIBILITY;
    lbl_teamchangeblock.Caption:=INFO_TEAMCHANGE;

    lbl_hwid.visible:=false;
    lbl_hwid.Caption:=INFO_HWID;

    lbl_orig_cdkey.visible:=false;
    lbl_orig_cdkey.Caption:=INFO_ORIG_CDKEY;

    lbl_sace.visible := false;
    lbl_sace.Caption:=INFO_SACE;
  end;
end;

procedure TFZControlGUI.RefreshChat;
var
  i:integer;
  si:SCROLLINFO;
begin
  if not self.visible then exit;
  ChatMessagesContainer.UpdateMessages(chatlog);

  si.cbSize:=sizeof(SCROLLINFO);
  si.fMask:=SIF_ALL;
  if (ChatMessagesContainer.GetChatDir() = FZ_CHAT_DIRECTION_NEW_UP) and GetScrollInfo(chatlog.Handle, SB_VERT, si) then begin
    if not TrackChat.Focused then begin
      //устанавливаем положение трека
      TrackChat.Max:=si.nMax-si.nMin{%H-}-si.nPage;
      TrackChat.Min:=si.nMin;
      TrackChat.Position:=si.nPos;
    end else begin
      //устанавливаем положение скролла
      i:=(si.nMax-si.nMin{%H-}-si.nPage);
      if i<0 then i:=0;
      i:=si.nMin + floor(i*(TrackChat.Position-TrackChat.Min)/(TrackChat.Max-TrackChat.Min));
    end;
  end;
end;

{ TFZPlayerData }

constructor TFZPlayerData.Create(cl: pxrClientData);
begin
  self.name:=cl.ps.name;
  if length(self.name)<1 then begin
    self.name:=STR_PLAYER_LOADING;
  end;
  self.id:=cl.base_IClient.ID;
  self.sace_status:=GetSACEStatus(self.id.id);

  self.chat_muted:= FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsMuted;
  self.speech_muted:= FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsSpeechMuted;
  self.votings_muted:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsPlayerVoteMuted;
  self.bps:=cl.base_IClient.stats.ci_last.dwThroughputBPS;

  self.sent_g:=cl.base_IClient.stats.ci_last.dwBytesSentGuaranteed;
  sent_ng:=cl.base_IClient.stats.ci_last.dwBytesSentNonGuaranteed;
  self.retried:= cl.base_IClient.stats.ci_last.dwBytesRetried;
  self.dropped:= cl.base_IClient.stats.ci_last.dwBytesDropped;
  self.updrate:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).updrate;
  self.game_id:=cl.ps.GameID;
  self.money:=cl.ps.money_for_round;
  self.frags:=cl.ps.m_iRivalKills;
  self.deathes:=cl.ps.m_iDeaths;
  self.selfkills:=cl.ps.m_iSelfKills;
  self.teamkills:=cl.ps.m_iTeamKills;
  self.rank:=cl.ps.rank;
  self.team:=cl.ps.team;
  self.hwid:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetHwId(false);
  self.orig_cdkey:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetOrigCdkeyHash();
  self.teamchange_blocked:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsTeamChangeBlocked();

  if self.sace_status = SACE_NOT_FOUND then begin
    self.item_color:=clRed;
    self.sace_string:='Not found';
  end else if self.sace_status = SACE_OUTDATED then begin
    self.item_color:=clYellow;
    self.sace_string:='Outdated';
  end else if self.sace_status = SACE_OK then begin
    self.item_color:=clMoneyGreen;
    self.sace_string:='Present';
  end else begin
    self.sace_string:='';
    self.item_color:=clWhite;
  end;

  case FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetForceInvincibilityStatus() of
    FZ_INVINCIBLE_DEFAULT: self.invincibility_string:='default';
    FZ_INVINCIBLE_FORCE_DISABLE: self.invincibility_string:='always off';
    FZ_INVINCIBLE_FORCE_ENABLE: self.invincibility_string:='always on';
  else
    self.invincibility_string:=INFO_INVINCIBILITY+'unknown';
  end;

end;

destructor TFZPlayerData.Destroy;
begin
  inherited;
end;

procedure TFZControlGUI.btn_clear_chatClick(Sender: TObject);
begin
  _ClearChat();
  ChatOptionsState(false);
end;

procedure TFZControlGUI.btn_inverse_chatClick(Sender: TObject);
begin
  _InverseChat();
  ChatOptionsState(false);
end;

procedure TFZControlGUI.btn_options_chatClick(Sender: TObject);
begin
  ChatOptionsState(not (btn_clear_chat.Visible or btn_inverse_chat.Visible));
end;

procedure TFZControlGUI.chatlogContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin
  Handled:=true;
end;

procedure TFZControlGUI.FormShow(Sender: TObject);
begin
  ChatOptionsState(false);
  _ActualizeChatControlsPos();
  ActRefresh.Execute;
end;

procedure TFZControlGUI.SelectOnDblClick(Sender: TObject);
var
  p:integer;
  txt:string;
begin
  txt:=(sender as TLabel).Caption;
  p:=pos(':', txt);
  if p = 0 then begin
    Clipboard.AsText:=txt;
  end else begin
    Clipboard.AsText:=trim(rightstr(txt, length(txt)-p));
  end;
end;

procedure TFZControlGUI.ListPlayersDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  dat:TFZPlayerData;
begin
  dat:= (ListPlayers.Items.Objects[Index]) as TFZPlayerData ;
  if dat=nil then exit; //как так получается???

  if odSelected in State then begin
    ListPlayers.Canvas.Brush.Color:=clHighlight;
  end else begin
    ListPlayers.Canvas.Brush.Color:=dat.item_color;
  end;
  ListPlayers.Canvas.FillRect(Rect);
  ListPlayers.Canvas.Font.Color:=clBlack;
  ListPlayers.Canvas.TextOut(Rect.Left, Rect.top, Listplayers.Items.Strings[Index] );
end;

procedure TFZControlGUI.RefreshTimerTimer(Sender: TObject);
begin
  if self.Visible and self.check_autorefresh.Checked then begin
    ActRefresh.Execute;
  end;
  RefreshChat();
  ShowScrollBar(chatlog.Handle, SB_VERT, true);
  EnableScrollBar(chatlog.Handle, SB_VERT, ESB_DISABLE_BOTH);
end;

procedure TFZControlGUI.FormCreate(Sender: TObject);
begin
  combo_options.AddItem(STR_REFRESH, FZOptionsItem.Create(ActOptDisableAll, ActRefresh) as TObject);
  combo_options.AddItem(STR_CONSOLE_CMD, FZOptionsItem.Create(ActOptCommand, ActConsoleCmd) as TObject);
  combo_options.AddItem(STR_KICK_PLAYER, FZOptionsItem.Create(ActOptReason, ActKick) as TObject);
  combo_options.AddItem(STR_MUTE_PLAYER, FZOptionsItem.Create(ActOptTime, ActMute) as TObject);
  combo_options.AddItem(STR_CHANGE_UPDRATE, FZOptionsItem.Create(ActOptValue, ActChangeUpdrate) as TObject);
  combo_options.AddItem(STR_TEST_CENSOR, FZOptionsItem.Create(ActOptInputOutput, ActCheckCensor) as TObject);
  combo_options.AddItem(STR_STOP_SERVER, FZOptionsItem.Create(ActOptDisableAll, ActStopServer) as TObject);

  combo_options.AddItem(STR_KILL_PLAYER, FZOptionsItem.Create(ActOptDisableAll, ActKill) as TObject);
  combo_options.AddItem(STR_ADD_MONEY, FZOptionsItem.Create(ActOptValue, ActMoneyAdd) as TObject);
  combo_options.AddItem(STR_SET_TEAM, FZOptionsItem.Create(ActOptValue, ActSetTeam) as TObject);
  combo_options.AddItem(STR_BLOCK_TEAMCHANGE, FZOptionsItem.Create(ActOptValue, ActBlockTeamchange) as TObject);

  combo_options.AddItem(STR_RANK_UP, FZOptionsItem.Create(ActOptDisableAll, ActRankUp) as TObject);
  combo_options.AddItem(STR_RANK_DOWN, FZOptionsItem.Create(ActOptDisableAll, ActRankDown) as TObject);
  combo_options.AddItem(STR_TELEPORT_PLAYER, FZOptionsItem.Create(ActOptPosDir, ActTeleport) as TObject);
  combo_options.AddItem(STR_INVINCIBILITY, FZOptionsItem.Create(ActOptValue, ActInvincibility) as TObject);

{$IFDEF REVO}
  combo_options.AddItem(STR_GENERATE_CDKEY, FZOptionsItem.Create(ActOptValue, ActKeyGen) as TObject);

  combo_options.AddItem(STR_TEST_SACE_CHAT, FZOptionsItem.Create(ActOptDisableAll, ActCheckSace_Chat) as TObject);
  combo_options.AddItem(STR_TEST_SACE_CHANGENAME, FZOptionsItem.Create(ActOptDisableAll, ActCheckSace_Changename) as TObject);

  combo_options.AddItem(STR_BUG_PLAYER_UPDATE, FZOptionsItem.Create(ActOptDisableAll, ActBugUpdate) as TObject);
  combo_options.AddItem(STR_BUG_PLAYER_SPAWN, FZOptionsItem.Create(ActOptDisableAll, ActBugSpawn) as TObject);
  combo_options.AddItem(STR_BUG_PLAYER_SVCONFIG, FZOptionsItem.Create(ActOptDisableAll, ActBugSvconfig) as TObject);
{$ENDIF}


  self._mousedown:=false;
  chatlog.Clear();
  RefreshChat();
  RefreshSelectedInfo();

end;

{ FZOptionsItem }

constructor FZOptionsItem.Create(prep, act: TAction);
begin
  self.form_prepare:=prep;
  self.action:=act;
end;

destructor FZOptionsItem.Destroy;
begin
  inherited;
end;

procedure TFZControlGUI.FormDestroy(Sender: TObject);
var
  i:integer;
begin
  for i:=0 to combo_options.Items.Count-1 do begin
    combo_options.Items.Objects[i].Free;
  end;
end;

procedure TFZControlGUI.combo_optionsSelect(Sender: TObject);
begin
  (combo_options.Items.Objects[combo_options.ItemIndex] as FZOptionsItem).form_prepare.Execute;
end;

procedure TFZControlGUI.btn_okClick(Sender: TObject);
begin
  if combo_options.ItemIndex>=0 then begin
    (combo_options.Items.Objects[combo_options.ItemIndex] as FZOptionsItem).action.Execute;
  end;
end;

procedure TFZControlGUI.ListPlayersClick(Sender: TObject);
begin
  RefreshSelectedInfo();
end;

procedure TFZControlGUI.ActClosePanelExecute(Sender: TObject);
begin
  self.Close;
end;

procedure TFZControlGUI.FormMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  self._mousedown:=true;
  GetCursorPos(_mousepoint);
end;

procedure TFZControlGUI.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  self._mousedown:=false;
end;

procedure TFZControlGUI.FormMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  newpoint:TPoint;
  dx, dy:integer;
begin
  if _mousedown then begin
    GetCursorPos(newpoint);
    dx:=newpoint.X-_mousepoint.X;
    dy:=newpoint.Y-_mousepoint.Y;
    self.Top:=self.Top+dy;
    self.Left:=self.Left+dx;
    _mousepoint:=newpoint;
  end;
end;

procedure TFZControlGUI.btn_closeClick(Sender: TObject);
begin
  ActClosePanel.Execute();
end;

procedure TFZControlGUI.check_autorefreshClick(Sender: TObject);
begin
  ActRefresh.Execute();
end;

procedure TFZControlGUI.btn_minimizeClick(Sender: TObject);
begin
  PostMessage(Handle,WM_SYSCOMMAND, SC_MINIMIZE, 1);
end;

procedure TFZControlGUI.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
  if key = chr(13) then begin
    btn_ok.Click;
  end;
end;

procedure TFZControlGUI.btn_sendmsgClick(Sender: TObject);
var
  astr:AnsiString;
begin
  if length(edit_chatmsg.Text)>0 then begin
    astr:=UTF8ToWinCP('chat '+edit_chatmsg.Text);
    ExecuteConsoleCommand(PAnsiChar(astr));
    edit_chatmsg.Text:='';
    RefreshChat();
  end;
end;

procedure TFZControlGUI.edit_chatmsgKeyPress(Sender: TObject;
  var Key: Char);
begin
  if key = chr(13) then begin
    btn_sendmsg.Click;
  end;
end;

procedure TFZControlGUI.TrackChatChange(Sender: TObject);
begin
  RefreshChat();
end;

//******************************** Actions for preparing editboxes when combobox item changing *************************************
procedure TFZControlGUI.ActOptDisableAllExecute(Sender: TObject);
begin
  label1.Visible:=false;
  label2.Visible:=false;
  edit1.Visible:=false;
  edit2.Visible:=false;
end;

procedure TFZControlGUI.ActOptTimeReasonExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=true;
  edit1.Visible:=true;
  edit2.Visible:=true;
  label1.Caption:=STR_TIME;
  label2.Caption:=STR_REASON;
  edit1.Text:='0';
  edit2.Text:='';
end;

procedure TFZControlGUI.ActOptReasonExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=false;
  edit1.Visible:=true;
  edit2.Visible:=false;
  label1.Caption:=STR_REASON;
  edit1.Text:='';
end;

procedure TFZControlGUI.ActOptTimeExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=false;
  edit1.Visible:=true;
  edit2.Visible:=false;
  label1.Caption:=STR_TIME;
  edit1.Text:='0';
end;

procedure TFZControlGUI.ActOptValueExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=false;
  edit1.Visible:=true;
  edit2.Visible:=false;
  label1.Caption:=STR_VALUE;
  edit1.Text:='0';
end;

procedure TFZControlGUI.ActOptInputOutputExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=true;
  edit1.Visible:=true;
  edit2.Visible:=true;
  label1.Caption:=STR_INPUT;
  label2.Caption:=STR_OUTPUT;
  edit1.Text:='';
  edit2.Text:='';
end;

procedure TFZControlGUI.ActOptPosDirExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=true;
  edit1.Visible:=true;
  edit2.Visible:=true;
  label1.Caption:=STR_POS;
  label2.Caption:=STR_DIR;
  edit1.Text:='0,0,0';
  edit2.Text:='0,1,0';
end;

procedure TFZControlGUI.ActOptCommandExecute(Sender: TObject);
begin
  label1.Visible:=true;
  label2.Visible:=false;
  edit1.Visible:=true;
  edit2.Visible:=false;
  label1.Caption:=STR_COMMAND;
  edit1.Text:='';
end;

//////////////////////////////////// Actions from combobox ////////////////////////////////////////////////////

//************************************** Common actions ******************************************************
procedure TFZControlGUI.ActConsoleCmdExecute(Sender: TObject);
var
  str:AnsiString;
begin
  str:=UTF8ToWinCP(Edit1.Text);
  if length(str)>0 then begin
    AddAdminCommandToQueue(FZSimpleConsoleCmd.Create(str, FZConsoleReporter.Create(0)));
  end;
end;
procedure TFZControlGUI.ActStopServerExecute(Sender: TObject);
begin
  if MessageBox(self.Handle, STR_REALLY_STOP_SERVER, '', MB_YESNO+MB_ICONQUESTION)=IDYES then begin
    AddAdminCommandToQueue(FZSimpleConsoleCmd.Create('quit', FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActRefreshExecute(Sender: TObject);
var
  last_id:cardinal;
  i:integer;
begin
  if not self.Visible then begin
    exit;
  end;

  if (ListPlayers.Count>0) and  (self.ListPlayers.ItemIndex>=0) then begin
    last_id:= (self.ListPlayers.Items.Objects[self.ListPlayers.ItemIndex] as TFZPlayerData).id.id;
  end else begin
    last_id:=$FFFFFFFF;
  end;

  _ClearListPlayers();
  ForEachClientDo(ProcessAddPlayerToListQuery);

  self.ListPlayers.ItemIndex:=ListPlayers.Count-1;

  //восстановим выделение, если оно было и игрок тут
  if last_id<>$FFFFFFFF then begin
    for i:=0 to ListPlayers.Count-1 do begin
      if (self.ListPlayers.Items.Objects[i] as TFZPlayerData).id.id=last_id then begin
        self.ListPlayers.ItemIndex:=i;
        break;
      end;
    end;
  end;
  RefreshSelectedInfo();
end;

procedure TFZControlGUI.ActCheckCensorExecute(Sender: TObject);
var
  str:AnsiString;
begin
  str:=UTF8ToWinCP(edit1.Text);
  if str<>'' then begin
    edit2.Text:=booltostr(FZCensor.Get.CheckAndCensorString(PAnsiChar(str), false, ''), true);
  end;
end;

//************************************************ Actions with players ****************************************
procedure TFZControlGUI.ActBanExecute(Sender: TObject);
begin
//TODO: implement
end;

procedure TFZControlGUI.ActRankDownExecute(Sender: TObject);
begin
  if ListPlayers.ItemIndex>=0 then begin
    AddAdminCommandToQueue(FZAdminRankChangeCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, -1, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActRankUpExecute(Sender: TObject);
begin
  if ListPlayers.ItemIndex>=0 then begin
    AddAdminCommandToQueue(FZAdminRankChangeCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, 1, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActKillExecute(Sender: TObject);
begin
  if ListPlayers.ItemIndex>=0 then begin
    AddAdminCommandToQueue(FZAdminKillPlayerCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActKickExecute(Sender: TObject);
var
  reason:string;
begin
  if ListPlayers.ItemIndex>=0 then begin
    reason:=UTF8ToWinCP(edit1.Text);
    AddAdminCommandToQueue(FZAdminKickPlayerCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, reason, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActKeyGenExecute(Sender: TObject);
begin
  edit1.Text:=GenerateRandomKey(true);
end;

procedure TFZControlGUI.ActMuteExecute(Sender: TObject);
var
  time:integer;
begin
  if (ListPlayers.ItemIndex>=0) and (length(edit1.text)>0) then begin
    time:=strtointdef(edit1.text, 0);
    AddAdminCommandToQueue(FZAdminMutePlayerCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, time, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActMoneyAddExecute(Sender: TObject);
var
  cnt:integer;
begin
  if ListPlayers.ItemIndex>=0 then begin
    cnt:=strtointdef(edit1.Text, 0);
    if cnt<>0 then begin
      AddAdminCommandToQueue(FZAdminAddMoneyCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, cnt, FZConsoleReporter.Create(0)));
    end;
  end;
end;

procedure TFZControlGUI.ActSetTeamExecute(Sender: TObject);
var
  team:integer;
begin
  if ListPlayers.ItemIndex>=0 then begin
    team:=strtointdef(edit1.Text, 0);
    if team<>0 then begin
      AddAdminCommandToQueue(FZAdminChangeTeamCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, team, false, FZConsoleReporter.Create(0)));
    end;
  end;
end;

procedure TFZControlGUI.ActBlockTeamchangeExecute(Sender: TObject);
var
  time:integer;
begin
  if ListPlayers.ItemIndex>=0 then begin
    time:=strtointdef(edit1.Text, 0);
    if time<>0 then begin
      AddAdminCommandToQueue(FZAdminBlockChangeTeamCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, time, false, FZConsoleReporter.Create(0)));
    end;
  end;
end;

procedure TFZControlGUI.ActInvincibilityExecute(Sender: TObject);
var
  status:integer;
begin
  if ListPlayers.ItemIndex>=0 then begin
    status:=strtointdef(edit1.Text, -10);
    if status<>-10 then begin
      AddAdminCommandToQueue(FZAdminForceInvincibilityCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, status, false, FZConsoleReporter.Create(0)));
    end;
  end;
end;

procedure TFZControlGUI.ActChangeUpdrateExecute(Sender: TObject);
var
  val:cardinal;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    val:=strtointdef(edit1.Text, 0);
    AddAdminCommandToQueue(FZAdminSetUpdrateCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, val, FZConsoleReporter.Create(0)));
  end;
end;

procedure TFZControlGUI.ActTeleportExecute(Sender: TObject);
var
  vp, vd:FVector3;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    v_zero(@vp);
    v_zero(@vd);
    if StringToFVector3(edit1.Text, vp) and StringToFVector3(edit2.Text, vd) then begin
      AddAdminCommandToQueue(FZAdminTeleportPlayerCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, vp, vd, FZConsoleReporter.Create(0)));
    end else begin
      FZLogMgr.Get.Write('Cannot parse coordinates!', FZ_LOG_ERROR);
    end;
  end;
end;

//************************************************************ SACE checking actions **************************************
procedure TFZControlGUI.ActCheckSACE_ChatExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
    CreateBrokenSaceChatMessage(cmd.GetPacket());
    AddAdminCommandToQueue(cmd);
  end;
end;

procedure TFZControlGUI.ActCheckSACE_ChangenameExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
    CreateBrokenChangeNamePacket(cmd.GetPacket());
    AddAdminCommandToQueue(cmd);
  end;
end;

//*************************************************************'Bugs' actions**********************************************
procedure TFZControlGUI.ActBugUpdateExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
    CreateBrokenUpdatePacket(cmd.GetPacket(), (ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id);
    AddAdminCommandToQueue(cmd);
  end;
end;

procedure TFZControlGUI.ActBugSpawnExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
    CreateBrokenSpawnPacket(cmd.GetPacket());
    AddAdminCommandToQueue(cmd);
  end;
end;

procedure TFZControlGUI.ActBugSvconfigExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
    CreateBrokenSVConfigGamePacket(cmd.GetPacket());
    AddAdminCommandToQueue(cmd);
  end;
end;

procedure TFZControlGUI.ActBugMoveExecute(Sender: TObject);
var
  cmd:FZAdminPacketSenderCommand;
  cl_d:pxrClientData;
begin
  if (ListPlayers.ItemIndex>=0) then begin
    cl_d:=ID_to_client((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id);
    if cl_d <> nil then begin
      cmd:=FZAdminPacketSenderCommand.Create((ListPlayers.Items.Objects[ListPlayers.ItemIndex] as TFZPlayerData).id.id, FZConsoleReporter.Create(0));
      CreateBrokenMovePlayersPacket(cmd.GetPacket(), cl_d.ps.GameID);
      AddAdminCommandToQueue(cmd);
    end;
  end;
end;

end.
