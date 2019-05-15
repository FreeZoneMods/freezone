unit Games;
{$mode delphi}
{$I _pathes.inc}
interface
uses BaseClasses, Packets, Vector, BuyWnd, xrstrings, Banned, Objects, Schedule, HUD, Clients, srcCalls, CSE, Synchro;

type
game_GameState = packed record
  base_DLL_Pure:DLL_Pure;
  m_type:cardinal;
  m_phase:cardinal; //Check - maybe word+unused
  m_round:cardinal;
  m_start_time:cardinal;
  m_round_start_time:cardinal;
  m_round_start_time_str:array [0..63] of Char;
  _unused1:cardinal;                             //�������� �� �������������� �����
  m_qwStartProcessorTime:int64;
  m_qwStartGameTime:int64;
  m_fTimeFactor:single; //� ���� ��������� ������ ����
  _unused2:cardinal;
  m_qwEStartProcessorTime:int64;
  m_qwEStartGameTime:int64;
  m_fETimeFactor:single;//� ���� ��������� �������� ������
  _unknown3:cardinal;
end;

WeaponUsageStatistic = packed record
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

game_cl_GameState = packed record
  base_game_GameState:game_GameState;
  base_ISheduled:ISheduled;
  m_game_type_name:shared_str;
  m_game_ui_custom:pCUIGameCustom;
  m_u16VotingEnabled:word;
  //offset: 0xaa
  m_bServerControlHits:byte; {boolean}
  _unused1:byte;
  players:array[0..23] of byte;
  local_svdpnid:ClientID;
  local_player:pgame_PlayerState;
  m_WeaponUsageStatistic:pWeaponUsageStatistic;
end;

pgame_cl_GameState = ^game_cl_GameState;

{type game_cl_mp = packed record
  base_game_cl_GameState:game_cl_GameState;
  TeamList:xr_deque;
  m_pSndMessages:xr_vector;
  m_bJustRestarted:byte;
  _unused1:byte;
  _unused2:word;
  m_pSndMessagesInPlay:xr_vector;
  m_pBonusList:xr_vector;
  m_bVotingActive:byte; //boolean
  _unused3:byte;
  _unused4:word;
  m_pVoteStartWindow:pCUIVotingCategory;
  m_pVoteRespondWindow:pCUIVote;
  m_pMessageBox:pCUIMessageBoxEx;
  m_bSpectatorSelected:cardinal; //BOOL
  m_EquipmentIconsShader:ui_shader;
  m_KillEventIconsShader:ui_shader;
  m_RadiationIconsShader:ui_shader;
  m_BloodLossIconsShader:ui_shader;
  m_RankIconsShader:ui_shader;
  m_u8SpectatorModes:byte;
  m_bSpectator_FreeFly:byte; //bool
  m_bSpectator_FirstEye:byte; //bool
  m_bSpectator_LookAt:byte; //bool
  m_bSpectator_FreeLook:byte; //bool
  m_bSpectator_TeamCamera:byte; //bool
  _unused5:word;
  m_cur_MenuID:cardinal;
  //todo:FILL!
end; }

type GameEventQueue = packed record
  //todo:fillme
end;
pGameEventQueue=^GameEventQueue;

type item_respawn_manager = packed record
  spawn_packet_store:NET_Packet;
  m_server:pointer;{pxrServer;}
  m_respawns:xr_vector {spawn_item};
  m_respawn_sections_cache:assotiative_vector;
  level_items_respawn:xr_set;
end;

type async_statistics_collector = packed record
  async_responses:assotiative_vector;
end;

type game_sv_GameState = packed record
  base_game_GameState:game_GameState;
  m_server:pointer;{pxrServer;}
  m_event_queue:pGameEventQueue;
  m_item_respawner:item_respawn_manager;
  m_bMapRotation:byte;{boolean}
  m_bMapNeedRotation:byte;{boolean}
  m_bMapSwitched:byte;{boolean}
  m_bFastRestart:byte;{boolean}
  m_pMapRotationList:xr_deque;
  sv_force_sync:byte;{boolean}
  _reserved1:byte;
  _reserved2:word;
  rpoints_MinDist:array[0..3] of single;
  rpoints: array[0..3] of xr_vector {RPoint};
  rpointsBlocked:xr_vector;
  round_end_reason:cardinal;
  _unknown:cardinal; //���������, � ������ ������ ��� 4 ����� �������, � �������� ��� � ������������. �� ������, ��� ������� ������  
end;
pgame_sv_GameState=^game_sv_GameState;

type game_sv_mp = packed record
  base_game_sv_GameState:game_sv_GameState;
  m_CorpseList:xr_deque;
  m_aRanks:xr_vector {Rank_Struct};
  m_bRankUp_Allowed:byte;{boolean}
  _unused1:byte;
  _unused2:word;
  TeamList:xr_deque;
  m_strWeaponsData:pCItemMgr;
  m_bVotingActive:byte; {boolean}
  m_bVotingReal:byte; {boolean}
  fz_vote_started_by_admin:byte;
  _unused3:byte;
  m_uVoteStartTime:cardinal;
  m_pVoteCommand:shared_str;
  m_voting_string:shared_str;
  m_started_player:shared_str;
  m_u8SpectatorModes:byte;
  _unused4:byte;
  _unused5:word;
  m_cdkey_ban_list:cdkey_ban_list;
  round_statistics_dump_fn:string_path;
  m_async_stats:async_statistics_collector;
  m_async_stats_request_time:cardinal;
  _unknown:cardinal; //���������, � ������ ������ ��� 4 ����� �������, � �������� ��� � ������������. ����� ������ �� ������, ��� ��� ������ ���� ������� �� ������ vtable  
end;
pgame_sv_mp=^game_sv_mp;


type game_sv_Deathmatch = packed record
  base_game_sv_mp:game_sv_mp;
  pure_relcase_base:pure_relcase;
  m_vFreeRPoints:array [0..3] of xr_vector {u32};
  m_dwLastRPoints:array[0..3] of cardinal;

  m_delayedRoundEnd:byte;
  _reserved1:byte;
  _reserved2:word;
  m_roundEndDelay:cardinal;

  m_delayedTeamEliminated:byte;
  _reserved3:byte;
  _reserved4:word;
  m_TeamEliminatedDelay:cardinal;

  m_sBaseWeaponCostSection:shared_str;
  teams:xr_vector {game_TeamState};
  pWinnigPlayerName:PChar;
  m_AnomaliesPermanent:xr_vector;
  m_AnomalySetsList:xr_vector;
  m_AnomalySetID:xr_vector {u8};
  m_dwLastAnomalySetID:cardinal;
  m_dwLastAnomalyStartTime:cardinal;
  m_AnomalyIDSetsList:xr_vector;
  m_bSpectatorMode:byte;
  _unused1:byte;
  _unused2:word;
  m_dwSM_SwitchDelta:cardinal;
  m_dwSM_LastSwitchTime:cardinal;
  m_dwSM_CurViewEntity:cardinal;
  m_pSM_CurViewEntity:pCObject;
  m_dwWarmUp_CurTime:cardinal;
  m_bInWarmUp:byte;
  _unused3:byte;
  _unused4:word;
  m_not_free_ammo_str:shared_str;
end;
pgame_sv_Deathmatch=^game_sv_Deathmatch;

type game_sv_TeamDeathmatch = packed record
  base_game_sv_Deathmatch:game_sv_Deathmatch;
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
uses basedefs, Level, Servers, PureServer, xr_debug, sysutils;

var
  game_sv_mp__KillPlayer:srcECXCallFunction;
  game_sv_mp__RejectGameItem:srcECXCallFunction;
  virtual_game_sv_mp__Player_AddMoney:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectTeam:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectSkin:srcVirtualECXCallFunction;
  virtual_game_sv_mp__DestroyAllPlayerItems:srcVirtualECXCallFunction;
  game_sv_GameState__get_entity_from_eid:srcEDXCallFunctionWEAXArg;
  virtual_game_sv_GameState__get_eid:srcVirtualECXCallFunction;
  pnet_sv_control_hit:pboolean;

const
  game_sv_mp__Player_AddMoney_index:cardinal=$1DC;
  game_sv_GameState__get_eid_index:cardinal=$98;
  game_sv_mp__DestroyAllPlayerItems_index:cardinal=$154;
  game_sv_mp__OnPlayerSelectTeam_index:cardinal=$1a0;
  game_sv_mp__OnPlayerSelectSkin_index:cardinal=$1a4;

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

  //������� ��������� ������� ������ � ��������
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

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$30ab90),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
    game_sv_mp__RejectGameItem:=srcECXCallFunction.Create(pointer(xrGame+$30ef40),[vtPointer, vtPointer], 'RejectGameItem', 'game_sv_mp');
    game_sv_GameState__get_entity_from_eid:=srcEDXCallFunctionWEAXArg.Create(pointer(xrGame+$2f2290), [vtPointer, vtInteger], 'get_entity_from_eid', 'game_sv_GameState');
    pnet_sv_control_hit:=pointer(xrGame+$5e94c8);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$3209E0),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
    game_sv_mp__RejectGameItem:=srcECXCallFunction.Create(pointer(xrGame+$324de0),[vtPointer, vtPointer], 'RejectGameItem', 'game_sv_mp');
    game_sv_GameState__get_entity_from_eid:=srcEDXCallFunctionWEAXArg.Create(pointer(xrGame+$3071c0), [vtPointer, vtInteger], 'get_entity_from_eid', 'game_sv_GameState');
    pnet_sv_control_hit:=pointer(xrGame+$6065C8);
  end;
  virtual_game_sv_mp__Player_AddMoney:=srcVirtualECXCallFunction.Create(game_sv_mp__Player_AddMoney_index, [vtPointer, vtPointer, vtInteger], 'Player_AddMoney','game_sv_mp');
  virtual_game_sv_mp__DestroyAllPlayerItems:=srcVirtualECXCallFunction.Create(game_sv_mp__DestroyAllPlayerItems_index, [vtPointer, vtInteger], 'DestroyAllPlayerItems', 'game_sv_mp');
  virtual_game_sv_mp__OnPlayerSelectTeam:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectTeam_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectTeam','game_sv_mp');
  virtual_game_sv_mp__OnPlayerSelectSkin:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectSkin_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectSkin','game_sv_mp');

  virtual_game_sv_GameState__get_eid:=srcVirtualECXCallFunction.Create(game_sv_GameState__get_eid_index, [vtPointer, vtInteger], 'get_eid', 'game_sv_GameState');
  result:=true;
end;

end.
