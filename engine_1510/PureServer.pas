unit PureServer;
{$MODE Delphi}
{$I _pathes.inc}
interface
uses xrstrings, vector, Synchro, basedefs, Packets, xr_time;

function Init():boolean; stdcall;

type
PlayersMonitor = packed record
  csPlayers:xrCriticalSection;
  net_Players:xr_vector;
  net_Players_disconnected:xr_vector;
  now_iterating_in_net_players:byte; {boolean}
  now_iterating_in_net_players_disconn:byte; {boolean}
  _unused1:word;
end;
pPlayersMonitor=^PlayersMonitor;

ip_filter = packed record
  m_all_subnets:xr_vector;
end;

IServerStatistics = packed record
  bytes_out:cardinal;
  bytes_out_real:cardinal;
  bytes_in:cardinal;
  bytes_in_real:cardinal;
  dwBytesSend:cardinal;
  dwSendTime:cardinal;
  dwBytesPerSec:cardinal;
end;

IPureServer = packed record
  //todo:fill
  base_MultipackedReceiver:MultipacketReciever;
  connect_options:shared_str;
  _unknown1:array[0..$2B] of byte;
  net_players:PlayersMonitor;
  SV_Client:pointer; {pIClient}
  psNET_Port:integer;
  BannedAddresses:xr_vector;
  m_ip_filter:ip_filter;
  csMessage:xrCriticalSection;
  stats:IServerStatistics;
  device_timer:pCTimer;
  m_bDedicated:cardinal; {BOOL}
  _unknown2:cardinal;
end;
pIPureServer=^IPureServer;
ppIPureServer=^pIPureServer;


PlayerSearchPredicate = function(player:pointer{pIClient}; parameter:pointer=nil; parameter2:pointer=nil):boolean; stdcall;
PlayerAction = function (player:pointer{pIClient}; parameter:pointer=nil; parameter2:pointer=nil):boolean stdcall;

procedure ForEachClientDo_LL(pm:pPlayersMonitor; action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;

function OneIDSearcher(player:pointer; id:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;
function AssignFoundClientAction(player:pointer; {%H-}id:pointer; res:pointer):boolean; stdcall;     //as pIClient
function AssignFoundClientDataAction(player:pointer; {%H-}id:pointer; res:pointer):boolean; stdcall; //as pxrClientData
function LocalClientSearcher(player:pointer; {%H-}id:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;
function OneGameIDSearcher(player:pointer; id:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;
function OnePlayerStateSearcher(player:pointer; ps:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;
function OnePlayerIndexSearcher({%H-}player:pointer; skip_count:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;

function CheckForClientOnline_LL(pm:pPlayersMonitor; cl:pointer{pIClient}):boolean; stdcall; //doesn't enter critical section! You MUST enter it manually before calls!

implementation
uses Clients, dynamic_caster;

function LocalClientSearcher(player:pointer; id:pointer; parameter2:pointer=nil):boolean; stdcall;
var
  cl:pIClient;
begin
  result:=false;
  cl:=pIClient(player);
  IsLocalServerClient(cl);
end;

function OneIDSearcher(player:pointer; id:pointer; parameter2:pointer=nil):boolean; stdcall;
var
  cid:cardinal;
  cl:pIClient;
begin
  result:=false;
  if (id=nil) then exit;

  cl:=pIClient(player);
  cid:= pcardinal(id)^;

  result:=(cl.ID.id = cid);
end;

function AssignFoundClientAction(player:pointer; id:pointer; res:pointer):boolean; stdcall;
begin
  result:=false;
  ppIClient(res)^:=player;
end;

function OneGameIDSearcher(player:pointer; id:pointer; parameter2:pointer=nil):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  if (id=nil) then exit;

  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld=nil then exit;

  result:=(cld.ps.GameID = pword(id)^);
end;

function OnePlayerStateSearcher(player:pointer; ps:pointer; {%H-}parameter2:pointer=nil):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  if (ps=nil) then exit;

  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld=nil then exit;

  result:= (cld.ps = ppgame_PlayerState(ps)^) ;
end;

function OnePlayerIndexSearcher(player: pointer; skip_count: pointer; parameter2: pointer): boolean; stdcall;
var
  cnt:pcardinal;
begin
  cnt:=pcardinal(skip_count);
  result:=(cnt^ = 0);

  if (cnt^ > 0) then begin
    cnt^:=cnt^-1;
  end;
end;

function AssignFoundClientDataAction(player:pointer; id:pointer; res:pointer):boolean; stdcall;
begin
  result:=false;
  ppxrClientData(res)^:=dynamic_cast(pIClient(player), 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
end;

procedure ForEachClientDo_LL(pm:pPlayersMonitor;action:PlayerAction; predicate:PlayerSearchPredicate = nil; parameter:pointer=nil; parameter2:pointer=nil); stdcall;
var
  cur,last:ppIClient;
begin
  xrCriticalSection__Enter(@pm.csPlayers);
  try
    pm.now_iterating_in_net_players:=1;
    cur:=pm.net_Players.start;
    last:=pm.net_Players.last;
    while cur<>last do begin
      if (@predicate=nil) or predicate(cur^, parameter, parameter2) then begin
        if not action(cur^, parameter, parameter2) then begin
          break;
        end;
      end;
      cur:=ppIClient( cardinal(cur)+sizeof(pIClient));
    end;

    pm.now_iterating_in_net_players:=0;
  finally
    xrCriticalSection__Leave(@pm.csPlayers);
  end;
end;

function CheckForClientOnline_LL(pm:pPlayersMonitor; cl:pointer {pIClient}):boolean; stdcall;
var
  cur,last:ppIClient;
begin
  pm.now_iterating_in_net_players:=1;
  cur:=pm.net_Players.start;
  last:=pm.net_Players.last;
  result:=false;
  while cur<>last do begin
    result:= (cl = cur^);
    if result then break;
    cur:=ppIClient( cardinal(cur)+sizeof(pIClient));
  end;

  pm.now_iterating_in_net_players:=0;
end;

function Init():boolean; stdcall;
begin
  result:=true;
end;


end.
