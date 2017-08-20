unit Gametypes;
{$mode delphi}
interface
uses BaseClasses, Servers, Packets, Items, xrstrings, Vector, srcCalls;
function Init():boolean; stdcall;

type

async_statistics_collector = packed record
  async_responses:array[0..15] of byte;
end;

GameEventQueue = packed record
//todo:fill
end;
pGameEventQueue=^GameEventQueue;

game_GameState = packed record
  base_DLL_Pure:DLL_Pure;
  m_type:byte;
  _zeros_1:byte;
  _zeros_2:word;
  m_phase:word;
  _zeros_3:word;
  m_round:integer;
  m_start_time:cardinal;
  m_round_start_time:cardinal;
  m_round_start_time_str:array [0..63] of char;
  _unknown_1:cardinal;
  m_qwStartProcessorTime:Int64;
  m_qwStartGameTime:Int64;
  m_fTimeFactor:single;
  _unknown_2:cardinal;
  m_qwEStartProcessorTime:Int64;
  m_qwEStartGameTime:Int64;
  m_fETimeFactor:single;
  _unknown_3:cardinal;
end;


item_respawn_manager = packed record
  spawn_packet_store:NET_Packet;
  m_server:pxrServer;
  m_respawns:xr_vector {spawn_item};
  respawn_sections_map:array [0..15] of byte;
  level_items_respawn:array[0..$17] of byte;
end;

game_sv_GameState = packed record
  base_game_GameState:game_GameState;
  m_server:pxrServer;
  m_event_queue:pGameEventQueue;
  m_item_respawner:item_respawn_manager;
  m_bMapRotation:byte; {boolean}
  m_bMapNeedRotation:byte; {boolean}
  m_bMapSwitched:byte; {boolean}
  m_bFastRestart:byte; {boolean}
  m_pMapRotation_List:array [0..$27] of byte;
  sv_force_sync:cardinal;
  rpoints_MinDist:array[0..3] of single;
  rpoints:array[0..3] of xr_vector;
  rpoints_blocked:xr_vector;
  round_end_reason:cardinal;
  _unknown_1:cardinal;
end;

game_sv_mp = packed record
  base_game_sv_GameState:game_sv_GameState;
  m_CorpseList:array [0..$27] of byte;
  m_aRanks:xr_vector;
  m_bRankUp_Allowed:byte {boolean};
  _unused_1:byte;
  _unused2:word;
  TeamList:array [0..$27] of byte;
  m_strWeaponsData:pCItemMgr;
  m_bVotingActive:byte {boolean};
  m_bVotingReal:byte {boolean};
  _unused3:word;
  m_uVoteStartTime:cardinal;
  m_pVoteCommand:shared_str;
  m_voting_string:shared_str;
  m_started_player:shared_str;
  m_u8SpectatorModes:byte;
  //todo: fill other...
//  _unknown_1:array[0..$207] of Byte;
//  m_async_stats:async_statistics_collector;
//  m_async_stats_request_time:cardinal;
end;

pgame_sv_mp = ^game_sv_mp;


const
  game_sv_GameState__get_eid_index:cardinal=$98;
  
var
  virtual_game_sv_GameState__get_eid:srcVirtualECXCallFunction;

implementation
function Init():boolean; stdcall;
begin
 virtual_game_sv_GameState__get_eid:=srcVirtualECXCallFunction.Create(game_sv_GameState__get_eid_index, [vtPointer, vtInteger], 'get_eid', 'game_sv_GameState');
 result:=true;
end;

end.
