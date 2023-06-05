unit Players;

{$mode delphi}

interface
uses Servers, Clients, windows;

type

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
  {_last_vote_time:cardinal;
  _last_vote_series:cardinal;
  _votemutes_count:cardinal;}
  _last_chat_message_time:cardinal;
  _chat_messages_series:cardinal;
  _chatmutes_count:cardinal;

  {_last_speech_message_time:cardinal;
  _speech_messages_series:cardinal;
  _speechmutes_count:cardinal;
  _speechmute_start_time:cardinal;
  _speechmute_time_period:cardinal;

  _teamchangeblock_start_time:cardinal;
  _teamchangeblock_time_period:cardinal;}

  _badwords_counter:cardinal;

  _my_player:pgame_PlayerState;
  {_updrate:cardinal;}

  _last_ready_time:cardinal;

  {_last_ping_warning_time:cardinal;

  _slots_block_counter:cardinal;

  _hwid:string;
  _hwhash:string;
  _orig_cdkey_hash:string;
  _hwid_received:boolean;

  _force_invincibility_cur:FZPlayerInvincibleStatus;
  _force_invincibility_next:FZPlayerInvincibleStatus;}

  {%H-}constructor Create(ps:pgame_PlayerState);
public
  {procedure SetUpdrate(d:cardinal);
  procedure SetHwId(hwid:string; hwhash:string);
  function GetHwId(allow_old:boolean):string;
  function GetHwHash(allow_old:boolean):string;
  procedure SetOrigCdkeyHash(hash:string);
  function GetOrigCdkeyHash():string;

  function GetHwhashSaceStatus():integer;

  property updrate:cardinal read _updrate write SetUpdrate; }
  property last_ready:cardinal read _last_ready_time write _last_ready_time;
  {property valid:boolean read _valid write _valid;
  property connected_and_ready: boolean read _connected_and_ready write _connected_and_ready;}

  function IsAllowedStartingVoting():boolean;
  procedure OnVoteStarted();
  {procedure OnVote();}
  function IsPlayerVoteMuted():boolean;
  procedure AssignVoteMute(time:cardinal);
  {procedure AssignSpeechMute(time:cardinal);

  procedure OnDisconnected();

  function GetForceInvincibilityStatus():FZPlayerInvincibleStatus;
  function SetForceInvincibilityStatus(status:FZPlayerInvincibleStatus):boolean;
  function UpdateForceInvincibilityStatus():FZPlayerInvincibleStatus;}

  function IsMuted():boolean;
  procedure UnMute();
  procedure AssignMute(time:cardinal);

  {function IsSpeechMuted():boolean;}

  function OnChatMessage():cardinal;
  {function OnSpeechMessage():cardinal;

  function IsTeamChangeBlocked():boolean;
  procedure BlockTeamChange(time:cardinal);
  procedure UnBlockTeamChange();
  function OnTeamChange():boolean;

  function SlotsBlockCount(delta:integer = 0):cardinal;
  procedure ResetSlotsBlockCount();    }

  function OnBadWordsInChat():cardinal;
  destructor Destroy; override;
end;


procedure FromPlayerStateConstructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateDestructor(ps:pgame_PlayerState); stdcall;
procedure FromPlayerStateClear({%H-}ps:pgame_PlayerState); stdcall;

function MutePlayer(cl: pxrClientData; time:cardinal):boolean; stdcall;
function UnMutePlayer(cl: pxrClientData):boolean; stdcall;

procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;

function CheckPlayerReadySignalValidity(cl:pxrClientData):boolean; stdcall;

function GenerateMessageForClientId(id:cardinal; message: string):string;

function GetFZBuffer(ps:pgame_PlayerState):FZPlayerStateAdditionalInfo;

function Init():boolean;
procedure Clean();

implementation
uses Packets, xrstrings, sysutils, PureServer, sysmsgs, MapList, LogMgr, TranslationMgr, ConfigCache, Synchro, DownloadMgr, ServerStuff, srcBase, xr_debug, CommonHelper;

var
  _ps_buffers:array of FZPlayerStateAdditionalInfo;
  _ps_lock:TRtlCriticalSection;

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
  {_last_vote_time:=0;
  _last_vote_series:=0;
  _votemutes_count:=0;}
  _badwords_counter:=0;
  _last_chat_message_time:=0;
  _chat_messages_series:=0;
  _chatmutes_count:=0;
  {_last_speech_message_time:=0;
  _speech_messages_series:=0;
  _speechmutes_count:=0;
  _speechmute_start_time:=0;
  _speechmute_time_period:=0;
  _teamchangeblock_start_time:=0;
  _teamchangeblock_time_period:=0;
  _slots_block_counter:=0;
  _updrate:=0;}
  _last_ready_time:=0;
  {_last_ping_warning_time:=0;
  _hwid:='';
  _hwhash:='';
  _orig_cdkey_hash:='';
  _hwid_received:=false;
  _force_invincibility_cur:=FZ_INVINCIBLE_DEFAULT;
  _force_invincibility_next:=FZ_INVINCIBLE_DEFAULT; }
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
var
  i:integer;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'FromPlayerStateConstructor');
  EnterCriticalSection(_ps_lock);
  try
    i:=length(_ps_buffers);
    setlength(_ps_buffers, i+1);
    _ps_buffers[i] :=FZPlayerStateAdditionalInfo.Create(ps);
  finally
    LeaveCriticalSection(_ps_lock);
  end;

  if FZLogMgr.Get.IsSeverityLogged(FZ_LOG_DBG) then begin
    FZLogMgr.Get.Write('PS created for '+inttohex(cardinal(ps), 8)+': '+inttohex(cardinal(@_ps_buffers[i]), 8)+', cnt = '+inttostr(i+1), FZ_LOG_IMPORTANT_INFO);
  end;
end;

procedure FromPlayerStateDestructor(ps:pgame_PlayerState); stdcall;
var
  i, idx:integer;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'FromPlayerStateDestructor');

  if FZLogMgr.Get.IsSeverityLogged(FZ_LOG_DBG) then begin
    FZLogMgr.Get.Write('PS destroying for '+inttohex(cardinal(ps), 8)+': '+inttohex(cardinal(@_ps_buffers[i]), 8)+', cnt = '+inttostr(length(_ps_buffers)-1), FZ_LOG_DBG);
  end;

  EnterCriticalSection(_ps_lock);
  try
    idx:=-1;
    for i:=0 to length(_ps_buffers)-1 do begin
      if _ps_buffers[i]._my_player = ps then begin
        idx:=i;
        break;
      end;
    end;
    R_ASSERT(idx >= 0, 'cannot find ps for FZ buffer', 'FromPlayerStateDestructor');

    _ps_buffers[i].Free;

    if length(_ps_buffers) > 1 then begin
      _ps_buffers[i]:=_ps_buffers[length(_ps_buffers)-1]
    end;
    setlength(_ps_buffers, length(_ps_buffers)-1);
  finally
    LeaveCriticalSection(_ps_lock);
  end;
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
        FZLogMgr.Get.Write('Chat mute of player '+GetPlayerName(_my_player)+' is expired.', FZ_LOG_IMPORTANT_INFO);
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
        FZLogMgr.Get.Write('Vote mute of player '+GetPlayerName(_my_player)+' is expired.', FZ_LOG_IMPORTANT_INFO);
        self._votes_mute_time_period:=0;
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
        FZLogMgr.Get.Write('Player '+GetPlayerName(_my_player)+' chat muted for '+inttostr(_chatmutes_count)+' time(s)', FZ_LOG_IMPORTANT_INFO);
      end;
    end;
    self._last_chat_message_time:=FZCommonHelper.GetGameTickCount();
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
  if FZCommonHelper.GetTimeDeltaSafe(GetFZBuffer(cl.ps).last_ready)>FZConfigCache.Get.GetDataCopy.player_ready_signal_interval then begin
    result:=true;
    GetFZBuffer(cl.ps).last_ready:=FZCommonHelper.GetGameTickCount();
  end else begin
    result:=false;
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
    SendSysMessage_COP(@ProcessClientVotingMaplist, @maplist, @SysMsg_SendCallback, @userdata);
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
        SendSysMessage_COP(@ProcessClientModDll, @moddllinfo, @SysMsg_SendCallback ,@userdata);
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
        SendSysMessage_COP(@ProcessClientMap, @dlinfo, @SysMsg_SendCallback ,@userdata);
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

function GetNameAndIpByClientId(id:cardinal; var ip:string; var name:string):boolean; stdcall;
var
  cld:pxrClientData;
begin
  ip:='0.0.0.0';
  name:='';
  result:=false;

  cld:=ID_to_client(id);
  if (cld<>nil) then begin
    ip:=ip_address_to_str(cld.base_IClient.m_cAddress);

    if (cld.ps <> nil) then begin
      name:=GetPlayerName(cld.ps);
    end;

    if length(name) = 0 then begin
      name:=get_string_value(@cld.base_IClient.name);
    end;
  end;

  if length(name) = 0 then begin
    name:='(null)';
  end else begin
    result:=true;
  end;
end;

function GenerateMessageForClientId(id:cardinal; message: string):string;
var
  name, ip:string;
begin
  ip:='';
  name:='';
  GetNameAndIpByClientId(id, ip, name);
  result:='Player "'+name+'" (ID='+inttostr(id)+', IP='+ip+') '+message;
end;

function GetFZBuffer(ps: pgame_PlayerState): FZPlayerStateAdditionalInfo;
var
  i:integer;
begin
  R_ASSERT(ps<>nil, 'ps is nil', 'GetFZBuffer');
  EnterCriticalSection(_ps_lock);
  try
    for i:=0 to length(_ps_buffers)-1 do begin
      if _ps_buffers[i]._my_player = ps then begin
        result:=_ps_buffers[i];
        break;
      end;
    end;
  finally
    LeaveCriticalSection(_ps_lock);
  end;
end;

function Init(): boolean;
begin
  setlength(_ps_buffers, 0);
  InitializeCriticalSection(_ps_lock);
  result:=true;
end;

procedure Clean();
begin
  setlength(_ps_buffers, 0);
  DeleteCriticalSection(_ps_lock);
end;

end.

