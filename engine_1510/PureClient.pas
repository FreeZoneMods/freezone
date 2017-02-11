unit PureClient;
{$mode delphi}
interface
uses Packets, NET_Common, Time, Synchro, vector, Clients;
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

implementation

end.
