unit Console;
{$mode delphi}
{$I _pathes.inc}

interface
uses basedefs, srcCalls;


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
  cName:PAnsiChar;
  bEnabled:byte;
  bLowerCaseArgs:byte;
  bEmptyArgsHandled:byte;
  _reserved:byte;
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
console_execute_callback = procedure(arg:PAnsiChar);stdcall;
console_status_callback = procedure(status:PAnsiChar);stdcall;
console_info_callback = procedure(info:PAnsiChar);stdcall;

var
  c_sv_fraglimit, c_sv_timelimit:pCCC_SV_Integer;
  c_sv_dedicated_server_update_rate:pCCC_SV_Integer;
  c_sv_vote_quota:pCCC_SV_Float;
  c_sv_vote_participants:pCCC_SV_Integer;
  c_sv_vote_enabled:pCCC_SV_Integer;
  c_sv_teamkill_punish:pCCC_SV_Integer;
  c_sv_teamkill_limit:pCCC_SV_Integer;

  g_ppConsole:ppCConsole;

  CConsole__AddCommand:srcECXCallFunction;
  CCC_Integer__CCC_Integer:srcECXCallFunction;

//FreeZone Stuff
  procedure AddConsoleCommand(name:PAnsiChar; cb:console_execute_callback; info_cb:console_info_callback=nil; status_cb:console_status_callback=nil); stdcall;
  procedure ExecuteConsoleCommand(cmd:PAnsiChar); stdcall;

  function GetLastPrintedID():cardinal;
  procedure SetLastPrintedID(id:cardinal);

implementation

var
  CConsole__Execute:srcECXCallFunction;
  _last_id:cardinal; //Last printed ID

procedure default_status(status:PAnsiChar); stdcall;
begin
  status[0]:=chr(0);
end;


procedure default_info(info:PAnsiChar); stdcall;
begin
  info[0]:=chr(0);
end;



procedure AddConsoleCommand(name:PAnsiChar; cb:console_execute_callback; info_cb:console_info_callback=nil; status_cb:console_status_callback=nil); stdcall;
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
  CConsole__Execute.Call([g_ppConsole^, cmd]);
end;

function GetLastPrintedID(): cardinal;
begin
  result:=_last_id;
end;

procedure SetLastPrintedID(id: cardinal);
begin
  _last_id:=id;
end;

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_10006 then begin

    c_sv_fraglimit:=pointer(xrGame+$561b40);
    c_sv_timelimit:=pointer(xrGame+$561b28);
    c_sv_vote_quota:=pointer(xrGame+$561b88);
    c_sv_vote_participants:=pointer(xrGame+$561ba0);
    c_sv_vote_enabled:=pointer(xrGame+$561c30);
    c_sv_teamkill_punish:=pointer(xrGame+$5619d4);
    c_sv_teamkill_limit:=pointer(xrGame+$5619ec);
  end;
  c_sv_dedicated_server_update_rate:=pointer(xrEngine+$106850);
  g_ppConsole:=pointer(xrEngine+$103bbc);
  _last_id:=0;


  CConsole__Execute:=srcECXCallFunction.Create(pointer(xrEngine+$6aa60),[vtPointer, vtPChar], 'Execute', 'CConsole');
  CConsole__AddCommand:=srcECXCallFunction.Create(pointer(xrEngine+$6abb0),[vtPointer, vtPointer], 'AddCommand', 'CConsole');
  CCC_Integer__CCC_Integer:=srcECXCallFunction.Create(pointer(xrEngine+$10710),[vtPointer, vtPChar, vtPointer, vtInteger, vtInteger], 'CCC_Integer', 'CCC_Integer');

  result:=true;
end;

end.
