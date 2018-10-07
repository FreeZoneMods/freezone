unit xr_time;
{$mode delphi}
interface
function Init():boolean; stdcall;

type
time_t = int64;
ptime_t = ^time_t;

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

function TimeToString(t:time_t):string;

implementation
uses sysutils;

function TimeToString(t: time_t): string;
var
  dt_days, dt_msecs:TDateTime;
  days, msecs:time_t;
begin
  //UnixToDateTime дает большую погрешность, так что разбиваем на целую/дробную части вручную
  days  :=t div SecsPerDay + 25569;
  msecs := t mod SecsPerDay;

  dt_days  := days;
  dt_msecs := msecs / SecsPerDay;

  result:=DateToStr(dt_days) + ' ' + TimeToStr(dt_msecs) + ' (UTC+0)';
end;

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
