unit ServerStuff;

{$mode delphi}

interface
uses Servers, Packets, PureServer, Clients,NET_common, CSE, Games, Hits;

type
FZServerState = record
  lock:TRTLCriticalSection;
  mapname:string;
  mapver:string;
  maplink:string;
end;


procedure xrGameSpyServer_constructor_reserve_zerogameid(srv:pxrServer); stdcall;
function OnGameEventDelayedHitProcessing(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
function game__OnEvent_SelfKill_Check(target:pxrClientData; senderid:cardinal):boolean; stdcall;
function OnGameEvent_CheckClientExist(p: pNET_Packet; msgid:word; clid: cardinal): boolean; stdcall;
procedure OnGameEventNotImplenented(p: pNET_Packet; msgid: word; clid: cardinal); stdcall;
function OnGameEventPlayerKilled(p:pNET_Packet; clid:cardinal):boolean; stdcall;
function OnGameEventPlayerHitted(p:pNET_Packet; clid:cardinal):boolean; stdcall;

function Check_xrClientData_owner_valid(ptr:pxrClientData):boolean; stdcall;

function game_sv__OnDetach_isitemremovingneeded(item:pCSE_Abstract):boolean; stdcall;
function game_sv__OnDetach_isitemtransfertobagneeded(item:pCSE_Abstract):boolean; stdcall;
procedure game_sv_Deathmatch__OnDetach_destroyitems(game:pgame_sv_mp; pfirst_item:ppCSE_Abstract; plast_item:ppCSE_Abstract); stdcall;


procedure game_sv_mp__Update_additionals(); stdcall;

function game_sv_mp__Update_could_corpse_be_removed(corpse:pCSE_Abstract):boolean; stdcall;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
procedure xrServer__Connect_SaveCurrentMapInfo(gametype:PAnsiChar); stdcall;
procedure CLevel__net_Start_overridelevelgametype(); stdcall;

procedure xrServer__OnMessage_additional(srv:pIPureServer; p:pNET_Packet; sender:ClientID ); stdcall;

function IPureServer__GetClientAddress_check_arg(pClientAddress:pointer; Address:pip_address; pPort:pcardinal):boolean; stdcall;

procedure NET_Packet__w_checkOverflow(p:pNET_Packet; count:cardinal); stdcall;
procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;

function game_sv_mp__OnPlayerGameMenu_isteamchangeblocked(clid:cardinal; p:pNET_Packet):boolean; stdcall;

function game_sv_TeamDeathmatch__OnPlayerConnect_selectteam(ps:pgame_PlayerState; autoteam: integer): integer; stdcall;

procedure xrServer__Process_event_onweaponhide(msgid:cardinal; clid:cardinal; p:pNET_Packet); stdcall;
procedure game_sv_mp_OnSpawnPlayer(clid:cardinal; section:PAnsiChar); stdcall;

function OnTeamKill(killer:pgame_PlayerState; victim:pgame_PlayerState):boolean; stdcall;
procedure OnHitInvincible(hit:PSHit); stdcall;
procedure OnTeamHit_FriendlyFire(killer:pgame_PlayerState; victim:pgame_PlayerState; hit:pSHit); stdcall;

procedure game_sv_mp__Player_AddExperience_expspeed(experience:psingle); stdcall;

procedure DisconnectPlayerWithMessage(cl:pIClient; disconnect_type:integer); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, ConfigCache, Windows, ItemsCfgMgr, clsids, xrstrings, HackProcessor, Players, CommonHelper, Level, Objects, xr_debug, Voting, sysmsgs, TranslationMgr, AdminCommands, Chat, InventoryItems, Console, dynamic_caster, basedefs, TeleportMgr, HitMgr;

const
  HITS_GROUP:string='[HIT] ';

  MAP_SETTINGS_FILE:string='fz_mapname.txt';

var
  _serverstate:FZServerState;

procedure xrGameSpyServer_constructor_reserve_zerogameid(srv:pxrServer); stdcall;
begin
  FZLogMgr.Get.Write('Reserving zero game ID', FZ_LOG_INFO);
  ReserveGameID(srv, 0);
end;

function game__OnEvent_SelfKill_Check(target:pxrClientData; senderid:cardinal):boolean; stdcall;
var
  local_cl:pxrClientData;
begin
  local_cl:=GetServerClient();
  if (local_cl = nil) or (local_cl.base_IClient.ID.id = senderid) then begin
    result:=true;
    exit;
  end;

  fzlogmgr.get.write('Player '+PChar(@target.ps.name[0])+' wants to die', FZ_LOG_INFO);
  result:=(target.base_IClient.ID.id = senderid);
end;

function GetNameFromClientdata(cld:pxrClientData; gameid:word):string;
var
  obj:pCSE_Abstract;
  game:pgame_sv_mp;
begin
  if cld = nil then begin
    result := '(null)';
    game:=GetCurrentGame();
    obj:=EntityFromEid(@game.base_game_sv_GameState, gameid);
    if obj<>nil then begin
      result:='['+get_string_value(@obj.s_name)+']';
    end;
  end else begin
    result:= cld.ps.name;
  end;
end;

//Проверка корректности сообщения GAME_EVENT_PLAYER_HITTED и GAME_EVENT_PLAYER_KILLED
function CheckForLocalHitterOrVictim(sender_clid:cardinal; victim_gameid:pword; killer_gameid:pword; onlylocalsender:boolean; try_correct_hitter:boolean):boolean;
var
  local_client:pxrClientData;
  victim_ps, killer_ps:pgame_PlayerState;
  pGame:pgame_sv_mp;
begin
  result:=false;
  local_client:=GetServerClient();
  if (local_client = nil) or (local_client.ps = nil) then begin
    FZLogMgr.Get().Write('Cannot get local player while checking hit / kill!', FZ_LOG_ERROR);
    result:=true;
    exit;
  end;

  if onlylocalsender and (sender_clid <> local_client.base_IClient.ID.id) then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, HITS_GROUP + GenerateMessageForClientId(sender_clid, '" tries to send server-only hit message'));
    exit;
  end;

  pGame:=GetCurrentGame();
  R_ASSERT(pGame<>nil, 'Cannot get game while checking hit for local player');

  victim_ps := GetPlayerStateByGameID(@pGame.base_game_sv_GameState, victim_gameid^);
  killer_ps := GetPlayerStateByGameID(@pGame.base_game_sv_GameState, killer_gameid^);

  //Теперь убедимся, что локальный клиент не захитован и не сделал хит. Опасность возникает только в случае, когда там напрямую указан GameID локального клиента-спектатора!
  //В противном случае game_sv_GameState::get_eid никогда не вернет локального клиента.
  //Но все-таки лучше сделать и через get_eid... На всякий
  if (local_client.ps.GameID = victim_gameid^) or (victim_ps = local_client.ps) then begin
    FZLogMgr.Get.Write('Local client is a victim in the hit message, skip the message', FZ_LOG_ERROR );
    exit;
  end;

  if (local_client.ps.GameID = killer_gameid^) or (killer_ps = local_client.ps) then begin
    if try_correct_hitter then begin
      FZLogMgr.Get.Write('Local client is a hitter in the hit message, force victim to be self-killed', FZ_LOG_ERROR );
      killer_gameid^:=victim_gameid^;
    end else begin
      FZLogMgr.Get.Write('Local client is a hitter in the hit message, skip the message', FZ_LOG_ERROR );
      exit;
    end;
  end;

  result:=true;
end;

function OnGameEvent_CheckClientExist(p: pNET_Packet; msgid:word; clid: cardinal): boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=true;

  cld:=ID_to_client(clid);
  if cld=nil then begin
    //Игрока, отправившего сообщение, почему-то нет на сервере. Вероятно, он отсоединился, а сообщение осталось висеть в очереди.
    //Ситуация опасна крешем - не во всех местах есть проверки
    if (msgid <> GAME_EVENT_PLAYER_CONNECTED) and
       (msgid <> GAME_EVENT_PLAYER_DISCONNECTED) and
       (msgid <> GAME_EVENT_PLAYER_KILLED) and
       (msgid <> GAME_EVENT_PLAYER_HITTED)
    then begin
      result:=false;
    end;

    if not result then begin
      FZLogMgr.Get().Write('CL ID '+inttostr(clid)+' not found, message #'+inttostr(msgid)+' skipped', FZ_LOG_DBG);
    end;
  end;
end;

procedure OnGameEventNotImplenented(p: pNET_Packet; msgid: word; clid: cardinal); stdcall;
begin
  BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GenerateMessageForClientId(clid, 'sent invalid game event('+inttostr(msgid)+')'));
end;

function OnGameEventPlayerHitted(p:pNET_Packet; clid:cardinal):boolean; stdcall;
begin
  //GAME_EVENT_PLAYER_HITTED серверу может отправлять только локальный клиент!
  result:=CheckForLocalHitterOrVictim(clid, pword(@p.B.data[p.r_pos]), pword(@p.B.data[p.r_pos+sizeof(word)]), true, true);
end;

function OnGameEventPlayerKilled(p:pNET_Packet; clid:cardinal):boolean; stdcall;
begin
  //GAME_EVENT_PLAYER_KILLED серверу может отправлять только локальный клиент!
  result:=CheckForLocalHitterOrVictim(clid, pword(@p.B.data[p.r_pos]), pword(@p.B.data[p.r_pos+sizeof(word)+sizeof(byte)]), true, true);
end;

function HitLogger(victim:pxrClientData; hitter:pxrClientData; hit:pSHit; check_state:FZHitCheckResult):string;
var
  hit_stat_mode:cardinal;
  victim_str, hitter_str, weapon_str:string;
  severity:FZLogMessageSeverity;
  msg:string;
begin
  //1 - Пишем стату по всем хитам
  //2 - Пишем стату по хитам, прилетающим от одного игрока в другого
  hit_stat_mode:=FZConfigCache.Get.GetDataCopy.hit_statistics_mode;

  result:='';
  if (check_state=FZ_HIT_BAD) or (hit_stat_mode = 1) or ((hit_stat_mode = 2) and (hitter<>nil) and (victim<>nil)) then begin
    victim_str := GetNameFromClientdata(victim, hit.DestID);
    hitter_str := GetNameFromClientdata(hitter, hit.whoID);

    if (hit.whoID <> hit.weaponID) then begin
      weapon_str := GetNameFromClientdata(nil, hit.weaponID);
      hitter_str:=hitter_str+' '+weapon_str;
    end;

    msg:= HITS_GROUP;
    if check_state=FZ_HIT_BAD then begin
      severity:=FZ_LOG_ERROR;
      msg:=msg+'[BAD] ';
     end else if check_state=FZ_HIT_BAD then begin
       severity:=FZ_LOG_IMPORTANT_INFO;
       msg:=msg+'[IGNORED] ';
     end else begin
      severity:=FZ_LOG_IMPORTANT_INFO;
     end;

    msg:= msg+hitter_str+' -> '+victim_str+
          ' (T='+inttostr(hit.hit_type)+
          ', P='+FZCommonHelper.FloatToString(hit.power, 4,2)+
          ', I='+FZCommonHelper.FloatToString(hit.impulse, 4,2)+
          ', B='+inttostr(hit.boneID)+
          ', AP='+FZCommonHelper.FloatToString(hit.armor_piercing, 4,2)+
          ')';

    FZLogMgr.Get.Write(msg, severity);
    result:=msg;
  end;
end;

function CorrectHitPower(hitter:pxrClientData; victim:pxrClientData; hit:pSHit; out_power:psingle):boolean;
var
  cfg:FZCacheData;
  stat_factor, hit_factor:single;
  deathes, frags:integer;
const
  FULLSPEED_CONST_PLAYERS_COUNT:integer = 4;
  FULLSPEED_VAR_PLAYERS_COUNT:integer = 8;
begin
  result:=false;
  cfg:=FZConfigCache.Get().GetDataCopy();

  if (out_power<>nil) and (hitter<>nil) and (victim<>nil) then begin
    //Проверяем на необходимость коррекции урона, наносимого другим игрокам (для усложнения жизни игрокам с высокой статой)
    out_power^:=hit.power;

    if (cfg.damage_correction_highscore_treasure > 0) and (victim.ps<>nil) and ((victim.ps.m_iRivalKills >= FULLSPEED_CONST_PLAYERS_COUNT+FULLSPEED_VAR_PLAYERS_COUNT) or (victim.ps.m_iRivalKills > (FULLSPEED_CONST_PLAYERS_COUNT+random(FULLSPEED_VAR_PLAYERS_COUNT)) )) then begin
      deathes:=victim.ps.m_iDeaths;
      if deathes<=0 then deathes:=1;

      frags:= victim.ps.m_iRivalKills - victim.ps.m_iSelfKills - victim.ps.m_iTeamKills;
      if frags < 0 then frags:=0;

      stat_factor:= frags / deathes;
      if (stat_factor > cfg.damage_correction_highscore_treasure) then begin
        //Хит нанесен игроку с высокой статой, увеличиваем его
        hit_factor:=cfg.damage_correction_highscore_speed * (1 + stat_factor-cfg.damage_correction_highscore_treasure);
        if (hit_factor > cfg.damage_correction_highscore_limit) or (hit_factor < 0) then hit_factor:=cfg.damage_correction_highscore_limit;
        if FZLogMgr.Get.IsSeverityLogged(FZ_LOG_DBG) then begin
          FZLogMgr.Get().Write('Apply damage scaler '+FZCommonHelper.FloatToString(hit_factor, 4, 2)+' to high-score player "'+PAnsiChar(@victim.ps.name[0])+'"', FZ_LOG_DBG);
        end;
        out_power^ := out_power^ * hit_factor;
        result:=true;
      end;
    end;

    if (cfg.hit_correction_highscore_treasure > 0) and (hitter.ps<>nil) and ((hitter.ps.m_iRivalKills >= FULLSPEED_CONST_PLAYERS_COUNT+FULLSPEED_VAR_PLAYERS_COUNT) or (hitter.ps.m_iRivalKills > (FULLSPEED_CONST_PLAYERS_COUNT+random(FULLSPEED_VAR_PLAYERS_COUNT)) )) then begin
      deathes:=hitter.ps.m_iDeaths;
      if deathes<=0 then deathes:=1;

      frags:= hitter.ps.m_iRivalKills - hitter.ps.m_iSelfKills - hitter.ps.m_iTeamKills;
      if frags < 0 then frags:=0;

      stat_factor:=frags / deathes;
      if (stat_factor > cfg.hit_correction_highscore_treasure) then begin
        //Хит нанесен игроком с высокой статой, уменьшаем его
        hit_factor:=(cfg.hit_correction_highscore_speed * (1 + stat_factor-cfg.hit_correction_highscore_treasure));
        if (hit_factor > cfg.hit_correction_highscore_limit) or (hit_factor < 0) then hit_factor:=cfg.hit_correction_highscore_limit;
        if FZLogMgr.Get.IsSeverityLogged(FZ_LOG_DBG) then begin
          FZLogMgr.Get().Write('Apply hit scaler '+FZCommonHelper.FloatToString(hit_factor, 4, 2)+' to high-score player "'+PAnsiChar(@hitter.ps.name[0])+'"', FZ_LOG_DBG);
        end;
        out_power^:= out_power^ / hit_factor;
        result:=true;
      end;
    end;
  end;
end;

//Обработчик GAME_EVENT_ON_HIT
function OnGameEventDelayedHitProcessing(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
var
  local_client, victim, hitter:pxrClientData;
  hit:SHit;
  hit_check_result:FZHitCheckResult;
  new_power:single;
  tmpstr:string;
const
  DEATH_LAG:cardinal = 3000;
begin
  result:=false;
  hitter:=nil;
  victim:=nil;

  //[bug] Если в пакете в качестве источника хита окажется GameID уже несуществующего объекта - сервак развалится, а клиенты вылетят
  //Так как src_id был проверен в движке и гарантированно существует (уже заменен на отправителя в случае необходимости),
  //то обновим на него тот, который в пакете
  (pword(@packet.B.data[packet.r_pos-2]))^ := word(src_id);

  //Сообщения могут прилетать как от локального клиента (взрывы гранат, огонь, ...), так и от самих игроков
  //Но вот быть захитованным или наносить хит локальному клиенту нельзя!
  if not CheckForLocalHitterOrVictim(senderid, @dest_id, @src_id, IsServerControlsHits(), false) then exit;

  ReadHitFromPacket(packet, @hit);

  LockServerPlayers();
  try
    local_client:=GetServerClient();
    if (local_client=nil) then begin
      //Нет локального клиента? Это ненормально! Игнорим хит
      FZLogMgr.Get().Write('No local client found in OnGameEventDelayedHitProcessing', FZ_LOG_ERROR);
      exit;
    end;

    hitter:=GetClientByGameID(src_id);
    victim:=GetClientByGameID(dest_id);

    if (local_client.base_IClient.ID.id<>senderid) then begin
      if ((hitter.ps.flags__ and GAME_PLAYER_FLAG_VERY_VERY_DEAD = 0) or (FZCommonHelper.GetTimeDeltaSafe(hitter.ps.DeathTime) > DEATH_LAG)) and ((hitter = nil) or (hitter.base_IClient.ID.id <> senderid)) and ((victim = nil) or (victim.base_IClient.ID.id <> senderid)) then begin
        //Если отправитель не является ни жертвой, ни киллером - что-то тут не так.
        //Однако, если игрок только что умер - это допустимое явление
        HitLogger(victim, hitter, @hit, FZ_HIT_BAD);
        BadEventsProcessor(FZ_SEC_EVENT_INFO, GenerateMessageForClientId(senderid, 'suspected in sending not own hits'));
        exit;
      end;

      //Проверка хита на валидность
      hit_check_result:=FZHitMgr.Get.CheckHit(@hit, hitter, victim);
      if hit_check_result<>FZ_HIT_OK then begin
        tmpstr:=HitLogger(victim, hitter, @hit, hit_check_result);
        if hit_check_result = FZ_HIT_BAD then begin
          BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(senderid, tmpstr));
        end;
        exit;
      end;
    end;

    HitLogger(victim, hitter, @hit, FZ_HIT_OK);

    if CorrectHitPower(hitter, victim, @hit, @new_power) then begin
      OverWriteHitPowerToPacket(packet, new_power);
    end;

    result:=true;
  finally
    UnlockServerPlayers();
  end;
end;

procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
var
  game:pgame_sv_mp;
  gametype:string;
begin
  EnterCriticalSection(_serverstate.lock);
  _serverstate.mapname:=PChar(@gdd.map_name[0]);
  _serverstate.mapver:=PChar(@gdd.map_version[0]);
  _serverstate.maplink:=PChar(@gdd.download_url[0]);
  LeaveCriticalSection(_serverstate.lock);
  FZLogMgr.Get.Write('Mapname updated: '+_serverstate.mapname+', '+_serverstate.mapver, FZ_LOG_IMPORTANT_INFO);

  game:=GetCurrentGame();
  gametype:=GametypeNameById(game.base_game_sv_GameState.base_game_GameState.m_type);

  xrServer__Connect_SaveCurrentMapInfo(PAnsiChar(gametype));
end;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  name:=_serverstate.mapname;
  ver:=_serverstate.mapver;
  link:=_serverstate.maplink;
  LeaveCriticalSection(_serverstate.lock);
end;

procedure xrServer__Connect_SaveCurrentMapInfo(gametype:PAnsiChar); stdcall;
var
  f:textfile;
begin
  if FZConfigCache.Get().GetDataCopy().preserve_map then begin
    EnterCriticalSection(_serverstate.lock);
    try
      FZLogMgr.Get.Write('Saving map status: '+_serverstate.mapname+' | '+_serverstate.mapver+' | '+gametype, FZ_LOG_INFO);

      assignfile(f, MAP_SETTINGS_FILE);
      rewrite(f);
      try
        writeln(f, _serverstate.mapname);
        writeln(f, _serverstate.mapver);
        writeln(f, gametype);
      finally
        closefile(f)
      end;
    except
      FZLogMgr.Get.Write('Cannot save map name!', FZ_LOG_ERROR);
    end;
    LeaveCriticalSection(_serverstate.lock);
  end;
end;

procedure CLevel__net_Start_overridelevelgametype(); stdcall;
var
  lvl:pCLevel;
  runstr, mapname, mode, mapversion, tmp:string;
  f:textfile;
  verpos, from:integer;
  is_first_start:boolean;
const
  VER_KEY:string='ver=';
begin
  lvl:=GetLevel();
  mapversion:='1.0';
  runstr:=get_string_value(@lvl.m_caServerOptions);
  if not FZCommonHelper.GetNextParam(runstr, mapname, '/') or not FZCommonHelper.GetNextParam(runstr, mode, '/') then begin
    FZLogMgr.Get.Write('Cannot parse current map parameters in command string!', FZ_LOG_ERROR);
    exit;
  end;

  verpos:=Pos(VER_KEY, runstr);
  if verpos > 0 then begin
    from:=verpos;
    mapversion:='';
    verpos:=verpos+length(VER_KEY);
    while (verpos<=length(runstr)) and (runstr[verpos] <> '/') do begin
      mapversion:=mapversion+runstr[verpos];
      verpos:=verpos+1;
    end;
    Delete(runstr, from, length(VER_KEY)+length(mapversion)+1);
  end;

  EnterCriticalSection(_serverstate.lock);
  is_first_start:=length(_serverstate.mapname) = 0;
  LeaveCriticalSection(_serverstate.lock);

  //Восстановление параметров надо выполнять только при запуске сервера! При смене карты производить это нельзя.
  if FZConfigCache.Get().GetDataCopy().preserve_map and is_first_start then begin
    FZLogMgr.Get.Write('Restoring map settings', FZ_LOG_DBG);
    try
      assignfile(f, MAP_SETTINGS_FILE);
      reset(f);
      try
        readln(f, tmp);
        if length(trim(tmp))>0 then mapname:=trim(tmp);
        readln(f, tmp);
        if length(trim(tmp))>0 then mapversion:=trim(tmp);
        readln(f, tmp);
        if length(trim(tmp))>0 then mode:=trim(tmp);
      finally
        closefile(f);
      end;
    except
      FZLogMgr.Get.Write('Cannot restore map name!', FZ_LOG_ERROR);
    end;
  end;

  if not is_first_start then begin
    Voting.OnMapChanged();
  end;

  FZTeleportMgr.Get.OnMapUpdate(mapname, mapversion);

  FZLogMgr.Get.Write('Overriding map params to: '+mapname+' | '+mapversion+' | '+mode, FZ_LOG_INFO);
  runstr:=mapname+'/'+mode+'/ver='+mapversion+'/'+runstr;
  assign_string(@lvl.m_caServerOptions, PAnsiChar(runstr));
end;

function Check_xrClientData_owner_valid(ptr: pxrClientData): boolean; stdcall;
begin
  result:=(ptr<>nil) and (ptr.owner<>nil);

  if not result then begin
    FZLogMgr.Get().Write('Invalid owner detected in Check_xrClientData_owner_valid!', FZ_LOG_DBG);
  end;
end;

function game_sv__OnDetach_isitemtransfertobagneeded(item: pCSE_Abstract): boolean; stdcall;
var
  obj:pCObject;
  section_name:string;
begin
  //Игрок умер, этот предмет в его инвентаре
  //Если вернем true - предмет будет перемещен в рюкзак, став доступным для поднятия другими
  result:=false;

  //Если предмет - рюкзак, возвращаем false
  if item.m_tClassID = CLSID_OBJECT_PLAYERS_BAG then exit;

  obj:=ObjectById(@GetLevel.base_IGame_Level, item.ID);
  if obj<>nil then begin
    section_name:=get_string_value(@obj.NameSection);
  end else begin
    section_name:=get_string_value(@item.s_name);
  end;

  result:=FZItemCfgMgr.Get.IsItemNeedToBeTransfered(section_name);
  FZLogMgr.Get.Write('TransferCheck for ' + get_string_value(@item.s_name)+', id= '+inttostr(item.ID)+' is '+booltostr(result, true), FZ_LOG_DBG );
end;

function game_sv__OnDetach_isitemremovingneeded(item: pCSE_Abstract): boolean; stdcall;
var
  obj:pCObject;
  section_name:string;
begin
  //Игрок умер, этот предмет в его инвентаре
  //Если вернем true - предмет будет удален из симуляции
  result:=false;

  //Если предмет - рюкзак, возвращаем false
  if item.m_tClassID = CLSID_OBJECT_PLAYERS_BAG then exit;

  obj:=ObjectById(@GetLevel.base_IGame_Level, item.ID);
  if obj<>nil then begin
    section_name:=get_string_value(@obj.NameSection);
  end else begin
    section_name:=get_string_value(@item.s_name);
  end;

  //перед этим уже было проверено, нуждается ли предмет в перемещении, и если нуждается - нас бы не вызвали
  result:=FZItemCfgMgr.Get.IsItemNeedToBeRemoved(section_name);

  FZLogMgr.Get.Write('RemoveCheck for ' + get_string_value(@item.s_name)+', id= '+inttostr(item.ID)+' is '+booltostr(result, true), FZ_LOG_DBG );
end;

procedure game_sv_Deathmatch__OnDetach_destroyitems(game: pgame_sv_mp; pfirst_item: ppCSE_Abstract; plast_item: ppCSE_Abstract); stdcall;
begin
  while pfirst_item<>plast_item do begin
    if pfirst_item<>nil then begin
      game_RejectGameItem(game, pfirst_item^);
    end;
    pfirst_item:=pointer(uintptr(pfirst_item)+sizeof(pfirst_item));
  end;
end;

function UpdatePlayer_cb(player:pointer{pIClient}; parameter:pointer=nil; {%H-}parameter2:pointer=nil):boolean stdcall;
var
  cld:pxrClientData;
begin
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);  ;
  UpdatePlayer(cld);
  result:=true;
end;

procedure game_sv_mp__Update_additionals(); stdcall;
begin
  AdminCommands.ProcessAdminCommands();
  ForEachClientDo(@UpdatePlayer_cb, nil, nil, nil);
end;

function game_sv_mp__Update_could_corpse_be_removed(corpse: pCSE_Abstract): boolean; stdcall;
var
  pid:pword;
  item:pCSE_Abstract;
  game:pgame_sv_GameState;
begin
  game:=@GetCurrentGame.base_game_sv_GameState;
  pid:=corpse.children.start;
  result:=true;
  while pid<>corpse.children.last do begin
    item:=EntityFromEid(game, pid^);
    if (item <> nil) and (item.m_tClassID = CLSID_OBJECT_PLAYERS_BAG) then begin
      // Рюкзак не выбросился, пока удалять нельзя
      result:=false;
      break;
    end;
    pid:=pointer(uintptr(pid)+sizeof(word));
  end;
end;

procedure ProcessHwidPacket(p:pNET_Packet; sender:ClientID);
var
  hwid_str, hwhash_str, cdkeyhash_str:shared_str;
  hwid, hwhash, cdkeyhash, old_hwid:string;
  hwres:FZHwIdValidationResult;
  xrCL:pxrClientData;
  doKick:boolean;
const
  HWID_LEN:integer = 32;
begin
  FZLogMgr.Get.Write('FZ digest from client ID='+inttostr(sender.id), FZ_LOG_DBG);

  xrCL:=ID_to_client(sender.id);
  if xrCL = nil then begin
    FZLogMgr.Get.Write('FZ digest from unexistent client ID='+inttostr(sender.id), FZ_LOG_ERROR);
    exit;
  end;

  doKick:=false;

  if UnreadBytesCountInPacket(p) < 2*(HWID_LEN+1) then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender.id, 'sent malformed FZ digest packet'));
    doKick:=true;
  end;

  if not doKick then begin
    p.B.data[integer(p.r_pos)+HWID_LEN]:=0;
    p.B.data[integer(p.r_pos)+2*(HWID_LEN)+1]:=0;

    init_string(@hwid_str);
    init_string(@hwhash_str);
    init_string(@cdkeyhash_str);
    NET_Packet__r_stringZ.Call([p, @hwhash_str]);
    NET_Packet__r_stringZ.Call([p, @hwid_str]);
    hwid:=get_string_value(@hwid_str);
    hwhash:=get_string_value(@hwhash_str);

    if UnreadBytesCountInPacket(p) > 0 then begin
      p.B.data[integer(p.r_pos)+3*(HWID_LEN)+2]:=0;
      NET_Packet__r_stringZ.Call([p, @cdkeyhash_str]);
      cdkeyhash:=get_string_value(@cdkeyhash_str);
    end else begin
      cdkeyhash:='';
    end;

    assign_string(@hwid_str, nil);
    assign_string(@hwhash_str, nil);
    assign_string(@cdkeyhash_str, nil);

    if (length(hwid)<>HWID_LEN) or (length(hwhash)<>HWID_LEN) or ( (length(cdkeyhash)<>0) and (length(cdkeyhash)<>HWID_LEN) ) then begin
      BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender.id, 'sent corrupted FZ digest'));
      doKick:=true;
    end else begin
      FZLogMgr.Get.Write(GenerateMessageForClientId(sender.id,'sent FZ digest ['+hwhash+'|'+hwid+'|'+cdkeyhash+']'), FZ_LOG_DBG);
    end;
  end;

  if not doKick then begin
    hwres:=ValidateHwId(PAnsiChar(hwid), PAnsiChar(hwhash));
    if hwres<>FZ_HWID_VALID then begin
      if hwres = FZ_HWID_UNKNOWN_VERSION then begin
        BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender.id, 'sent FZ digest with unknown type; a cheater or your server is out of date'));
      end else begin
        BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender.id, 'sent invalid FZ digest'));
      end;
      //Кик будет после сигнала Ready, тут в нем нет смысла - можем закрешить клиента
    end else begin
      old_hwid:=GetHwId(xrCL, true);
      if (length(old_hwid)>0) and (old_hwid<>hwid) then begin
        //Зашел другой клиент с тем же ip, сбросим флаг реконнекта для обнуления статы
        FZLogMgr.Get.Write(GenerateMessageForClientId(xrCL.base_IClient.ID.id, 'has different HWID, reset reconnect flag'), FZ_LOG_INFO);
        xrCL.base_IClient.flags:= xrCL.base_IClient.flags and (not ICLIENT_FLAG_RECONNECT);
      end;
      SetHwId(xrCL, hwid, hwhash);
      SetOrigCdkeyHash(xrCL, cdkeyhash);
    end;
  end;

  if doKick then begin
    IPureServer__DisconnectClient(GetPureServer(), @xrCL.base_IClient, FZTranslationMgr.Get().TranslateSingle('fz_invalid_hwid'));
  end;
end;

procedure xrServer__OnMessage_additional(srv:pIPureServer; p:pNET_Packet; sender:ClientID ); stdcall;
begin
  if PWord(@p.B.data[0])^=M_FZ_DIGEST then begin
    ProcessHwidPacket(p, sender);
  end;
end;

function IPureServer__GetClientAddress_check_arg(pClientAddress:pointer; Address:pip_address; pPort:pcardinal):boolean; stdcall;
begin
  result:=true;
  if pClientAddress=nil then begin
    FillMemory(Address, sizeof(ip_address), 0);
    FillMemory(pPort, sizeof(cardinal), 0);
    result:=false;
  end;
end;

procedure NET_Packet__w_checkOverflow(p:pNET_Packet; count:cardinal); stdcall;
begin
  if sizeof(p.B.data) - p.B.count < count then begin
    R_ASSERT(false, 'Net packet overflow: stored '+inttostr(p.B.count)+' bytes, trying to write '+inttostr(count)+' bytes; packet type '+inttostr(pWord(@p.B.data[0])^), 'NET_Packet::w');
  end;
end;

procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;
begin
  if packet.B.count > sizeof(packet.B.data) - 100 then begin
    FZLogMgr.Get().Write('Flushing part of the events pack to prevent buffer overrun', FZ_LOG_DBG);
    //Отправим пакет
    SendBroadcastPacket(@GetLevel.Server.base_IPureServer, packet);

    //Начнем запись в пакет с самого начала
    ClearPacket(packet);
    WriteToPacket(packet, @M_EVENT_PACK, sizeof(M_EVENT_PACK));
  end;
end;

function game_sv_mp__OnPlayerGameMenu_isteamchangeblocked(clid: cardinal; p:pNET_Packet): boolean; stdcall;
var
  cld:pxrClientData;
  newteam:word;
begin
  result:=false;

  cld:=ID_to_client(clid);
  if cld=nil then exit;

  newteam:=pWord(@p.B.data[p.r_pos])^;
  if newteam <> cld.ps.team then begin
    result:=not FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).OnTeamChange();
    if result then begin
      SendChatMessageByFreezone(GetPureServer(), clid, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_change_team'));
    end;
  end;
end;

function game_sv_TeamDeathmatch__OnPlayerConnect_selectteam(ps:pgame_PlayerState; autoteam: integer): integer; stdcall;
begin
  R_ASSERT(ps<>nil, 'game_sv_TeamDeathmatch__OnPlayerConnect_selectteam got nil in ps');
  FZLogMgr.Get.Write('Autoteam '+inttostr(autoteam)+', current team '+inttostr(ps.team)+' for player "'+PAnsiChar(@ps.name[0])+'"', FZ_LOG_DBG);

  if (ps.team>0) and FZPlayerStateAdditionalInfo(ps.FZBuffer).IsTeamChangeBlocked() then begin
    result:=ps.team;
    FZLogMgr.Get.Write('Assigning team '+inttostr(result)+' for player "'+PAnsiChar(@ps.name[0])+'" - team changing for this player is blocked', FZ_LOG_INFO);
  end else if (ps.team > 0) and (autoteam <> ps.team) and FZConfigCache.Get().GetDataCopy().preserve_team_after_reconnect then begin
    result:=ps.team;
    FZLogMgr.Get.Write('Restoring team '+inttostr(result)+' for player "'+PAnsiChar(@ps.name[0])+'" after reconnect', FZ_LOG_INFO);
  end else begin
    result:=autoteam;
  end;
end;

type
InventoryBlockItem = packed record
  mask:cardinal;
  block_activation:byte;
end;
pInventoryBlockItem = ^InventoryBlockItem;

procedure xrServer__Process_event_onweaponhide(msgid:cardinal; clid: cardinal; p: pNET_Packet); stdcall;
var
  cld:pxrClientData;
  blockstate:InventoryBlockItem;
  cnt:cardinal;
begin
  if (msgid and $FFFF) <> GEG_PLAYER_WEAPON_HIDE_STATE then exit;

  cld:=ID_to_client(clid);
  if (cld=nil) or (cld.ps=nil) then exit;

  blockstate:=pInventoryBlockItem(@p.B.data[p.r_pos])^;
  if blockstate.mask = INV_STATE_BLOCK_ALL then begin
    if blockstate.block_activation = 0 then begin
      cnt:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).SlotsBlockCount(-1);
    end else begin
      cnt:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).SlotsBlockCount(1);
    end;
    FZLogMgr.Get().Write('block count '+inttostr(cnt)+' for player '+PAnsiChar(@cld.ps.name[0]), FZ_LOG_DBG);
  end;
end;

procedure game_sv_mp_OnSpawnPlayer(clid:cardinal; section:PAnsiChar); stdcall;
var
  cld:pxrClientData;
begin
  //Вызывается как в момент спавна актора, так и в момент спавна наблюдателя! При необходимости - различать по секции
  cld:=ID_to_client(clid);
  if (cld=nil) or (cld.ps=nil) then exit;

  FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).ResetSlotsBlockCount();
end;

function OnTeamKill(killer:pgame_PlayerState; victim:pgame_PlayerState):boolean; stdcall;
var
  cfg:FZCacheData;
  cld:pxrClientData;
begin
  //Вернуть true в случае необходимости кика клиента
  result:=false;
  cfg:=FZConfigCache.Get.GetDataCopy();

  if cfg.teamkill_decrease_rank then begin
    killer.experience_New:=0; //опыт с момента получения предыдущего ранга
    killer.experience_D:=0; //Визуальный индикатор приращения опыта до следующего ранга
    if killer.rank > 0 then begin
      killer.rank:=killer.rank - 1;
    end;
  end;

  if cfg.teamkill_decrease_money > 0 then begin
    cld:=GetClientDataByPlayerState(killer);
    if cld<>nil then begin
      AddMoney(cld, -1 * cfg.teamkill_decrease_money);
    end;
  end;

  if cfg.teamkill_reparations_to_victim > 0 then begin
    cld:=GetClientDataByPlayerState(victim);
    if cld<>nil then begin
      AddMoney(cld, cfg.teamkill_reparations_to_victim);
    end;
  end;

  if (c_sv_teamkill_punish.value^ <> 0) then begin
    //Кикаем клиента через каждые n тимкиллов, где n - это число из консольной команды sv_teamkill_limit
    if c_sv_teamkill_limit.value^ > 0 then begin
      result:= (killer.m_iTeamKills mod c_sv_teamkill_limit.value^) = 0;
    end else begin
      result:=true;
    end;
  end;
end;

procedure OnHitInvincible(hit:PSHit); stdcall;
begin
  hit.power:=0;
  hit.impulse:=0;
  hit.armor_piercing:=0;
  hit.power_critical:=0;
end;

procedure OnTeamHit_FriendlyFire(killer:pgame_PlayerState; victim:pgame_PlayerState; hit:pSHit); stdcall;
var
  ff_koeff:single;
const
  EPS:single = 0.001;
begin
  ff_koeff:=c_sv_friendlyfire.value^;

  if ff_koeff < EPS then begin
    OnHitInvincible(hit);
  end else begin
    hit.power:=ff_koeff * hit.power;
    if ff_koeff < 1.0 then begin;
      hit.impulse:=ff_koeff * hit.impulse;
    end;
  end;
end;

procedure game_sv_mp__Player_AddExperience_expspeed(experience:psingle); stdcall;
begin
  if experience<>nil then begin
    experience^:=FZConfigCache.Get().GetDataCopy().experience_speed*experience^;
  end;
end;

procedure DisconnectPlayerWithMessage(cl:pIClient; disconnect_type:integer); stdcall;
var
  reason:PAnsiChar;
begin
  case disconnect_type of
    0:reason:='fz_teamkill_punish';
  else
    reason:='fz_undefined';
  end;

  DisconnectPlayer(cl, FZTranslationMgr.Get.TranslateSingle(reason));
end;

function Init():boolean; stdcall;
begin
  result:=true;
  InitializeCriticalSection( _serverstate.lock );
end;

procedure Clean(); stdcall;
begin
  DeleteCriticalSection( _serverstate.lock );
end;

end.

