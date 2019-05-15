unit global_functions;
{$mode delphi}
{$I _pathes.inc}

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
  result:=false;

  //1.6.02 - expected xrCore+158B0
  addr:=GetProcAddress(xrCore, '?Log@@YAXPBD@Z');
  if addr=nil then begin
    MessageBox(0, '"Log" function not found!', 'global_functions.Init', MB_OK+MB_ICONERROR+MB_SYSTEMMODAL);
    exit;
  end;
  Log_fun:=srcCdeclFunction.Create(addr, [vtPChar], 'Log');

  //1.6.02 - expected xrCore+1FCE0
  addr:=GetProcAddress(xrCore, '?crc32@@YAIPBXI@Z');
  if addr=nil then begin
    MessageBox(0, '"crc32" function not found!', 'global_functions.Init', MB_OK+MB_ICONERROR+MB_SYSTEMMODAL);
    exit;
  end;
  crc32_fun:=srcCdeclFunction.Create(addr, [vtPointer, vtInteger], 'crc32');

  addr:=GetProcAddress(xrGameSpy, 'xrGS_gcd_getkeyhash');
  if addr=nil then begin
    MessageBox(0, '"xrGS_gcd_getkeyhash" function not found!', 'global_functions.Init', MB_OK+MB_ICONERROR+MB_SYSTEMMODAL);
    exit;
  end;
  xrGS_gcd_getkeyhash:=srcCdeclFunction.Create(addr, [vtInteger], 'xrGS_gcd_getkeyhash');

  //1.6.02 - expected xrEngine+8bbe1
  addr:=GetProcAddress(xrEngine, '?g_dedicated_server@@3_NA');
  if addr=nil then begin
    MessageBox(0, '"g_dedicated_server" variable not found!', 'global_functions.Init', MB_OK+MB_ICONERROR+MB_SYSTEMMODAL);
    exit;
  end;
  g_dedicated_server:=addr;

  result:=true;
end;

end.
