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
uses basedefs;

var
  Log_fun:srcCdeclFunction;
  MD5Digest_fun:srcCdeclFunction;
  crc32_fun:srcCdeclFunction;

procedure LogExactly(str:string); stdcall;
begin
  Log_fun.Call([PAnsiChar(str)])
end;

function crc32(ptr:pointer; size:cardinal):cardinal; stdcall;
begin
  result:=cardinal(crc32_fun.Call([ptr, size]).VPointer);
end;

function Init():boolean; stdcall;
var
  tmp:pointer;
begin
  result:=false;
  tmp:=nil;

  //1.0006 - expected xrEngine+103b55
  if not InitSymbol(g_dedicated_server, xrEngine, '?g_dedicated_server@@3_NA') then exit;

  //1.0006 - expected xrCore+185d0
  if not InitSymbol(tmp, xrCore, '?Log@@YAXPBD@Z') then exit;
  Log_fun:=srcCdeclFunction.Create(tmp, [vtPChar], 'Log');

  //1.0006 - expected xrCore+1e8b0
  if not InitSymbol(tmp, xrCore, '?crc32@@YAIPBXI@Z') then exit;
  crc32_fun:=srcCdeclFunction.Create(tmp, [vtPointer, vtInteger], 'crc32');

  if not InitSymbol(tmp, xrGameSpy, 'xrGS_gcd_getkeyhash') then exit;
  xrGS_gcd_getkeyhash:=srcCdeclFunction.Create(tmp, [vtInteger], 'xrGS_gcd_getkeyhash');

  result:=true;
end;

end.
