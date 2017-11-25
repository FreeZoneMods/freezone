unit Servers;
{$MODE Delphi}
interface
uses xrstrings, PureServer, SrcCalls, Clients, vector, Synchro, Games;
function Init():boolean; stdcall;
procedure ForEachClientDo(action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;
function CurPlayersCount:cardinal; stdcall;

function GetPureServer():pIPureServer; stdcall;
function GetServerClient():pxrClientData; stdcall;

procedure LockServerPlayers(); stdcall;
procedure UnlockServerPlayers(); stdcall;


type
xrServer = packed record
  base_IPureServer:IPureServer;
  _unknown1:array[0..$2F] of byte;
  conn_spawned_ids:xr_vector;
  m_cheaters:xr_vector;
  m_file_transfers:pointer; {file_transfer::server_site*}
  m_screenshot_proxies:array [0..31] of pointer; {clientdata_proxy*}
  m_iCurUpdatePacket:word;
  _unused1:word;
  m_aUpdatePackets:xr_vector;
  m_first_packet_size:cardinal;
  DelayedPackestCS:xrCriticalSection;
  m_aDelayedPackets:xr_deque;
  m_tID_Generator:array[0..$10807] of byte;
  //here should be secure_messaging::seed_generator m_seed_generator, but we don't know real offset
  //so it merged with m_tID_Generator
  game:pgame_sv_GameState;
end;
pxrServer=^xrServer;

xrGameSpyServer = packed record
  base_xrServer:xrServer;
  m_iReportToMasterServer:integer;
  m_bQR2_Initialized:cardinal; {BOOL}
  m_bCDKey_Initialized:cardinal; {BOOL}
  _unknown1:array[0..$57] of byte;
  iGameSpyBasePort:integer;
  HostName:shared_str;
  MapName:shared_str;
  Password:shared_str;
  ServerFlags:byte;
  _unused1:byte;
  _unused2:word;
  m_iMaxPlayers:integer;
  m_bCheckCDKey:byte; {bool}



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

var
  IPureServer__SendTo:srcECXCallFunction;
  IPureServer__SendTo_LL:srcECXCallFunction;
  virtual_IPureServer__DisconnectClient:srcVirtualECXCallFunction;
  virtual_IPureServer__OnMessage:srcVirtualECXCallFunction;
  virtual_IPureServer__Flush_Clients_Buffers:srcVirtualECXCallFunction;
  CID_Generator__tfGetID:srcESICallFunctionWEAXArg;
  xrServer__ID_to_entity:srcECXCallFunction;

procedure xrServer__SendConnectResult(this:pxrServer; CL:pIClient; res:byte; res1:byte; ResultStr:PChar); stdcall;

function CheckForClientExist(srv:pxrServer; cl:pIClient):boolean; stdcall; //doesn't enter critical section! You MUST enter it manually before calls!

const
  xrServer__ErrNoErr:cardinal=2;

implementation
uses basedefs, Packets, Level, dynamic_caster;

procedure xrServer__SendConnectResult(this:pxrServer; CL:pIClient; res:byte; res1:byte; ResultStr:PChar); stdcall;
var
  p:NET_Packet;
  tmpb:byte;
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
  WriteToPacket(@p, @pCLevel(g_ppGameLevel^).m_caServerOptions.p_.value, length(PChar(@pCLevel(g_ppGameLevel^).m_caServerOptions.p_.value)));

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
    result:= (cardinal(pm.net_Players.last) - cardinal(pm.net_Players.start)) div sizeof(pIClient);
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
  if (g_ppGameLevel=nil) or (g_ppGameLevel^=nil) then begin
    result:=nil;
    exit;
  end;

  result:=@(pCLevel(g_ppGameLevel^).Server.base_IPureServer);
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

function Init():boolean; stdcall;
const
  IPureServer__DisconnectClient_index:cardinal = $40;
  IPureServer__Flush_Clients_Buffers_index:cardinal = $1C;
  IPureServer__OnMessage_index:cardinal = $24;
begin
 IPureServer__SendTo:=srcECXCallFunction.Create(pointer(xrNetServer+$B0E0), [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger], 'SendTo', 'IPureServer'); ;
 IPureServer__SendTo_LL:=srcECXCallFunction.Create(pointer(xrNetServer+$AFF0), [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger, vtInteger], 'SendTo_LL', 'IPureServer'); ; 
 virtual_IPureServer__DisconnectClient:=srcVirtualECXCallFunction.Create(IPureServer__DisconnectClient_index, [vtPointer, vtPointer, vtPChar], 'DisconnectClient','IPureServer');
 virtual_IPureServer__Flush_Clients_Buffers:=srcVirtualECXCallFunction.Create(IPureServer__Flush_Clients_Buffers_index, [vtPointer], 'Flush_Clients_Buffers','IPureServer');
 virtual_IPureServer__OnMessage:=srcVirtualECXCallFunction.Create(IPureServer__OnMessage_index, [vtPointer, vtPointer, vtInteger], 'OnMessage', 'IPureServer' );

 if xrGameDllType()=XRGAME_SV_1510 then begin
   CID_Generator__tfGetID:=srcESICallFunctionWEAXArg.Create(pointer(xrGame+$5F370), [vtPointer, vtInteger], 'tfGetID', 'CID_Generator');
   xrServer__ID_to_entity:=srcECXCallFunction.Create(pointer(xrGame+$2c6f20), [vtPointer, vtPointer], 'ID_to_entity', 'xrServer');
 end else if xrGameDllType()=XRGAME_CL_1510 then begin
   CID_Generator__tfGetID:=srcESICallFunctionWEAXArg.Create(pointer(xrGame+$60F00), [vtPointer, vtInteger], 'tfGetID', 'CID_Generator');
   xrServer__ID_to_entity:=srcECXCallFunction.Create(pointer(xrGame+$2dbf90), [vtPointer, vtPointer], 'ID_to_entity', 'xrServer');
 end;


 result:=true;
end;

end.
