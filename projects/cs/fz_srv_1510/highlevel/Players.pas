unit Players;
{$mode delphi}
interface
uses Clients, windows, Servers,PureServer,MatVectors;

type
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


  _badwords_counter:cardinal;

  _my_player:pgame_PlayerState;
  _updrate:cardinal;

  _last_ready_time:cardinal;

  _last_ping_warning_time:cardinal;

  constructor Create(ps:pgame_PlayerState);
public
  procedure SetUpdrate(d:cardinal);
  property updrate:cardinal read _updrate write SetUpdrate;
  property last_ready:cardinal read _last_ready_time write _last_ready_time;
  property valid:boolean read _valid write _valid;

  function IsAllowedStartingVoting():boolean;
  procedure OnVoteStarted();
  procedure OnVote();
  function IsPlayerVoteMuted():boolean;
  procedure AssignVoteMute(time:cardinal);
  procedure AssignSpeechMute(time:cardinal);



  function IsMuted():boolean;
  procedure UnMute();
  procedure AssignMute(time:cardinal);

  function IsSpeechMuted():boolean;

  function OnChatMessage():cardinal;
  function OnSpeechMessage():cardinal;

  function OnBadWordsInChat():cardinal;
  destructor Destroy; override;

end;
//pFZPlayerStateAdditionalInfo=^FZPlayerStateAdditionalInfo;

procedure FromPlayerStateConstructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateDestructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateClear(ps:pgame_PlayerState); stdcall;


procedure DisconnectPlayer(id:ClientID; reason:string); stdcall;
function MutePlayer(id:ClientID; time:cardinal):boolean; stdcall;
function UnMutePlayer(id:ClientID):boolean; stdcall;
procedure SetUpdRate(id:ClientID; updrate:cardinal); stdcall;
procedure KillPlayer(id:ClientID); stdcall;
procedure AddMoney(id:ClientID; amount:integer); stdcall;

procedure modify_player_name (name:PChar; new_name:PChar); stdcall;

function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;
function OnPingWarn(cl:pxrClientData):boolean; stdcall;

function CanChangeName(client:pxrClientData):boolean; stdcall;

procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;
procedure OnClientReady(srv:pIPureServer; cl:pxrClientData); stdcall;

function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;

procedure SendMovePlayersPacket(srv:pIPureServer; cl_id:cardinal; gameid:word; pos:pFVector3; dir:pFVector3); stdcall;

implementation
uses LogMgr, sysutils, srcBase, Level, CommonHelper, dynamic_caster, basedefs, ConfigCache, Games, TranslationMgr, Chat, Packets, sysmsgs, DownloadMgr, Synchro, ServerStuff, NET_Common, MapList;

procedure modify_player_name (name:PChar; new_name:PChar); stdcall;
const
  allowed_symbols:string = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_[]';
  russian_symbols:string = 'абвгдеЄжзийклмнпопрстуфхцчшщъыьэю€јЅ¬√ƒ≈®∆«»… ЋћЌќѕ–—“”‘’÷„ЎўЏџ№Ёёя';
  max_len:integer=20;
var
  i:integer;
begin
  i:=0;
  while (i<max_len) and (name[i]<>chr(0)) do begin
    if (pos(name[i], allowed_symbols)<>0) or (FZConfigCache.Get.GetDataCopy.allow_russian_nicknames and (pos(name[i], russian_symbols) <> 0)) then begin
      new_name[i]:=name[i];
    end else begin
    //пробуем исправить русские буквы на англ
      new_name[i]:=FZCommonHelper.GetEnglishCharFromRussian(name[i]);
    end;
    i:=i+1;
  end;
  if length(name)>0 then begin
    //[bug] ƒелаем первый символ заглавным - чтобы в клиентском окне старта голосований не срабатывал на имена стандартный сталкерский трансл€тор строк
    new_name[0]:=FZCommonHelper.GetEnglishUppercaseChar(new_name[0]);
  end;
  new_name[i]:=chr(0);
end;


/////////////////////////////////////////////////////
function DoAddMoney(player:pointer{pIClient}; pcardinal_id:pointer; amount:pointer):boolean; stdcall;
var
  cl_d:pxrClientData;
  lvl:pCLevel;
begin
  result:=false;
  cl_d:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cl_d<>nil) and (g_ppGameLevel^<>nil) then begin
    lvl:=pCLevel(g_ppGameLevel^);
    virtual_game_sv_mp__Player_AddMoney.Call([lvl.Server.game, cl_d.ps, pcardinal(amount)^])
  end;
end;

procedure AddMoney(id:ClientID; amount:integer); stdcall;
begin
  ForEachClientDo(DoAddMoney, OneIDSearcher, @id.id, @amount);
end;

/////////////////////////////////////////////////////
function DoKillPlayer(player:pointer{pIClient}; pcardinal_id:pointer; junk:pointer):boolean; stdcall;
var
  cl_d:pxrClientData;
  lvl:pCLevel;
begin
  result:=false;
  cl_d:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cl_d<>nil) and (g_ppGameLevel^<>nil) then begin
    lvl:=pCLevel(g_ppGameLevel^);
    game_sv_mp__KillPlayer.Call([lvl.Server.game, cl_d.base_IClient.ID.id, cl_d.ps.GameID])
  end;
end;

procedure KillPlayer(id:ClientID); stdcall;
begin
  ForEachClientDo(DoKillPlayer, OneIDSearcher, @id.id);
end;

/////////////////////////////////////////////////////
function DoSetUpdRate(player:pointer{pIClient}; pcardinal_id:pointer; val:pointer):boolean; stdcall;
var
  cl_d:pxrClientData;
begin
  result:=false;
  cl_d:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cl_d<>nil then begin
    FZPlayerStateAdditionalInfo(cl_d.ps.FZBuffer).updrate:=PCardinal(val)^;
  end;
end;

procedure SetUpdRate(id:ClientID; updrate:cardinal); stdcall;
begin
  ForEachClientDo(DoSetUpdRate, OneIDSearcher, @id.id, @updrate);
end;
/////////////////////////////////////////////////////
function DoUnMutePlayer(player:pointer{pIClient}; pcardinal_id:pointer; res:pointer):boolean; stdcall;
var
  cl_d:pxrClientData;
begin
  result:=false;
  cl_d:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cl_d<>nil then begin
    FZPlayerStateAdditionalInfo(cl_d.ps.FZBuffer).UnMute();
    pboolean(res)^:=1 ;//true;
  end;
end;

function UnMutePlayer(id:ClientID):boolean; stdcall;
begin
  if time>0 then begin
    result:=false;
    ForEachClientDo(DoUnMutePlayer, OneIDSearcher, @id.id, @result);
  end;
end;

/////////////////////////////////////////////////////
function DoMutePlayer(player:pointer{pIClient}; pcardinal_id:pointer; pcardinal_time:pointer):boolean; stdcall;
var
  cl_d:pxrClientData;
begin
  result:=false;
  cl_d:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cl_d<>nil then begin
    FZPlayerStateAdditionalInfo(cl_d.ps.FZBuffer).AssignMute(pcardinal(pcardinal_time)^);
    pcardinal(pcardinal_time)^:=0;
  end;
end;

function MutePlayer(id:ClientID; time:cardinal):boolean; stdcall;
begin
  result:=false;
  if time>0 then begin
    ForEachClientDo(DoMutePlayer, OneIDSearcher, @id.id, @time);
    result:=(time=0);
  end;
end;

/////////////////////////////////////////////////////
function DoDisconnectPlayer(player:pointer{pIClient}; pcardinal_id:pointer; pchar_reason:pointer):boolean; stdcall;
var
  l:pCLevel;
  sv:pxrServer;
begin
  result:=true;
  if pchar_reason=nil then exit;

  l:=pCLevel(g_ppGameLevel^);
  if l=nil then exit;

  sv:=l.Server;
  if sv=nil then exit;

  virtual_IPureServer__DisconnectClient.Call([@sv.base_IPureServer, player, PChar(pchar_reason)]);
  result:=false;
end;

procedure DisconnectPlayer(id:ClientID; reason:string); stdcall;
begin
  ForEachClientDo(DoDisconnectPlayer, OneIDSearcher, @id.id, PChar(reason));
end;
/////////////////////////////////////////////////////

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

  _updrate:=0;
  _last_ready_time:=0;
  _last_ping_warning_time:=0;
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

function FZPlayerStateAdditionalInfo.IsAllowedStartingVoting: boolean;
begin
  EnterCriticalSection(_lock);
  try
    if IsPlayerVoteMuted then begin
      //≈сли игроку запрещено даже просто голосовать - то и про способность начать голосование можно забыть
      result:=false;
    end else begin
      //если игрок один на сервере - пусть делает, что хочет
      result:= (CurPlayersCount()<=2) or (self._last_started_voted_time=0) or (FZConfigCache.Get.GetDataCopy.vote_mute_time_ms=0) or (FZCommonHelper.GetTimeDeltaSafe(self._last_started_voted_time)>=FZConfigCache.Get.GetDataCopy.vote_mute_time_ms);
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsMuted: boolean;
begin
  EnterCriticalSection(_lock);
  try
    if self._mute_time_period = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._mute_start_time)<self._mute_time_period;
      if not result then begin
        FZLogMgr.Get.Write('Chat mute of player '+PChar(@self._my_player.name)+' is expired.');
        self._mute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsPlayerVoteMuted: boolean;
begin
  EnterCriticalSection(_lock);
  try
    if self._votes_mute_time_period = 0 then begin
      result:=false;
    end else begin
      result:=FZCommonHelper.GetTimeDeltaSafe(self._votes_mute_start_time)<self._votes_mute_time_period;
      if not result then begin
        FZLogMgr.Get.Write('Vote mute of player '+PChar(@self._my_player.name)+' is expired.');
        self._votes_mute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.IsSpeechMuted: boolean;
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
        FZLogMgr.Get.Write('Speech mute of player '+PChar(@self._my_player.name)+' is expired.');
        self._speechmute_time_period:=0;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnBadWordsInChat: cardinal;
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

function FZPlayerStateAdditionalInfo.OnChatMessage:cardinal;
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
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' chat muted for '+inttostr(_chatmutes_count)+' time(s)');
      end;
    end;
    self._last_chat_message_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZPlayerStateAdditionalInfo.OnSpeechMessage: cardinal;
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
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' speech messages muted for '+inttostr(_speechmutes_count)+' time(s)');
      end;
    end;
    self._last_speech_message_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.OnVote;
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
        //ƒобби должен быть наказан...
        _votemutes_count:=_votemutes_count+1;
        AssignVoteMute(_votemutes_count*_data.vote_first_mute_time);
        FZLogMgr.Get.Write('Player '+PChar(@_my_player.name)+' votes muted for '+inttostr(_votemutes_count)+' time(s)');
      end;
    end;

    self._last_vote_time:=FZCommonHelper.GetGameTickCount();
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZPlayerStateAdditionalInfo.OnVoteStarted;
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
  if (d<>0) and (d<10) then d:=10;
  if d>1000 then d:=1000;
  self._updrate:=d;
end;

procedure FZPlayerStateAdditionalInfo.UnMute;
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
    DisconnectPlayer(cl.base_IClient.ID, FZTranslationMgr.Get.TranslateSingle('fz_ping_limit_exceeded'));
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
  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendMovePlayersPacket(srv:pIPureServer; cl_id:cardinal; gameid:word; pos:pFVector3; dir:pFVector3); stdcall;
var
  p:NET_Packet;
  s:string;
  b:byte;
  c:cardinal;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_MOVE_PLAYERS, sizeof(M_MOVE_PLAYERS)); //хидер
  b:=3;
  WriteToPacket(@p, @b, sizeof(b)); //count
  WriteToPacket(@p, @gameid, sizeof(gameid));
  WriteToPacket(@p, pos, sizeof(FVector3));
  WriteToPacket(@p, dir, sizeof(FVector3));


  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

function CanChangeName(client:pxrClientData):boolean; stdcall;
begin
  result:=FZConfigCache.Get.GetDataCopy.can_player_change_name;
  if not result then begin
    SendChatMessageByFreeZone(@(pCLevel(g_ppGameLevel^).Server.base_IPureServer), client.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_cant_change_name'));
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
  IPureServer__SendTo_LL.Call([data.srv, data.cl_id.id, msg, len, $100+$8+$80, 0]);
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
    FZLogMgr.Get.Write('No gametype in maplist, id='+inttostr(gameid), true);
    exit;
  end;

  //—оставим список карт дл€ экспорта
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
    elements[i].mapname:=@mapitm_cur.map_name.p_.value;
    elements[i].mapver:=@mapitm_cur.map_ver.p_.value;
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
    SendSysMessage(@ProcessClientVotingMaplist, @maplist, @SysMsg_SendCallback, @userdata);
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
  mapname, mapver, maplink, link, xml:string;
  dl_msg, err_msg:string;
  filename:string;
  need_dl:boolean;
  userdata:FZSysMsgSendCallbackData;

  gamedescr:GameDescriptionData;
  buf:FZClientVotingElement;
  mapname2:string;
begin
  xrCriticalSection__Enter(@srv.base_IPureServer.net_players.csPlayers);
  try
    userdata.srv:=@srv.base_IPureServer;
    userdata.cl_id:=cl.ID;

    if ((cl.flags and ICLIENT_FLAG_LOCAL)<>0) or not CheckForClientExist(srv, cl) then exit;
    dat:=FZConfigCache.Get.GetDataCopy();

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
      dl_msg:=FZTranslationMgr.Get().Translate('fz_map_downloading');
      err_msg:=FZTranslationMgr.Get().Translate('fz_already_has_download');
      xml:=FZDownloadMgr.Get.GetXMLName(mapname, mapver);

      dlinfo.fileinfo.filename:=PAnsiChar(filename);
      dlinfo.fileinfo.progress_msg:=PAnsiChar(dl_msg);
      dlinfo.fileinfo.error_already_has_dl_msg:=PAnsiChar(err_msg);
      dlinfo.fileinfo.crc32:=FZDownloadMgr.Get.GetCRC32(mapname, mapver, need_dl);
      dlinfo.fileinfo.compression:=FZDownloadMgr.Get.GetCompressionType(mapname, mapver);

      dlinfo.reconnect_addr.ip:=PAnsiChar(dat.reconnect_ip);
      dlinfo.reconnect_addr.port:=dat.reconnect_port;
      dlinfo.mapver:=PAnsiChar(mapver);
      dlinfo.mapname:=PAnsiChar(mapname);
      dlinfo.xmlname:=PAnsiChar(xml);

      if not need_dl then begin
        // онтрольна€ сумма не найдена, просто сообщаем
        FZLogMgr.Get.Write('No CRC32 for map '+mapname+', ver '+mapver);
      end else begin
        FZLogMgr.Get.Write('Send DOWNLOAD packet for '+mapname+', ver.='+mapver);
        SendSysMessage(@ProcessClientMap, @dlinfo, @SysMsg_SendCallback ,@userdata);
      end;
    end;

    // TODO: отправл€ть при загрузке
    if dat.enable_maplist_sync then begin
      ExportMapListToClient(@srv.base_IPureServer, cl.ID, srv.game.base_game_GameState.m_type);
    end;

  finally
    xrCriticalSection__Leave(@srv.base_IPureServer.net_players.csPlayers);
  end;
end;

procedure OnClientReady(srv:pIPureServer; cl:pxrClientData); stdcall;
begin
  FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).valid:=true;
end;

function xrServer__client_Destroy_force_destroy(cl:pxrClientData):boolean; stdcall;
begin
  result:=not FZPlayerStateAdditionalInfo(cl.ps.FZBuffer).valid;
  if result then begin
    FZLogMgr.Get.Write('Force removing player state of disconnected client!');
  end;
end;

end.
