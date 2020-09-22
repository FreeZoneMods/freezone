unit Games;
{$mode delphi}
{$I _pathes.inc}

interface
uses BaseClasses, Schedule, Packets, Vector, xrstrings, Synchro, Clients, Banned, Objects, CSE;

type
game_GameState = packed record  //sizeof = 0x98
  base_DLL_Pure:DLL_Pure;
  m_type:cardinal;
  m_phase:cardinal; //word + unused?
  m_round:cardinal;
  m_start_time:cardinal;
  m_round_start_time:cardinal;
  m_round_start_time_str:array [0..63] of Char;
  _unused1:cardinal;                             //кандидат на дополнительный буфер
  m_qwStartProcessorTime:int64;
  m_qwStartGameTime:int64;
  m_fTimeFactor:single; //с этой скоростью тикают часы
  _unused2:cardinal;
  m_qwEStartProcessorTime:int64;
  m_qwEStartGameTime:int64;
  m_fETimeFactor:single;//с этой скоростью мен€етс€ погода
  _unknown3:cardinal;
end;

WeaponUsageStatistic = packed record
  vtable:pointer;
  m_bCollectStatistic:byte;
  _unused1:byte;
  _unused2:word;
  ActiveBullets:xr_vector;
  aPlayersStatistic:xr_vector;
  m_dwTotalPlayersAliveTime:array[0..2] of cardinal;
  m_dwTotalPlayersMoneyRound:array[0..2] of integer;
  m_dwTotalNumRespawns:array[0..2] of cardinal;
  m_dwLastUpdateTime:cardinal;
  m_dwUpdateTimeDelta:cardinal;
  m_dwLastRequestSenderID:cardinal;
  m_Requests:xr_vector;
  mFileName:string_path;
  m_mutex:xrCriticalSection;
end;
pWeaponUsageStatistic=^WeaponUsageStatistic;

game_cl_GameState = packed record  //sizeof: 0xc8
  base_game_GameState:game_GameState;
  base_ISheduled:ISheduled;
  //offset: 0xa0
  m_game_type_name:shared_str;
  m_game_ui_custom:pointer; //pCUIGameCustom;
  m_u16VotingEnabled:word;
  //offset: 0xaa
  m_bServerControlHits:byte; //boolean
  _unused1:byte;
  players:array[0..15] of byte;
  //offset: 0xBC
  local_svdpnid:ClientID;
  local_player:pgame_PlayerState;
  m_WeaponUsageStatistic:pWeaponUsageStatistic;
end;

type GameEventQueue = packed record
  //todo:fillme
end;
pGameEventQueue=^GameEventQueue;

type item_respawn_manager = packed record  //sizeof = 0x404C
  spawn_packet_store:NET_Packet;
  //offset:0x4014
  m_server:pointer;//pxrServer;
  m_respawns:xr_vector; //spawn_item
  m_respawn_sections_cache:assotiative_vector;
  level_items_respawn:array[0..$17] of byte;
end;

type async_statistics_collector = packed record
  async_responses:assotiative_vector;
end;

type game_sv_GameState = packed record //sizeof = 0x4170
  base_game_GameState:game_GameState;
  //offset:0x98
  m_server:pointer;//pxrServer;
  m_event_queue:pGameEventQueue;
  m_item_respawner:item_respawn_manager;
  //offset:0x40EC
  m_bMapRotation:byte;//boolean
  m_bMapNeedRotation:byte;//boolean
  m_bMapSwitched:byte;//boolean
  m_bFastRestart:byte;//boolean
  m_pMapRotationList:xr_deque;
  sv_force_sync:byte;//boolean
  _reserved1:byte;
  _reserved2:word;
  //offset:0x411C
  rpoints_MinDist:array[0..3] of single;
  rpoints: array[0..3] of xr_vector; //RPoint;
  rpointsBlocked:xr_vector;
  //offset:0x4168
  round_end_reason:cardinal;
  _unknown:cardinal; //непон€тно, к какому классу эти 4 байта отнести, к текущему или к производному. Ќе похоже, что юзаютс€ вообще  
end;
pgame_sv_GameState=^game_sv_GameState;

type game_sv_mp = packed record //sizeof = 0x4418
  base_game_sv_GameState:game_sv_GameState;
  //offset:0x4170
  m_CorpseList:xr_deque;
  m_aRanks:xr_vector;//Rank_Struct;
  m_bRankUp_Allowed:byte;//boolean
  _unused1:byte;
  _unused2:word;
  TeamList:xr_deque;
  m_strWeaponsData:pointer; //pCItemMgr;
  m_bVotingActive:byte; //boolean
  m_bVotingReal:byte; //boolean
  fz_vote_started_by_admin:byte;
  _unused3:byte;
  m_uVoteStartTime:cardinal;
  m_pVoteCommand:shared_str;
  m_voting_string:shared_str;
  m_started_player:shared_str;
  //offset:0x41E8
  m_u8SpectatorModes:byte;
  _unused4:byte;
  _unused5:word;
  //offset:0x41EC
  m_cdkey_ban_list:cdkey_ban_list;
  //offset:0x41F8
  round_statistics_dump_fn:string_path;
  //offset:0x4400
  m_async_stats:async_statistics_collector;
  //offset:0x4410
  m_async_stats_request_time:cardinal;
  _unknown:cardinal; //непон€тно, к какому классу эти 4 байта отнести, к текущему или к производному. Ѕолее похоже на первое, так как первый член второго по смыслу vtable  
end;
pgame_sv_mp=^game_sv_mp;


type game_sv_Deathmatch = packed record//0x44E0
  base_game_sv_mp:game_sv_mp;
  pure_relcase_base:pure_relcase;
  //offset:0x4420
  m_vFreeRPoints:array [0..3] of xr_vector; //u32;
  m_dwLastRPoints:array[0..3] of cardinal;

  m_delayedRoundEnd:cardinal;
  m_roundEndDelay:cardinal;

  m_delayedTeamEliminated:cardinal;
  m_TeamEliminatedDelay:cardinal;

  m_sBaseWeaponCostSection:shared_str;
  teams:xr_vector; //game_TeamState;
  //offset:0x4480
  pWinnigPlayerName:PChar;
  m_AnomaliesPermanent:xr_vector;
  m_AnomalySetsList:xr_vector;
  m_AnomalySetID:xr_vector; //u8;
  m_dwLastAnomalySetID:cardinal;
  m_dwLastAnomalyStartTime:cardinal;
  //offset:0x44B0
  m_AnomalyIDSetsList:xr_vector;
  m_bSpectatorMode:byte;
  _unused1:byte;
  _unused2:word;
  m_dwSM_SwitchDelta:cardinal;
  m_dwSM_LastSwitchTime:cardinal;
  m_dwSM_CurViewEntity:cardinal;
  m_pSM_CurViewEntity:pCObject;
  m_dwWarmUp_CurTime:cardinal;
  //offset:0x44D4
  m_bInWarmUp:byte;
  _unused3:byte;
  _unused4:word;
  m_not_free_ammo_str:shared_str;
  _unused5:cardinal;
end;
pgame_sv_Deathmatch=^game_sv_Deathmatch;

type game_sv_TeamDeathmatch = packed record
  base_game_sv_Deathmatch:game_sv_Deathmatch;
  //offset:0x44e0
  teams_swaped:boolean;
end;

type game_sv_CaptureTheArtefact = packed record
  base_game_sv_mp:game_sv_mp;
  _unknown:array[0..$72] of byte;
  m_bInWarmUp:byte;//bool, offset:$4488
end;
pgame_sv_CaptureTheArtefact=^game_sv_CaptureTheArtefact;

const
  eRoundEnd_Finish:cardinal=0;
  eRoundEnd_GameRestarted:cardinal=1;
  eRoundEnd_GameRestartedFast:cardinal=2;
  eRoundEnd_TimeLimit:cardinal=3;
  eRoundEnd_FragLimit:cardinal=4;
  eRoundEnd_ArtefactLimit:cardinal=3;
  eRoundEnd_Force:cardinal=$FFFFFFFF;

  function IsServerControlsHits():boolean;
  procedure game_PlayerAddMoney(pgame:pgame_sv_mp; ps:pgame_PlayerState; amount:int32); stdcall;
  procedure game_RejectGameItem(pgame:pgame_sv_mp; entity:pCSE_Abstract); stdcall;
  procedure game_KillPlayer(pgame:pgame_sv_mp; id_who:cardinal; GameID:cardinal); stdcall;
  procedure game_OnPlayerSelectTeam(pgame:pgame_sv_mp; client_id:cardinal; team:int16); stdcall;
  procedure game_OnPlayerSelectSkin(pgame:pgame_sv_mp; client_id:cardinal; skin:int16); stdcall;
  function GetPlayerStateByGameID(game:pgame_sv_GameState; gameid:cardinal):pgame_PlayerState; stdcall;
  function GetClientByGameID(gameid:cardinal):pxrClientData; stdcall;
  function GetClientDataByPlayerState(ps:pgame_PlayerState):pxrClientData;
  function IsServerObjectControlledByClient(obj:pCSE_Abstract; client:pxrClientData):boolean;
  function GetCurrentGame():pgame_sv_mp;
  procedure DestroyAllPlayerItems(game:pgame_sv_mp; client_id:cardinal); stdcall;
  function EntityFromEid(game:pgame_sv_GameState; gameid:cardinal):pCSE_Abstract; stdcall;
  procedure game_signal_Syncronize(); stdcall;
  function Init():boolean; stdcall;

implementation
uses basedefs, Level, Servers, PureServer, xr_debug, sysutils, srcCalls;

var
  game_sv_mp__KillPlayer:srcECXCallFunction;
  game_sv_mp__RejectGameItem:srcECXCallFunction;
  virtual_game_sv_mp__Player_AddMoney:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectTeam:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectSkin:srcVirtualECXCallFunction;
  virtual_game_sv_mp__DestroyAllPlayerItems:srcVirtualECXCallFunction;
  game_sv_GameState__get_entity_from_eid:srcECXCallFunction;
  virtual_game_sv_GameState__get_eid:srcVirtualECXCallFunction;
  pnet_sv_control_hit:pboolean;

procedure game_PlayerAddMoney(pgame:pgame_sv_mp; ps:pgame_PlayerState; amount:int32); stdcall;
begin
  virtual_game_sv_mp__Player_AddMoney.Call([pgame, ps, amount]);
end;

procedure game_OnPlayerSelectTeam(pgame:pgame_sv_mp; client_id:cardinal; team:int16); stdcall;
var
  p:NET_Packet;
begin
  ClearPacket(@p);
  WriteToPacket(@p, @team, sizeof(team));

  virtual_game_sv_mp__OnPlayerSelectTeam.Call([pgame, @p, client_id]);
end;

procedure game_OnPlayerSelectSkin(pgame:pgame_sv_mp; client_id:cardinal; skin:int16); stdcall;
var
  p:NET_Packet;
begin
  ClearPacket(@p);
  WriteToPacket(@p, @skin, sizeof(skin));

  virtual_game_sv_mp__OnPlayerSelectSkin.Call([pgame, @p, client_id]);
end;

function IsServerControlsHits():boolean;
begin
  result:=pnet_sv_control_hit^;
end;

procedure game_RejectGameItem(pgame:pgame_sv_mp; entity:pCSE_Abstract); stdcall;
begin
  game_sv_mp__RejectGameItem.Call([pgame,entity]);
end;

procedure game_KillPlayer(pgame:pgame_sv_mp; id_who:cardinal; GameID:cardinal); stdcall;
begin
  game_sv_mp__KillPlayer.Call([pgame, id_who, GameID]);
end;

function GetCurrentGame():pgame_sv_mp;
var
  lvl:pCLevel;
begin
  lvl:=GetLevel();
  R_ASSERT(lvl<>nil, 'Cannot get current game - no level present');
  R_ASSERT(lvl.Server<>nil, 'Cannot get current game - no server present');
  result:=pgame_sv_mp(GetLevel().Server.game);
end;

procedure DestroyAllPlayerItems(game:pgame_sv_mp; client_id:cardinal); stdcall;
begin
  virtual_game_sv_mp__DestroyAllPlayerItems.Call([game, client_id]);
end;

function GetPlayerStateByGameID(game:pgame_sv_GameState; gameid:cardinal):pgame_PlayerState; stdcall;
begin
 result:=virtual_game_sv_GameState__get_eid.Call([game, gameid]).VPointer;
end;

function GetClientByGameID(gameid: cardinal): pxrClientData; stdcall;
begin
  result:=nil;
  ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @gameid, @result);
end;

function IsServerObjectControlledByClient(obj:pCSE_Abstract; client:pxrClientData):boolean;
begin
  result:=false;
  if (obj=nil) or (client=nil) then exit;

  //ѕолучим владельца высшего уровн€ в иерархии
  while obj.ID_Parent<>$FFFF do begin
    obj:=EntityFromEid(@GetCurrentGame.base_game_sv_GameState, obj.ID_Parent);
    R_ASSERT(obj<>nil, 'Can''t get parent object by ID='+inttostr(obj.ID_Parent), 'CheckServerObjectParent');
  end;

  result:=pxrClientData(obj.owner).base_IClient.ID.id = client.base_IClient.ID.id;
end;

function GetClientDataByPlayerState(ps:pgame_PlayerState):pxrClientData;
begin
 result:=nil;
  if ps <> nil then begin
    ForEachClientDo(AssignFoundClientDataAction, OnePlayerStateSearcher, @ps, @result);
  end;
end;

function EntityFromEid(game:pgame_sv_GameState; gameid:cardinal):pCSE_Abstract; stdcall;
begin
  result:=game_sv_GameState__get_entity_from_eid.Call([game, gameid]).VPointer;
  R_ASSERT((result = nil) or (result.ID = gameid), 'Cannot get entity by eid ('+inttostr(gameid)+') - something gone wrong');
end;

procedure game_signal_Syncronize(); stdcall;
var
  game:pgame_sv_mp;
begin
  game:=GetCurrentGame();
  if game<>nil then begin
    game.base_game_sv_GameState.sv_force_sync:=1;
  end;
end;


//xrgame+38c1b0 -  game_sv_mp::OnEvent

function Init():boolean; stdcall;
const
  game_sv_mp__Player_AddMoney_index:cardinal=$1DC;
  game_sv_GameState__get_eid_index:cardinal=$98;
  game_sv_mp__DestroyAllPlayerItems_index:cardinal=$154;
  game_sv_mp__OnPlayerSelectTeam_index:cardinal=$1a0;
  game_sv_mp__OnPlayerSelectSkin_index:cardinal=$1a4;
begin
  if xrGameDllType()=XRGAME_1602 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$38f750),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
    game_sv_mp__RejectGameItem:=srcECXCallFunction.Create(pointer(xrGame+$38d6a0),[vtPointer, vtPointer], 'RejectGameItem', 'game_sv_mp');
    game_sv_GameState__get_entity_from_eid:=srcECXCallFunction.Create(pointer(xrGame+$377530), [vtPointer, vtInteger], 'get_entity_from_eid', 'game_sv_GameState');
    pnet_sv_control_hit:=pointer(xrGame+$651110);
  end;
  virtual_game_sv_mp__Player_AddMoney:=srcVirtualECXCallFunction.Create(game_sv_mp__Player_AddMoney_index, [vtPointer, vtPointer, vtInteger], 'Player_AddMoney','game_sv_mp');
  virtual_game_sv_mp__DestroyAllPlayerItems:=srcVirtualECXCallFunction.Create(game_sv_mp__DestroyAllPlayerItems_index, [vtPointer, vtInteger], 'DestroyAllPlayerItems', 'game_sv_mp');
  virtual_game_sv_mp__OnPlayerSelectTeam:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectTeam_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectTeam','game_sv_mp');
  virtual_game_sv_mp__OnPlayerSelectSkin:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectSkin_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectSkin','game_sv_mp');

  virtual_game_sv_GameState__get_eid:=srcVirtualECXCallFunction.Create(game_sv_GameState__get_eid_index, [vtPointer, vtInteger], 'get_eid', 'game_sv_GameState');
  result:=true;
end;

end.
