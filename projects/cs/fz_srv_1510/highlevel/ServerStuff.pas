unit ServerStuff;

{$mode delphi}

interface
uses Servers, Packets, PureServer, Clients,NET_common, CSE, Games;

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
function OnGameEventPlayerKilled(p:pNET_Packet; clid:cardinal):boolean; stdcall;
function OnGameEventPlayerHitted(p:pNET_Packet; clid:cardinal):boolean; stdcall;

function Check_xrClientData_owner_valid(ptr:pxrClientData):boolean; stdcall;

function game_sv__OnDetach_isitemremovingneeded(item:pCSE_Abstract):boolean; stdcall;
function game_sv__OnDetach_isitemtransfertobagneeded(item:pCSE_Abstract):boolean; stdcall;
procedure game_sv_Deathmatch__OnDetach_destroyitems(game:pgame_sv_mp; pfirst_item:ppCSE_Abstract; plast_item:ppCSE_Abstract); stdcall;

function game_sv_mp__Update_could_corpse_be_removed(game:pgame_sv_GameState; corpse:pCSE_Abstract):boolean; stdcall;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;

procedure xrServer__OnMessage_additional(srv:pIPureServer; p:pNET_Packet; sender:ClientID ); stdcall;

function IPureServer__GetClientAddress_check_arg(pClientAddress:pointer; Address:pip_address; pPort:pcardinal):boolean; stdcall;

procedure NET_Packet__w_checkOverflow(p:pNET_Packet; count:cardinal); stdcall;
procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, Hits, ConfigCache, Windows, ItemsCfgMgr, clsids, xrstrings, HackProcessor, Players, CommonHelper, Level, Objects, xr_debug;

const
  HITS_GROUP:string='[HIT] ';

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

procedure HitLogger(victim:pxrClientData; hitter:pxrClientData; hit:pSHit);
var
  hit_stat_mode:cardinal;
  victim_str, hitter_str, weapon_str:string;
begin
  //1 - Пишем стату по всем хитам
  //2 - Пишем стату по хитам, прилетающим от одного игрока в другого
  hit_stat_mode:=FZConfigCache.Get.GetDataCopy.hit_statistics_mode;

  if (hit_stat_mode = 1) or ((hit_stat_mode = 2) and (hitter<>nil) and (victim<>nil) ) then begin
    victim_str := GetNameFromClientdata(victim, hit.DestID);
    hitter_str := GetNameFromClientdata(hitter, hit.whoID);

    if (hit.whoID <> hit.weaponID) then begin
      weapon_str := GetNameFromClientdata(nil, hit.weaponID);
      hitter_str:=hitter_str+' '+weapon_str;
    end;

    FZLogMgr.Get.Write( HITS_GROUP+hitter_str+' -> '+victim_str+
                        ' (T='+inttostr(hit.hit_type)+
                        ', P='+FZCommonHelper.FloatToString(hit.power, 4,2)+
                        ', I='+FZCommonHelper.FloatToString(hit.impulse, 4,2)+
                        ', B='+inttostr(hit.boneID)+
                        ')', FZ_LOG_IMPORTANT_INFO);
  end;
end;

//Обработчик GAME_EVENT_ON_HIT
function OnGameEventDelayedHitProcessing(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
var
  local_client, victim, hitter:pxrClientData;
  hit:SHit;
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

  //Если хит отправлен не локальным клиентом, надо убедиться, что игровой ИД нанесшего хит соответствует отправителю
  LockServerPlayers();
  try
    local_client:=GetServerClient();
    hitter:=GetClientByGameID(src_id);
    victim:=GetClientByGameID(dest_id);

    ReadHitFromPacket(packet, @hit);
    HitLogger(victim, hitter, @hit);

    if (local_client=nil) or (local_client.base_IClient.ID.id<>senderid) then begin
      //Если отправитель не является ни жертвой, ни киллером - что-то тут не так.
      if ((hitter<>nil) and (hitter.base_IClient.ID.id <> senderid)) and ((victim<>nil) and (victim.base_IClient.ID.id <> senderid)) then begin
        BadEventsProcessor(FZ_SEC_EVENT_INFO, GenerateMessageForClientId(senderid, 'sent not own hit?'));
        exit;
      end;
    end;

    result:=true;
  finally
    UnlockServerPlayers();
  end;

  //todo:анализ хита
end;

procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  _serverstate.mapname:=PChar(@gdd.map_name[0]);
  _serverstate.mapver:=PChar(@gdd.map_version[0]);
  _serverstate.maplink:=PChar(@gdd.download_url[0]);
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

function Check_xrClientData_owner_valid(ptr: pxrClientData): boolean;
  stdcall;
begin
  result:=(ptr<>nil) and (ptr.owner<>nil);
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

function game_sv_mp__Update_could_corpse_be_removed(game:pgame_sv_GameState; corpse: pCSE_Abstract): boolean; stdcall;
var
  pid:pword;
  item:pCSE_Abstract;
begin
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

procedure xrServer__OnMessage_additional(srv:pIPureServer; p:pNET_Packet; sender:ClientID ); stdcall;
var
  tmp_packet:NET_Packet;
begin
  if PWord(@p.B.data[0])^=M_FZ_DIGEST then begin
    FZLogMgr.Get.Write('FZ digest from '+inttostr(sender.id), FZ_LOG_DBG);
    tmp_packet:=p^;
    PWord(@tmp_packet.B.data[0])^:=M_SV_DIGEST;
    tmp_packet.r_pos:=0;
    IPureServer__OnMessage(srv, @tmp_packet, sender.id);
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

