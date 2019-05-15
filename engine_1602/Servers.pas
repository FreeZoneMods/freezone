unit Servers;
{$MODE Delphi}
{$I _pathes.inc}

interface
uses xrstrings, PureServer, Clients, vector, Synchro, Games,Packets, CSE;
function Init():boolean; stdcall;
procedure ForEachClientDo(action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;
function CurPlayersCount:cardinal; stdcall;

function GetPureServer():pIPureServer; stdcall;
function GetServerClient():pxrClientData; stdcall;

procedure LockServerPlayers(); stdcall;
procedure UnlockServerPlayers(); stdcall;

function ID_to_client(clid:cardinal): pxrClientData;
function PS_to_client(ps:pgame_PlayerState): pxrClientData;

type
update_iterator_t = pointer;

server_updates_compressor = packed record//sizeof = 0x883d0
  _unknown: array[0..$883cf] of byte;
end;

xrClientsPool = packed record
  m_dclients:xr_vector; //dclient
end;

xrServer = packed record
  base_IPureServer:IPureServer;
  //offset:0xa0
  _unknown1:array[0..$2F] of byte;
  conn_spawned_ids:xr_vector;
  m_cheaters:xr_vector;
  m_file_transfers:pointer; //file_transfer::server_site*
  //offset:0xec
  m_screenshot_proxies:array [0..63] of pointer; //clientdata_proxy*
  //offset:0x1ec
  m_update_begin:update_iterator_t;
  m_update_end:update_iterator_t;
  //offset:0x1F4
  m_updator:server_updates_compressor;
  //offset:0x885C4
  m_last_updates_size:cardinal;
  //offset:0x885C8
  m_last_update_time:cardinal;
  m_info_uploaders:xr_vector; //server_info_uploader*
  m_server_logo:pointer; //IReader*
  m_server_rules:pointer; //IReader*
  //offset:0x885E0
  DelayedPackestCS:xrCriticalSection;
  m_aDelayedPackets:xr_deque;
  //offset:0x8860C
  m_tID_Generator:array[0..$10807] of byte;
  //here should be secure_messaging::seed_generator m_seed_generator, but we don't know real offset
  //so it merged with m_tID_Generator

  //offset:0x98e14
  game:pgame_sv_GameState;

  m_disconnected_clients:xrClientsPool;
end;
pxrServer=^xrServer;

xrGameSpyServer = packed record
  base_xrServer:xrServer;
  m_iReportToMasterServer:integer;
  m_bQR2_Initialized:cardinal; //BOOL
  m_bCDKey_Initialized:cardinal; //BOOL
  _unknown1:array[0..$57] of byte;
  iGameSpyBasePort:integer;
  HostName:shared_str;
  MapName:shared_str;
  Password:shared_str;
  ServerFlags:byte;
  _unused1:byte;
  _unused2:word;
  m_iMaxPlayers:integer;
  m_bCheckCDKey:byte; //bool



end;

{
#define DPNSEND_SYNC DPNOP_SYNC
#define DPNSEND_NOCOPY 0x0001
#define DPNSEND_NOCOMPLETE 0x0002
#define DPNSEND_COMPLETEONPROCESS 0x0004
#define DPNSEND_GUARANTEED 0x0008
#define DPNSEND_NONSEQUENTIAL 0x0010
#define DPNSEND_NOLOOPBACK 0x0020
#define DPNSEND_PRIORITY_LOW 0x0040
#define   DPNSEND _ PRIORITY _ HIGH 	0x0080
// Flag added for DirectX 9
#define DPNSEND_COALESCE 0x0100
}

procedure xrServer__SendConnectResult(this:pxrServer; CL:pIClient; res:byte; res1:byte; ResultStr:PChar); stdcall;

procedure SendPacketToClient(this:pIPureServer; clid:cardinal; p:pNET_Packet; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
procedure SendPacketToClient_LL(this:pIPureServer; clid:cardinal; data:pointer; size:cardinal; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
procedure SendBroadcastPacket(this:pIPureServer; p:pNET_Packet; flags:cardinal = 8) stdcall;
procedure ReserveGameID(srv:pxrServer; gameid:cardinal); stdcall;

//use EntityFromEid instead (Games module)
//function EntityByGameID(srv:pxrServer; gameid:cardinal):pCSE_Abstract; stdcall;

procedure IPureServer__OnMessage(srv:pIPureServer; p:pNET_Packet; clid:cardinal); stdcall;
procedure IPureServer__DisconnectClient(srv:pIPureServer; player:pIClient; reason:string); stdcall;
function GetClientAddress(srv:pIPureServer; clid:cardinal; addr:pip_address; port:pcardinal):boolean; stdcall;

function CheckForClientExist(srv:pxrServer; cl:pIClient):boolean; stdcall; //doesn't enter critical section! You MUST enter it manually before calls!

const
  xrServer__ErrNoErr:cardinal=2;

implementation
uses basedefs, SrcCalls, Level, dynamic_caster, xr_debug, windows;

var
  IPureServer__SendTo:srcECXCallFunction;
  IPureServer__SendTo_LL:srcECXCallFunction;
  IPureServer__SendBroadcast:srcECXCallFunction;
  IPureServer__GetClientAddress:srcECXCallFunction;
  virtual_IPureServer__DisconnectClient:srcVirtualECXCallFunction;
  virtual_IPureServer__OnMessage:srcVirtualECXCallFunction;
  virtual_IPureServer__Flush_Clients_Buffers:srcVirtualECXCallFunction;
  CID_Generator__tfGetID:srcECXCallFunction;
  xrServer__ID_to_entity:srcECXCallFunction;

procedure SendPacketToClient(this:pIPureServer; clid:cardinal; p:pNET_Packet; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
begin
 IPureServer__SendTo.Call([this, clid, p, flags, timeout]);
end;

procedure SendPacketToClient_LL(this:pIPureServer; clid:cardinal; data:pointer; size:cardinal; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
begin
 IPureServer__SendTo_LL.Call([this, clid, data, size, flags, timeout]);
end;

procedure ReserveGameID(srv:pxrServer; gameid:cardinal); stdcall;
begin
  CID_Generator__tfGetID.Call([@srv.m_tID_Generator, gameid]);
end;

function EntityByGameID(srv:pxrServer; gameid:cardinal):pCSE_Abstract; stdcall;
begin
  result:=xrServer__ID_to_entity.Call([srv, gameid]).VPointer;
end;

procedure IPureServer__OnMessage(srv:pIPureServer; p:pNET_Packet; clid:cardinal); stdcall;
begin
  virtual_IPureServer__OnMessage.Call([srv, p, clid]);
end;

procedure IPureServer__DisconnectClient(srv:pIPureServer; player:pIClient; reason:string); stdcall;
begin
  virtual_IPureServer__DisconnectClient.Call([srv, player, PAnsiChar(reason)]);
end;

function GetClientAddress(srv: pIPureServer; clid: cardinal; addr: pip_address; port: pcardinal): boolean; stdcall;
begin
  result:=IPureServer__GetClientAddress.Call([srv, clid, addr, port]).VBoolean;
end;

procedure SendBroadcastPacket(this: pIPureServer; p: pNET_Packet; flags: cardinal)stdcall;
begin
  IPureServer__SendBroadcast.Call([this, -1, p, flags]);
end;

procedure xrServer__SendConnectResult(this:pxrServer; CL:pIClient; res:byte; res1:byte; ResultStr:PChar); stdcall;
var
  p:NET_Packet;
  tmpb:byte;
  pSrvOptions:PAnsiChar;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  
  WriteToPacket(@p, @M_CLIENT_CONNECT_RESULT, sizeof(M_CLIENT_CONNECT_RESULT));
  WriteToPacket(@p, @res, sizeof(res));
  WriteToPacket(@p, @res1, sizeof(res1));
  WriteToPacket(@p, ResultStr, length(ResultStr)+1);

  if (this.base_IPureServer.SV_Client<>nil) and (this.base_IPureServer.SV_Client=CL) then begin
    tmpb:=1;
  end else begin
    tmpb:=0;
  end;
  WriteToPacket(@p, @tmpb, sizeof(tmpb));

  pSrvOptions:=get_string_value(@(GetLevel.m_caServerOptions));
  WriteToPacket(@p, pSrvOptions, length(pSrvOptions));

  IPureServer__SendTo.Call([@this.base_IPureServer, CL.ID.id, @p, 8, 0]);
  if res=0 then begin
    virtual_IPureServer__Flush_Clients_Buffers.Call([@this.base_IPureServer]);
    virtual_IPureServer__DisconnectClient.Call([@this.base_IPureServer, CL, ResultStr])
  end;
end;

procedure ForEachClientDo(action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;
var
  srv:pIPureServer;
begin
  srv:=GetPureServer();
  if srv<>nil then begin
    ForEachClientDo_LL(@srv.net_players, @action, @predicate, parameter, parameter2);
  end;
end;

function CheckForClientExist(srv:pxrServer; cl:pIClient):boolean; stdcall;
begin
  result:=CheckForClientOnline_LL(@srv.base_IPureServer.net_players, cl);
end;

function CurPlayersCount:cardinal; stdcall;
var
  pm:pPlayersMonitor;
  srv:pIPureServer;
begin
  result:=0;
  srv:=GetPureServer();
  if (srv=nil) then exit;

  pm:=@srv.net_players;
  if (pm=nil) then exit;

  xrCriticalSection__Enter(@pm.csPlayers);
  try
    pm.now_iterating_in_net_players:=1;
    result:= items_count_in_vector(@pm.net_Players, sizeof(pIClient));
    pm.now_iterating_in_net_players:=0;
  finally
    xrCriticalSection__Leave(@pm.csPlayers);
  end;
end;

function GetServerClient():pxrClientData; stdcall;
var
  srv:pIPureServer;
  cl:pIClient;
begin
  result:=nil;
  srv:=GetPureServer();
  if (srv=nil) then exit;

  cl:=srv.SV_Client;
  if (cl=nil) then exit;

  result:=dynamic_cast(cl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
end;

function GetPureServer():pIPureServer; stdcall;
begin
  if GetLevel() = nil then begin
    result:=nil;
    exit;
  end;

  result:=@GetLevel.Server.base_IPureServer;
end;

procedure LockServerPlayers(); stdcall;
var
   srv:pIPureServer;
begin
  srv:=GetPureServer();
  if (srv<>nil) then begin
    xrCriticalSection__Enter(@srv.net_players.csPlayers);
  end;
end;

procedure UnlockServerPlayers(); stdcall;
var
   srv:pIPureServer;
begin
  srv:=GetPureServer();
  if (srv<>nil) then begin
    xrCriticalSection__Leave(@srv.net_players.csPlayers);
  end;
end;

function ID_to_client(clid:cardinal): pxrClientData;
begin
  result:=nil;
  ForEachClientDo(AssignFoundClientDataAction, OneIDSearcher, @clid, @result);
end;

function PS_to_client(ps:pgame_PlayerState): pxrClientData;
begin
  R_ASSERT(ps<>nil, 'Cannot get client by nil PlayerState');
  result:=nil;
  //Кастуется от IClient к xrClientData автоматом
  ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @ps.GameID, @result);
end;

function Init():boolean; stdcall;
const
  IPureServer__DisconnectClient_index:cardinal = $40;
  IPureServer__Flush_Clients_Buffers_index:cardinal = $1C;
  IPureServer__OnMessage_index:cardinal = $24;
begin
 IPureServer__SendTo:=srcECXCallFunction.Create(GetProcAddress(xrNetServer, '?SendTo@IPureServer@@QAEXVClientID@@AAVNET_Packet@@II@Z'), [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger], 'SendTo', 'IPureServer'); ;
 IPureServer__SendTo_LL:=srcECXCallFunction.Create(GetProcAddress(xrNetServer, '?SendTo_LL@IPureServer@@UAEXVClientID@@PAXIII@Z'), [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger, vtInteger], 'SendTo_LL', 'IPureServer'); ;
 IPureServer__SendBroadcast:=srcECXCallFunction.Create(GetProcAddress(xrNetServer, '?SendBroadcast@IPureServer@@UAEXVClientID@@AAVNET_Packet@@I@Z'), [vtPointer, vtInteger, vtPointer, vtInteger], 'SendBroadcast', 'IPureServer'); ;
 IPureServer__GetClientAddress:=srcECXCallFunction.Create(GetProcAddress(xrNetServer, '?GetClientAddress@IPureServer@@QAE_NVClientID@@AAUip_address@@PAK@Z'), [vtPointer, vtInteger, vtPointer, vtPointer], 'GetClientAddress', 'IPureServer'); ;

 virtual_IPureServer__DisconnectClient:=srcVirtualECXCallFunction.Create(IPureServer__DisconnectClient_index, [vtPointer, vtPointer, vtPChar], 'DisconnectClient','IPureServer');
 virtual_IPureServer__Flush_Clients_Buffers:=srcVirtualECXCallFunction.Create(IPureServer__Flush_Clients_Buffers_index, [vtPointer], 'Flush_Clients_Buffers','IPureServer');
 virtual_IPureServer__OnMessage:=srcVirtualECXCallFunction.Create(IPureServer__OnMessage_index, [vtPointer, vtPointer, vtInteger], 'OnMessage', 'IPureServer' );
 if xrGameDllType()=XRGAME_1602 then begin
   CID_Generator__tfGetID:=srcECXCallFunction.Create(pointer(xrGame+$9e510), [vtPointer, vtInteger], 'tfGetID', 'CID_Generator');
   xrServer__ID_to_entity:=srcECXCallFunction.Create(pointer(xrGame+$34cee0), [vtPointer, vtPointer], 'ID_to_entity', 'xrServer');
 end;

 result:= (IPureServer__SendTo.GetMyAddress()<>nil) and
          (IPureServer__SendTo_LL.GetMyAddress()<>nil) and
          (IPureServer__SendBroadcast.GetMyAddress()<>nil) and
          (IPureServer__GetClientAddress.GetMyAddress()<>nil);
end;

end.
