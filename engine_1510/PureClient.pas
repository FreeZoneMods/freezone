unit PureClient;
{$mode delphi}
interface
uses Packets, NET_Common, xr_time, Synchro, vector, Clients;
type
IPureClient = packed record
  base_MultipacketReciever:MultipacketReciever;
  base_MultipacketSender:MultipacketSender;
  m_game_description:GameDescriptionData;
  device_timer:pCTimer;
  NET:pointer; {IDirectPlay8Client}
  net_Address_device:pointer; {IDirectPlay8Address}
  net_Address_server:pointer; {IDirectPlay8Address}
  net_csEnumeration:xrCriticalSection;
  net_Hosts:xr_vector;
  net_Compressor:NET_Compressor;
  net_Connected:integer;
  net_Syncronised:cardinal;
  net_Disconnected:cardinal;
  net_Queue:INetQueue;
  net_Statistic:IClientStatistics;
  net_Time_LastUpdate:cardinal;
  net_TimeDelta:integer;
  net_TimeDelta_Calculated:cardinal;
  net_TimeDelta_User:cardinal;
end;
pIPureClient = ^IPureClient;

procedure IPureClient_Send(cl:pIPureClient; packet:pNET_Packet; dwFlags:cardinal; dwTimeout:cardinal = 0);

function Init():boolean;

implementation
uses srcCalls;

var
  virtual_IPureClient__Send:srcVirtualECXCallFunction;

const
  virtual_IPureClient__Send_index:cardinal=$10;

procedure IPureClient_Send(cl:pIPureClient; packet:pNET_Packet; dwFlags:cardinal; dwTimeout:cardinal = 0);
begin
  virtual_IPureClient__Send.Call([cl, packet, dwFlags, dwTimeout]);
end;

function Init():boolean;
begin
  virtual_IPureClient__Send:=srcVirtualECXCallFunction.Create(virtual_IPureClient__Send_index, [vtPointer, vtPointer, vtInteger, vtInteger], 'Send', 'IPureClient');
  result:=true;
end;

end.
