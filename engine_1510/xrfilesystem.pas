unit xrfilesystem;
{$mode delphi}
{$I _pathes.inc}

interface
type
CLocatorAPI = packed record
//TODO: fill
end;
pCLocatorAPI = ^CLocatorAPI;
ppCLocatorAPI = ^pCLocatorAPI;


function Init():boolean; stdcall;
function Free():boolean; stdcall;
function UpdatePath(root:string; appendix:string):string;

implementation
uses srcCalls, basedefs;
var
  CLocatorApi__xr_FS:ppCLocatorAPI;
  CLocatorApi__update_path:srcECXCallFunction;

function UpdatePath(root:string; appendix:string):string;
var
  buf:array[0..1023] of char;
  fs:pCLocatorAPI;
  res_buf:PChar;
begin
  res_buf:=@buf[0];
  fs:=CLocatorApi__xr_FS^;
  CLocatorApi__update_path.Call([fs, res_buf, PChar(root), PChar(appendix)]);
  result:=res_buf;
end;

function Init():boolean; stdcall;
var
  tmp:pointer;
begin
  result:=false;

  //1.5.10: expected xrCore+$BE718
  if not InitSymbol(CLocatorApi__xr_FS, xrCore, '?xr_FS@@3PAVCLocatorAPI@@A') then exit;

  //1.5.10: expected xrCore+$128d0
  if not InitSymbol(tmp, xrCore, '?update_path@CLocatorAPI@@QAEPBDAAY0CAI@DPBD1@Z') then exit;
  CLocatorApi__update_path:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar, vtPChar, vtPChar], 'update_path', 'CLocatorAPI');

  result:=true;
end;

function Free():boolean; stdcall;
begin
  result:=true;
  //Functions will be deleted by framework
end;

end.
