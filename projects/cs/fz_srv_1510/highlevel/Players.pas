unit Players;
{$mode delphi}
interface
uses Clients, windows, Servers,PureServer,MatVectors,Packets, xrstrings, Games, Vector,InventoryItems, CSE;

type

FZPlayerInvincibleStatus = (
                              FZ_INVINCIBLE_DEFAULT, //Состояние по умолчанию - определяется игрой;
                              FZ_INVINCIBLE_FORCE_ENABLE, //Форсировать включение
                              FZ_INVINCIBLE_FORCE_DISABLE //форсировать выключение
                           );

{ FZPlayerStateAdditionalInfo }

FZPlayerStateAdditionalInfo = class
protected
  _lock:TRtlCriticalSection;
  _valid:boolean;
  _connected_and_ready:boolean;

  _mute_start_time:cardinal;
  _mute_time_period:cardinal;

  _votes_mute_start_time:cardinal;
  _votes_mute_time_period:cardinal;
  _last_started_voted_time:cardinal;
  _last_vote_time:cardinal;
  _last_vote_series:cardinal;
  _votemutes_count:cardinal;
  _last_chat_message_time:cardinal;
  _chat_messages_series:cardinal;
  _chatmutes_count:cardinal;

  _last_speech_message_time:cardinal;
  _speech_messages_series:cardinal;
  _speechmutes_count:cardinal;
  _speechmute_start_time:cardinal;
  _speechmute_time_period:cardinal;

  _teamchangeblock_start_time:cardinal;
  _teamchangeblock_time_period:cardinal;

  _badwords_counter:cardinal;

  _my_player:pgame_PlayerState;
  _updrate:cardinal;

  _last_ready_time:cardinal;

  _last_ping_warning_time:cardinal;

  _slots_block_counter:cardinal;

  _hwid:string;
  _hwhash:string;
  _orig_cdkey_hash:string;
  _hwid_received:boolean;

  _force_invincibility_cur:FZPlayerInvincibleStatus;
  _force_invincibility_next:FZPlayerInvincibleStatus;

  {%H-}constructor Create(ps:pgame_PlayerState);
public
  procedure SetUpdrate(d:cardinal);
  procedure SetHwId(hwid:string; hwhash:string);
  function GetHwId(allow_old:boolean):string;
  function GetHwHash(allow_old:boolean):string;
  procedure SetOrigCdkeyHash(hash:string);
  function GetOrigCdkeyHash():string;

  function GetHwhashSaceStatus():integer;

  property updrate:cardinal read _updrate write SetUpdrate;
  property last_ready:cardinal read _last_ready_time write _last_ready_time;
  property valid:boolean read _valid write _valid;
  property connected_and_ready: boolean read _connected_and_ready write _connected_and_ready;

  function IsAllowedStartingVoting():boolean;
  procedure OnVoteStarted();
  procedure OnVote();
  function IsPlayerVoteMuted():boolean;
  procedure AssignVoteMute(time:cardinal);
  procedure AssignSpeechMute(time:cardinal);

  procedure OnDisconnected();

  function GetForceInvincibilityStatus():FZPlayerInvincibleStatus;
  function SetForceInvincibilityStatus(status:FZPlayerInvincibleStatus):boolean;
  function UpdateForceInvincibilityStatus():FZPlayerInvincibleStatus;

  function IsMuted():boolean;
  procedure UnMute();
  procedure AssignMute(time:cardinal);

  function IsSpeechMuted():boolean;

  function OnChatMessage():cardinal;
  function OnSpeechMessage():cardinal;

  function IsTeamChangeBlocked():boolean;
  procedure BlockTeamChange(time:cardinal);
  procedure UnBlockTeamChange();
  function OnTeamChange():boolean;

  function SlotsBlockCount(delta:integer = 0):cardinal;
  procedure ResetSlotsBlockCount();

  function OnBadWordsInChat():cardinal;
  destructor Destroy; override;
end;
//pFZPlayerStateAdditionalInfo=^FZPlayerStateAdditionalInfo;

procedure FromPlayerStateConstructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateDestructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateClear({%H-}ps:pgame_PlayerState); stdcall;


procedure DisconnectPlayer(cl:pIClient; reason:string); stdcall;
function MutePlayer(cl: pxrClientData; time:cardinal):boolean; stdcall;
function UnMutePlayer(cl: pxrClientData):boolean; stdcall;
function BlockPlayerTeamChange(cl: pxrClientData; time:cardinal):boolean; stdcall;
function UnBlockPlayerTeamChange(cl: pxrClientData): boolean; stdcall;
function IsPlayerTeamChangeBlocked(cl: pxrClientData): boolean; stdcall;
procedure SetUpdRate(cl: pxrClientData; updrate:cardinal); stdcall;
procedure KillPlayer(cl: pxrClientData); stdcall;
procedure AddMoney(cl: pxrClientData; amount:integer); stdcall;
function ChangePlayerRank(cl: pxrClientData; delta:integer):boolean; stdcall;
function IsSlotsBlocked(cl: pxrClientData): boolean; stdcall;
function GetForceInvincibilityStatus(cl: pxrClientData): FZPlayerInvincibleStatus; stdcall;
function SetForceInvincibilityStatus(cl: pxrClientData; status:FZPlayerInvincibleStatus):boolean;
function UpdateForceInvincibilityStatus(cl: pxrClientData):FZPlayerInvincibleStatus; //переключить на следующее состояние, вернуть его

procedure SetHwId(cl: pxrClientData; hwid: string; hwhash:string); stdcall;
function GetHwId(cl: pxrClientData; allow_old:boolean): string; stdcall;
function GetHwHash(cl: pxrClientData; allow_old:boolean): string; stdcall;
procedure SetOrigCdkeyHash(cl: pxrClientData; hash:string);
function GetOrigCdkeyHash(cl: pxrClientData):string;


procedure modify_player_name (name:PChar; new_name:PChar); stdcall;
procedure CheckClientConnectData(data:pSClientConnectData); stdcall;
procedure CheckClientConnectionName(str: PAnsiChar; msg: pDPNMSG_CREATE_PLAYER); stdcall;

function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;
function OnPingWarn(cl:pxrClientData):boolean; stdcall;

function CanChangeName(client:pxrClientData):boolean; stdcall;

procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;
procedure OnClientReady({%H-}srv:pIPureServer; cl:pxrClientData); stdcall;

function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;
procedure xrServer__OnCL_Disconnected_appendToPacket({%H-}p:pNET_Packet; pname:ppshared_str; cl:pxrClientData); stdcall;
function game_sv_mp__OnPlayerDisconnect_is_message_needed(name:PAnsiChar):boolean; stdcall;

function SendTeleportPlayerPacket(client:pxrClientData; pos:pFVector3; dir:pFVector3):boolean; stdcall;

function BeforeSpawnBoughtItems_DM(ps:pgame_PlayerState; game:pgame_sv_Deathmatch):boolean; stdcall;
function BeforeSpawnBoughtItems_CTA(ps:pgame_PlayerState; game:pgame_sv_CaptureTheArtefact):boolean; stdcall;
procedure DestroyAllItemsFromPlayersInventoryDeforeBuying(game:pgame_sv_mp; client_id:cardinal); stdcall;
function CanPlayerBuyNow(cl:pxrClientData):boolean;stdcall;
function IsSpawnFreeAmmoAllowedForGametype(game:pgame_sv_mp):boolean; stdcall;

function GenerateMessageForClientId(id:cardinal; message: string):string;

function IsWeaponKnife(item:pCSE_Abstract):boolean;stdcall;

procedure UpdatePlayer(cld:pxrClientData);

//function CheckPlayerInvincible(ps:pgame_PlayerState; onshot:cardinal):boolean; stdcall;

function IsInvincibilityControlledByFZ(ps:pgame_PlayerState):boolean; stdcall;
function IsInvinciblePersistAfterShot(ps:pgame_PlayerState):boolean; stdcall;

implementation
uses LogMgr, sysutils, srcBase, Level, CommonHelper, dynamic_caster, basedefs, ConfigCache, TranslationMgr, Chat, sysmsgs, DownloadMgr, Synchro, ServerStuff, MapList, Censor, BuyWnd, Weapons, xr_configs, HackProcessor, Objects, Device, NET_Common, PureClient, ItemsCfgMgr, BaseClasses, BasicProtection, xr_debug, Banned, xr_time, SACE_interface, whitehashes, TeleportMgr;

const
  SHOP_GROUP = '[SHOP] ';

procedure SetHwId(cl: pxrClientData; hwid: string; hwhash:string); stdcall;
begin
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).SetHwId(hwid, hwhash);
end;

function GetHwId(cl: pxrClientData; allow_old: boolean): string; stdcall;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetHwId(allow_old);
end;

function GetHwHash(cl: pxrClientData; allow_old: boolean): string; stdcall;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetHwHash(allow_old);
end;

procedure SetOrigCdkeyHash(cl: pxrClientData; hash: string);
begin
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).SetOrigCdkeyHash(hash);
end;

function GetOrigCdkeyHash(cl: pxrClientData): string;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetOrigCdkeyHash();
end;

procedure modify_player_name (name:PChar; new_name:PChar); stdcall;
const
  allowed_symbols:string = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_[]';
  russian_symbols:string = 'абвгдеёжзийклмнпопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ';
  max_len:integer=20;
var
  i:integer;
  cfg:FZCacheData;
begin
  cfg:=FZConfigCache.Get.GetDataCopy();
  if cfg.censor_names and FZCensor.Get().CheckAndCensorString(name, false, 'Name censored:' ) then begin
    strcopy(new_name, 'BadName');
    exit;
  end;

  i:=0;
  while (i<max_len) and (name[i]<>chr(0)) do begin
    if (pos(name[i], allowed_symbols)<>0) or (cfg.allow_russian_nicknames and (pos(name[i], russian_symbols) <> 0)) then begin
      new_name[i]:=name[i];
    end else begin
    //пробуем исправить русские буквы на англ
      new_name[i]:=FZCommonHelper.GetEnglishCharFromRussian(name[i]);
    end;
    i:=i+1;
  end;
  if length(name)>0 then begin
    //[bug] Делаем первый символ заглавным - чтобы в клиентском окне старта голосований не срабатывал на имена стандартный сталкерский транслятор строк
    new_name[0]:=FZCommonHelper.GetEnglishUppercaseChar(new_name[0]);
  end;
  new_name[i]:=chr(0);
end;

procedure CheckClientConnectData(data:pSClientConnectData); stdcall;
begin
  CheckIfPCharZStringIsLesserThan(@data.name[0], length(data.name), data.clientID, true, $FF, true);
  CheckIfPCharZStringIsLesserThan(@data.pass[0], length(data.pass), data.clientID, true, $FF, true);
end;

procedure CheckClientConnectionName(str: PAnsiChar; msg: pDPNMSG_CREATE_PLAYER); stdcall;
var
  clid:ClientID;
  addr:ip_address;
  port:dword;
const
  BUF_SZ:cardinal=64;
begin
  clid.id:=0;
  if not CheckIfPCharZStringIsLesserThan(str, BUF_SZ, clid, false, $FF, false) then begin
    str[BUF_SZ-1]:=chr(0);
    if GetClientAddress(GetPureServer(), msg.dpnidPlayer, @addr, @port) then begin
      BadEventsProcessor(FZ_SEC_EVENT_ATTACK, 'Player (ID='+inttostr(msg.dpnidPlayer)+', IP='+ip_address_to_str(addr)+') sent too long nickname');
    end;
  end;
end;

function ChangePlayerRank(cl: pxrClientData; delta: integer): boolean; stdcall;
var
  newrank:integer;
begin
  result:=false;
  if cl.ps = nil then exit;

  newrank:=cl.ps.rank+delta;
  if (newrank >= 0) and (newrank < integer(_RANK_COUNT)) then begin
    cl.ps.rank:=byte(newrank);
    game_signal_Syncronize();
    result:=true;
  end;
end;

function IsSlotsBlocked(cl: pxrClientData): boolean; stdcall;
begin
  result:=true;
  if cl.ps = nil then exit;

  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).SlotsBlockCount() > 0;
end;

function GetForceInvincibilityStatus(cl: pxrClientData): FZPlayerInvincibleStatus; stdcall;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetForceInvincibilityStatus();
end;

function SetForceInvincibilityStatus(cl: pxrClientData; status: FZPlayerInvincibleStatus): boolean;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).SetForceInvincibilityStatus(status);
end;

function UpdateForceInvincibilityStatus(cl: pxrClientData):FZPlayerInvincibleStatus;
begin
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).UpdateForceInvincibilityStatus();
end;

function IsPlayerTeamChangeBlocked(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil', 'IsPlayerTeamChangeBlocked');
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsTeamChangeBlocked();
end;

procedure SetUpdRate(cl: pxrClientData; updrate: cardinal); stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil', 'SetUpdRate');
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).updrate:=updrate;
end;

function UnMutePlayer(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'UnMutePlayer');
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsMuted();

  if result then begin
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).UnMute();
  end;
end;

function MutePlayer(cl: pxrClientData; time: cardinal): boolean; stdcall;
var
  newtime:int64;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'MutePlayer');

  result:=false;
  if time>0 then begin
    newtime:= int64(time) * MSecsPerSec;
    if newtime > $FFFFFFFF then begin
      time:=$FFFFFFFF;
    end else begin
      time:=cardinal(newtime);
    end;
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).AssignMute(time);
    result:=true;
  end;
end;

function UnBlockPlayerTeamChange(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'UnBlockPlayerTeamChange');
  result:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).IsTeamChangeBlocked();

  if result then begin
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).UnBlockTeamChange();
  end;
end;

function BlockPlayerTeamChange(cl: pxrClientData; time: cardinal): boolean; stdcall;
var
  newtime:int64;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'BlockPlayerTeamChange');

  result:=false;
  if time>0 then begin
    newtime:= int64(time) * MSecsPerSec;
    if newtime > $FFFFFFFF then begin
      time:=$FFFFFFFF;
    end else begin
      time:=cardinal(newtime);
    end;
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).BlockTeamChange(time);
    result:=true;
  end;
end;

procedure KillPlayer(cl: pxrClientData); stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'KillPlayer');
  game_KillPlayer(GetCurrentGame(), cl.base_IClient.ID.id, cl.ps.GameID);
end;

procedure AddMoney(cl: pxrClientData; amount: integer); stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'AddMoney');
  game_PlayerAddMoney(GetCurrentGame(), cl.ps, amount);
end;

procedure DisconnectPlayer(cl: pIClient; reason: string); stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'DisconnectPlayer');
  IPureServer__DisconnectClient(GetPureServer(), cl, PAnsiChar(reason));
end;

{ FZPlayerStateAdditionalInfo }

procedure FZPlayerStateAdditionalInfo.AssignMute(time: cardinal);
var
  new_period:cardinal;
begin
  EnterCriticalSection(_lock);
  try
    if not IsMuted() then begin
      self._mute_start_time:=FZCommonHelper.GetGameTickCount();
      self._mute_time_period:=0;
    end;

    new_period:=self._mute_time_period+time;

    if new_period<self._mute_time_period then begin
      self._mute_time_period:=$FFFFFFFF;
    end else begin;
      self._mute_time_period:=new_period
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;


procedure FZPlayerStateAdditionalInfo.AssignSpeechMute(time: cardinal);
var
  new_period:cardinal;
begin
  EnterCriticalSection(_lock);
  try
    if not IsSpeechMuted() then begin
      self._speechmute_start_time:=FZCommonHelper.GetGameTickCount();
      self._speechmute_time_period:=0;
    end;

    new_period:=self._speechmute_time_period+time;

    if new_period<self._speechmute_time_period then begin
      self._speechmute_time_period:=$FFFFFFFF;
    end else begin;
      self._speechmute_time_period:=new_period
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.OnDisconnected();
begin
  self._connected_and_ready:=false;
  self._hwid_received:=false;
end;

function FZPlayerStateAdditionalInfo.GetForceInvincibilityStatus(): FZPlayerInvincibleStatus;
begin
  result:=_force_invincibility_cur;
end;

function FZPlayerStateAdditionalInfo.SetForceInvincibilityStatus(status: FZPlayerInvincibleStatus):boolean;
begin
  result:=(_force_invincibility_cur<>status);
  if result then _force_invincibility_next:=status;
end;

function FZPlayerStateAdditionalInfo.UpdateForceInvincibilityStatus(): FZPlayerInvincibleStatus;
begin
  result:=_force_invincibility_next;
  _force_invincibility_cur:=_force_invincibility_next;
end;

procedure FZPlayerStateAdditionalInfo.AssignVoteMute(time: cardinal);
var
  new_period:cardinal;
begin
  EnterCriticalSection(_lock);
  try
    if not IsPlayerVoteMuted() then begin
      self._votes_mute_start_time:=FZCommonHelper.GetGameTickCount();
      self._votes_mute_time_period:=0;
    end;

    new_period:=self._votes_mute_time_period+time;

    if new_period<self._votes_mute_time_period then begin
      self._votes_mute_time_period:=$FFFFFFFF;
    end else begin;
      self._votes_mute_time_period:=new_period
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

constructor FZPlayerStateAdditionalInfo.Create(ps:pgame_PlayerState);
begin
  srcKit.Get.DbgLog('New buffer, '+inttohex(cardinal(self),8));
  InitializeCriticalSection(_lock);
  _valid:=false;
  _connected_and_ready:=false;
  _mute_start_time:=0;
  _mute_time_period:=0;
  _my_player:=ps;
  _last_started_voted_time:=0;
  _votes_mute_start_time:=0;
  _votes_mute_time_period:=0;
  _last_vote_time:=0;
  _last_vote_series:=0;
  _votemutes_count:=0;
  _badwords_counter:=0;
  _last_chat_message_time:=0;
  _chat_messages_series:=0;
  _chatmutes_count:=0;

  _last_speech_message_time:=0;
  _speech_messages_series:=0;
  _speechmutes_count:=0;
  _speechmute_start_time:=0;
  _speechmute_time_period:=0;

  _teamchangeblock_start_time:=0;
  _teamchangeblock_time_period:=0;
  _slots_block_counter:=0;

  _updrate:=0;
  _last_ready_time:=0;
  _last_ping_warning_time:=0;

  _hwid:='';
  _hwhash:='';
  _orig_cdkey_hash:='';
  _hwid_received:=false;

  _force_invincibility_cur:=FZ_INVINCIBLE_DEFAULT;
  _force_invincibility_next:=FZ_INVINCIBLE_DEFAULT;
end;

destructor FZPlayerStateAdditionalInfo.Destroy;
begin
  inherited;
  srcKit.Get.DbgLog('Del buffer, '+inttohex(cardinal(self),8));
  DeleteCriticalSection(_lock);
end;

procedure FromPlayerStateClear(ps:pgame_PlayerState); stdcall;
begin
end;

procedure FromPlayerStateConstructor(ps:pgame_PlayerState); stdcall;
begin
  ps.FZBuffer:=FZPlayerStateAdditionalInfo.Create(ps);
end;

procedure FromPlayerStateDestructor(ps:pgame_PlayerState); stdcall;
begin
  FZPlayerStateAdditionalInfo(ps.FZBuffer).Free;
end;

function FZPlayerStateAdditionalInfo.IsAllowedStartingVoting(): boolean;
begin
  EnterCriticalSection(_lock);
  try
    if IsPlayerVoteMuted then begin
      //Если игроку запрещено даже просто голосовать - то и про способность начать голосование можно забыть
      result:=false;
    end else begin
      //если игрок один на сервере - пусть делает, что хочет
      result:= (CurPlayersCount()<=2) or (self._last_started_voted_time=0) or (FZConfigCache.Get.GetDataCopy.vote_mute_time_ms=0) or (FZCommonHelper.GetTimeDeltaSafe(self._last_started_voted_time)>=FZConfigCache.Get.GetDataCopy.vote_mute_time_ms);
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsMuted(): boolean;
begin
  EnterCriticalSection(_lock);
  try
    if self._mute_time_period = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._mute_start_time)<self._mute_time_period;
      if not result then begin
        FZLogMgr.Get.Write('Chat mute of player '+PChar(@self._my_player.name)+' is expired.', FZ_LOG_IMPORTANT_INFO);
        self._mute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsPlayerVoteMuted(): boolean;
begin
  EnterCriticalSection(_lock);
  try
    if self._votes_mute_time_period = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._votes_mute_start_time)<self._votes_mute_time_period;
      if not result then begin
        FZLogMgr.Get.Write('Vote mute of player '+PChar(@self._my_player.name)+' is expired.', FZ_LOG_IMPORTANT_INFO);
        self._votes_mute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsTeamChangeBlocked(): boolean;
begin
  EnterCriticalSection(_lock);
  try
    if self._teamchangeblock_start_time = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._teamchangeblock_start_time)<self._teamchangeblock_time_period;
      if not result then begin
        self._teamchangeblock_start_time:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.BlockTeamChange(time: cardinal);
var
  new_period:cardinal;
begin
  EnterCriticalSection(_lock);
  try
    if not IsTeamChangeBlocked() then begin
      self._teamchangeblock_start_time:=FZCommonHelper.GetGameTickCount();
      self._teamchangeblock_time_period:=0;
    end;

    new_period:=self._teamchangeblock_time_period+time;

    if new_period<self._teamchangeblock_time_period then begin
      self._teamchangeblock_time_period:=$FFFFFFFF;
    end else begin;
      self._teamchangeblock_time_period:=new_period
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.UnBlockTeamChange();
begin
  EnterCriticalSection(_lock);
  try
    self._teamchangeblock_start_time:=0;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnTeamChange(): boolean;
var
  _data:FZCacheData;
begin
  _data:=FZConfigCache.Get.GetDataCopy();
  result:=false;
  EnterCriticalSection(_lock);
  try
    result:=not IsTeamChangeBlocked();
    if result and (_data.teamchange_minimal_period > 0) then begin
      BlockTeamChange(_data.teamchange_minimal_period);
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.SlotsBlockCount(delta: integer):cardinal;
begin
  EnterCriticalSection(_lock);
  try
    if (delta < 0) and ((-1)*delta > _slots_block_counter) then begin
      _slots_block_counter:=0;
    end else if ( _slots_block_counter > $FFFFFFFF - delta) then begin
      _slots_block_counter:=$FFFFFFFF;
    end else begin
      _slots_block_counter:=_slots_block_counter+delta;
    end;
    result:=_slots_block_counter;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.ResetSlotsBlockCount();
begin
  _slots_block_counter:=0;
end;

function FZPlayerStateAdditionalInfo.IsSpeechMuted(): boolean;
begin
  if IsMuted then begin
    result:=true;
    exit;
  end;
  EnterCriticalSection(_lock);
  try
    if self._speechmute_time_period = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._speechmute_start_time)<self._speechmute_time_period;
      if not result then begin
        FZLogMgr.Get.Write('Speech mute of player '+PChar(@self._my_player.name)+' is expired.', FZ_LOG_IMPORTANT_INFO);
        self._speechmute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnBadWordsInChat(): cardinal;
begin
  EnterCriticalSection(_lock);
  try
    self._badwords_counter:=self._badwords_counter+1;
    if FZConfigCache.Get.GetDataCopy.chat_badwords_treasure<self._badwords_counter then begin
      result:=FZConfigCache.Get.GetDataCopy.mutetime_per_badword*self._badwords_counter;
      AssignMute(result);
    end else begin
      result:=0;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnChatMessage(): cardinal;
var
  _data:FZCacheData;
begin
  _data:=FZConfigCache.Get.GetDataCopy();
  result:=0;
  EnterCriticalSection(_lock);
  try
    if not IsMuted() and (_data.chat_series_for_mute<>0) and  (_data.chat_series_interval<>0) then begin
      if (self._last_chat_message_time=0) or (FZCommonHelper.GetTimeDeltaSafe(self._last_chat_message_time)>_data.chat_series_interval) then begin
        self._chat_messages_series:=0;
      end;
      self._chat_messages_series:=self._chat_messages_series+1;
      if self._chat_messages_series>_data.chat_series_for_mute then begin
        self._chatmutes_count:=self._chatmutes_count+1;
        result:=self._chatmutes_count*_data.chat_mute_time;
        AssignMute(result);
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' chat muted for '+inttostr(_chatmutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
      end;
    end;
    self._last_chat_message_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnSpeechMessage(): cardinal;
var
  _data:FZCacheData;
begin
  _data:=FZConfigCache.Get.GetDataCopy();
  result:=0;
  EnterCriticalSection(_lock);
  try
    if not IsSpeechMuted() and (_data.speech_series_for_mute<>0) and  (_data.speech_series_interval<>0) then begin
      if (self._last_speech_message_time=0) or (FZCommonHelper.GetTimeDeltaSafe(self._last_speech_message_time)>_data.speech_series_interval) then begin
        self._speech_messages_series:=0;
      end;
      self._speech_messages_series:=self._speech_messages_series+1;
      if self._speech_messages_series>_data.speech_series_for_mute then begin
        self._speechmutes_count:=self._speechmutes_count+1;
        result:=self._speechmutes_count*_data.speech_mute_time;
        AssignSpeechMute(result);
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' speech messages muted for '+inttostr(_speechmutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
      end;
    end;
    self._last_speech_message_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.OnVote();
var
  _data:FZCacheData;
begin
  _data:=FZConfigCache.Get.GetDataCopy();

  EnterCriticalSection(_lock);
  try
    if not IsPlayerVoteMuted() and (_data.vote_series_for_mute <> 0) and (_data.vote_mute_interval<>0) then begin
      //защита от злоупотребений включена!
      if (self._last_vote_time=0) or (FZCommonHelper.GetTimeDeltaSafe(self._last_vote_time)>_data.vote_mute_interval) then begin
        self._last_vote_series:=0;
      end;
      self._last_vote_series:=self._last_vote_series+1;
      if self._last_vote_series>_data.vote_series_for_mute then begin
        //Добби должен быть наказан...
        _votemutes_count:=_votemutes_count+1;
        AssignVoteMute(_votemutes_count*_data.vote_first_mute_time);
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' votes muted for '+inttostr(_votemutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
      end;
    end;

    self._last_vote_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.OnVoteStarted();
begin
  EnterCriticalSection(_lock);
  try
    self._last_started_voted_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;



procedure FZPlayerStateAdditionalInfo.SetUpdrate(d: cardinal);
begin
  if (d=0) then d:=1;
  if d>1000 then d:=1000;
  self._updrate:=d;
end;

procedure FZPlayerStateAdditionalInfo.SetHwId(hwid: string; hwhash:string);
begin
  if not _hwid_received then begin
    self._hwid:=hwid;
    self._hwhash:=hwhash;
    self._hwid_received:=true;
  end;
end;

function FZPlayerStateAdditionalInfo.GetHwId(allow_old: boolean): string;
begin
  if not allow_old and not self._hwid_received then begin
    result:='';
  end else begin
    result:=_hwid;
  end;
end;

function FZPlayerStateAdditionalInfo.GetHwHash(allow_old: boolean): string;
begin
  if not allow_old and not self._hwid_received then begin
    result:='';
  end else begin
    result:=_hwhash;
  end;
end;

procedure FZPlayerStateAdditionalInfo.SetOrigCdkeyHash(hash: string);
begin
  _orig_cdkey_hash:=hash;
end;

function FZPlayerStateAdditionalInfo.GetOrigCdkeyHash(): string;
begin
  if not self._hwid_received then begin
    result:='';
  end else begin
    result:=_orig_cdkey_hash;
  end;
end;

function FZPlayerStateAdditionalInfo.GetHwhashSaceStatus(): integer;
var
  h:string;
begin
  h:=GetHwHash(false);
  if length(h) > 0 then begin
    result:=GetSACEStatusForHash(PAnsiChar(GetSACEStatusForHash));
  end else begin
    result:=SACE_NOT_FOUND;
  end;
end;

procedure FZPlayerStateAdditionalInfo.UnMute();
begin
  EnterCriticalSection(_lock);
  try
    self._mute_time_period:=0;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;
begin
  if FZCommonHelper.GetTimeDeltaSafe(FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).last_ready)>FZConfigCache.Get.GetDataCopy.player_ready_signal_interval then begin
    result:=true;
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).last_ready:=FZCommonHelper.GetGameTickCount();
  end else begin
    result:=false;
  end;
end;

function OnPingWarn(cl:pxrClientData):boolean; stdcall;
begin
  if (FZPlayerStateAdditionalInfo(cl.ps.FZBuffer)._last_ping_warning_time=0) or (FZCommonHelper.GetTimeDeltaSafe(FZPlayerStateAdditionalInfo(cl.ps.FZBuffer)._last_ping_warning_time)>FZConfigCache.Get.GetDataCopy.ping_warnings_max_interval) then begin
    cl.m_ping_warn__m_maxPingWarnings:=1;
  end;
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer)._last_ping_warning_time:=FZCommonHelper.GetGameTickCount();
  if cl.m_ping_warn__m_maxPingWarnings>=5 then begin
    DisconnectPlayer(@cl.base_IClient, FZTranslationMgr.Get.TranslateSingle('fz_ping_limit_exceeded'));
  end;
  result:=false;
end;

procedure SendChangeLevelPacket(srv:pIPureServer; cl_id:cardinal); stdcall;
var
  p:NET_Packet;
  s:string;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_CHANGE_LEVEL, sizeof(M_CHANGE_LEVEL)); //хидер
  s:='sace';
  WriteToPacket(@p, PChar(s), length(s)+1);
  SendPacketToClient(srv, cl_id, @p);
end;

function SendTeleportPlayerPacket(client:pxrClientData; pos:pFVector3; dir:pFVector3):boolean; stdcall;
var
  p:NET_Packet;
  owner_entity:pCSE_Abstract;
begin
  R_ASSERT(client<>nil, 'client is nil', 'SendTeleportPlayerPacket');

  result:=false;
  if GetPureServer() = nil then exit;

  owner_entity:=client.owner;
  if (owner_entity = nil) or (dynamic_cast(owner_entity, 0, xrGame+RTTI_CSE_Abstract, xrGame+RTTI_CSE_ALifeCreatureActor, false) = nil) then exit;

  MakeMovePlayerPacket(@p, client.ps.GameID, pos, dir);
  //Заставим пропускать апдейт-пакеты от игрока до подтверждения о перемещении (чтобы старые апдейты не "перебили" позицию)
  client.net_PassUpdates:=0;
  //Запишем в серверный объект игрока его новую позицию (чтобы до получения ответа о перемещении в вызовах ReplicatePlayersStateToPlayer в AH отправлялась новая позиция)
  owner_entity.o_Position := pos^;
  owner_entity.o_Angle := dir^;

  SendPacketToClient(GetPureServer(), client.base_IClient.ID.id, @p);
  result:=true;
end;

function CanChangeName(client:pxrClientData):boolean; stdcall;
begin
  result:=FZConfigCache.Get.GetDataCopy.can_player_change_name;
  if not result then begin
    SendChatMessageByFreeZone(GetPureServer(), client.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_cant_change_name'));
  end;
end;


//Callback for sending SYSMSGS
type FZSysMsgSendCallbackData = record
  srv:pIPureServer;
  cl_id:ClientID;
end;
pFZSysMsgSendCallbackData = ^FZSysMsgSendCallbackData;

procedure SysMsg_SendCallback(msg:pointer; len:cardinal; userdata:pointer); stdcall;
var
  data:pFZSysMsgSendCallbackData;
begin
  data:=pFZSysMsgSendCallbackData(userdata);
  //DPNSEND_IMMEDIATELLY + DPNSEND_GUARANTEED + DPNSEND_PRIORITY_HIGH
  SendPacketToClient_LL(data.srv, data.cl_id.id, msg, len, $100+$8+$80, 0);
end;

procedure ExportMapListToClient(srv:pIPureServer; cl_id:ClientID; gameid:cardinal); stdcall;
var
  maplist:FZClientVotingMapList;
  elements:array of FZClientVotingElement;
  translations:array of string;
  helper:pCMapListHelper;
  servermaps_cur:pSGameTypeMaps;
  mapitm_cur, mapitm_end:pSGameTypeMaps_SMapItm;
  i:integer;
  userdata:FZSysMsgSendCallbackData;
begin
  maplist.gametype := gameid;

  helper:=GetMapList();

  if helper.m_storage.start = nil then begin
    LoadMapList();
  end;

  servermaps_cur:=helper.m_storage.start;
  while servermaps_cur<>helper.m_storage.last do begin
    if servermaps_cur.m_game_type_id = gameid then break;
    servermaps_cur:=pointer(servermaps_cur)+sizeof(SGameTypeMaps);
  end;
  if servermaps_cur=helper.m_storage.last then begin
    //нет такого типа игры!
    FZLogMgr.Get.Write('No gametype in maplist, id='+inttostr(gameid), FZ_LOG_ERROR);
    exit;
  end;

  //Составим список карт для экспорта
  mapitm_end:=servermaps_cur.m_map_names.last;
  mapitm_cur:=servermaps_cur.m_map_names.start;
  maplist.count:= (mapitm_end - mapitm_cur)+1;
  setlength(elements, maplist.count);
  setlength(translations, maplist.count);
  maplist.maps:=@elements[0];

  //первый элемент отвечает за очистку списка карт клиента

  elements[0].mapname:=nil;
  elements[0].mapver:=nil;

  for i:=1 to maplist.count-1 do begin
    elements[i].mapname:=get_string_value(@mapitm_cur.map_name);
    elements[i].mapver:=get_string_value(@mapitm_cur.map_ver);
    translations[i]:=FZTranslationMgr.Get().TranslateOrEmptySingle(elements[i].mapname);
    if length(translations[i])>0 then begin
      elements[i].description:=PAnsiChar(translations[i]);
    end else begin
      elements[i].description:=nil;
    end;
    mapitm_cur:=pointer(mapitm_cur)+sizeof(SGameTypeMaps_SMapItm);
  end;


  userdata.srv:=srv;
  userdata.cl_id:=cl_id;

  while(maplist.count>0) do begin
    SendSysMessage_CS(@ProcessClientVotingMaplist, @maplist, @SysMsg_SendCallback, @userdata);
    maplist.count:=maplist.count-maplist.was_sent;
    maplist.maps:=pointer(maplist.maps)+maplist.was_sent*sizeof(FZClientVotingElement);
  end;

  setlength(elements, 0);
  setlength(translations, 0);
end;

//Here we call constructing downloader SYSMSGS
procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;
var
  dat:FZCacheData;
  dlinfo:FZMapInfo;
  moddllinfo:FZDllDownloadInfo;
  mapname, mapver, maplink, link, xml:string;
  dl_msg, err_msg, incompatible_mod_msg:string;
  filename:string;
  need_dl:boolean;
  userdata:FZSysMsgSendCallbackData;
  flags:FZSysmsgsCommonFlags;
begin
  xrCriticalSection__Enter(@srv.base_IPureServer.net_players.csPlayers);
  try
    userdata.srv:=@srv.base_IPureServer;
    userdata.cl_id:=cl.ID;

    if IsLocalServerClient(cl) or not CheckForClientExist(srv, cl) then exit;
    dat:=FZConfigCache.Get.GetDataCopy();

    if length(dat.mod_name)>0 then begin
      filename:=dat.mod_name+'.mod';
      dl_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_mod_downloading');
      err_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_already_has_download');
      incompatible_mod_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_incompatible_mod');

      moddllinfo.fileinfo.filename:=PAnsiChar(filename);
      moddllinfo.fileinfo.url:=PAnsiChar(dat.mod_link);
      moddllinfo.fileinfo.crc32:=dat.mod_crc32;
      moddllinfo.fileinfo.progress_msg:=PAnsiChar(dl_msg);
      moddllinfo.fileinfo.error_already_has_dl_msg:=PAnsiChar(err_msg);
      moddllinfo.fileinfo.compression:=FZDownloadMgr.GetCompressionTypeByIndex(dat.mod_compression_type);
      moddllinfo.procname:='ModLoad';
      moddllinfo.procarg1:=PAnsiChar(dat.mod_name);
      moddllinfo.procarg2:=PAnsiChar(dat.mod_params);
      moddllinfo.dsign:=PAnsiChar(dat.mod_dsign);
      moddllinfo.name_lock:=PAnsiChar(dat.mod_name);
      moddllinfo.incompatible_mod_message:=PAnsiChar(incompatible_mod_msg);
      moddllinfo.mod_is_applying_message:=PAnsiChar(dl_msg);

      if dat.mod_is_reconnect_needed then begin
        moddllinfo.modding_policy:=FZ_MODDING_WHEN_CONNECTING;
      end else begin
        moddllinfo.modding_policy:=FZ_MODDING_WHEN_NOT_CONNECTING;
      end;
      moddllinfo.reconnect_addr.ip:=PAnsiChar(dat.reconnect_ip);
      moddllinfo.reconnect_addr.port:=dat.reconnect_port;

      if (length(dat.mod_link) = 0) or (length(dat.mod_dsign) > 0) then begin
        if (length(dat.mod_link) = 0) then begin
          FZLogMgr.Get.Write('Send MODLOAD packet for '+dat.mod_name+' (default loader)', FZ_LOG_INFO);
        end else begin
          FZLogMgr.Get.Write('Send MODLOAD packet for '+dat.mod_name, FZ_LOG_INFO);
        end;
        SendSysMessage_CS(@ProcessClientModDll, @moddllinfo, @SysMsg_SendCallback ,@userdata);
      end else begin
        FZLogMgr.Get.Write('MOD_DSIGN parameter not specified!'+dat.mod_name, FZ_LOG_ERROR);
      end;
    end;

    GetMapStatus(mapname, mapver, maplink);
    if (length(mapname)=0) or (length(mapver)=0) then exit;

    if (dat.enable_map_downloader) then begin
      link:=FZDownloadMgr.Get.GetLinkByMapName(mapname, mapver);
      if length(link)>0 then begin
        dlinfo.fileinfo.url:=PAnsiChar(link);
      end else begin
        dlinfo.fileinfo.url:=PAnsiChar(maplink);
      end;
      filename:=FZDownloadMgr.Get.GetMapPrefix(mapname, mapver)+mapname+'_'+mapver+'.map';
      dl_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_map_downloading');
      err_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_already_has_download');
      xml:=FZDownloadMgr.Get.GetXMLName(mapname, mapver);

      dlinfo.fileinfo.filename:=PAnsiChar(filename);
      dlinfo.fileinfo.progress_msg:=PAnsiChar(dl_msg);
      dlinfo.fileinfo.error_already_has_dl_msg:=PAnsiChar(err_msg);
      need_dl:=true;
      dlinfo.fileinfo.crc32:=FZDownloadMgr.Get.GetCRC32(mapname, mapver, need_dl);
      dlinfo.fileinfo.compression:=FZDownloadMgr.Get.GetCompressionType(mapname, mapver);

      dlinfo.reconnect_addr.ip:=PAnsiChar(dat.reconnect_ip);
      dlinfo.reconnect_addr.port:=dat.reconnect_port;
      dlinfo.mapver:=PAnsiChar(mapver);
      dlinfo.mapname:=PAnsiChar(mapname);
      dlinfo.xmlname:=PAnsiChar(xml);
      dlinfo.flags := 0;

      if dat.mod_prefer_parent_appdata_for_maps or FZDownloadMgr.Get().IsPreferParentAppdataDl(mapname, mapver) then begin
        dlinfo.flags:=dlinfo.flags or FZ_MAPLOAD_PREFER_PARENT_APPDATA_STORE;
      end;

      flags:=GetCommonSysmsgsFlags();
      if FZDownloadMgr.Get.IsPatchAndReconnectAfterMapload(mapname, mapver) then begin
        if flags and FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE <> FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE then begin
          flags:=flags or FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE;
          SetCommonSysmsgsFlags(flags);
        end;
        dlinfo.flags:=dlinfo.flags or FZ_MAPLOAD_MANDATORY_RECONNECT;
      end else begin
        if flags and FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE <> 0 then begin
          flags:=flags and (FZ_SYSMSGS_FLAGS_ALL_ENABLED - FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE);
          SetCommonSysmsgsFlags(flags);
        end;
      end;

      if not need_dl then begin
        //Контрольная сумма не найдена, просто сообщаем
        FZLogMgr.Get.Write('No CRC32 for map '+mapname+', ver '+mapver, FZ_LOG_INFO);
      end else begin
        FZLogMgr.Get.Write('Send DOWNLOAD packet for '+mapname+', ver.='+mapver, FZ_LOG_INFO);
        SendSysMessage_CS(@ProcessClientMap, @dlinfo, @SysMsg_SendCallback ,@userdata);
      end;
    end;

    // TODO: отправлять при загрузке клиента, а не при коннекте (минимизация лагов)
    if dat.enable_maplist_sync then begin
      ExportMapListToClient(@srv.base_IPureServer, cl.ID, srv.game.base_game_GameState.m_type);
    end;

  finally
    xrCriticalSection__Leave(@srv.base_IPureServer.net_players.csPlayers);
  end;
end;

procedure OnClientReady(srv:pIPureServer; cl:pxrClientData); stdcall;
var
  hwid:string;
  banned_cl:pbanned_client;
  cfg:FZCacheData;
  sace_status:integer;
  error_message:string;
  cdkey:string;
begin
  //Клиент прогрузился и окончательно готов к игре, не путать с сигналами при респавне
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).valid:=true;
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer)._connected_and_ready:=true;

  if not IsLocalServerClient(@cl.base_IClient) then begin
    error_message:='';
    cdkey:=PAnsiChar(@cl.base_IClient.m_guid[0]);
    hwid:=FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).GetHwId(false);

    if length(error_message) = 0 then begin
      cfg:=FZConfigCache.Get().GetDataCopy();

      //Сначала проверяем наличие HWID, и если он есть - копируем его в m_guid (особенно если тот пустой - это при локальном сервере)
      //на этом этапе коннекта хеш уже был гарантированно проверем геймспаем (но еще пока не был добавлен в BattleEye - добавляется сразу после выхода из этой процедуры, после врезки)
      //Если выставлять m_guid в ProcessHwidPacket, то есть риск, что валидация геймспая произойдет позже, и перезапишет hwid значением ключа
      if (length(hwid) = 0) then begin
        if cfg.strict_hwid then begin
          //проверяем, разрешено ли игроку с таким CDKEY заходить к нам без hwid
          if not FZHashesMgr.Get.IsHashWhitelisted(cdkey) then begin
            FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'has no assigned HWID, disconnecting'), FZ_LOG_INFO);
            error_message:=FZTranslationMgr.Get().TranslateSingle('fz_invalid_hwid');
          end else begin
            FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'has no HWID, but CDKEY '+cdkey+' is whitelisted'), FZ_LOG_INFO);
          end;
        end;
      end else begin
        banned_cl:=CheckDigestForBan(@GetCurrentGame.m_cdkey_ban_list, hwid);
        if banned_cl<>nil then begin
          FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'is FZ-banned ('+get_string_value(@banned_cl.client_hexstr_digest)+') by '+get_string_value(@banned_cl.admin_name)+', disconnecting'), FZ_LOG_INFO);
          error_message:=FZTranslationMgr.Get().TranslateSingle('fz_player_banned')+' '+get_string_value(@banned_cl.admin_name)+', '+FZTranslationMgr.Get().TranslateSingle('fz_expiration_date')+' '+TimeToString(banned_cl.ban_end_time);
        end else begin
          FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id,'has approved FZ digest ['+hwid+']'), FZ_LOG_INFO);
          //все хорошо, в m_guid отправляется hwhash
          strcopy(@cl.base_IClient.m_guid[0], PAnsiChar(GetHwHash(cl, false)));
        end;
      end;
    end;

    if (length(error_message) = 0) and cfg.strict_sace then begin
      sace_status:=GetSACEStatus(cl.base_IClient.ID.id);
      if sace_status = SACE_UNSUPPORTED then begin
        FZLogMgr.Get.Write('strict_sace parameter doesn''t work - seems like your server has no installed SACE!', FZ_LOG_ERROR);
      end else if sace_status<>SACE_OK then begin
        if (length(hwid) > 0) and FZHashesMgr.Get.IsHashWhitelisted(hwid) then begin
          FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'has no SACE, but HWID '+hwid+' is whitelisted'), FZ_LOG_INFO);
        end else if (length(cdkey)>0) and FZHashesMgr.Get.IsHashWhitelisted(cdkey) then begin
          FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'has no SACE, but CDKEY '+cdkey+' is whitelisted'), FZ_LOG_INFO);
        end else begin
          FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'has no SACE, disconnecting'), FZ_LOG_INFO);
          error_message:=FZTranslationMgr.Get().TranslateSingle('fz_required_sace');
        end;
      end;
    end;

    if length(error_message) <> 0 then begin
      IPureServer__DisconnectClient(srv, @cl.base_IClient, error_message);
    end;
  end;
end;

function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;
begin
  result:=not FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).valid;
  if result then begin
    FZLogMgr.Get.Write('Force removing player state of disconnected client!', FZ_LOG_INFO);
  end;
end;

procedure xrServer__OnCL_Disconnected_appendToPacket(p:pNET_Packet; pname:ppshared_str; cl:pxrClientData); stdcall;
var
  write_empty_name:boolean;
begin
  write_empty_name:=true;

  if cl<>nil then begin
    if FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).connected_and_ready then begin
      write_empty_name:=false;
    end;
    FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).OnDisconnected();
  end;

  if write_empty_name then begin
    //make 'empty' name if we don't need to show 'disconnect' message to clients
    FZLogMgr.Get.Write('CL (not ready) disconnecting: '+get_string_value(pname^)+', id='+inttostr(cl.base_IClient.ID.id), FZ_LOG_INFO);
    pname^:=GetGlobalUndockedEmptyStr();
  end else begin
    FZLogMgr.Get.Write('CL disconnecting: '+get_string_value(pname^)+', id='+inttostr(cl.base_IClient.ID.id), FZ_LOG_INFO);
  end;

end;

function game_sv_mp__OnPlayerDisconnect_is_message_needed(name:PAnsiChar):boolean; stdcall;
var
  empty_name:string;
begin
  empty_name:='';
  result:= empty_name <> name;
end;

function CheckItemRank(rank:cardinal; item_sect:string):boolean;
begin
  result:=(GetRankForItem(item_sect) <= rank);
end;

type FZAddonDescription = record
  flag:EWeaponAddonState;
  oldFlag:EWeaponAddonState;
  name_param:string;
  status_param:string;
end;
FZAddonDescrArray = array[0..2] of FZAddonDescription;

function GetAddonsDescription():FZAddonDescrArray;
begin
  result[0].flag := eWeaponAddonScope; result[0].name_param:='scope_name'; result[0].status_param:='scope_status'; result[0].oldFlag:=fzBuyItemOldScopeStateBit;
  result[1].flag := eWeaponAddonGrenadeLauncher; result[1].name_param:='grenade_launcher_name'; result[1].status_param:='grenade_launcher_status'; result[1].oldFlag:=fzBuyItemOldGlStateBit;
  result[2].flag := eWeaponAddonSilencer; result[2].name_param:='silencer_name'; result[2].status_param:='silencer_status'; result[2].oldFlag:=fzBuyItemOldSilencerStateBit
end;

function GetItemCostForRank(name_for_log:string; rank:cardinal; mgr:pCItemMgr; item_sect:PAnsiChar; addons:byte; item_rebuying:boolean; warmup:boolean):integer; stdcall;
var
  addons_descr:FZAddonDescrArray;
  i:integer;

  addon_cost:integer;
  total_cost:integer;
  addon_sect:string;
begin
  //-1 значит, что покупать нельзя
  result:=-1;
  R_ASSERT(item_sect<>nil, 'Cannot calculate cost for rank - item is nil');

  if (not item_rebuying) and not (warmup) and (not CheckItemRank(rank, item_sect)) then begin
    if length(name_for_log) > 0 then BadEventsProcessor(FZ_SEC_EVENT_WARN, SHOP_GROUP+'Player '+name_for_log+' with rank '+inttostr(rank)+' wants to buy item "'+item_sect+'"');
    exit;
  end;

  total_cost:=CItemMgr__GetItemCost(mgr, item_sect, rank);
  if total_cost < 0 then exit;

  //Проверим аддоны
  addons_descr:=GetAddonsDescription();
  for i:=0 to length(addons_descr)-1 do begin
    if addons and addons_descr[i].flag <> 0 then begin
      if game_ini_read_int_def(PAnsiChar(item_sect), addons_descr[i].status_param, -1) <> eAddonAttachable then exit;
      addon_sect:=game_ini_read_string_def(PAnsiChar(item_sect), addons_descr[i].name_param);
      if length(addon_sect) = 0 then exit;

      if (not warmup) and (addons and addons_descr[i].oldFlag = 0) and (not CheckItemRank(rank, addon_sect)) then begin
        if length(name_for_log) > 0 then BadEventsProcessor(FZ_SEC_EVENT_WARN, SHOP_GROUP+'Player '+name_for_log+' with rank '+inttostr(rank)+' wants to buy addon "'+addon_sect+'"');
        exit;
      end;

      addon_cost:=CItemMgr__GetItemCost(mgr, addon_sect, rank);
      if addon_cost < 0 then exit;
      total_cost:=total_cost+addon_cost;
    end;
  end;

  result:=total_cost;
end;

function CouldItemBeBought(name_for_log:string; rank:cardinal; game:pgame_sv_mp; item_id:cardinal; warmup:boolean; max_cost:integer; all_items:pxr_vector):integer;
var
  cost:integer;
  item, item_second:pCItemMgr__m_items_pair;

  item_second_id:word;

  group:string;
  count_remains:integer;
  i:integer;

  rebuying:boolean;
begin
  result:=-1;

  //Проверяем, не идет ли сейчас перезакуп проданного (он разрешен)
  rebuying:=((item_id shr 8) and fzBuyItemRenewing) <> 0;

  //Проверим, разрешено ли игроку покупать этот предмет
  item:=CItemMgr__GetElement(game.m_strWeaponsData, item_id and $00FF);
  cost:=GetItemCostForRank(name_for_log, rank, game.m_strWeaponsData, get_string_value(@item.first), (item_id and $FF00) shr 8, rebuying, warmup);

  if length(name_for_log) > 0 then begin
    FZLogMgr.Get.Write('Player '+name_for_log+' buys item with description 0x'+inttohex(item_id, 4)+', cost='+inttostr(cost), FZ_LOG_DBG);
  end;

  if cost < 0 then exit;

  //Смотрим, хватает ли у нас денег на покупку
  if (not warmup) and (cost > max_cost) then begin
    if length(name_for_log) > 0 then BadEventsProcessor(FZ_SEC_EVENT_WARN, SHOP_GROUP+'Player '+name_for_log+' tries to spend more money than really has');
    exit;
  end;

  if not rebuying then begin
    //Смотрим ограничение на число закупаемых предметов
    group:=GetItemGroup(get_string_value(@item.first));
    if not warmup then begin
      count_remains:=GetItemGroupMaxCounter(group, rank);
    end else begin
      count_remains:=GetItemGroupMaxCounter(group, _RANK_COUNT-1);
    end;

    if count_remains <= 0 then begin
      if length(name_for_log) > 0 then BadEventsProcessor(FZ_SEC_EVENT_WARN, SHOP_GROUP+'Player '+name_for_log+' tries to buy item ['+get_string_value(@item.first)+'] which is unavailable for him!');
      exit;
    end;

    //Проверяем, что игрок не закупил больше предметов, чем разрешено
    //В общем счетчике учитываются и перезакупаемые предметы! Если все предметы - перезакуп, то сюда мы не попадем, иначе - нефиг
    for i:=0 to items_count_in_vector(all_items, sizeof(word))-1 do begin
      item_second_id:=pword(get_item_from_vector(all_items, i, sizeof(word)))^;
      item_second_id:=item_second_id and $00FF;
      item_second:=CItemMgr__GetElement(game.m_strWeaponsData, item_second_id );
      if group = GetItemGroup(get_string_value(@item_second.first)) then begin
        if count_remains = 0 then begin
          if length(name_for_log) > 0 then BadEventsProcessor(FZ_SEC_EVENT_WARN, SHOP_GROUP+'Player '+name_for_log+' tries to override count restrictions for ['+get_string_value(@item_second.first)+']');
          exit;
        end;
        count_remains:=count_remains-1;
      end;
    end;
  end;

  result:=cost;
end;

function CheckForShopItemBanned(game:pgame_sv_mp; var item_id:word; player_name:PAnsiChar):boolean;
var
  sect_pair:pCItemMgr__m_items_pair;
  addons:byte;
  addons_descr:FZAddonDescrArray;
  sect, addon_sect:string;
  i:integer;
begin
  sect_pair:=CItemMgr__GetElement(game.m_strWeaponsData, item_id and $00FF);
  sect:=get_string_value(@sect_pair.first);

  result:=false;
  if FZItemCfgMgr.Get().IsItemBannedToBuy(sect) then begin
    FZLogMgr.Get.Write('Removing banned item '+sect+' from buy vector of player '+player_name, FZ_LOG_DBG);

    result:=true;
  end else begin
    addons:=(item_id and $FF00) shr 8;
    addons_descr:=GetAddonsDescription();

    for i:=0 to length(addons_descr)-1 do begin
      if addons and addons_descr[i].flag <> 0 then begin
        if game_ini_read_int_def(PAnsiChar(sect), addons_descr[i].status_param, -1) <> eAddonAttachable then continue;

        addon_sect:=game_ini_read_string_def(PAnsiChar(sect), addons_descr[i].name_param);
        if length(addon_sect) = 0 then continue;

        if FZItemCfgMgr.Get().IsItemBannedToBuy(addon_sect) then begin
          FZLogMgr.Get.Write('Removing banned addon '+addon_sect+' for item '+sect+' from buy vector of player '+player_name, FZ_LOG_DBG);
          item_id:=item_id and (not (word(addons_descr[i].flag) shl 8));
        end;
      end;
    end;
  end;
end;

function BeforeSpawnBoughtItems(ps:pgame_PlayerState; game:pgame_sv_mp; warmup:boolean):boolean; stdcall;
var
  i:integer;
  pidx:pword;
  idx:word;
  cost:integer;

  cl:pxrClientData;
begin
  result:=true;

  R_ASSERT(ps<>nil, 'Checking bought items failed - PlayerState is NIL');
  ps.LastBuyAcount:=0;

  FZLogMgr.Get.Write('Start processing bought items for player '+PAnsiChar(@ps.name[0])+', money = '+ inttostr(ps.money_for_round)+', warmup='+booltostr(warmup), FZ_LOG_DBG);

  //Сначала проверим на DoS для гарантированной раздачи ништяков хакерам
  for i:=0 to items_count_in_vector(@ps.pItemList, sizeof(word))-1 do begin
    idx:= pWord(get_item_from_vector(@ps.pItemList, i, sizeof(word)))^;
    if CItemMgr__GetItemsCount(game.m_strWeaponsData) <= (integer(idx) and $00FF) then begin
      if FZConfigCache.Get().GetDataCopy().antihacker then begin
        ActiveDefence(ps);
      end else begin
        BadEventsProcessor(FZ_SEC_EVENT_ATTACK, SHOP_GROUP+'DoS from player '+PAnsiChar(@ps.name[0]));
      end;
      result:=false;
      break;
    end;
  end;

  //Теперь проверяем на валидность закупа
  i:=items_count_in_vector(@ps.pItemList, sizeof(word))-1;
  while result and (i >= 0)  do begin
    pidx:=pWord(get_item_from_vector(@ps.pItemList, i, sizeof(word)));
    idx:= pidx^;

    if CheckForShopItemBanned(game, idx, PAnsiChar(@ps.name[0])) then begin
      //Предмет запрещено покупать!
      cl:=PS_to_client(ps);
      if cl<>nil then begin
        SendChatMessageByFreeZone(GetPureServer(), cl.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_banned_item_removed'));
      end;
      remove_item_from_vector(@ps.pItemList, i, sizeof(word));
    end else begin
      cost:= CouldItemBeBought(PAnsiChar(@ps.name[0]), ps.rank, game, idx, warmup, ps.money_for_round + ps.LastBuyAcount, @ps.pItemList);

      if cost < 0 then begin
        //Предмет купить нельзя. Разбираемся, что нам делать теперь
        if FZConfigCache.Get().GetDataCopy().sell_items_for_shophackers then begin
          //Удаляем этот предмет из списка закупа
          FZLogMgr.Get.Write('Removing item with description 0x'+inttohex(idx, 0)+' ('+inttostr(i)+') from buy vector', FZ_LOG_DBG);
          remove_item_from_vector(@ps.pItemList, i, sizeof(word));
        end else begin
          //Отменяем весь закуп
          result:=false;
          break;
        end;
      end else begin
        //Покупать можно, докинем стоимость этого предмета к общей стоимости покупок в этот раз
        if not warmup then begin
          ps.LastBuyAcount:=ps.LastBuyAcount - cost;
        end;
        //сбросим все наши дополнительные флаги у закупаемого предмета для гарантии чистоты
        pidx^:=idx and (((word(eWeaponAddonScope or eWeaponAddonGrenadeLauncher or eWeaponAddonSilencer)) shl 8) or $FF);
      end;
    end;
    i:=i-1;
  end;

  if not result then begin
    //Закупа не будет, очищаем вектор
    ps.pItemList.last:=ps.pItemList.start;
    ps.LastBuyAcount:=0;
  end;

  //Если что-то стоящее купили - сбрасываем бонус за респавн голышом
  if ps.LastBuyAcount<>0 then begin
    ps.m_bClearRun:=0;
  end;
end;

////////////////////
//Helper class
type
  SSectionAmmoCount = record
    name:string;
    count:integer;
  end;

  { CAmmoSectionContainer }

  CAmmoSectionContainer = class
    _ammos:array of SSectionAmmoCount;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure AddAmmoCount(section:string; cnt:integer);
    function GetAmmoCount(section:string):integer;
    function GetRefundCost(game:pgame_sv_mp; ps:pgame_PlayerState; client_id:cardinal; itemsDesired:pxr_vector):integer;
  end;

{ CAmmoSectionContainer }

constructor CAmmoSectionContainer.Create;
begin
  setlength(_ammos, 0);
end;

destructor CAmmoSectionContainer.Destroy;
begin
  setlength(_ammos, 0);
  inherited Destroy;
end;

procedure CAmmoSectionContainer.AddAmmoCount(section: string; cnt: integer);
var
  i:integer;
  flag:boolean;
begin
  flag:=false;
  for i:=0 to length(_ammos)-1 do begin
    if _ammos[i].name = section then begin
      _ammos[i].count := _ammos[i].count + cnt;
      flag:=true;
      break;
    end;
  end;

  if not flag then begin
    i:=length(_ammos);
    setlength(_ammos, i+1);
    _ammos[i].name:=section;
    _ammos[i].count:=cnt;
  end;
end;

function CAmmoSectionContainer.GetAmmoCount(section: string): integer;
var
  i:integer;
begin
  result:=0;
  for i:=0 to length(_ammos)-1 do begin
    if _ammos[i].name = section then begin
      result:=_ammos[i].count;
      break;
    end;
  end;
end;

function CAmmoSectionContainer.GetRefundCost(game: pgame_sv_mp; ps: pgame_PlayerState; client_id: cardinal; itemsDesired: pxr_vector): integer;
var
  i, j:integer;
  idToBuy:integer;
  pIdOfDesired:psmallint;
  box_size:integer;
  box_cost:integer;
  box_count:integer;
begin
  result:=0;
  for i:=0 to length(_ammos)-1 do begin
    box_cost:=CItemMgr__GetItemCost(game.m_strWeaponsData, _ammos[i].name, ps.rank);
    if box_cost < 0 then continue;

    //Если цена нашлась, то сам предмет обязательно должен уже быть в магазине!
    idToBuy:=CItemMgr__GetItemIdx(game.m_strWeaponsData, _ammos[i].name);
    if (idToBuy < 0) then begin
      FZLogMgr.Get.Write('[BUG-SUSPECT] Refund cost is '+inttostr(box_cost)+' but cannot get shop ID for '+_ammos[i].name, FZ_LOG_ERROR);
      continue;
    end;

    box_size:=game_ini_read_int_def(_ammos[i].name, 'box_size', 1);
    if (box_size <= 0) then begin
      FZLogMgr.Get.Write('[BUG-SUSPECT] Box size of ammo '+_ammos[i].name+' is 0', FZ_LOG_ERROR);
      continue;
    end;

    box_count:=_ammos[i].count div box_size;

    FZLogMgr.Get.Write(GenerateMessageForClientId(client_id, ' got refund '+inttostr(box_count)+'x'+inttostr(box_cost)+' for "'+_ammos[i].name+'", lost '+inttostr(_ammos[i].count mod box_size)+' cartridges'), FZ_LOG_DBG);
    result:=result + box_count * box_cost;

    //Пробегаемся по вектору желаемых покупок и отмечаем там перезакупаемые пачки
    for j:=0 to items_count_in_vector(itemsDesired, sizeof(word))-1 do begin
      //Если больше коробок нет, то и ловить тут нечего
      if box_count = 0 then break;

      pIdOfDesired:=get_item_from_vector(itemsDesired, j, sizeof(word));
      if (pIdOfDesired^ and $00FF) = idToBuy then begin
        //Если пачка с таким ИД нашлась, бит переиспользования в ней должен еще быть неактивен, иначе что-то у нас пошло не так
        R_ASSERT( (pIdOfDesired^ shr 8) and fzBuyItemRenewing = 0, 'Reusage bit is already set for ammo box' );

        //Взведем бит и пойдем проверять далее
        pIdOfDesired^:=(smallint(fzBuyItemRenewing) shl 8) or (pIdOfDesired^);
        box_count:=box_count-1;

        FZLogMgr.Get().Write('Player '+PAnsiChar(@ps.name[0])+' re-buys ammo '+_ammos[i].name+', full mask 0x'+inttohex(word(pIdOfDesired^), 4), FZ_LOG_DBG);
      end;
    end;
  end;
end;

////////////////////

procedure BeforeDestroyingSoldItem(itm:pCInventoryItem; game:pgame_sv_mp; warmup:boolean; ps:pgame_PlayerState; itemsDesired:pxr_vector); stdcall;
var
  sect:PAnsiChar;
  i:integer;
  idToBuy:integer;
  pIdOfDesired:psmallint;
  addons_mask, old_addons:smallint;
  pwpn:pCWeapon;
  cost:integer;
begin
  //В разминке деньги не возвращаем
  if warmup then exit;

  cost:=0;

  old_addons:=0;
  pwpn:=dynamic_cast(itm, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeapon, false);
  if pwpn<>nil then begin
    //На оружии могут быть аддоны
    old_addons:=pwpn.m_flagsAddOnState;
  end;

  //Посмотрим на секцию удаляемого предмета и получим ее ИДшник в магазине
  sect:=get_string_value(@itm.m_section_id);
  idToBuy:=CItemMgr__GetItemIdx(game.m_strWeaponsData, sect);
  if idToBuy<0 then begin
    FZLogMgr.Get.Write('Item "'+sect+' is not registered in the shop, cannot return money to player', FZ_LOG_IMPORTANT_INFO);
    exit;
  end;

  //пробежимся по предметам, которые будут приобретаться, попробуем найти предмет с таким ID и невзведенным битом переиспользования
  for i:=0 to items_count_in_vector(itemsDesired, sizeof(word))-1 do begin
    pIdOfDesired:=get_item_from_vector(itemsDesired, i, sizeof(word));
    //Если предмет с таким ИД нашелся и бит переиспользования неактивен - выставим этот бит и, если это оружие, выставим старую конфигурацию аддонов
    if ((pIdOfDesired^ and $00FF) = idToBuy) and (((pIdOfDesired^ shr 8) and fzBuyItemRenewing) = 0) then begin
      addons_mask:=fzBuyItemRenewing or ((pIdOfDesired^ and $FF00) shr 8);
      if (old_addons and eWeaponAddonScope) <> 0 then addons_mask:=addons_mask or fzBuyItemOldScopeStateBit;
      if (old_addons and eWeaponAddonGrenadeLauncher) <> 0 then addons_mask:=addons_mask or fzBuyItemOldGlStateBit;
      if (old_addons and eWeaponAddonSilencer) <> 0 then addons_mask:=addons_mask or fzBuyItemOldSilencerStateBit;
      pIdOfDesired^:= smallint((addons_mask shl 8) or idToBuy);

      FZLogMgr.Get().Write('Player '+PAnsiChar(@ps.name[0])+' re-buys (upgrades) '+sect+', full mask 0x'+inttohex(word(pIdOfDesired^), 4), FZ_LOG_DBG);
      break;
    end;
  end;

  //Посчитаем стоимость удаляемого и вернем сумму игроку
  cost:=cost+GetItemCostForRank('', ps.rank, game.m_strWeaponsData, sect, old_addons, true, true);
  FZLogMgr.Get().Write('Return '+inttostr(cost)+' credits to player '+PAnsiChar(@ps.name[0])+' for item '+sect+', full mask 0x'+inttohex(word(idToBuy), 4), FZ_LOG_DBG);
  if cost > 0 then begin
    ps.m_bClearRun:=0;
    game_PlayerAddMoney(game, ps, cost);
  end;
end;

function BeforeSpawnBoughtItems_DM(ps:pgame_PlayerState; game:pgame_sv_Deathmatch):boolean; stdcall;
begin
  FZLogMgr.Get.Write('BeforeSpawnBoughtItems_DM: ps='+inttohex(uintptr(ps), 8)+', game='+inttohex(uintptr(game), 8), FZ_LOG_DBG);
  result:=BeforeSpawnBoughtItems(ps, @game.base_game_sv_mp, game.m_bInWarmUp<>0);
end;

function BeforeSpawnBoughtItems_CTA(ps:pgame_PlayerState; game:pgame_sv_CaptureTheArtefact):boolean; stdcall;
begin
  FZLogMgr.Get.Write('BeforeSpawnBoughtItems_CTA: ps='+inttohex(uintptr(ps), 8)+', game='+inttohex(uintptr(game), 8), FZ_LOG_DBG);
  result:=BeforeSpawnBoughtItems(ps, @game.base_game_sv_mp, game.m_bInWarmUp<>0);
end;

procedure DestroyAllItemsFromPlayersInventoryDeforeBuying(game:pgame_sv_mp; client_id:cardinal); stdcall;
var
  obj:pCObject;
  owner:pCInventoryOwner;
  cl:pxrClientData;
  itm:ppCInventoryItem;
  i:integer;
  gameid:cardinal;
  packet:NET_Packet;
  warmup:boolean;
  game_dm:pgame_sv_Deathmatch;
  game_cta:pgame_sv_CaptureTheArtefact;

  wpnMag:pCWeaponMagazined;
  wpnMagGl:pCWeaponMagazinedWGrenade;
  sect, ammosect:string;
  pammosect:pshared_str;
  ammos:CAmmoSectionContainer;
  ammobox:pCWeaponAmmo;
  total_cost:integer;
begin
  warmup:=false;
  game_cta:=nil;
  total_cost:=0;

  game_dm:=dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_Deathmatch, false);
  if game_dm = nil then begin
    game_cta:=dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_CaptureTheArtefact, false);
    if game_cta<>nil then begin
      warmup:=game_cta.m_bInWarmUp<>0;
    end;
  end else begin
    warmup:=game_dm.m_bInWarmUp<>0;
  end;

  cl:=ID_to_client(client_id);
  if (cl = nil) or (cl.ps = nil) then exit;

  obj:=ObjectById(@GetLevel.base_IGame_Level, cl.ps.GameID);
  if obj = nil then exit;

  owner:=dynamic_cast(obj, 0, xrGame+RTTI_CObject, xrGame+RTTI_CInventoryOwner, false);
  if (owner=nil) or (owner.m_inventory=nil) then exit;

  FZLogMgr.Get.Write('DestroyAllItemsFromPlayersInventoryDeforeBuying: game='+inttohex(uintptr(game), 8)+', clid='+inttostr(client_id)+', owner='+inttohex(uintptr(obj), 8), FZ_LOG_DBG);


  //НАЧИНАЯ С ЭТОЙ ТОЧКИ ПРОСТО ИСПОЛЬЗОВАТЬ exit НЕЛЬЗЯ - НАДО ТАКЖЕ УДАЛЯТЬ ammos!
  //Сначала пробежимся по предметам, не удаляя их, с целью подсчета имеющихся боеприпасов
  ammos:=CAmmoSectionContainer.Create();
  for i:=0 to items_count_in_vector(@owner.m_inventory.m_all, sizeof(pCInventoryItem))-1 do begin
    itm:=get_item_from_vector(@owner.m_inventory.m_all, i, sizeof(pCInventoryItem));
    if itm^=nil then continue;
    sect:=get_string_value(@itm^.m_section_id);

    ammobox:= dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeaponAmmo, false);
    if ammobox<>nil then begin
      if ammobox.m_boxCurr <= ammobox.m_boxSize then begin
        FZLogMgr.Get.Write(GenerateMessageForClientId(client_id, ' has box of "'+sect+'" (max size is '+inttostr(ammobox.m_boxSize)+', current size is '+inttostr(ammobox.m_boxCurr)+')' ), FZ_LOG_DBG);
        ammos.AddAmmoCount(sect, ammobox.m_boxCurr);
      end else begin
        FZLogMgr.Get.Write(GenerateMessageForClientId(client_id, ' has strange box of "'+sect+'" (max size is '+inttostr(ammobox.m_boxSize)+', current size is '+inttostr(ammobox.m_boxCurr)+')'), FZ_LOG_ERROR);
        ammos.AddAmmoCount(sect, ammobox.m_boxSize);
      end;
    end else begin
      wpnMag := dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeaponMagazined, false);
      if (wpnMag <> nil) and (wpnMag.base_CWeapon.iAmmoElapsed <> 0) then begin
        pammosect:= get_item_from_vector(@wpnMag.base_CWeapon.m_ammoTypes, wpnMag.base_CWeapon.m_ammoType, sizeof(shared_str));
        ammosect:=get_string_value(pammosect);
        FZLogMgr.Get.Write(GenerateMessageForClientId(client_id, ' has '+inttostr(wpnMag.base_CWeapon.iAmmoElapsed)+' ammos of type "'+ammosect+'" in the weapon "'+sect+'"'), FZ_LOG_DBG);
        ammos.AddAmmoCount(ammosect, wpnMag.base_CWeapon.iAmmoElapsed);
      end;

      wpnMagGl := dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeaponMagazinedWGrenade, false);
      if (wpnMagGl <> nil) and (wpnMagGl.iAmmoElapsed2 <> 0) then begin
        pammosect:= get_item_from_vector(@wpnMagGl.m_ammoTypes2, wpnMagGl.m_ammoType2, sizeof(shared_str));
        ammosect:=get_string_value(pammosect);
        FZLogMgr.Get.Write(GenerateMessageForClientId(client_id, ' has '+inttostr(wpnMagGl.iAmmoElapsed2)+' ammos of type "'+ammosect+'" in the weapon "'+sect+'"'), FZ_LOG_DBG);
        ammos.AddAmmoCount(ammosect, wpnMagGl.iAmmoElapsed2);
      end;
    end;
  end;

  for i:=0 to items_count_in_vector(@owner.m_inventory.m_all, sizeof(pCInventoryItem))-1 do begin
    itm:=get_item_from_vector(@owner.m_inventory.m_all, i, sizeof(pCInventoryItem));
    if itm^=nil then continue;

    if dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CMPPlayersBag, false) <> nil then continue;
    if dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CArtefact, false) <> nil then continue;

    //в CTA также нельзя удалять и ножи (они не приходят в векторе на перезакуп, так сделано почему-то в оригинале)
    if (game_cta<>nil) and (dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeaponKnife, false) <> nil) then continue;

    if itm^.m_object = nil then continue;

    gameid:=itm^.m_object.base_CGameObject.base_CObject.Props.net_ID;
    sect:=get_string_value(@itm^.m_section_id);

    //Возврат денег за пачки патронов обрабатывается далее отдельно
    if dynamic_cast(itm^, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeaponAmmo, false) = nil then begin
      BeforeDestroyingSoldItem(itm^, game, warmup, cl.ps, @cl.ps.pItemList);
    end;

    MakeDestroyGameItemPacket(@packet, gameid, GetDevice().dwTimeGlobal - NET_Latency - NET_Latency);
    IPureClient_Send(@GetLevel.base_IPureClient, @packet, DPNSEND_GUARANTEED);
  end;

  //Теперь смотрим, какие боеприпасы остались непроданными, и считаем стоимость
  total_cost:=total_cost+ammos.GetRefundCost(game, cl.ps, client_id, @cl.ps.pItemList);

  if total_cost > 0 then begin
    cl.ps.m_bClearRun:=0;
    game_PlayerAddMoney(game, cl.ps, total_cost);
  end;

  ammos.Free();
end;

procedure UpdatePlayer(cld: pxrClientData);
var
  owner_entity:pCSE_Abstract;
  pos, dir:FVector3;

  old_state, new_state:FZPlayerInvincibleStatus;
  cur_inv_flag:boolean;
begin
  R_ASSERT(cld<>nil, 'UpdatePlayer got nil player');

  //Проверим состояние форсирования неуязвимости
  old_state:=GetForceInvincibilityStatus(cld);
  new_state:=UpdateForceInvincibilityStatus(cld);
  cur_inv_flag:=(cld.ps.flags__ and GAME_PLAYER_FLAG_INVINCIBLE) <> 0;

  if new_state = FZ_INVINCIBLE_FORCE_ENABLE then begin
    //Неуязвимость всегда должна быть включена
    if not cur_inv_flag then begin
      cld.ps.flags__:=cld.ps.flags__ or GAME_PLAYER_FLAG_INVINCIBLE;
      game_signal_Syncronize();
    end;
  end else if new_state = FZ_INVINCIBLE_FORCE_DISABLE then begin
    //Неуязвимость в любом случае должна быть выключена
    if cur_inv_flag then begin
      cld.ps.flags__:=cld.ps.flags__ and (not GAME_PLAYER_FLAG_INVINCIBLE);
      game_signal_Syncronize();
    end;
  end else if new_state <> old_state then begin
    //Новый стейт в нашем случае может быть ТОЛЬКО дефолтовым!
    R_ASSERT(new_state = FZ_INVINCIBLE_DEFAULT, 'Invincibility is in unexpected state');

    //Выключаем неуязвимость от греха подальше
    if cur_inv_flag then begin
      cld.ps.flags__:=cld.ps.flags__ and (not GAME_PLAYER_FLAG_INVINCIBLE);
      game_signal_Syncronize();
    end;
  end;

  //Проверим, не зашел ли игрок в зону телепорта, и телепортнем его при необходимости
  if (cld.net_Ready<>0) and (cld.net_PassUpdates<>0) and (cld.ps.flags__ and GAME_PLAYER_FLAG_VERY_VERY_DEAD = 0) then begin
    owner_entity:=cld.owner;
    if (owner_entity <> nil) and (dynamic_cast(owner_entity, 0, xrGame+RTTI_CSE_Abstract, xrGame+RTTI_CSE_ALifeCreatureActor, false) <> nil)  then begin
      if FZTeleportMgr.Get().IsTeleportingNeeded(@owner_entity.o_Position, @owner_entity.o_Angle, @pos, @dir) then begin
        SendTeleportPlayerPacket(cld, @pos, @dir);
      end;
    end;
  end;
end;

function CanPlayerBuyNow(cl:pxrClientData):boolean;stdcall;
begin
 result:=false;
 if (cl=nil) or (cl.ps=nil) then exit;
 FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'send buy request, flags='+inttostr(cl.ps.flags__)), FZ_LOG_DBG);
 result:=(cl.ps.flags__ and (GAME_PLAYER_FLAG_ONBASE or GAME_PLAYER_FLAG_VERY_VERY_DEAD)<>0);
 if not result then begin
   FZLogMgr.Get.Write('Buy attempt of "'+PAnsiChar(@cl.ps.name[0])+'" cancelled', FZ_LOG_INFO);
 end;
end;

function IsSpawnFreeAmmoAllowedForGametype(game:pgame_sv_mp):boolean; stdcall;
begin
  result:=false;

  //В артханте и CTA спавнить патроны бесплатно нельзя - они ограничены и вполне продаваемы
  if dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_ArtefactHunt, false) <> nil then exit;
  if dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_CaptureTheArtefact, false) <> nil then exit;

  result:=true;
end;

function IsWeaponKnife(item: pCSE_Abstract): boolean; stdcall;
begin
  result:=item.m_tClassID = GetClassId('W_KNIFE');
end;

function GetNameAndIpByClientId(id:cardinal; var ip:string):string;
var
  cld:pxrClientData;
begin
  ip:='0.0.0.0';
  result:='(null)';

  cld:=ID_to_client(id);
  if (cld=nil) then exit;

  ip:=ip_address_to_str(cld.base_IClient.m_cAddress);

  if (cld.ps <> nil) then begin
    result:=PAnsiChar(@cld.ps.name[0]);
  end;

  if length(result) = 0 then begin
    result:=get_string_value(@cld.base_IClient.name);
  end;
end;

function GenerateMessageForClientId(id:cardinal; message: string):string;
var
  name, ip:string;
begin
  ip:='';
  name:=GetNameAndIpByClientId(id, ip);
  result:='Player "'+name+'" (ID='+inttostr(id)+', IP='+ip+') '+message;
end;

function IsInvincibilityControlledByFZ(ps:pgame_PlayerState):boolean; stdcall;
var
  buf:FZPlayerStateAdditionalInfo;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'IsInvincibilityControlledByFZ');

  buf:=FZPlayerStateAdditionalInfo(ps.FZBuffer);
  result:=buf.GetForceInvincibilityStatus()<>FZ_INVINCIBLE_DEFAULT;
end;

function IsInvinciblePersistAfterShot(ps:pgame_PlayerState):boolean; stdcall;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'IsInvinciblePersistAfterShot');
  result:=FZConfigCache.Get().GetDataCopy().invincibility_after_shot;
end;

end.
