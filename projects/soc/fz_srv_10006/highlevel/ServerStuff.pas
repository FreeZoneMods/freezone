unit ServerStuff;

{$mode delphi}

interface
uses Servers, Packets, Clients, Hits, CSE, InventoryItems, Device, Timersmgr;

type
FZServerState = record
  lock:TRTLCriticalSection;
  mapname:string;
  mapver:string;
  maplink:string;
end;


procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_SaveCurrentMapInfo(gametype:PAnsiChar); stdcall;
procedure CLevel__net_start1_updatemapname(mapname:PChar); stdcall;
procedure CLevel__net_Start_overridelevelgametype(); stdcall;

function OnGameEvent_CheckClientExist(p:pNET_Packet; msgid:word; clid:cardinal):boolean; stdcall;
function OnGameEventPlayerHitted(p:pNET_Packet; clid:cardinal):boolean; stdcall;
function OnGameEventPlayerKilled(p:pNET_Packet; clid:cardinal):boolean; stdcall;

function Check_xrClientData_owner_valid(ptr: pxrClientData): boolean; stdcall;

procedure game_sv_mp__Update_additionals(); stdcall;
procedure xrServer__OnDelayedMessage_before_radmincmd(cmd: PAnsiChar; cl: pxrClientData); stdcall;
procedure xrServer__OnDelayedMessage_after_radmincmd(cl: pxrClientData); stdcall;

function game_sv_mp__Update_could_corpse_be_removed(corpse:pCSE_Abstract):boolean; stdcall;

function OnGameEventDelayedHitProcessing(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
function xrServer__Process_event_reject_CheckEntities(parent:pCSE_Abstract; entity:pCSE_Abstract):boolean; stdcall;
procedure OnGameEventNotImplenented(p:pNET_Packet; msgid:word; clid:cardinal); stdcall;
function CInventory_Eat_CheckIsValid(itm:pCInventoryItem; inventory:pCInventory):boolean;stdcall;

function xrServer__Process_event_GE_DIE_CheckKillerGameEntity(e_src:pCSE_Abstract; e_dest:pCSE_Abstract):pCSE_Abstract; stdcall;

procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;

procedure CInventoryItem_Detach_CheckForCheat(this:pCInventoryItem; section_name:PAnsiChar; b_spawn_item:boolean); stdcall;

function IsCurrentGameExist():boolean; stdcall;

function game_sv_mp__OnPlayerGameMenu_isteamchangeblocked(clid:cardinal; p:pNET_Packet):boolean; stdcall;

function game_sv_TeamDeathmatch__OnPlayerConnect_selectteam(ps:pgame_PlayerState; autoteam: integer): integer; stdcall;

procedure xrServer__Process_event_onweaponhide(msgid:cardinal; clid: cardinal; p: pNET_Packet); stdcall;
procedure game_sv_mp_OnSpawnPlayer(clid:cardinal; section:PAnsiChar); stdcall;

function OnTeamKill(killer:pgame_PlayerState; victim:pgame_PlayerState):boolean; stdcall;

procedure game_sv_mp__Player_AddExperience_expspeed(experience:psingle); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, ConfigCache, Windows, Games, HackProcessor, CommonHelper, Players, xrstrings, Vector, dynamic_caster, basedefs, Level, xr_debug, clsids, Voting, xr_configs, AdminCommands, PlayersConsole, Chat, TranslationMgr, Console, TeleportMgr, Objects, HitMgr;

const
  HITS_GROUP:string='[HIT] ';

  MAP_SETTINGS_FILE:string='fz_mapname.txt';

var
  _serverstate:FZServerState;


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
    result:=GetPlayerName(cld.ps);
  end;
end;

//Проверка корректности сообщения GAME_EVENT_PLAYER_HITTED и GAME_EVENT_PLAYER_KILLED
function CheckForLocalHitterOrVictim(sender_clid:cardinal; victim_gameid:pword; killer_gameid:pword; onlylocalsender:boolean; try_correct_hitter:boolean):boolean;
var
  local_client:pxrClientData;
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

  //Теперь убедимся, что локальный клиент не захитован и не сделал хит. Опасность возникает только в случае, когда там напрямую указан GameID локального клиента-спектатора!
  //В противном случае game_sv_GameState::get_eid никогда не вернет локального клиента.
  if (local_client.ps.GameID = victim_gameid^) then begin
    FZLogMgr.Get.Write('Local client is a victim in the hit message, skip the message', FZ_LOG_ERROR );
    exit;
  end;

  if (local_client.ps.GameID = killer_gameid^) then begin
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
    end else if check_state=FZ_HIT_IGNORE then begin
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
          ', AP='+FZCommonHelper.FloatToString(hit.ap, 4,2)+
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
          FZLogMgr.Get().Write('Apply damage scaler '+FZCommonHelper.FloatToString(hit_factor, 4, 2)+' to high-score player "'+GetPlayerName(victim.ps)+'"', FZ_LOG_DBG);
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
          FZLogMgr.Get().Write('Apply hit scaler '+FZCommonHelper.FloatToString(hit_factor, 4, 2)+' to high-score player "'+GetPlayerName(hitter.ps)+'"', FZ_LOG_DBG);
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
  invalid_hitter:boolean;
  dt:cardinal;
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

  if hit.hit_type >= EHitType__eHitTypeMax then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GenerateMessageForClientId(senderid, 'send hit of invalid type'));
    exit;
  end;

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
      //Проверяем - если отправитель не является ни жертвой, ни киллером - что-то тут не так.
      //Однако, если игрок только что умер - это допустимое явление
      invalid_hitter:=false;
      if (hitter <> nil) and (hitter.ps<>nil) then begin
        if (hitter.ps.flags__ and GAME_PLAYER_FLAG_VERY_VERY_DEAD <> 0) then begin
          //Мертвый игрок отправил хит. Это нормально, если он был убит только что.
          dt:=GetDevice().dwTimeGlobal - hitter.ps.DeathTime;
          FZLogMgr.Get().Write('Hit sent by dead player, dt='+inttostr(dt), FZ_LOG_DBG);
          if (dt > DEATH_LAG) then begin
            invalid_hitter:=true;
          end;
        end else if (hitter.base_IClient.ID.id <> senderid) and ((victim = nil) or (victim.base_IClient.ID.id <> senderid)) then begin
          //отправитель не является ни жертвой, ни киллером - что-то тут не так.
          invalid_hitter:=true;
        end;
      end else begin
        // TODO: проверять исторические ID игроков
        HitLogger(victim, hitter, @hit, FZ_HIT_IGNORE);
        exit;
      end;

      if invalid_hitter then begin
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

function xrServer__Process_event_reject_CheckEntities(parent: pCSE_Abstract; entity: pCSE_Abstract): boolean; stdcall;
var
  str:string;
  i:integer;
  pid:pword;
begin
  result:=false;
  if (entity = nil) or (parent = nil) then begin
    if (entity = nil) then begin
      str:='ERROR on rejecting: entity not found';
    end else begin
      str:='ERROR on rejecting: parent not found';
    end;
    FZLogMgr.Get().Write(str, FZ_LOG_INFO);
    exit;
  end;

  if parent.ID <> entity.ID_Parent then begin
    FZLogMgr.Get().Write('ERROR on rejecting: parent.ID ('+inttostr(parent.ID)+') <> entity.ID_Parent ('+inttostr(entity.ID_Parent)+')', FZ_LOG_INFO);
    exit;
  end;

  for i:=0 to items_count_in_vector(@parent.children, sizeof(word)) do begin
    pid:=get_item_from_vector(@parent.children, i, sizeof(word));
    if pid^ = entity.ID then begin
      result:=true;
      break;
    end;
  end;

  if not result then begin
    FZLogMgr.Get().Write('ERROR on rejecting: parent ('+inttostr(parent.ID)+') has no child entity ('+inttostr(entity.ID)+')', FZ_LOG_INFO);
  end;

  result:=true;
end;

procedure OnGameEventNotImplenented(p: pNET_Packet; msgid: word; clid: cardinal); stdcall;
begin
  BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GenerateMessageForClientId(clid, 'sent invalid game event('+inttostr(msgid)+')'));
end;

function CInventory_Eat_CheckIsValid(itm: pCInventoryItem; inventory: pCInventory): boolean; stdcall;
begin
  result:=false;
  if inventory <> itm.m_pCurrentInventory then begin
    FZLogMgr.Get.Write('Attempt to eat not own item, player may be already dead', FZ_LOG_INFO);
    exit;
  end;

  if dynamic_cast(itm, 0, xrGame+RTTI_CInventoryItem, xrGame+RTTI_CEatableItem, false) = nil then begin
    FZLogMgr.Get.Write('Attempt to eat non-eatable item', FZ_LOG_INFO);
    exit;
  end;

  if dynamic_cast(inventory.m_pOwner, 0, xrGame+RTTI_CInventoryOwner, xrGame+RTTI_CEntityAlive, false) = nil then begin
    FZLogMgr.Get.Write('Inventory owner is not alive entity', FZ_LOG_INFO);
    exit;
  end;

  result:=true;
end;

procedure CLevel__net_start1_updatemapname(mapname:PChar); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  _serverstate.mapname:=mapname;
  _serverstate.mapver:='1.0';
  _serverstate.maplink:='';
  LeaveCriticalSection(_serverstate.lock);
  FZLogMgr.Get.Write('Mapname updated: '+_serverstate.mapname+', '+_serverstate.mapver, FZ_LOG_IMPORTANT_INFO);
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
  is_first_start:boolean;
begin
  lvl:=GetLevel();
  mapversion:='1.0';
  runstr:=get_string_value(@lvl.m_caServerOptions);
  if not FZCommonHelper.GetNextParam(runstr, mapname, '/') or not FZCommonHelper.GetNextParam(runstr, mode, '/') then begin
    FZLogMgr.Get.Write('Cannot parse current map parameters in command string!', FZ_LOG_ERROR);
    exit;
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
  runstr:=mapname+'/'+mode+'/'+runstr;
  assign_string(@lvl.m_caServerOptions, PAnsiChar(runstr));
end;

function Check_xrClientData_owner_valid(ptr: pxrClientData): boolean; stdcall;
begin
  result:=(ptr<>nil) and (ptr.owner<>nil);

  if not result then begin
    FZLogMgr.Get().Write('Invalid owner detected in Check_xrClientData_owner_valid!', FZ_LOG_DBG);
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
  FZTimersMgr.Get.Update();
  ForEachClientDo(@UpdatePlayer_cb, nil, nil, nil);
end;

procedure xrServer__OnDelayedMessage_before_radmincmd(cmd: PAnsiChar; cl: pxrClientData); stdcall;
begin
  FZLogMgr.Get().Write('Radmin "'+GetPlayerName(cl.ps)+'"['+inttostr(cl.base_IClient.ID.id)+'] is running command '+cmd, FZ_LOG_INFO);
  PlayersConsole.SetRadminId(cl.base_IClient.ID.id);
end;

procedure xrServer__OnDelayedMessage_after_radmincmd(cl: pxrClientData); stdcall;
begin
  PlayersConsole.ClearRadminId();
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

function xrServer__Process_event_GE_DIE_CheckKillerGameEntity(e_src: pCSE_Abstract; e_dest: pCSE_Abstract): pCSE_Abstract;
begin
  if e_src = nil then begin
    //Этого быть не должно (согласно коду сервера), но все равно проверим
    R_ASSERT(e_dest<>nil, 'xrServer__Process_event_CheckKillerGameEntity has nil e_dest');
    FZLogMgr.Get().Write('Entity '+inttostr(e_dest.ID)+' dead but has no killer, make self-kill', FZ_LOG_ERROR);
    result:=e_dest;
  end else begin
    result:=e_src;
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

procedure CInventoryItem_Detach_CheckForCheat(this: pCInventoryItem; section_name: PAnsiChar; b_spawn_item: boolean); stdcall;
begin
  if not game_ini_section_exist(section_name) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, 'Some player tries to detach non-existant item');
  end else if not b_spawn_item then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, 'Some player tries to detach invalid item');
  end;
end;

function IsCurrentGameExist():boolean; stdcall;
var
  lvl:pCLevel;
begin
  result:=false;
  lvl:=GetLevel();
  if lvl=nil then exit;

  if (lvl.Server=nil) or (lvl.game=nil) then exit;
  result:=true;
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
    result:=not GetFZBuffer(cld.ps).OnTeamChange();
    if result then begin
      SendChatMessageByFreezone(GetPureServer(), clid, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_change_team'));
    end;
  end;
end;

function game_sv_TeamDeathmatch__OnPlayerConnect_selectteam(ps:pgame_PlayerState; autoteam: integer): integer; stdcall;
begin
  R_ASSERT(ps<>nil, 'game_sv_TeamDeathmatch__OnPlayerConnect_selectteam got nil in ps');
  FZLogMgr.Get.Write('Autoteam '+inttostr(autoteam)+', current team '+inttostr(ps.team)+' for player "'+GetPlayerName(ps)+'"', FZ_LOG_DBG);

  if (ps.team>0) and GetFZBuffer(ps).IsTeamChangeBlocked() then begin
    result:=ps.team;
    FZLogMgr.Get.Write('Assigning team '+inttostr(result)+' for player "'+GetPlayerName(ps)+'" - team changing for this player is blocked', FZ_LOG_INFO);
  end else if (ps.team > 0) and (autoteam <> ps.team) and FZConfigCache.Get().GetDataCopy().preserve_team_after_reconnect then begin
    result:=ps.team;
    FZLogMgr.Get.Write('Restoring team '+inttostr(result)+' for player "'+GetPlayerName(ps)+'" after reconnect', FZ_LOG_INFO);
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
      cnt:=GetFZBuffer(cld.ps).SlotsBlockCount(-1);
    end else begin
      cnt:=GetFZBuffer(cld.ps).SlotsBlockCount(1);
    end;
    FZLogMgr.Get().Write('block count '+inttostr(cnt)+' for player '+GetPlayerName(cld.ps), FZ_LOG_DBG);
  end;
end;

procedure game_sv_mp_OnSpawnPlayer(clid:cardinal; section:PAnsiChar); stdcall;
var
  cld:pxrClientData;
begin
  //Вызывается как в момент спавна актора, так и в момент спавна наблюдателя! При необходимости - различать по секции
  cld:=ID_to_client(clid);
  if (cld=nil) or (cld.ps=nil) then exit;

  GetFZBuffer(cld.ps).ResetSlotsBlockCount();
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

procedure game_sv_mp__Player_AddExperience_expspeed(experience:psingle); stdcall;
begin
  if experience<>nil then begin
    experience^:=FZConfigCache.Get().GetDataCopy().experience_speed*experience^;
  end;
end;

function Init():boolean; stdcall;
begin
  result:=true;
  InitializeCriticalSection( _serverstate.lock );
  _serverstate.mapname:='';
  _serverstate.maplink:='';
  _serverstate.mapver:='';
end;

procedure Clean(); stdcall;
begin
  DeleteCriticalSection( _serverstate.lock );
end;

end.

