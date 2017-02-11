unit global_functions;
{$mode delphi}
interface
uses srcCalls;

function Init():boolean; stdcall;
procedure LogExactly(str:string); stdcall;
function crc32(ptr:pointer; size:cardinal):cardinal; stdcall;

var
  xrGS_gcd_getkeyhash:srcCdeclFunction;
  is_widescreen:srcCdeclFunction;
  GameID:srcCdeclFunction;
  g_dedicated_server:pbyte;

implementation
uses basedefs, windows;

var
  Log_fun:srcCdeclFunction;
  crc32_fun:srcCdeclFunction;

procedure LogExactly(str:string); stdcall;
begin
  Log_fun.Call([PChar(str)])
end;

function crc32(ptr:pointer; size:cardinal):cardinal; stdcall;
begin
  result:=cardinal(crc32_fun.Call([ptr, size]).VPointer);
end;

function Init():boolean; stdcall;
var
  addr:pointer;
begin
  Log_fun:=srcCdeclFunction.Create(pointer(xrCore+$16270), [vtPChar], 'Log');
  crc32_fun:=srcCdeclFunction.Create(pointer(xrCore+$1d4d0), [vtPointer, vtInteger], 'crc32');
  addr:=GetProcAddress(xrGameSpy, 'xrGS_gcd_getkeyhash');
  if addr<>nil then begin
    xrGS_gcd_getkeyhash:=srcCdeclFunction.Create(addr, [vtInteger], 'xrGS_gcd_getkeyhash');
  end else begin
    MessageBox(0, 'xrGS_gcd_getkeyhash not found!', 'global_functions.Init', MB_OK+MB_ICONERROR+MB_SYSTEMMODAL);
    result:=false;
    exit;
  end;
  g_dedicated_server:=pointer(xrEngine+$909A5);
  result:=true;
end;

end.
