unit Games;
{$mode delphi}
interface
uses BaseClasses, Packets, Vector, Items, xrstrings, Banned, Objects, Schedule, HUD, Clients, srcCalls;
function Init():boolean; stdcall;

type
game_GameState = packed record
  base_DLL_Pure:DLL_Pure;
  m_type:cardinal;
  m_phase:cardinal;
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
  m_fETimeFactor:single;//с этой скоростью меняется погода
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
  base_ISheduled:IScheduled;
  m_game_type_name:shared_str;
  m_game_ui_custom:pCUIGameCustom;
  m_u16VotingEnabled:word;
  _unused1:word;
  m_bServerControlHits:byte; {boolean}
  _unused2:byte;
  _unused3:word;
  players:array[0..19] of byte;
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
  m_bMapRotation:boolean;
  m_bMapNeedRotation:boolean;
  m_bMapSwitched:boolean;
  m_bFastRestart:boolean;
  m_pMapRotationList:xr_deque;
  sv_force_sync:boolean;
  _reserved1:byte;
  _reserved2:word;
  rpoints_MinDist:array[0..3] of single;
  rpoints: array[0..3] of xr_vector {RPoint};
  rpointsBlocked:xr_vector;
  round_end_reason:cardinal;
  _unknown:cardinal; //непонятно, к какому классу эти 4 байта отнести, к текущему или к производному. Не похоже, что юзаются вообще  
end;
pgame_sv_GameState=^game_sv_GameState;

type game_sv_mp = packed record
  base_game_sv_GameState:game_sv_GameState;
  m_CorpseList:xr_deque;
  m_aRanks:xr_vector {Rank_Struct};
  m_bRankUp_Allowed:boolean;
  _unused1:byte;
  _unused2:word;
  TeamList:xr_deque;
  m_strWeaponsData:pCItemMgr;
  m_bVotingActive:boolean;
  m_bVotingReal:boolean;
  fz_vote_started_by_admin:byte;
  _unused3:byte;
  m_uVoteStartTime:cardinal;
  m_pVoteCommand:shared_str;
  m_voting_string:shared_str;
  m_started_player:shared_str;
  m_u8SpectatorModes:byte;
  m_cdkey_ban_list:cdkey_ban_list;
  round_statistics_dump_fn:string_path;
  m_async_stats:async_statistics_collector;
  m_async_stats_request_time:cardinal;
  _unknown:cardinal; //непонятно, к какому классу эти 4 байта отнести, к текущему или к производному. Более похоже на первое, так как первый член второго по смыслу vtable  
end;
pgame_sv_mp=^game_sv_mp;


type game_sv_Deathmatch = packed record
  game_sv_mp_base:game_sv_mp;
  game_sv_mp:pure_relcase;
  m_vFreeRPoints:array [0..3] of xr_vector {u32};
  m_dwLastRPoints:array[0..3] of cardinal;

  m_delayedRoundEnd:boolean;
  _reserved1:byte;
  _reserved2:word;
  m_roundEndDelay:cardinal;

  m_delayedTeamEliminated:boolean;
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
  m_bSpectatorMode:boolean;
  _unused1:byte;
  _unused2:word;
  m_dwSM_SwitchDelta:cardinal;
  m_dwSM_LastSwitchTime:cardinal;
  m_dwSM_CurViewEntity:cardinal;
  m_pSM_CurViewEntity:pCObject;
  m_dwWarmUp_CurTime:cardinal;
  m_bInWarmUp:boolean;
  _unused3:byte;
  _unused4:word;
  m_not_free_ammo_str:shared_str;
end;

type game_sv_TeamDeathmatch = packed record
  game_sv_Deathmatch_base:game_sv_Deathmatch;
  teams_swaped:boolean;
end;

const
  eRoundEnd_Finish:cardinal=0;
  eRoundEnd_GameRestarted:cardinal=1;
  eRoundEnd_GameRestartedFast:cardinal=2;
  eRoundEnd_TimeLimit:cardinal=3;
  eRoundEnd_FragLimit:cardinal=4;
  eRoundEnd_ArtefactLimit:cardinal=3;
  eRoundEnd_Force:cardinal=$FFFFFFFF;


var
  game_sv_mp__KillPlayer:srcECXCallFunction;
  virtual_game_sv_mp__Player_AddMoney:srcVirtualECXCallFunction;

const
  game_sv_mp__Player_AddMoney_index:cardinal=$1DC;  

implementation
uses basedefs;

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$30ab90),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$3209E0),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
  end;
  virtual_game_sv_mp__Player_AddMoney:=srcVirtualECXCallFunction.Create(game_sv_mp__Player_AddMoney_index, [vtPointer, vtPointer, vtInteger], 'Player_AddMoney','game_sv_mp');
 result:=true;
end;

end.
