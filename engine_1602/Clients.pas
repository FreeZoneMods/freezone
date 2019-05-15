unit Clients;
{$mode delphi}
{$I _pathes.inc}

interface
uses Packets, xrstrings, Vector, GameMessages;

type
ClientID = packed record
  id:cardinal;
end;

SClientConnectData = packed record
  clientID:ClientID;
  name:array[0..63] of char;
  pass:array[0..63] of char;
  process_id:cardinal;
end;
pSClientConnectData = ^SClientConnectData;

IClientStatistics = packed record //sizeof = 0x88
  ci_last:DPN_CONNECTION_INFO;
  //offset:0x5c
  mps_recive:cardinal;
  mps_receive_base:cardinal;
  mps_send:cardinal;
  mps_send_base:cardinal;
  dwBaseTime:cardinal;
  device_timer:pointer; //pCTimer;
  dwTimesBlocked:cardinal;
  dwBytesSended:cardinal;
  dwBytesPerSec:cardinal;
  dwBytesReceived:cardinal;
  dwBytesReceivedPerSec:cardinal;
end;

IClient = packed record //sizeof = 0x8164
  base_MultipacketSender:MultipacketSender;
  //offset: 0x8038
  stats:IClientStatistics;
  //offset: 0x80C0
  ID:ClientID;
  m_guid:array [0..127] of Char;
  //offset: 0x8144
  name:shared_str;
  pass:shared_str;
  flags:cardinal;
  dwTime_LastUpdate:cardinal;
  m_cAddress:ip_address;
  m_dwPort:cardinal;
  process_id:cardinal;
  server:pointer; //pIPureServer;
end;
pIClient=^IClient;
ppIClient=^pIClient;

award_data = packed record
  m_count:word;
  _unused1:word;
  m_last_reward_date:cardinal;
end;

player_account = packed record //sizeof = 0x20
  m_player_name:shared_str;
  m_clan_name:shared_str;
  //offset:0x8
  m_profile_id:cardinal;
  //offset:0xc
  m_clan_leader:byte;
  //offset:0xD
  m_online_account:byte;
  _unused1:word;
  //offset:0x10
  m_last_reward_date:assotiative_vector; //<award_data>
end;

game_PlayerState = packed record //sizeof = 0xb9 (Exact! determined by operator new argument!)
  vftable:pointer;  
  //name:array[0..63] of char; //оригинальное определение
  //мы тут схитрим - в последние 4 байта запихнем указатель на пристегивающийся буфер
  //name:array[0..59] of char;
  //FZBuffer:pointer;

  team:byte;

  m_iRivalKills:smallint;
  m_iSelfKills:smallint;
  //offset: 0x9
  m_iTeamKills:smallint;
  m_iKillsInRowCurr:smallint;
  m_iKillsInRowMax:smallint;
  //offset: 0xf
  m_iDeaths:smallint;
  //offset: 0x11
  money_for_round:integer;
  experience_Real:single;
  experience_New:single;
  experience_D:single;
  rank:byte;
  af_count:byte;
  //offste:0x23
  flags__:word;
  ping:word;
  GameID:word;
  lasthitter:word;
  lasthitweapon:word;
  skin:byte;
  RespawnTime:cardinal;
  DeathTime:cardinal;
  money_delta:smallint;
  //offset: 0x34
  m_bCurrentVoteAgreed:byte;
  mOldIDs:xr_deque;
  //offset:0x5d
  money_added:integer;
  m_aBonusMoney:xr_vector;//<Bonus_Money_Struct>
  m_bPayForSpawn:boolean;
  m_online_time:cardinal;
  //offset: 0x72
  m_account:player_account;
  //offset:0x92
  m_player_ip:shared_str;
  m_player_digest:shared_str;

  pItemList:xr_vector;//<s16>
  pSpawnPointsList:xr_vector;//<s16>
  m_s16LastSRoint:smallint;
  LastBuyAcount:integer;
  //offset:0xb8
  m_bClearRun:byte;
end;
pgame_PlayerState=^game_PlayerState;
ppgame_PlayerState=^pgame_PlayerState;

xrClientData = packed record //sizeof = 0x8214
  base_IClient:IClient;
  //offset: 0x8164
  owner:pointer; //pCSE_Abstract;
  net_Ready:cardinal;

  net_Accepted:cardinal;
  net_PassUpdates:cardinal;
  net_LastMoveUpdateTime:cardinal;

  //offset:0x8178
  ps:pgame_PlayerState;

  m_ping_warn__m_maxPingWarnings:byte;
  _unused7:byte;
  _unused8:word; //!!!good candidate for additional buffer
  m_ping_warn__m_dwLastMaxPingWarningTimes:cardinal;

  m_admin_rights__m_has_admin_rights:boolean;
  _unused9:byte;
  _unused10:word; //candidate for additional buffer
  m_admin_rights__m_dwLoginTime:cardinal;

  m_cdkey_digest:shared_str;
  m_secret_key:secure_messaging__key_t;
  m_last_key_sync_request_seed:integer;

end;
pxrClientData=^xrClientData;
ppxrClientData=^pxrClientData;

xrGameSpyClientData = packed record
  base_xrClientData:xrClientData;
  m_pChallengeString:array[0..63] of char;
  m_iCDKeyReauthHint:integer;
  m_bCDKeyAuth:boolean;
  _unused1:byte;
  _unused2:word;
end;
pxrGameSpyClientData=^xrGameSpyClientData;


const
  ICLIENT_FLAG_LOCAL:cardinal = 1;
  ICLIENT_FLAG_RECONNECT:cardinal = 4;

  GAME_PLAYER_FLAG_LOCAL:cardinal=1;
  GAME_PLAYER_FLAG_VERY_VERY_DEAD:cardinal=4;
  GAME_PLAYER_FLAG_SPECTATOR:cardinal = 8;
  GAME_PLAYER_FLAG_INVINCIBLE:cardinal=32;
  GAME_PLAYER_FLAG_ONBASE:cardinal = 64;

function Init():boolean; stdcall;
function IsLocalServerClient(client: pIClient): boolean;

implementation

function IsLocalServerClient(client: pIClient): boolean;
begin
  result:=(client.flags and ICLIENT_FLAG_LOCAL) <> 0;
end;

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
