unit Players;
{$mode delphi}
interface
uses Clients, windows, Servers,PureServer, games, InventoryItems, Vector,Packets, MatVectors;

procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;
function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;
function CanPlayerBuyNow(cl:pxrClientData):boolean;stdcall;

function GenerateMessageForClientId(id:cardinal; message: string):string;

procedure CorrectPlayerName(s:PAnsiChar); stdcall;
function CorrectPlayerNameWhenRenaming(p:pNET_Packet; id:cardinal):boolean; stdcall;

procedure CheckClientConnectData(data:pSClientConnectData); stdcall;
procedure CheckClientConnectionName(str:PAnsiChar; msg:pDPNMSG_CREATE_PLAYER); stdcall;

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

  _force_invincibility_cur:FZPlayerInvincibleStatus;
  _force_invincibility_next:FZPlayerInvincibleStatus;


  {%H-}constructor Create(ps:pgame_PlayerState);
public
  procedure SetUpdrate(d:cardinal);
  property updrate:cardinal read _updrate write SetUpdrate;
  property last_ready:cardinal read _last_ready_time write _last_ready_time;
  property valid:boolean read _valid write _valid;

{  function IsAllowedStartingVoting():boolean;
  procedure OnVoteStarted();
  procedure OnVote();
  function IsPlayerVoteMuted():boolean;
  procedure AssignVoteMute(time:cardinal);  }
  procedure AssignSpeechMute(time:cardinal);

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
function IsSlotsBlocked(cl: pxrClientData):boolean; stdcall;
function GetForceInvincibilityStatus(cl: pxrClientData): FZPlayerInvincibleStatus; stdcall;
function SetForceInvincibilityStatus(cl: pxrClientData; status:FZPlayerInvincibleStatus):boolean;
function UpdateForceInvincibilityStatus(cl: pxrClientData):FZPlayerInvincibleStatus; //переключить на следующее состояние, вернуть его

function SendTeleportPlayerPacket(client:pxrClientData; pos:pFVector3; dir:pFVector3):boolean; stdcall;

procedure OnClientReady({%H-}srv:pIPureServer; cl:pxrClientData); stdcall;
function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;

function BeforeSpawnBoughtItems_DM(ps:pgame_PlayerState; game:pgame_sv_Deathmatch):boolean; stdcall;
procedure BeforeDestroyingSoldItem_DM(itemGameId:word; game:pgame_sv_Deathmatch; ps:pgame_PlayerState; itemsDesired:pxr_vector); stdcall;

procedure UpdatePlayer(cld:pxrClientData);

function IsInvincibilityControlledByFZ(ps:pgame_PlayerState):boolean; stdcall;
function IsInvinciblePersistAfterShot(ps:pgame_PlayerState):boolean; stdcall;

function GetFZBuffer(ps:pgame_PlayerState):FZPlayerStateAdditionalInfo;

implementation
uses LogMgr, sysutils, srcBase, CommonHelper, dynamic_caster, basedefs, ConfigCache, TranslationMgr, sysmsgs, DownloadMgr, Synchro, ServerStuff, MapList, xrstrings, BuyWnd, xr_configs, Weapons, Level, HackProcessor, Chat, ItemsCfgMgr, BasicProtection, xr_debug, CSE, TeleportMgr;

const
  SHOP_GROUP = '[SHOP] ';


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

  result:=GetFZBuffer(cl.ps).SlotsBlockCount() > 0;
end;

function GetForceInvincibilityStatus(cl: pxrClientData): FZPlayerInvincibleStatus; stdcall;
begin
  result:=GetFZBuffer(cl.ps).GetForceInvincibilityStatus();
end;

function SetForceInvincibilityStatus(cl: pxrClientData; status: FZPlayerInvincibleStatus): boolean;
begin
  result:=GetFZBuffer(cl.ps).SetForceInvincibilityStatus(status);
end;

function UpdateForceInvincibilityStatus(cl: pxrClientData):FZPlayerInvincibleStatus;
begin
  result:=GetFZBuffer(cl.ps).UpdateForceInvincibilityStatus();
end;

function IsPlayerTeamChangeBlocked(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil', 'IsPlayerTeamChangeBlocked');
  result:=GetFZBuffer(cl.ps).IsTeamChangeBlocked();
end;

procedure SetUpdRate(cl: pxrClientData; updrate: cardinal); stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil', 'SetUpdRate');
  GetFZBuffer(cl.ps).updrate:=updrate;
end;

function UnMutePlayer(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'UnMutePlayer');
  result:=GetFZBuffer(cl.ps).IsMuted();

  if result then begin
    GetFZBuffer(cl.ps).UnMute();
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
    GetFZBuffer(cl.ps).AssignMute(time);
    result:=true;
  end;
end;

function UnBlockPlayerTeamChange(cl: pxrClientData): boolean; stdcall;
begin
  R_ASSERT(cl <> nil, 'client is nil',  'UnBlockPlayerTeamChange');
  result:=GetFZBuffer(cl.ps).IsTeamChangeBlocked();

  if result then begin
    GetFZBuffer(cl.ps).UnBlockTeamChange();
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
    GetFZBuffer(cl.ps).BlockTeamChange(time);
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

constructor FZPlayerStateAdditionalInfo.Create(ps:pgame_PlayerState);
begin
  srcKit.Get.DbgLog('New buffer, '+inttohex(cardinal(self),8));
  InitializeCriticalSection(_lock);
  _valid:=false;
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
end;

procedure FZPlayerStateAdditionalInfo.SetUpdrate(d: cardinal);
begin
  if (d=0) then d:=1;
  if d>1000 then d:=1000;
  self._updrate:=d;
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
        FZLogMgr.Get.Write('Chat mute of player '+GetPlayerName(_my_player)+' is expired.', FZ_LOG_IMPORTANT_INFO);
        self._mute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
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
        FZLogMgr.Get.Write('Player '+GetPlayerName(_my_player)+' chat muted for '+inttostr(_chatmutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
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
        FZLogMgr.Get.Write('Player '+GetPlayerName(_my_player)+' speech messages muted for '+inttostr(_speechmutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
      end;
    end;
    self._last_speech_message_time:=FZCommonHelper.GetGameTickCount();
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
        FZLogMgr.Get.Write('Speech mute of player '+GetPlayerName(_my_player)+' is expired.', FZ_LOG_IMPORTANT_INFO);
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

function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;
begin
  if FZCommonHelper.GetTimeDeltaSafe(GetFZBuffer(cl.ps).last_ready)>FZConfigCache.Get.GetDataCopy.player_ready_signal_interval then begin
    result:=true;
    GetFZBuffer(cl.ps).last_ready:=FZCommonHelper.GetGameTickCount();
    FZLogMgr.Get.Write(GenerateMessageForClientId(cl.base_IClient.ID.id, 'ready, flags='+inttostr(cl.ps.flags__)), FZ_LOG_DBG);
  end else begin
    result:=false;
  end;
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

//Callback for sending download SYSMSGS
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
  SendPacketToClient_LL(data.srv, data.cl_id.id, msg, len, 8, 0);
end;

procedure ExportMapListToClient(srv:pIPureServer; cl_id:ClientID; gameid:cardinal); stdcall;
var
  maplist:FZClientVotingMapList;
  elements:array of FZClientVotingElement;
  translations:array of string;
  helper:pCMapListHelper;
  servermaps_cur:pSGameTypeMaps;
  mapname_cur, mapname_end:pshared_str;
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
  mapname_end:=servermaps_cur.m_map_names.last;
  mapname_cur:=servermaps_cur.m_map_names.start;
  maplist.count:= (mapname_end - mapname_cur)+1;
  setlength(elements, maplist.count);
  setlength(translations, maplist.count);
  maplist.maps:=@elements[0];

  //первый элемент отвечает за очистку списка карт клиента

  elements[0].mapname:=nil;
  elements[0].mapver:=nil;

  for i:=1 to maplist.count-1 do begin
    elements[i].mapname:=get_string_value(mapname_cur);
    elements[i].mapver:='1.0';
    translations[i]:=FZTranslationMgr.Get().TranslateOrEmptySingle(elements[i].mapname);
    if length(translations[i])>0 then begin
      elements[i].description:=PAnsiChar(translations[i]);
    end else begin
      elements[i].description:=nil;
    end;
    mapname_cur:=pointer(mapname_cur)+sizeof(shared_str);
  end;


  userdata.srv:=srv;
  userdata.cl_id:=cl_id;

  while(maplist.count>0) do begin
    SendSysMessage_SOC(@ProcessClientVotingMaplist, @maplist, @SysMsg_SendCallback, @userdata);
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
        SendSysMessage_SOC(@ProcessClientModDll, @moddllinfo, @SysMsg_SendCallback ,@userdata);
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
        SendSysMessage_SOC(@ProcessClientMap, @dlinfo, @SysMsg_SendCallback ,@userdata);
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
begin
  //Клиент прогрузился и окончательно готов к игре, не путать с сигналами при респавне
  GetFZBuffer(cl.ps).valid:=true;
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

  FZLogMgr.Get.Write('Start processing bought items for player '+GetPlayerName(ps)+', money = '+ inttostr(ps.money_for_round)+', warmup='+booltostr(warmup), FZ_LOG_DBG);

  //Сначала проверим на DoS для гарантированной раздачи ништяков хакерам
  for i:=0 to items_count_in_vector(@ps.pItemList, sizeof(word))-1 do begin
    idx:= pWord(get_item_from_vector(@ps.pItemList, i, sizeof(word)))^;
    if CItemMgr__GetItemsCount(game.m_strWeaponsData) <= (integer(idx) and $00FF) then begin
      if FZConfigCache.Get().GetDataCopy().antihacker then begin
        ActiveDefence(ps);
      end else begin
        BadEventsProcessor(FZ_SEC_EVENT_ATTACK, SHOP_GROUP+'DoS from player '+GetPlayerName(ps));
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

    if CheckForShopItemBanned(game, idx, PAnsiChar(GetPlayerName(ps))) then begin
      //Предмет запрещено покупать!
      cl:=PS_to_client(ps);
      if cl<>nil then begin
        SendChatMessageByFreeZone(GetPureServer(), cl.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_banned_item_removed'));
      end;
      remove_item_from_vector(@ps.pItemList, i, sizeof(word));
    end else begin
      cost:= CouldItemBeBought(GetPlayerName(ps), ps.rank, game, idx, warmup, ps.money_for_round + ps.LastBuyAcount, @ps.pItemList);

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
  old_addons:=0;
  pwpn:=dynamic_cast(itm, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CWeapon, false);
  if pwpn<>nil then begin
    old_addons:=pwpn.m_flagsAddOnState;
  end;

  //Посмотрим на секцию удаляемого предмета и получим ее ИДшник в магазине
  sect:=get_string_value(@itm.m_object.NameSection);
  idToBuy:=CItemMgr__GetItemIdx(game.m_strWeaponsData, sect);
  if idToBuy<0 then begin
    FZLogMgr.Get.Write('Item "'+sect+' is not registered in the shop, cannot return money to player; avoid false-positives!', FZ_LOG_IMPORTANT_INFO);
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

      FZLogMgr.Get().Write('Player '+GetPlayerName(ps)+' re-buys (upgrades) '+sect+', full mask 0x'+inttohex(word(pIdOfDesired^), 4), FZ_LOG_DBG);
      break;
    end;
  end;

  //Посчитаем стоимость удаляемого и вернем сумму игроку (в разминке деньги не возвращаем, но флаги для перезакупа проставлять должны
  if not warmup then begin
    cost:=GetItemCostForRank('', ps.rank, game.m_strWeaponsData, sect, old_addons, true, true);
    FZLogMgr.Get().Write('Return '+inttostr(cost)+' credits to player '+GetPlayerName(ps)+' for item '+sect+', full mask 0x'+inttohex(word(idToBuy), 4), FZ_LOG_DBG);
    if cost > 0 then begin
      ps.m_bClearRun:=0;
      game_PlayerAddMoney(game, ps, cost);
    end;
  end;
end;

function BeforeSpawnBoughtItems_DM(ps:pgame_PlayerState; game:pgame_sv_Deathmatch):boolean; stdcall;
begin
  result:=BeforeSpawnBoughtItems(ps, @game.base_game_sv_mp, game.m_bInWarmUp<>0);
end;

procedure BeforeDestroyingSoldItem_DM(itemGameId:word; game:pgame_sv_Deathmatch; ps:pgame_PlayerState; itemsDesired:pxr_vector); stdcall;
var
  itm:pCInventoryItem;
  lvl:pCLevel;
begin
  //Получим CObject по GameID
  lvl:=GetLevel();
  itm:= dynamic_cast(ObjectById(@lvl.base_IGame_Level, itemGameId), 0, xrGame+RTTI_CObject, xrGame+RTTI_CInventoryItem, false);
  if itm=nil then begin
    FZLogMgr.Get.Write('Cannot get object with ID = '+inttostr(itemGameId), FZ_LOG_ERROR);
    exit;
  end;

  //TODO: Для CWeaponAmmo возвращать деньги только за полные пачки патронов

  BeforeDestroyingSoldItem(itm, @game.base_game_sv_mp, game.m_bInWarmUp<>0, ps, itemsDesired);
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
   FZLogMgr.Get.Write('Buy attempt of "'+GetPlayerName(cl.ps)+'" cancelled', FZ_LOG_INFO);
 end;
end;

function IsSpawnFreeAmmoAllowedForGametype(game:pgame_sv_mp):boolean; stdcall;
begin
  result:=false;

  //В артханте спавнить патроны бесплатно нельзя - они ограничены и вполне продаваемы
  if dynamic_cast(game, 0, xrGame+RTTI_game_sv_mp, xrGame+RTTI_game_sv_ArtefactHunt, false) <> nil then exit;

  result:=true;
end;

function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;
begin
  result:=not GetFZBuffer(cl.ps).valid;
  if result then begin
    FZLogMgr.Get.Write('Force removing player state of disconnected client!', FZ_LOG_INFO);
  end;
end;

procedure CorrectPlayerName(s:PAnsiChar); stdcall;
const
  MAX_NICK_LEN:integer=20;
var
  i:integer;
  BannedSymbols:string;
  str:string;
  c:char;
begin
  i:=0;
  str:='';

  //Пробел в начале и конце запрещен для нормальной работы с голосованиями, % для невозможности "цветного" крэша
  BannedSymbols:=FZConfigCache.Get.GetDataCopy().banned_symbols+'%';
  while (i<MAX_NICK_LEN) and (s[i]<>chr(0)) do begin
    c:=s[i];
    if pos(c, BannedSymbols)<>0 then c:='_';

    str:=str+c;
    i:=i+1;
  end;

  str:=trim(str);

  //[bug] Делаем первый символ заглавным - чтобы в клиентском окне старта голосований не срабатывал на имена стандартный сталкерский транслятор строк
  if length(str)>0 then begin
    str[1]:=FZCommonHelper.GetEnglishUppercaseChar(str[1]);
  end else begin
    str:='EmptyNick';
  end;

  //Скопируем модифицированную строку в исходную
  s[0]:=chr(0);
  Move(str[1], s[0], length(str)+1);
end;


function CorrectPlayerNameWhenRenaming(p:pNET_Packet; id:cardinal):boolean; stdcall;
var
  s:PAnsiChar;
  cfg:FZCacheData;
  ban_str, kick_str, vote_str, ban_cmp, kick_cmp:string;
  cld:pxrClientData;
begin
  result:=false;

  cfg:=FZConfigCache.Get.GetDataCopy();
  case cfg.can_player_change_name of
    FZ_CFG_CACHE_CHANGE_NAME_ENABLED: begin
      result:=true;
    end;

    FZ_CFG_CACHE_CHANGE_NAME_WHEN_NO_VOTING: begin
      result:=(GetCurrentGame().m_bVotingActive = 0);
    end;

    FZ_CFG_CACHE_CHANGE_NAME_WHEN_NO_BAN_OR_KICK_VOTE: begin
      if (GetCurrentGame().m_bVotingActive = 0) or (GetCurrentGame().m_bVotingReal=0) then begin
        result:=true;
      end else begin
        cld:=ID_to_client(id);
        vote_str:=trim(lowercase(get_string_value(@GetCurrentGame.m_pVoteCommand)));
        if (cld<>nil) and (length(vote_str)<>0) then begin
          ban_str:='sv_banplayer '+lowercase(GetPlayerName(cld.ps));
          kick_str:='sv_kick '+lowercase(GetPlayerName(cld.ps));
          ban_cmp:=leftstr(vote_str, length(ban_str));
          kick_cmp:=leftstr(vote_str, length(kick_str));
          if (kick_cmp<>kick_str) and (ban_cmp<>ban_str) then begin
            result:=true;
          end;
        end;
      end;
    end;

    else begin
      result:=false;
    end;
  end;

  if not result then begin
    SendChatMessageByFreeZone(GetPureServer(), id, FZTranslationMgr.Get.TranslateSingle('fz_cant_change_name'));
  end else begin
    s:=PAnsiChar(@p.B.data[p.r_pos]);
    CorrectPlayerName(s);

    FZLogMgr.Get.Write(GenerateMessageForClientId(id, ' changes name to "'+s+'"'), FZ_LOG_IMPORTANT_INFO);
  end;
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
    result:=GetPlayerName(cld.ps);
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
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'IsInvincibilityControlledByFZ');
  result:=GetFZBuffer(ps).GetForceInvincibilityStatus()<>FZ_INVINCIBLE_DEFAULT;
end;

function IsInvinciblePersistAfterShot(ps:pgame_PlayerState):boolean; stdcall;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'IsInvinciblePersistAfterShot');
  result:=FZConfigCache.Get().GetDataCopy().invincibility_after_shot;
end;

function GetFZBuffer(ps: pgame_PlayerState): FZPlayerStateAdditionalInfo;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'GetFZBuffer');
  result:=FZPlayerStateAdditionalInfo(ps.FZBuffer);
end;

end.
