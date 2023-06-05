unit Timersmgr;

{$mode delphi}

interface
uses windows;

type

FZTimer = class;
FZTimerCallback = procedure(timer:FZTimer; userdata:pointer; delta:cardinal); stdcall;

FZTimerConfig = packed record
  period:cardinal; //ms
  cb:FZTimerCallback;
  userdata:pointer;
end;

FZTimersGroupConfig = packed record
  min_interval:cardinal; //Минимальный интервал между 2мя вызовами колбэков одной группы
end;

{ FZTimer }

FZTimer = class
private
  _last_trigger_time:cardinal;
  _cfg:FZTimerConfig;
  _active:boolean;
public
  constructor Create(cfg:FZTimerConfig);
  destructor Destroy; override;

  function GetOverdue():cardinal;
  function GetPeriod():cardinal;
  procedure SetPeriod(new_period:cardinal);
  function Trigger(force:boolean):boolean;
  procedure SetActive(status:boolean);
end;

{ FZTimersGroup }

FZTimersGroup = class
private
  _timers:array of FZTimer;
  _cfg:FZTimersGroupConfig;
  _last_trigger_time:cardinal;

  function CreateTimer(cfg:FZTimerConfig):FZTimer;
  function DeleteTimer(timer:FZTimer):boolean;
  function TimersCount():integer;
  procedure Update();
  function _FindTimerIdx(timer:FZTimer):integer;
  function _SelectTimerToTrigger():integer;
public
  constructor Create(cfg:FZTimersGroupConfig);
  destructor Destroy; override;
end;

{ FZTimersMgr }

FZTimersMgr = class
  _lock:TRTLCriticalSection;
  _groups:array of FZTimersGroup;

  constructor Create();
  destructor Destroy(); override;

  function _FindGroupIdx(group:FZTimersGroup):integer;
public
  function RegisterTimersGroup(cfg:FZTimersGroupConfig):FZTimersGroup;
  function UnregisterTimersGroup(group:FZTimersGroup):boolean;

  function CreateTimer(group:FZTimersGroup; cfg:FZTimerConfig):FZTimer;
  function DeleteTimer(group:FZTimersGroup; timer:FZTimer):boolean;

  procedure Update();

  class function Get():FZTimersMgr;
end;

function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses CommonHelper;

var
  _instance:FZTimersMgr = nil;

{ FZTimer }

constructor FZTimer.Create(cfg: FZTimerConfig);
begin
  inherited Create();
  _active:=false;
  _cfg:=cfg;
  _last_trigger_time:=FZCommonHelper.GetGameTickCount();
end;

destructor FZTimer.Destroy;
begin
  inherited Destroy;
end;

function FZTimer.GetOverdue(): cardinal;
var
  dt:cardinal;
begin
  result:=0;
  if not _active then exit;

  dt:=FZCommonHelper.GetTimeDeltaSafe(_last_trigger_time);
  if dt > _cfg.period then begin
    result:=dt - _cfg.period;
  end;
end;

function FZTimer.GetPeriod(): cardinal;
begin
  result:=_cfg.period;
end;

procedure FZTimer.SetPeriod(new_period: cardinal);
begin
  _cfg.period:=new_period;
end;

function FZTimer.Trigger(force: boolean): boolean;
begin
  if not _active then begin
    result:=false;
    exit;
  end;

  result:=force;

  if not result then begin
    result:=GetOverdue() > 0;
  end;

  if result then begin
    _cfg.cb(self, _cfg.userdata, FZCommonHelper.GetTimeDeltaSafe(_last_trigger_time));
    _last_trigger_time:=FZCommonHelper.GetGameTickCount();
  end;

end;

procedure FZTimer.SetActive(status: boolean);
begin
  _last_trigger_time:=FZCommonHelper.GetGameTickCount();
  _active:=status;
end;

{ FZTimersGroup }

constructor FZTimersGroup.Create(cfg: FZTimersGroupConfig);
begin
  inherited Create();
  _cfg:=cfg;
  _last_trigger_time:=FZCommonHelper.GetGameTickCount();
  setlength(_timers, 0);
end;

destructor FZTimersGroup.Destroy;
var
  i:integer;
begin
  for i:=0 to length(_timers)-1 do begin
    _timers[i].Free;
  end;
  setlength(_timers, 0);

  inherited Destroy;
end;

function FZTimersGroup.CreateTimer(cfg: FZTimerConfig): FZTimer;
var
  i:integer;
begin
  i:=length(_timers);
  setlength(_timers, i+1);
  _timers[i]:=FZTimer.Create(cfg);
  result:=_timers[i];
end;

function FZTimersGroup.DeleteTimer(timer: FZTimer): boolean;
var
  idx:integer;
begin
  result:=false;
  idx:=_FindTimerIdx(timer);
  if (idx >= 0) then begin
    _timers[idx].Free();
    if idx < length(_timers)-1 then begin
      _timers[idx]:=_timers[length(_timers)-1]
    end;
    setlength(_timers, length(_timers)-1);
    result:=true;
  end;
end;

function FZTimersGroup.TimersCount(): integer;
begin
  result:=length(_timers);
end;

procedure FZTimersGroup.Update();
var
  idx:integer;
begin
  if FZCommonHelper.GetTimeDeltaSafe(_last_trigger_time) >= _cfg.min_interval then begin
    //Ищем таймер с максимальной просрочкой и вызываем его
    idx:=_SelectTimerToTrigger();
    if idx >= 0 then begin
      if _timers[idx].Trigger(false) then begin
        _last_trigger_time:=FZCommonHelper.GetGameTickCount();
      end;
    end;
  end;
end;

function FZTimersGroup._FindTimerIdx(timer:FZTimer): integer;
var
  i:integer;
begin
  result:=-1;
  for i:=0 to length(_timers)-1 do begin
    if _timers[i]=timer then begin
      result:=i;
      break;
    end;
  end;
end;

function FZTimersGroup._SelectTimerToTrigger(): integer;
var
  i:integer;
  max_overdue, cur_overdue:cardinal;
begin
  result:=-1;
  max_overdue:=0;
  for i:=0 to length(_timers)-1 do begin
    cur_overdue:=_timers[i].GetOverdue();
    if cur_overdue > max_overdue then begin
      max_overdue:=cur_overdue;
      result:=i;
    end;
  end;
end;

{ FZTimersMgr }

constructor FZTimersMgr.Create();
begin
  inherited;
  InitializeCriticalSection(_lock);
  setlength(_groups, 0);
end;

destructor FZTimersMgr.Destroy();
var
  i:integer;
begin
  for i:=0 to length(_groups)-1 do begin
    _groups[i].Free();
  end;
  setlength(_groups, 0);
  DeleteCriticalSection(_lock);
  inherited Destroy;
end;

function FZTimersMgr._FindGroupIdx(group: FZTimersGroup): integer;
var
  i:integer;
begin
  result:=-1;
  for i:=0 to length(_groups)-1 do begin
    if _groups[i] = group then begin
      result:=i;
      break;
    end;
  end;
end;

function FZTimersMgr.RegisterTimersGroup(cfg:FZTimersGroupConfig): FZTimersGroup;
var
  i:integer;
begin
  result:=nil;
  EnterCriticalSection(_lock);
  try
    i:=length(_groups);
    setlength(_groups, i+1);
    _groups[i]:=FZTimersGroup.Create(cfg);
    result:=_groups[i];
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZTimersMgr.UnregisterTimersGroup(group: FZTimersGroup): boolean;
var
  i:integer;
begin
  result:=false;
  if group=nil then exit;

  EnterCriticalSection(_lock);
  try
    i:=_FindGroupIdx(group);

    if (i >= 0) and (group.TimersCount() > 0) then begin
      group.Free;

      if i < length(_groups)-1 then begin
        _groups[i]:=_groups[length(_groups)-1];
      end;

      setlength(_groups, length(_groups)-1);
    end;

  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZTimersMgr.CreateTimer(group: FZTimersGroup; cfg: FZTimerConfig): FZTimer;
begin
{$IFNDEF RELEASE_BUILD}
  assert(_FindGroupIdx(group) >= 0);
{$ENDIF}

  result:=nil;
  EnterCriticalSection(_lock);
  try
    result:=group.CreateTimer(cfg);
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZTimersMgr.DeleteTimer(group: FZTimersGroup; timer: FZTimer): boolean;
begin
{$IFNDEF RELEASE_BUILD}
  assert(_FindGroupIdx(group) >= 0);
{$ENDIF}

  result:=false;
  EnterCriticalSection(_lock);
  try
    result:=group.DeleteTimer(timer);
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZTimersMgr.Update();
var
  i:integer;
begin
  EnterCriticalSection(_lock);
  try
     for i:=0 to length(_groups)-1 do begin
       _groups[i].Update();
     end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

class function FZTimersMgr.Get(): FZTimersMgr;
begin
  result:=_instance;
end;

function Init:boolean; stdcall;
begin
  _instance:=FZTimersMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

