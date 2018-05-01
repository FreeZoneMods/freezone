unit Packets;
{$mode delphi}
interface
uses srcCalls, Synchro, Vector, xr_configs;
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

NET_Buffer = packed record
  data: array[0..16383] of Byte;
  count:cardinal;
end;
pNET_Buffer=^NET_Buffer;

NET_Packet = packed record
  inistream:pIIniFileStream; //0x0
  B:NET_Buffer;              //0x4
  r_pos:cardinal;            //0x4008
  timeReceive:cardinal;      //0x400C
  w_allow:boolean;           //0x4010
  _unused1:byte;
  _unused2:word;    
end;
pNET_Packet = ^NET_Packet;


MultipacketSender__Buffer = packed record  //size = 0x4018
  buffer:NET_Packet;    //0x0
  last_flags:cardinal;  //0x4014
end;

MultipacketSender = packed record
  vftable:pointer;                 //0x0
  _buf:MultipacketSender__Buffer;  //0x4
  _gbuf:MultipacketSender__Buffer; //0x401C
  _buf_cs:xrCriticalSection;       //0x8034
end;
pMultipacketSender=^MultipacketSender;

MultipacketReciever = packed record
  vftable:pointer;
end;

NET_Compressor = packed record
  CS:xrCriticalSection;
  m_stats:xr_map;
end;
pNET_Compressor=^NET_Compressor;

function ip_address_to_str(a:ip_address):string; stdcall;
function ip_address_equal(ip1: ip_address; ip2: ip_address): boolean; stdcall;

procedure ClearPacket(p:pNET_Packet); stdcall;
function WriteToPacket(p:pNET_Packet; buf:pointer; size:cardinal):boolean; stdcall;
procedure InvalidatePacket(p:pNET_Packet); stdcall;

procedure MakeDestroyGameItemPacket(p:pNET_Packet; gameid:word; time:cardinal);

var
  pCompressor:pNET_Compressor;
  NET_Compressor__Decompress:srcECXCallFunction;
  NET_Packet__r_stringZ:srcECXCallFunction;
  NET_Packet__w_u8:srcECXCallFunction;
  NET_Packet__r_u8:srcECXCallFunction;

const
  M_UPDATE: word = 0;
  M_SPAWN:word=1;
  M_SV_CONFIG_NEW_CLIENT:word=2;//<---------------------------!!!
  M_CHAT:word=7; //<------------------------------------???
  M_EVENT:word=8;
  M_CHANGE_LEVEL:word=13;
  M_LOAD_GAME:word=14;
  M_SAVE_GAME: word=16;
  M_GAMEMESSAGE:word=19;
  M_EVENT_PACK:word = 20;
  M_GAMESPY_CDKEY_VALIDATION_CHALLENGE:word=21;//<------------------------------------???
  M_CLIENT_CONNECT_RESULT:word=23;
  M_CHAT_MESSAGE: word = 25;
  M_CLIENT_WARN:word=26;
  M_MOVE_PLAYERS:word=36;
  M_CHANGE_SELF_NAME:word=39;  
  M_SV_MAP_NAME:word=43;
  M_SV_DIGEST:word=44;
  M_REMOTE_CONTROL_CMD:word=41;//<------------------------------------!!!
  M_FILE_TRANSFER:word=45;
  M_SECURE_MESSAGE:word=48;

  M_FZ_DIGEST:word=$1300;


  GAME_EVENT_MAKE_DATA:cardinal=42;


  GE_DESTROY:cardinal = 8;
  GE_HIT_STATISTIC:cardinal = 47;


  PACKET_MAX_SIZE:cardinal = 16384;

  DPN_MSGID_RECEIVE:word =$11;
  SIGN1:cardinal=$12071980;
  SIGN2:cardinal=$26111975;
  NET_TAG_MERGED:byte = $E1;
  NET_TAG_NONMERGED:byte=$E0;

  NET_TAG_COMPRESSED:byte=$C1;
  NET_TAG_NONCOMPRESSED:byte=$C0;

  DPNSEND_GUARANTEED:cardinal=$8;
  DPNSEND_PRIORITY_HIGH:cardinal=$80;
  DPNSEND_IMMEDIATELLY:cardinal=$100;

implementation
uses sysutils, srcBase, basedefs, windows;

function ip_address_to_str(a:ip_address):string; stdcall;
begin
  result:=inttostr(a.a1)+'.'+inttostr(a.a2)+'.'+inttostr(a.a3)+'.'+inttostr(a.a4);
end;

function ip_address_equal(ip1: ip_address; ip2: ip_address): boolean; stdcall;
begin
  result:=(ip1.a1 = ip2.a1) and (ip1.a2 = ip2.a2) and (ip1.a3 = ip2.a3) and (ip1.a4 = ip2.a4);
end;

function Init():boolean; stdcall;
var
  ptr:pointer;
begin
  pCompressor:=pointer(xrNetServer+$14630);

  ptr:=GetProcAddress(xrNetServer, '?Decompress@NET_Compressor@@QAEGPAEABI01@Z');
  NET_Compressor__Decompress:=srcECXCallFunction.Create(ptr,[vtPointer, vtInteger, vtPointer, vtInteger], 'Decompress', 'NET_Compressor');

  ptr:=GetProcAddress(xrCore, '?r_stringZ@NET_Packet@@QAEXAAVshared_str@@@Z');
  NET_Packet__r_stringZ:=srcECXCallFunction.Create(ptr, [vtPointer, vtPointer], 'r_stringZ', 'NET_Packet');

  //Write arg (uint)
  ptr:=GetProcAddress(xrCore, '?w_u8@NET_Packet@@QAEXE@Z');
  NET_Packet__w_u8:=srcECXCallFunction.Create(ptr, [vtPointer, vtInteger], 'w_u8', 'NET_Packet' );

  //read to arg (puint)
  ptr:=GetProcAddress(xrCore, '?r_u8@NET_Packet@@QAEXAAE@Z');
  NET_Packet__r_u8:=srcECXCallFunction.Create(ptr, [vtPointer, vtPointer], 'r_u8', 'NET_Packet');

  result:=true;
end;

procedure ClearPacket(p:pNET_Packet); stdcall;
begin
  p^.inistream:=nil;
  p^.B.count:=0;
  p^.r_pos:=0;
  p^.timeReceive:=0;
  p^.w_allow:=true;
end;

procedure InvalidatePacket(p:pNET_Packet); stdcall;
begin
//todo:заFFить весь пакет
  p^.B.data[0] := $FF;
  p^.B.data[1] := $FF;

end;

function WriteToPacket(p:pNET_Packet; buf:pointer; size:cardinal):boolean; stdcall;
begin
  if (PACKET_MAX_SIZE - p^.B.count < size) then begin
    //осталось слишком мало места, данные не влезут
    result:=false;
    exit;
  end;

  srcKit.CopyBuf(buf, @p^.B.data[p^.B.count], size);

  p^.B.count:=p^.B.count+size;
  result:=true;
end;

procedure MakeDestroyGameItemPacket(p:pNET_Packet; gameid:word; time:cardinal);
begin
  ClearPacket(p);
  WriteToPacket(p, @M_EVENT, sizeof(word));
  WriteToPacket(p, @time, sizeof(cardinal));
  WriteToPacket(p, @GE_DESTROY, sizeof(word));
  WriteToPacket(p, @gameid, sizeof(word));
end;

end.
