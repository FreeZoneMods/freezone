unit Packets;
{$mode delphi}
{$I _pathes.inc}

interface
uses srcCalls, Synchro, Vector;

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

DPN_CONNECTION_INFO = packed record //sizeof = 0x5c
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

NET_Packet = packed record //sizeof = 0x4014
  inistream:pointer;//pIIniFileStream; //0x0
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

//procedure MakeDestroyGameItemPacket(p:pNET_Packet; gameid:word; time:cardinal);
//procedure MakeRadminCmdPacket(p:pNET_Packet; s:string);
//procedure MakeMovePlayerPacket(p: pNET_Packet; gameid:word; pos:pFVector3; dir:pFVector3);

var
//  pCompressor:pNET_Compressor;
  NET_Compressor__Decompress:srcECXCallFunction;
  NET_Packet__r_stringZ:srcECXCallFunction;
  NET_Packet__w_u8:srcECXCallFunction;
  NET_Packet__r_u8:srcECXCallFunction;


  //Packet IDs
  M_EVENT_PACK:word = 20;
  M_CLIENT_CONNECT_RESULT:word=23;
  M_CHAT_MESSAGE: word = 25;

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

function Init():boolean; stdcall;

function UnreadBytesCountInPacket(p:pNET_Packet):cardinal;

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
//  pCompressor:=pointer(xrNetServer+$14630);

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
{procedure MakeDestroyGameItemPacket(p:pNET_Packet; gameid:word; time:cardinal);
begin
  ClearPacket(p);
  WriteToPacket(p, @M_EVENT, sizeof(word));
  WriteToPacket(p, @time, sizeof(cardinal));
  WriteToPacket(p, @GE_DESTROY, sizeof(word));
  WriteToPacket(p, @gameid, sizeof(word));
end;

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
end;}

end.
