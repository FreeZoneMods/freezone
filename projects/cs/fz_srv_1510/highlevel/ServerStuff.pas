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
function game_sv_GameState__OnEvent_CheckHit(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
function game__OnEvent_SelfKill_Check(target:pxrClientData; senderid:cardinal):boolean; stdcall;
function CheckKillMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
function CheckHitMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;

function game_sv_mp__OnPlayerHit_preventlocal({%H-}victim:pgame_PlayerState; hitter:pgame_PlayerState):boolean; stdcall;
procedure game_sv_mp__OnPlayerKilled_preventlocal(victim:pgame_PlayerState; hitter:ppgame_PlayerState; weaponid:pword; specialkilltype:pbyte); stdcall;
function game_sv__OnDetach_isitemremovingneeded(item:pCSE_Abstract):boolean; stdcall;
function game_sv__OnDetach_isitemtransfertobagneeded(item:pCSE_Abstract):boolean; stdcall;
procedure game_sv_Deathmatch__OnDetach_destroyitems(game:pgame_sv_mp; pfirst_item:ppCSE_Abstract; plast_item:ppCSE_Abstract); stdcall;

function game_sv_mp__Update_could_corpse_be_removed(game:pgame_sv_mp; corpse:pCSE_Abstract):boolean; stdcall;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;

procedure xrServer__OnMessage_additional(srv:pIPureServer; p:pNET_Packet; sender:ClientID ); stdcall;

function IPureServer__GetClientAddress_check_arg(pClientAddress:pointer; Address:pip_address; pPort:pcardinal):boolean; stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, Hits, ConfigCache, Windows, ItemsCfgMgr, clsids;

var
  _serverstate:FZServerState;

procedure xrGameSpyServer_constructor_reserve_zerogameid(srv:pxrServer); stdcall;
begin
  FZLogMgr.Get.Write('Reserving zero game ID', FZ_LOG_INFO);
  CID_Generator__tfGetID.Call([@srv.m_tID_Generator, 0]);
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

function CheckKillMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
var
  cld:pxrClientData;
  killer_id:word;
  target_id:word;
begin
  result:=false;

  //GAME_EVENT_PLAYER_KILLED имеет право отправлять только локальный клиент!
  cld:=GetServerClient();
  if (cld = nil) or (cld.base_IClient.ID.id <> sender_id) then begin
    fzlogmgr.get.write('Player id='+inttostr(sender_id)+' tried to send GAME_EVENT_PLAYER_KILLED message!', FZ_LOG_ERROR);
    exit;
  end;

  //кроме того, локальный клиент не может быть убийцей либо быть убит!
  killer_id:=pword(@p.B.data[p.r_pos+3])^;
  target_id:=pword(@p.B.data[p.r_pos])^;
  FZLogMgr.Get.Write('Killer id = '+inttostr(killer_id)+', victim id = '+inttostr(target_id), FZ_LOG_IMPORTANT_INFO);


  if (cld.ps.GameID = killer_id) or (cld.ps.GameID = target_id) then begin
    FZLogMgr.Get.Write('Local player cannot be victim or killer!', FZ_LOG_ERROR);
    exit;
  end;

  result:=true;
end;

function GetNameFromClientdata(cld:pxrClientData):string;
begin
  if cld = nil then begin
    result := '(null)';
  end else begin
    result:= cld.ps.name;
  end;
end;

function CheckHitMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
var
  cld, victim, hitter:pxrClientData;
  killer_id:word;
  target_id:word;
  health_dec:single;
  victim_str, hitter_str:string;
begin
  result:=false;

  //GAME_EVENT_PLAYER_HITTED имеет право отправлять только локальный клиент!
  cld:=GetServerClient();
  if (cld = nil) or (cld.base_IClient.ID.id <> sender_id) then begin
    fzlogmgr.get.write('Player id='+inttostr(sender_id)+' tried to send GAME_EVENT_PLAYER_HITTED message!', FZ_LOG_ERROR);
    exit;
  end;

  //кроме того, локальный клиент не может быть убийцей либо быть убит!
  killer_id:=pword(@p.B.data[p.r_pos+2])^;
  target_id:=pword(@p.B.data[p.r_pos])^;
  health_dec:=psingle(@p.B.data[p.r_pos+4])^;
  if (cld.ps.GameID = killer_id) or (cld.ps.GameID = target_id) then begin
    FZLogMgr.Get.Write('Local player cannot be victim or hitter!', FZ_LOG_ERROR);
    exit;
  end else begin
    victim:=nil;
    hitter:=nil;
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @target_id, @victim);
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @killer_id, @hitter);

    victim_str := GetNameFromClientdata(victim);
    hitter_str := GetNameFromClientdata(hitter);

    FZLogMgr.Get.Write('Hitter '+hitter_str+' (id='+inttostr(killer_id)+'), victim = '+victim_str+' (id='+inttostr(target_id)+'), health dec = '+floattostr(health_dec), FZ_LOG_IMPORTANT_INFO);
  end;

  result:=true;
end;

function game_sv_GameState__OnEvent_CheckHit(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
var
  cld, victim, hitter:pxrClientData;
  hit:SHit;
  hit_stat_mode:cardinal;
  victim_str, hitter_str:string;
begin
//  FZLogMgr.Get.Write('hit by '+inttostr(senderid));

  result:=false;


  cld:=GetServerClient();
  if cld = nil then begin
    FZLogMgr.Get.Write('No local player in OnHit!', FZ_LOG_ERROR);
    result:=true;
    exit;
  end;

  if cld.base_IClient.ID.id<>senderid then begin
    //Хит отправлен не локальным клиентом.
    //Проверяем, что хит нам отправил сам отправитель, а не кто-то левый
    LockServerPlayers();
    try
      hitter:=nil;
      ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @src_id, @hitter);
      if hitter=nil then begin
        FZLogMgr.Get.Write('Hit from unexistent client???', FZ_LOG_ERROR);
        exit;
      end;

      if hitter.ps.GameID<>src_id then begin
        FZLogMgr.Get.Write('Player id='+inttostr(senderid)+' sent not own hit!!!', FZ_LOG_ERROR);
        exit;
      end;
    finally
      UnLockServerPlayers();
    end;
  end;

  //локальный игрок может отправлять хиты от окружающей среды, но не может быть хиттером или жертвой
  result:= not ((cld.ps.GameID = src_id) or (cld.ps.GameID = dest_id));
  if not result then begin
    if (cld.ps.GameID = src_id) then begin
      FZLogMgr.Get.Write('Local player makes hit? Rejecting!', FZ_LOG_ERROR);
    end else if (cld.ps.GameID = dest_id) then begin
      FZLogMgr.Get.Write('Local player has been hitted? Rejecting!', FZ_LOG_ERROR);
    end;
  end else begin
    ReadHitFromPacket(packet, @hit);

    victim:=nil;
    hitter:=nil;
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @dest_id, @victim);
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @src_id, @hitter);

    hit_stat_mode:=FZConfigCache.Get.GetDataCopy.hit_statistics_mode;
    if hit_stat_mode = 1 then begin
      //Пишем стату по всем хитам, прилетающим в клиента
      victim_str := GetNameFromClientdata(victim);
      hitter_str := GetNameFromClientdata(hitter);

      FZLogMgr.Get.Write( hitter_str+'->'+victim_str+
                          ' (T='+inttostr(hit.hit_type)+
                          ', P='+floattostrf(hit.power, ffFixed,4,2)+
                          ', I='+floattostrf(hit.impulse, ffFixed,4,2)+
                          ', B='+inttostr(hit.boneID)+
                          ')', FZ_LOG_INFO);

      //todo:анализ хита
    end;
  end;
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

procedure game_sv_mp__OnPlayerKilled_checkkiller(victim:pxrClientData; pkiller:ppxrClientData); stdcall;
var
  killer:pxrClientData;
begin
  if (pkiller<>nil) then begin
    killer:=pkiller^;
    if (killer<>nil) then begin
      if killer.base_IClient.flags and ICLIENT_FLAG_LOCAL<>0 then begin
        pkiller^ := victim;
      end;
    end;
  end;
end;

function game_sv_mp__OnPlayerHit_preventlocal(victim:pgame_PlayerState; hitter:pgame_PlayerState):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  cld:=GetServerClient();

  if (cld<>nil) and (hitter<>nil) and (cld.ps = hitter) then begin
    result:=true;
  end;

end;

procedure game_sv_mp__OnPlayerKilled_preventlocal(victim:pgame_PlayerState; hitter:ppgame_PlayerState; weaponid:pword; specialkilltype:pbyte); stdcall;
var
  cld:pxrClientData;
begin
  cld:=GetServerClient();

  if (cld<>nil) and (hitter<>nil) and (cld.ps = hitter^) then begin
    hitter^:=victim;
    specialkilltype^:=SPECIAL_KILL_TYPE__SKT_NONE;
    weaponid^:=$FFFF;
  end;
end;

function game_sv__OnDetach_isitemtransfertobagneeded(item: pCSE_Abstract): boolean; stdcall;
begin
  //Игрок умер, этот предмет в его инвентаре
  //Если вернем true - предмет будет перемещен в рюкзак, став доступным для поднятия другими
  result:=false;

  //Если предмет - рюкзак, возвращаем false
  if item.m_tClassID = CLSID_OBJECT_PLAYERS_BAG then exit;

  result:=FZItemCgfMgr.Get.IsItemNeedToBeTransfered(PAnsiChar(@item.s_name.p_.value));
end;

function game_sv__OnDetach_isitemremovingneeded(item: pCSE_Abstract): boolean; stdcall;
begin
  //Игрок умер, этот предмет в его инвентаре
  //Если вернем true - предмет будет удален из симуляции
  result:=false;

  //Если предмет - рюкзак, возвращаем false
  if item.m_tClassID = CLSID_OBJECT_PLAYERS_BAG then exit;

  //перед этим уже было проверено, нуждается ли предмет в перемещении, и если нуждается - нас бы не вызвали
  result:=FZItemCgfMgr.Get.IsItemNeedToBeRemoved(PAnsiChar(@item.s_name.p_.value));
end;

procedure game_sv_Deathmatch__OnDetach_destroyitems(game: pgame_sv_mp; pfirst_item: ppCSE_Abstract; plast_item: ppCSE_Abstract); stdcall;
begin
  while pfirst_item<>plast_item do begin
    if pfirst_item<>nil then begin
      game_sv_mp__RejectGameItem.Call([game, pfirst_item^]);
    end;
    pfirst_item:=pointer(uintptr(pfirst_item)+sizeof(pfirst_item));
  end;
end;

function game_sv_mp__Update_could_corpse_be_removed(game:pgame_sv_mp; corpse: pCSE_Abstract): boolean; stdcall;
var
  pid:pword;
  item:pCSE_Abstract;
begin
  pid:=corpse.children.start;
  result:=true;
  while pid<>corpse.children.last do begin
    item:=xrServer__ID_to_entity.Call([game.base_game_sv_GameState.m_server, pid^]).VPointer;
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
    virtual_IPureServer__OnMessage.Call([srv, @tmp_packet, sender.id]);
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

