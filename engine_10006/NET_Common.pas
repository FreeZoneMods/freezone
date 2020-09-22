unit NET_Common;
{$mode delphi}
{$I _pathes.inc}

interface
uses vector, Synchro;
type

INetQueue = packed record
  cs:xrCriticalSection;
  ready:xr_deque;
  unused:xr_vector;
end;

NET_Queue_Event = packed record
//todo:fill
end;
pNET_Queue_Event=^NET_Queue_Event;

implementation

end.
