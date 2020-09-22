unit PeriodicExecutionMgr;

{$mode delphi}

interface
uses Classes, Timersmgr, ConfigBase;

type

{ FZPeriodicItem }
FZPeriodicItem = class
  _active:boolean;
  _group_owner:boolean;
  _period:cardinal;
  _my_group:FZTimersGroup;
  _my_timer:FZTimer;
protected
  procedure _PerformAction(); virtual; abstract;
  function _Activate():boolean;
public
  constructor Create(group:FZTimersGroup; period:cardinal; auto_activate:boolean = false);
  destructor Destroy; override;
end;

{ FZPeriodicChatItem }
FZPeriodicChatItem = class (FZPeriodicItem)
protected
  _sender_name:string;
  _text:string;
  _target_channel_id:word;

  procedure _PerformAction(); override;
public
  constructor Create(group:FZTimersGroup; period:cardinal; name:string; text:string; channel_id:word);
end;

{ FZPeriodicCommandsBlock }

FZPeriodicCommandsBlock = class(FZPeriodicItem)
protected
  _commands:TStringList;

  procedure _PerformAction(); override;
public
  constructor Create(period:cardinal; commands:TStringList);
  destructor Destroy(); override;
end;


{ FZPeriodicExecutionMgr }
FZPeriodicExecutionMgr = class
private
  _chat_group:FZTimersGroup;
  _items:array of FZPeriodicItem;

  {%H-}constructor Create();
  procedure _ResetItems();
  procedure _AddItem(itm:FZPeriodicItem);
public
  destructor Destroy(); override;

  class function Get():FZPeriodicExecutionMgr;
  procedure Reload();
end;

function Init():boolean;
procedure Free();

implementation
uses xr_debug, Chat, sysutils, LogMgr, AdminCommands;

var
  _instance:FZPeriodicExecutionMgr;

{ FZPeriodicItem }
procedure _TimerCallback(timer: FZTimer; userdata: pointer; delta: cardinal); stdcall;
var
  itm:FZPeriodicItem;
begin
  itm:=FZPeriodicItem(userdata);
  R_ASSERT(timer = itm._my_timer, 'Callback called from invalid timer', 'FZPeriodicItem._Callback');
  itm._PerformAction();
end;

function FZPeriodicItem._Activate():boolean;
var
  cfg_t:FZTimerConfig;
begin
  if _active then begin
    result:=false;
  end else begin
    cfg_t.period:=_period;
    cfg_t.cb:=@_TimerCallback;
    cfg_t.userdata:=self;
    _my_timer:=FZTimersMgr.Get.CreateTimer(_my_group, cfg_t);
    _my_timer.SetActive(true);
    result:=true;
  end;
end;

constructor FZPeriodicItem.Create(group: FZTimersGroup; period: cardinal; auto_activate:boolean);
var
  cfg_g:FZTimersGroupConfig;
begin
  _active:=false;
  _my_timer:=nil;
  _period:=period;
  _group_owner:= (group = nil);

  if _group_owner then begin
    //В группе будет только наш таймер, так что минимальный интервал смысла настраивать нет
    cfg_g.min_interval:=0;
    _my_group:=FZTimersMgr.Get.RegisterTimersGroup(cfg_g);
  end else begin
    _my_group:=group;
  end;

  if auto_activate then begin
     _Activate();
  end;
end;

destructor FZPeriodicItem.Destroy;
begin
  if _my_timer<>nil then begin
    FZTimersMgr.Get.DeleteTimer(_my_group, _my_timer);
  end;

  if _group_owner then begin
    FZTimersMgr.Get.UnregisterTimersGroup(_my_group);
  end;
end;

{ FZPeriodicChatItem }

constructor FZPeriodicChatItem.Create(group: FZTimersGroup; period: cardinal; name: string; text: string; channel_id: word);
begin
  inherited Create(group, period, false);
  _sender_name:=name;
  _target_channel_id:=channel_id;
  _text:=text;
  _Activate();
end;

procedure FZPeriodicChatItem._PerformAction();
begin
  SendChatMessageToPlayers(_sender_name, _text, 0, _target_channel_id);
end;

{ FZPeriodicCommandsBlock }

constructor FZPeriodicCommandsBlock.Create(period: cardinal; commands: TStringList);
begin
  inherited Create(nil, period, false);
  R_ASSERT(commands<>nil, 'No commands in block', 'FZPeriodicCommandsBlock.Create');
  _commands:=commands;
  _Activate();
end;

destructor FZPeriodicCommandsBlock.Destroy();
begin
  _commands.Free();
  inherited Destroy();
end;

procedure FZPeriodicCommandsBlock._PerformAction();
var
  i:integer;
begin
  FZLogMgr.Get.Write('Start executing block of console commands', FZ_LOG_DBG);
  for i:=0 to _commands.Count - 1 do begin
    AddAdminCommandToQueue(FZSimpleConsoleCmd.Create(_commands.Strings[i], FZConsoleReporter.Create(0)));
  end;
  FZLogMgr.Get.Write('End executing block of console commands', FZ_LOG_DBG);
end;

{ FZPeriodicExecutionMgr }

constructor FZPeriodicExecutionMgr.Create();
begin
  inherited;
  _chat_group:=nil;
  setlength(_items, 0);
  Reload();
end;

destructor FZPeriodicExecutionMgr.Destroy();
begin
  _ResetItems();
  FZTimersMgr.Get.UnregisterTimersGroup(_chat_group);
  inherited;
end;

procedure FZPeriodicExecutionMgr._ResetItems();
var
  i:integer;
begin
  for i:=length(_items)-1 downto 0 do begin
    _items[i].Free();
  end;
  SetLength(_items, 0);
end;

procedure FZPeriodicExecutionMgr._AddItem(itm: FZPeriodicItem);
var
  i:integer;
begin
  i:=length(_items);
  setlength(_items, i+1);
  _items[i]:=itm;
end;

class function FZPeriodicExecutionMgr.Get(): FZPeriodicExecutionMgr;
begin
  result:=_instance;
end;

procedure FZPeriodicExecutionMgr.Reload();
const
  CONFIG_NAME:string='fz_timers.ini';
  CHAT_MSG_SECTION:string = 'chat_messages';
  DEFAULT_SENDER:string='ServerAdmin';
  DEFAULT_CHANNEL:word = $FFFF;
  MIN_INTERVAL:string='min_interval';
  MIN_INTERVAL_DEF:cardinal=2000;

  COMMANDS_BLOCK_SECTION_TEMPLATE:string='commands_';
  TIMER_PERIOD_PARAM:string='period';

var
  cfg:FZConfigBase;

  cfg_chat_gr:FZTimersGroupConfig;
  prefix, txt, sect:string;
  period:integer;
  itm:FZPeriodicItem;
  i, j:integer;
  strings:TStringList;
begin
  //Unload and clean old
  _ResetItems();
  FZTimersMgr.Get.UnregisterTimersGroup(_chat_group);

  //Load new
  cfg:=FZConfigBase.Create();
  cfg.Load(CONFIG_NAME);

  cfg_chat_gr.min_interval:=cfg.GetInt(MIN_INTERVAL, MIN_INTERVAL_DEF, CHAT_MSG_SECTION);
  _chat_group:=FZTimersMgr.Get.RegisterTimersGroup(cfg_chat_gr);

  i:=0;
  while (true) do begin
    prefix:='message_'+inttostr(i);
    txt:=cfg.GetString(prefix, '', CHAT_MSG_SECTION);
    if length(txt) = 0 then break;

    period:=cfg.GetInt(prefix+'_'+TIMER_PERIOD_PARAM, 0, CHAT_MSG_SECTION);
    if period <= 0 then begin
      FZLogMgr.Get.Write('Periodic chat message #'+inttostr(i)+' is misconfigured - check period', FZ_LOG_ERROR);
      continue;
    end;

    itm:=FZPeriodicChatItem.Create(
                                    _chat_group, period,
                                    cfg.GetString(prefix+'_sender', DEFAULT_SENDER, CHAT_MSG_SECTION),
                                    txt,
                                    cfg.GetInt(prefix+'_target', DEFAULT_CHANNEL, CHAT_MSG_SECTION)
                                  );

    R_ASSERT(itm<>nil, 'Can''t create chat item', 'FZPeriodicExecutionMgr.Reload');
    _AddItem(itm);
    i:=i+1;
  end;

  i:=0;
  while (true) do begin
    sect:=COMMANDS_BLOCK_SECTION_TEMPLATE+inttostr(i);
    if not cfg.IsSectionExist(sect) then break;

    period:=cfg.GetInt(TIMER_PERIOD_PARAM, 0, sect);
    if period <= 0 then begin
      FZLogMgr.Get.Write('Periodic commands block #'+inttostr(i)+' is misconfigured - check period', FZ_LOG_ERROR);
    end else begin
      strings:=TStringList.Create;
      j:=0;
      while (true) do begin
        txt:='command_'+inttostr(j);
        txt:=cfg.GetString(txt, '', sect);
        if length(txt) = 0 then break;

        strings.Add(txt);
        j:=j+1;
      end;

      if strings.Count > 0 then begin
        itm:=FZPeriodicCommandsBlock.Create(period, strings);
        R_ASSERT(itm<>nil, 'Can''t create commands block item', 'FZPeriodicExecutionMgr.Reload');
        _AddItem(itm);
      end else begin
        strings.Free;
      end;
    end;

    i:=i+1;
  end;

  cfg.Free;
end;

function Init(): boolean;
begin
  _instance:=FZPeriodicExecutionMgr.Create();
  result:=true;
end;

procedure Free();
begin
  _instance.Free();
end;

end.

