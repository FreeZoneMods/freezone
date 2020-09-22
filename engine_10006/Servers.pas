unit Servers;
{$MODE Delphi}
{$I _pathes.inc}

interface
uses PureServer, SrcCalls, Synchro, Clients, basedefs, Games, Packets;
function Init():boolean; stdcall;

type
xrServer = packed record
  base_IPureServer:IPureServer;
  _unknown:array[0..$10843] of byte;
  game:pgame_sv_GameState;
end;
pxrServer=^xrServer;

function CheckForClientExist(srv:pxrServer; cl:pIClient):boolean; stdcall; //doesn't enter critical section! You MUST enter it manually before calls!

procedure ForEachClientDo(action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;
function CurPlayersCount:cardinal; stdcall;

function GetPureServer():pIPureServer; stdcall;
function GetServerClient():pxrClientData; stdcall;

procedure LockServerPlayers(); stdcall;
procedure UnlockServerPlayers(); stdcall;

procedure SendPacketToClient(this:pIPureServer; clid:cardinal; p:pNET_Packet; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
procedure SendPacketToClient_LL(this:pIPureServer; clid:cardinal; data:pointer; size:cardinal; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
procedure IPureServer__DisconnectClient(srv:pIPureServer; player:pIClient; reason:string); stdcall;
function GetClientAddress(srv:pIPureServer; clid:cardinal; addr:pip_address; port:pcardinal):boolean; stdcall;
procedure SendBroadcastPacket(this:pIPureServer; p:pNET_Packet; flags:cardinal = 8) stdcall;

function ID_to_client(clid:cardinal): pxrClientData;
function PS_to_client(ps:pgame_PlayerState): pxrClientData;

implementation
uses Vector, dynamic_caster, Level, xr_debug;

var
  IPureServer__SendTo:srcECXCallFunction;
  IPureServer__SendBroadcast:srcECXCallFunction;
  IPureServer__SendTo_LL:srcECXCallFunction;
  IPureServer__GetClientAddress:srcECXCallFunction;

  virtual_IPureServer__DisconnectClient:srcVirtualECXCallFunction;

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

procedure SendPacketToClient(this:pIPureServer; clid:cardinal; p:pNET_Packet; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
begin
 IPureServer__SendTo.Call([this, clid, p, flags, timeout]);
end;

procedure SendPacketToClient_LL(this:pIPureServer; clid:cardinal; data:pointer; size:cardinal; flags:cardinal = 8; timeout:cardinal = 0); stdcall;
begin
 IPureServer__SendTo_LL.Call([this, clid, data, size, flags, timeout]);
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
    result:= items_count_in_vector(@pm.net_Players, sizeof(pIClient));
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
  IPureServer__DisconnectClient_index:cardinal = $3C;
var
   tmp:pointer;
begin
  result:=false;
  tmp:=nil;

  if not InitSymbol(tmp, xrNetServer, '?SendTo@IPureServer@@QAEXVClientID@@AAVNET_Packet@@II@Z') then exit;
  IPureServer__SendTo:=srcECXCallFunction.Create(tmp, [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger], 'SendTo', 'IPureServer'); ;

  if not InitSymbol(tmp, xrNetServer, '?SendTo_LL@IPureServer@@UAEXVClientID@@PAXIII@Z') then exit;
  IPureServer__SendTo_LL:=srcECXCallFunction.Create(tmp, [vtPointer, vtInteger, vtPointer, vtInteger, vtInteger, vtInteger], 'SendTo_LL', 'IPureServer'); ;

  if not InitSymbol(tmp, xrNetServer, '?SendBroadcast@IPureServer@@QAEXVClientID@@AAVNET_Packet@@I@Z') then exit;
  IPureServer__SendBroadcast:=srcECXCallFunction.Create(tmp, [vtPointer, vtInteger, vtPointer, vtInteger], 'SendBroadcast', 'IPureServer'); ;

  if not InitSymbol(tmp, xrNetServer, '?GetClientAddress@IPureServer@@QAE_NVClientID@@AAUip_address@@PAK@Z') then exit;
  IPureServer__GetClientAddress:=srcECXCallFunction.Create(tmp, [vtPointer, vtInteger, vtPointer, vtPointer], 'GetClientAddress', 'IPureServer'); ;

  virtual_IPureServer__DisconnectClient:=srcVirtualECXCallFunction.Create(IPureServer__DisconnectClient_index, [vtPointer, vtPointer, vtPChar], 'DisconnectClient','IPureServer');

  result:= true;
end;


end.
