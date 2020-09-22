unit Packets;
{$mode delphi}
{$I _pathes.inc}

interface
uses srcCalls, Synchro, MatVectors;
function Init():boolean; stdcall;


type
//Direct Play structs

DPNMSG_CREATE_PLAYER = packed record
  dwSize:cardinal;
  dpnidPlayer:cardinal;
  pvPlayerContext:pointer;
end;
pDPNMSG_CREATE_PLAYER = ^DPNMSG_CREATE_PLAYER;

DPNMSG_RECEIVE = packed record
  dwSize:cardinal;
  dpnidSender:cardinal;
  pvPlayerContext:cardinal;
  pReceiveData:pByte;
  dwReceiveDataSize:cardinal;
  hBufferHandle:cardinal;
end;
pDPNMSG_RECEIVE=^DPNMSG_RECEIVE;

DPN_CONNECTION_INFO = packed record
  dwSize:cardinal;
  dwRoundTripLatencyMS:cardinal;
  dwThroughputBPS:cardinal;
  dwPeakThroughputBPS:cardinal;

  dwBytesSentGuaranteed:cardinal;
  dwPacketsSentGuaranteed:cardinal;
  dwBytesSentNonGuaranteed:cardinal;
  dwPacketsSentNonGuaranteed:cardinal;

  dwBytesRetried:cardinal;
  dwPacketsRetried:cardinal;
  dwBytesDropped:cardinal;
  dwPacketsDropped:cardinal;

  dwMessagesTransmittedHighPriority:cardinal;
  dwMessagesTimedOutHighPriority:cardinal;
  dwMessagesTransmittedNormalPriority:cardinal;
  dwMessagesTimedOutNormalPriority:cardinal;
  dwMessagesTransmittedLowPriority:cardinal;
  dwMessagesTimedOutLowPriority:cardinal;

  dwBytesReceivedGuaranteed:cardinal;
  dwPacketsReceivedGuaranteed:cardinal;
  dwBytesReceivedNonGuaranteed:cardinal;
  dwPacketsReceivedNonGuaranteed:cardinal;
  dwMessagesReceived:cardinal;
end;
pDPN_CONNECTION_INFO=^DPN_CONNECTION_INFO;


//Game structs
MSYS_PING = packed record
  sign1:cardinal;
  sign2:cardinal;
  dwTime_ClientSend:cardinal;
  dwTime_Server:cardinal;
  dwTime_ClientReceive:cardinal
end;
pMSYS_PING=^MSYS_PING;

MultipacketHeader = packed record
  tag:byte;
  unpacked_size:word;
end;
pMultipacketHeader=^MultipacketHeader;

ip_address = packed record
  a1:byte;
  a2:byte;
  a3:byte;
  a4:byte;
end;
pip_address = ^ip_address;

NET_Buffer = packed record      //size = 0x2004
  data: array[0..8191] of Byte;
  count:cardinal;
end;
pNET_Buffer=^NET_Buffer;

NET_Packet = packed record
  B:NET_Buffer;
  r_pos:cardinal;
  timeReceive:cardinal;
end;
pNET_Packet = ^NET_Packet;


MultipacketSender__Buffer = packed record  //size = 0x2010
  buffer:NET_Packet;
  last_flags:cardinal;
end;

MultipacketSender = packed record  //size = 0x4028
  vftable:pointer;                 //0x0
  _buf:MultipacketSender__Buffer;
  _gbuf:MultipacketSender__Buffer;
  _buf_cs:xrCriticalSection;       //0x4024
end;
pMultipacketSender=^MultipacketSender;

MultipacketReciever = packed record
  vftable:pointer;
end;

NET_Compressor = packed record
  CS:xrCriticalSection;
  m_stats:array[0..$13] of Byte; {xr_map}
end;
pNET_Compressor=^NET_Compressor;

function ip_address_to_str(a:ip_address):string; stdcall;
function ip_address_equal(ip1: ip_address; ip2: ip_address): boolean; stdcall;

procedure ClearPacket(p:pNET_Packet); stdcall;
function WriteToPacket(p:pNET_Packet; buf:pointer; size:cardinal):boolean; stdcall;
procedure InvalidatePacket(p:pNET_Packet); stdcall;
function UnreadBytesCountInPacket(p:pNET_Packet):cardinal;

procedure MakeRadminCmdPacket(p:pNET_Packet; s:string);
procedure MakeMovePlayerPacket(p: pNET_Packet; gameid:word; pos:pFVector3; dir:pFVector3);

var
  pCompressor:pNET_Compressor;
  Decompress:srcECXCallFunction;

const
  PACKET_MAX_SIZE:cardinal = 8192;

  M_EVENT_PACK:word = 20;
  M_CHAT_MESSAGE: word = 25;
  M_MOVE_PLAYERS:word = 36;
  M_REMOTE_CONTROL_CMD:word=40;

//-----------------------------
  GE_RESPAWN: cardinal = 0;
  GE_OWNERSHIP_TAKE: cardinal = 1;
  GE_OWNERSHIP_TAKE_MP_FORCED: cardinal = 2;
  GE_OWNERSHIP_REJECT: cardinal = 3;
  GE_TRANSFER_AMMO: cardinal = 4;
  GE_HIT: cardinal = 5;
  GE_DIE: cardinal = 6;
  GE_ASSIGN_KILLER: cardinal = 7;
  GE_DESTROY: cardinal = 8;
  GE_DESTROY_REJECT: cardinal = 9;
  GE_TELEPORT_OBJECT: cardinal = 10;
  GE_ADD_RESTRICTION: cardinal = 11;
  GE_REMOVE_RESTRICTION: cardinal = 12;
  GE_REMOVE_ALL_RESTRICTIONS: cardinal = 13;
  GE_BUY: cardinal = 14;
  GE_INFO_TRANSFER: cardinal = 15;
  GE_TRADE_SELL: cardinal = 16;
  GE_TRADE_BUY: cardinal = 17;
  GE_WPN_AMMO_ADD: cardinal = 18;
  GE_WPN_STATE_CHANGE: cardinal = 19;
  GE_ADDON_ATTACH: cardinal = 20;
  GE_ADDON_DETACH: cardinal = 21;
  GE_ADDON_CHANGE: cardinal = 22;
  GE_GRENADE_EXPLODE: cardinal = 23;
  GE_INV_ACTION: cardinal = 24;
  GE_ZONE_STATE_CHANGE: cardinal = 25;
  GE_MOVE_ACTOR: cardinal = 26;
  GE_ACTOR_JUMPING: cardinal = 27;
  GE_ACTOR_MAX_POWER: cardinal = 28;
  GE_CHANGE_POS: cardinal = 29;
  GE_GAME_EVENT: cardinal = 30;
  GE_CHANGE_VISUAL: cardinal = 31;
  GE_MONEY: cardinal = 32;
  GEG_PLAYER_ACTIVATE_SLOT: cardinal = 33;
  GEG_PLAYER_ITEM2SLOT: cardinal = 34;
  GEG_PLAYER_ITEM2BELT: cardinal = 35;
  GEG_PLAYER_ITEM2RUCK: cardinal = 36;
  GEG_PLAYER_ITEM_EAT: cardinal = 37;
  GEG_PLAYER_ITEM_SELL: cardinal = 38;
  GEG_PLAYER_ACTIVATEARTEFACT: cardinal = 39;
  GEG_PLAYER_WEAPON_HIDE_STATE: cardinal = 40;
  GEG_PLAYER_ATTACH_HOLDER: cardinal = 41;
  GEG_PLAYER_DETACH_HOLDER: cardinal = 42;
  GEG_PLAYER_PLAY_HEADSHOT_PARTICLE: cardinal = 43;
  GE_HIT_STATISTIC: cardinal = 44;
  GE_KILL_SOMEONE: cardinal = 45;
  GE_FREEZE_OBJECT: cardinal = 46;
  GE_LAUNCH_ROCKET: cardinal = 47;

  GE_LAST: cardinal = 47;
//-----------------------------
  GAME_EVENT_PLAYER_READY:word = 0;
  GAME_EVENT_PLAYER_GAME_MENU:word = 4;
  GAME_EVENT_PLAYER_CONNECTED:word = 6;
  GAME_EVENT_PLAYER_DISCONNECTED:word = 7;
  GAME_EVENT_PLAYER_KILLED:word = 9;
  GAME_EVENT_PLAYER_HITTED:word = 10;

implementation
uses sysutils, srcBase, basedefs;

function ip_address_to_str(a:ip_address):string; stdcall;
begin
  result:=inttostr(a.a1)+'.'+inttostr(a.a2)+'.'+inttostr(a.a3)+'.'+inttostr(a.a4);
end;

function ip_address_equal(ip1: ip_address; ip2: ip_address): boolean; stdcall;
begin
  result:=(ip1.a1 = ip2.a1) and (ip1.a2 = ip2.a2) and (ip1.a3 = ip2.a3) and (ip1.a4 = ip2.a4);
end;

function Init():boolean; stdcall;
begin
  pCompressor:=pointer(xrNetServer+$146b8);
//  Decompress:=srcECXCallFunction.Create(pointer(xrNetServer+$7410),[vtPointer, vtInteger, vtPointer, vtInteger], 'Decompress', 'NET_Compressor');

  result:=true;
end;

procedure ClearPacket(p:pNET_Packet); stdcall;
begin
  p^.B.count:=0;
  p^.r_pos:=0;
  p^.timeReceive:=0;
end;

procedure InvalidatePacket(p:pNET_Packet); stdcall;
begin
//todo:заFFить весь пакет
  p^.B.data[0] := $FF;
  p^.B.data[1] := $FF;

end;

function WriteToPacket(p:pNET_Packet; buf:pointer; size:cardinal):boolean; stdcall;
begin
  result:=false;

  if (PACKET_MAX_SIZE - p^.B.count < size) then exit; //осталось слишком мало места, данные не влезут  
  if not srcKit.CopyBuf(buf, @p^.B.data[p^.B.count], size) then exit;

  p^.B.count:=p^.B.count+size;
  result:=true;
end;

function UnreadBytesCountInPacket(p:pNET_Packet):cardinal;
begin
  result:=0;
  if p=nil then exit;

  result:=p.B.count - p.r_pos;
end;

//******************************Special packets constructors**********************
procedure MakeRadminCmdPacket(p:pNET_Packet; s:string);
begin
  ClearPacket(p);
  WriteToPacket(p, @M_REMOTE_CONTROL_CMD, sizeof(word));
  WriteToPacket(p, PAnsiChar(s), length(s)+1);
end;

procedure MakeMovePlayerPacket(p: pNET_Packet; gameid:word; pos:pFVector3; dir:pFVector3);
var
  b:byte;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_MOVE_PLAYERS, sizeof(M_MOVE_PLAYERS)); //хидер
  b:=1;
  WriteToPacket(p, @b, sizeof(b)); //число игроков в пакете

  WriteToPacket(p, @gameid, sizeof(gameid));
  WriteToPacket(p, pos, sizeof(FVector3));
  WriteToPacket(p, dir, sizeof(FVector3));
end;

end.
