unit Time;
{$mode delphi}
interface
function Init():boolean; stdcall;

type
CTimerBase = packed record //sizeof=0x20
  qwStartTime:int64;
  qwPausedTime:int64;
  qwPauseAccum:int64;
  bPause:cardinal;
  _unused_align:cardinal;
end;

CTimer = packed record  //sizeof=0x38
  base_CTimerBase:CTimerBase;
  //offset: 0x20
  m_time_factor:single;
  _unused1:cardinal;
  m_real_ticks:int64;
  m_ticks:int64;
end;
pCTimer = ^CTimer;

CTimer_paused_ex = packed record //sizeof=0x48
  vtable:pointer;
  _unused1:cardinal;
  base_CTimer:CTimer;
  //offset: 0x40
  save_clock:int64;
end;

CTimer_paused = packed record
  base_CTimer_paused_ex:CTimer_paused_ex;
end;

implementation


function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
