unit global_functions;
{$mode delphi}
interface
uses srcCalls;

function Init():boolean; stdcall;
function Free():boolean; stdcall;
procedure LogExactly(str:string); stdcall;
function crc32(ptr:pointer; size:cardinal):cardinal; stdcall;
procedure fz_thread_spawn(proc:pointer; args:pointer); stdcall;
procedure thread_spawn(proc:pointer; name:PChar; stack:cardinal; args:pointer); stdcall;

implementation
uses basedefs;

var
  log_fun:srcCdeclFunction;
  crc32_fun:srcCdeclFunction;
  thread_spawn_fun:srcCdeclFunction;

procedure LogExactly(str:string); stdcall;
begin
  log_fun.Call([PChar(str)])
end;

procedure thread_spawn(proc:pointer; name:PChar; stack:cardinal; args:pointer); stdcall;
begin
  thread_spawn_fun.Call([proc, name, stack, args]);
end;

procedure fz_thread_spawn(proc:pointer; args:pointer); stdcall;
begin
  thread_spawn_fun.Call([proc, 'FZ thread', 0, args]);
end;

function crc32(ptr:pointer; size:cardinal):cardinal; stdcall;
begin
  result:=cardinal(crc32_fun.Call([ptr, size]).VPointer);
end;

function Init():boolean; stdcall;
begin
  crc32_fun:=srcCdeclFunction.Create(pointer(xrCore+$1d4d0), [vtPointer, vtInteger], 'crc32');
  log_fun:=srcCdeclFunction.Create(pointer(xrCore+$16270), [vtPChar], 'Log');
  thread_spawn_fun:=srcCdeclFunction.Create(pointer(xrCore+$7380), [vtPointer, vtPChar, vtInteger, vtPointer], 'thread_spawn');
  result:=true;
end;

function Free():boolean; stdcall;
begin
  //Functions will be deleted by framework
end;

end.
