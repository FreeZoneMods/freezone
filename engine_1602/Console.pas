unit Console;
{$mode delphi}
{$I _pathes.inc}

interface
uses basedefs, srcCalls, Vector;


function Init():boolean; stdcall;

type

IConsole_Command_vftable = packed record
  _destr:pointer;
  Execute:pointer;
  Status:pointer;
  Info:pointer;
  Save:pointer;
end;

type
pIConsole_Command_vftable = ^IConsole_Command_vftable;

IConsole_Command = packed record
  vftable:pIConsole_Command_vftable;
  cName:PChar;
  bEnabled:byte;
  bLowerCaseArgs:byte;
  bEmptyArgsHandled:byte;
  _reserved:byte;
  m_LRU:xr_vector;
end;

pIConsole_Command = ^IConsole_Command;

CCC_Mask = packed record
  base:IConsole_Command;
  value:pcardinal;
  mask:cardinal;  
end;
pCCC_Mask = ^CCC_Mask;

CCC_Integer = packed record
  base:IConsole_Command;
  value:pinteger;
  min:integer;
  max:integer;
end;
pCCC_Integer= ^CCC_Integer;
pCCC_SV_Integer=pCCC_Integer;

CCC_Float = packed record
  base:IConsole_Command;
  value:psingle;
  min:single;
  max:single;
end;
pCCC_Float= ^CCC_Float;
pCCC_SV_Float=pCCC_Float;


CConsole = packed record
  //TODO:fill
end;
pCConsole=^CConsole;
ppCConsole=^pCConsole;

//FreeZone Stuff
console_execute_callback = procedure(arg:PChar);stdcall;
console_status_callback = procedure(status:PChar);stdcall;
console_info_callback = procedure(info:PChar);stdcall;

var
  c_sv_fraglimit, c_sv_timelimit:pCCC_SV_Integer;
  c_sv_vote_quota:pCCC_SV_Float;
  c_sv_vote_participants:pCCC_SV_Integer;
  c_sv_vote_enabled:pCCC_SV_Integer;
  c_sv_teamkill_punish:pCCC_SV_Integer;
  c_sv_teamkill_limit:pCCC_SV_Integer;
  c_sv_friendlyfire:pCCC_SV_Float;

  g_ppConsole:ppCConsole;

  CConsole__AddCommand:srcECXCallFunction;
  CCC_Integer__CCC_Integer:srcECXCallFunction;

//FreeZone Stuff
  procedure AddConsoleCommand(name:PChar; cb:console_execute_callback; info_cb:console_info_callback=nil; status_cb:console_status_callback=nil); stdcall;
  procedure ExecuteConsoleCommand(cmd:PAnsiChar); stdcall;
  function GetLastPrintedID():cardinal;
  procedure SetLastPrintedID(id:cardinal);

implementation

uses windows;

var
  CConsole__ExecuteCommand:srcECXCallFunction;
  last_printed_id:pcardinal;

procedure default_status(status:PChar); stdcall;
begin
  status[0]:=chr(0);
end;

procedure default_info(info:PChar); stdcall;
begin
  info[0]:=chr(0);
end;

procedure AddConsoleCommand(name:PChar; cb:console_execute_callback; info_cb:console_info_callback=nil; status_cb:console_status_callback=nil); stdcall;
var
  cmd:pIConsole_Command;
  tbl:pIConsole_Command_vftable;
begin
  //TODO: Memory leak... или забить... ’з, пусть пока так, если будет нефиг делать допилим
  New(tbl);
  New(cmd);

  tbl^._destr:=c_sv_fraglimit^.base.vftable^._destr;
  tbl^.Save := c_sv_fraglimit^.base.vftable^.Save;

  tbl^.Execute:=@cb;

  if @status_cb=nil then
    tbl^.Status:=@default_status
  else
    tbl^.Status:=@status_cb;

  if @info_cb=nil then
    tbl^.Info:=@default_info
  else
    tbl^.Info:=@info_cb;


  cmd^.vftable:=tbl;
  cmd^.cName:=name;
  cmd^.bLowerCaseArgs:=0;
  cmd^.bEmptyArgsHandled:=1;
  cmd^.bEnabled:=1;

  CConsole__AddCommand.Call([g_ppConsole^, cmd])
end;

procedure ExecuteConsoleCommand(cmd:PAnsiChar); stdcall;
begin
  CConsole__ExecuteCommand.Call([g_ppConsole^, cmd, false]);
end;

function GetLastPrintedID(): cardinal;
begin
  result:=last_printed_id^;
end;

procedure SetLastPrintedID(id: cardinal);
begin
  last_printed_id^:=id;
end;

function Init():boolean; stdcall;
var
  ptr:pointer;
begin
  result:=false;
  if xrGameDllType()=XRGAME_1602 then begin
    c_sv_timelimit:=pointer(xrGame+$650190);
    c_sv_fraglimit:=pointer(xrGame+$6501b4);
    c_sv_vote_quota:=pointer(xrGame+$650220);
    c_sv_vote_participants:=pointer(xrGame+$650244);
    c_sv_vote_enabled:=pointer(xrGame+$650340);
    c_sv_teamkill_punish:=pointer(xrGame+$64ff98);
    c_sv_teamkill_limit:=pointer(xrGame+$64ffbc);
    c_sv_friendlyfire:=pointer(xrGame+$64ffe0);
    last_printed_id:=pointer(xrGame+$64fb60);
  end;
  g_ppConsole:= GetProcAddress(xrEngine, '?Console@@3PAVCConsole@@A');
  if g_ppConsole = nil then exit;

  ptr:= GetProcAddress(xrEngine, '?ExecuteCommand@CConsole@@QAEXPBD_N@Z');
  if ptr = nil then exit;
  CConsole__ExecuteCommand:=srcECXCallFunction.Create(ptr,[vtPointer, vtPChar, vtBoolean], 'ExecuteCommand', 'CConsole');

  ptr:= GetProcAddress(xrEngine, '?AddCommand@CConsole@@QAEXPAVIConsole_Command@@@Z');
  if ptr = nil then exit;
  CConsole__AddCommand:=srcECXCallFunction.Create(ptr,[vtPointer, vtPointer], 'AddCommand', 'CConsole');

  ptr:= GetProcAddress(xrEngine, '??0CCC_Integer@@QAE@PBDPAHHH@Z');
  if ptr = nil then exit;
  CCC_Integer__CCC_Integer:=srcECXCallFunction.Create(ptr,[vtPointer, vtPChar, vtPointer, vtInteger, vtInteger], 'CCC_Integer', 'CCC_Integer');

  result:=true;
end;

end.
