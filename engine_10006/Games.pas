unit Games;
{$mode delphi}
{$I _pathes.inc}

interface
uses BaseClasses, Vector, xrstrings, Objects, Clients, srcCalls, BuyWnd, CSE;
function Init():boolean; stdcall;

type
game_GameState = packed record //sizeof = 0x98
  base_DLL_Pure:DLL_Pure;
  m_type:cardinal;
  m_phase:word;
  _unused1:word;
  m_round:integer;
  m_start_time:cardinal;
  m_round_start_time:cardinal;
  m_round_start_time_str:array [0..63] of Char;
  _unused2:cardinal;                             //кандидат на дополнительный буфер
  m_qwStartProcessorTime:int64;
  m_qwStartGameTime:int64;
  m_fTimeFactor:single; //с этой скоростью тикают часы
  _unused3:cardinal;
  m_qwEStartProcessorTime:int64;
  m_qwEStartGameTime:int64;
  m_fETimeFactor:single;//с этой скоростью мен€етс€ погода
  _unknown3:cardinal;
end;

game_cl_GameState = packed record
//todo:fill
end;

pgame_cl_GameState = ^game_cl_GameState;

type GameEventQueue = packed record
  //todo:fillme
end;
pGameEventQueue=^GameEventQueue;

type game_sv_GameState = packed record //sizeof = 0x120
  base_game_GameState:game_GameState;
  m_server:pointer;{pxrServer;}
  m_event_queue:pGameEventQueue;
  m_bMapRotation:byte;{boolean}
  m_bMapNeedRotation:byte;{boolean}
  m_bMapSwitched:byte;{boolean}
  m_bFastRestart:byte;{boolean}
  m_pMapRotationList:array[0..19] of byte;
  sv_force_sync:byte;{boolean}
  _reserved1:byte;
  _reserved2:word;
  rpoints_MinDist:array[0..3] of single;
  rpoints: array[0..3] of xr_vector {RPoint};
  rpointsBlocked:xr_vector;
  round_end_reason:cardinal;
end;
pgame_sv_GameState=^game_sv_GameState;

type game_sv_mp = packed record //sizeof = 0x170
  base_game_sv_GameState:game_sv_GameState;
  m_CorpseList:xr_deque;
  m_aRanks:xr_vector; {RANKS_LIST}
  m_bRankUp_Allowed:byte; {boolean}
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
  m_u8SpectatorModes:byte;
  _unused4:byte;
  _unused5:word;
end;
pgame_sv_mp=^game_sv_mp;

type game_sv_Deathmatch = packed record  //sizeof = 0x218
  base_game_sv_mp:game_sv_mp;
  base_pure_relcase:pure_relcase;
  m_vFreeRPoints:xr_vector; {cardinal}
  m_dwLastRPoint:cardinal;
  m_delayedRoundEnd:cardinal; {BOOL}
  m_roundEndDelay:cardinal;
  m_delayedTeamEliminated:cardinal; {BOOL}
  m_TeamEliminatedDelay:cardinal;
  m_sBaseWeaponCostSection:shared_str;
  teams:xr_vector;
  pWinnigPlayerName:PAnsiChar;
  m_AnomaliesPermanent:xr_vector; {xr_string}
  m_AnomalySetsList:xr_vector; {from xr_vector<xr_string>}
  m_AnomalySetID:xr_vector; {byte}
  m_dwLastAnomalySetID:cardinal;
  m_dwLastAnomalyStartTime:cardinal;
  m_AnomalyIDSetsList:xr_vector; {from xr_vector<u16>}
  m_bSpectatorMode:byte;{boolean}
  _unused1:byte;
  _unused2:word;
  m_dwSM_SwitchDelta:cardinal;
  m_dwSM_LastSwitchTime:cardinal;
  m_dwSM_CurViewEntity:cardinal;
  m_pSM_CurViewEntity:pCObject;
  m_dwWarmUp_CurTime:cardinal;
  m_bInWarmUp:byte; {boolean}
  _unused3:byte;
  _unused4:word;
end;

pgame_sv_Deathmatch = ^game_sv_Deathmatch;


procedure game_PlayerAddMoney(pgame:pgame_sv_mp; ps:pgame_PlayerState; amount:int32); stdcall;
procedure game_KillPlayer(pgame:pgame_sv_mp; id_who:cardinal; GameID:cardinal); stdcall;
procedure game_OnPlayerSelectTeam(pgame:pgame_sv_mp; client_id:cardinal; team:int16); stdcall;
procedure game_OnPlayerSelectSkin(pgame:pgame_sv_mp; client_id:cardinal; skin:int16); stdcall;
function GetClientDataByPlayerState(ps:pgame_PlayerState):pxrClientData;
function EntityFromEid(game:pgame_sv_GameState; gameid:cardinal):pCSE_Abstract; stdcall;

procedure game_signal_Syncronize(); stdcall;

function IsServerControlsHits():boolean;
function GetCurrentGame():pgame_sv_mp;
function GetClientByGameID(gameid:cardinal):pxrClientData; stdcall;

function IsServerObjectControlledByClient(obj:pCSE_Abstract; client:pxrClientData):boolean;

implementation
uses basedefs, Level, PureServer, Servers, xr_debug, sysutils, Packets;
var
  game_sv_mp__KillPlayer:srcECXCallFunction;
  virtual_game_sv_mp__Player_AddMoney:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectTeam:srcVirtualECXCallFunction;
  virtual_game_sv_mp__OnPlayerSelectSkin:srcVirtualECXCallFunction;
  game_sv_GameState__get_entity_from_eid:srcEDXCallFunctionWEAXArg;
  pnet_sv_control_hit:pboolean;

const
  game_sv_mp__Player_AddMoney_index:cardinal=$174;
  game_sv_mp__OnPlayerSelectTeam_index:cardinal=$1a8;
  game_sv_mp__OnPlayerSelectSkin_index:cardinal=$1ac;

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

procedure game_KillPlayer(pgame: pgame_sv_mp; id_who: cardinal; GameID: cardinal); stdcall;
begin
  game_sv_mp__KillPlayer.Call([pgame, id_who, GameID]);
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

function GetCurrentGame():pgame_sv_mp;
var
  lvl:pCLevel;
begin
  lvl:=GetLevel();
  R_ASSERT(lvl<>nil, 'Cannot get current game - no level present');
  R_ASSERT(lvl.Server<>nil, 'Cannot get current game - no server present');
  result:=pgame_sv_mp(GetLevel().Server.game);
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
  if xrGameDllType()=XRGAME_SV_10006 then begin
    game_sv_mp__KillPlayer:=srcECXCallFunction.Create(pointer(xrGame+$2d8640),[vtPointer, vtInteger, vtInteger], 'KillPlayer', 'game_sv_mp');
    virtual_game_sv_mp__Player_AddMoney:=srcVirtualECXCallFunction.Create(game_sv_mp__Player_AddMoney_index, [vtPointer, vtPointer, vtInteger], 'Player_AddMoney','game_sv_mp');
    virtual_game_sv_mp__OnPlayerSelectTeam:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectTeam_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectTeam','game_sv_mp');
    virtual_game_sv_mp__OnPlayerSelectSkin:=srcVirtualECXCallFunction.Create(game_sv_mp__OnPlayerSelectSkin_index, [vtPointer, vtPointer, vtInteger], 'OnPlayerSelectSkin','game_sv_mp');
    game_sv_GameState__get_entity_from_eid:=srcEDXCallFunctionWEAXArg.Create(pointer(xrGame+$2c1560), [vtPointer, vtInteger], 'get_entity_from_eid', 'game_sv_GameState');
    pnet_sv_control_hit := pointer(xrGame+$56035c);
  end;

  result:=pnet_sv_control_hit<>nil;
end;

end.
