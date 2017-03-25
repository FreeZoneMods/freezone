unit SACE_hacks;

{$mode delphi}

interface
function IPureServer__net_Handler_isToConnectsentbysace(dvReceivedData:pointer):boolean; stdcall;

function Init():boolean; stdcall;
procedure Free(); stdcall;

implementation
uses LogMgr, ServerStuff, DownloadMgr;

function IPureServer__net_Handler_isToConnectsentbysace(dvReceivedData:pointer):boolean; stdcall;
var
  mapname, mapver, maplink:string;
const
  SACE_MARK_OFFSET:cardinal = $14;
  SACE_MARK_VALUE:cardinal = $01A01202;
begin
    //true, если пакет отправлен SACE. Это приведет к игнору пакета.
    result:=false;
    GetMapStatus(mapname, mapver, maplink);
    if not FZDownloadMgr.Get.IsSaceFakeNeeded(mapname, mapver) then exit;
    if PChar(dvReceivedData)<>'ToConnect' then exit;

    dvReceivedData:=dvReceivedData-SACE_MARK_OFFSET;
    result:= (pcardinal(dvReceivedData)^ = SACE_MARK_VALUE);
    if result then begin
      FZLogMgr.Get.Write('SACE DL bypass', FZ_LOG_INFO);
    end;
end;

function Init():boolean; stdcall;
begin
  result:=true;
end;

procedure Free(); stdcall;
begin
end;

end.

