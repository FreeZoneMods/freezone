unit Clients;
{$mode delphi}
interface
uses Packets, Time, xrstrings, PureServer, CSE, Vector, GameMessages;
function Init():boolean; stdcall;

type
ClientID = packed record
  id:cardinal;
end;

IClientStatistics = packed record
  ci_last:DPN_CONNECTION_INFO;
  mps_recive:cardinal;
  mps_receive_base:cardinal;
  mps_send:cardinal;
  mps_send_base:cardinal;
  dwBaseTime:cardinal;
  device_timer:pCTimer;
	dwTimesBlocked:cardinal;
	dwBytesSended:cardinal;
	dwBytesPerSec:cardinal;
end;

IClient = packed record
  base_MultipacketSender:MultipacketSender;
  stats:IClientStatistics;
  ID:ClientID;
  m_guid:array [0..127] of Char;
  name:shared_str;
  pass:shared_str;
  flags:cardinal; //may be gap!!!
  dwTime_LastUpdate:cardinal;
  m_cAddress:ip_address;
  m_dwPort:cardinal;
  process_id:cardinal;
  server:pIPureServer;
end;
pIClient=^IClient;
ppIClient=^pIClient;

game_PlayerState = packed record
  vftable:pointer;  
  //name:array[0..63] of char; //оригинальное определение
  //мы тут схитрим - в последние 4 байта запихнем указатель на пристегивающийся буфер
  name:array[0..59] of char;
  FZBuffer:pointer;

  team:byte;

  m_iRivalKills:smallint;
  m_iSelfKills:smallint;
  m_iTeamKills:smallint;
  m_iKillsInRowCurr:smallint;
  m_iKillsInRowMax:smallint;
  m_iDeaths:smallint;
  money_for_round:integer;
  experience_Real:single;
  experience_New:single;
  experience_D:single;
  rank:byte;
  af_count:byte;
  flags__:word;
  ping:word;
  GameID:word;
  lasthitter:word;
  lasthitweapon:word;
  skin:byte;
  RespawnTime:cardinal;
  DeathTime:cardinal;
  money_delta:smallint;
  m_bCurrentVoteAgreed:byte;
  mOldIDs:xr_deque;   
  money_added:integer;
  m_aBonusMoney:xr_vector{<Bonus_Money_Struct>};
  m_bPayForSpawn:boolean;
  m_online_time:cardinal;
  pItemList:xr_vector{<s16>};
  pSpawnPointsList:xr_vector{<s16>};
  m_s16LastSRoint:smallint;
  LastBuyAcount:integer;
  m_bClearRun:boolean;
  _unused1:byte;
  _unused2:word;
end;
pgame_PlayerState=^game_PlayerState;
ppgame_PlayerState=^pgame_PlayerState;

xrClientData = packed record
  base_IClient:IClient;
  owner:pCSE_Abstract;
  net_Ready:boolean;
  _unused1:byte;
  _unused2:word;

  net_Accepted:boolean;
  _unused3:byte;
  _unused4:word;

  net_PassUpdates:boolean;
  _unused5:byte;
  _unused6:word;

  net_LastMoveUpdateTime:cardinal;

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

implementation

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
