unit SACE_interface;
{$MODE Delphi}
interface

type

FZUACPlayerInfo = packed record
  dwSize:cardinal;
  dwCheatFlags:cardinal;
  bOutdated:cardinal;
  bFullscreen:cardinal;
  Reserved:array[0..23] of cardinal;
end;
pFZUACPlayerInfo=^FZUACPlayerInfo;

FZGetUACPlayerInfo_fun = function (szHash_MD5:PChar; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall;
FZGetUACPlayerInfoByID_fun = function (ID:cardinal; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall;

const
  SACE_NOT_FOUND:integer=-10;
  SACE_OUTDATED:integer=0;
  SACE_UNSUPPORTED:integer=10;
  SACE_OK:integer = 20;


function GetSACEStatus(id:cardinal):integer; stdcall;
function IsSaceSupportedByServer():boolean; stdcall;
function Init():boolean;

implementation
uses Windows, LogMgr, basedefs, sysutils;

var
  UACInfo:FZGetUACPlayerInfoByID_fun;

function GetSACEStatus(id:cardinal):integer; stdcall;
var
  s:FZUACPlayerInfo;
begin
  if @UACInfo=nil then begin
    result:= SACE_UNSUPPORTED;
    exit;
  end;
  
  s.dwSize:=sizeof(s);
  if UACInfo(id, @s) then begin
    if s.bOutdated>0 then begin
      result:=SACE_OUTDATED;
    end else begin
      result:=SACE_OK;
    end;
  end else begin
    result:=SACE_NOT_FOUND;
  end;
end;

function IsSaceSupportedByServer():boolean; stdcall;
begin
  result:=(@UACInfo<>nil);
end;

function Init():boolean;
begin
  @UACInfo:=nil;
  if xrAPI<>0 then begin
    @UACInfo:=GetProcAddress(xrAPI, 'GetUACPlayerInfoByID');
  end else begin
    FZLogMgr.Get.Write('xrAPI module not found.', FZ_LOG_INFO);
  end;

  if @UACInfo<>nil then begin
    FZLogMgr.Get.Write('Anticheat engine found.', FZ_LOG_INFO);
    FZLogMgr.Get.Write('SACE fun is '+inttohex(cardinal(@UACInfo),8), FZ_LOG_DBG);
  end else begin
    FZLogMgr.Get.Write('SACE not found.', FZ_LOG_INFO);
  end;
  result:=true;  
end;

end.
