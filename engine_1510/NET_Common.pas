unit NET_Common;
{$mode delphi}
{$I _pathes.inc}
interface
uses vector, Synchro;
type
GameDescriptionData = packed record
  map_name:array [0..127] of char;
  map_version:array [0..127] of char;
  download_url:array[0..511] of char;
end;
pGameDescriptionData = ^GameDescriptionData;
ppGameDescriptionData = ^pGameDescriptionData;

INetQueue = packed record
  cs:xrCriticalSection;
  ready:xr_deque;
  unused:xr_vector;
end;

NET_Queue_Event = packed record
//todo:fill
end;
pNET_Queue_Event=^NET_Queue_Event;

const
  NET_Latency:cardinal = 50;

implementation

end.
