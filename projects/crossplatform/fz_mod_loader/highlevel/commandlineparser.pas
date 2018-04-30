unit CommandLineParser;

{$mode delphi}

interface
function GetCustomGamedataUrl(cmdline: PChar):string;
function GetCustomBinUrl(cmdline: PChar):string;
function GetServerIp(cmdline: PChar):string;
function GetServerPort(cmdline: PChar):integer;
function IsGameSpyDlForced(cmdline: PChar):boolean;

implementation
uses sysutils,JwaWinDNS, LogMgr;

function GetServerPort(cmdline: PChar):integer;
var
  mod_params, tmp:string;
  posit, i:integer;
const
  PORT_ARG='-srvport ';
begin
  result:=-1;
  mod_params:=cmdline+' ';
  posit:=Pos(PORT_ARG, mod_params);
  if posit>0 then begin
    tmp:='';
    for i:=posit+length(PORT_ARG) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        tmp:=tmp+mod_params[i];
      end;
    end;
    result:=strtointdef(tmp, -1);
  end;
end;

function GetServerIp(cmdline: PChar):string;
var
  i:integer;
  posit:integer;
  mod_params:string;
  rec:PDNS_RECORD;
  res:cardinal;
  ip:cardinal;
const
  SRV_IP:string='-srv ';
  SRV_DOMAIN:string='-srvname ';
begin
  result:='';
  mod_params:=cmdline+' ';
  rec:=nil;
    //если в параметрах есть прямой IP - используем его
  posit:=Pos(SRV_IP, mod_params);
  if posit>0 then begin
    for i:=posit+length(SRV_IP) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
    FZLogMgr.Get.Write('Use direct IP '+result, FZ_LOG_DBG);
    exit;
  end;
    //если в параметрах есть доменное имя сервера - используем его
  posit:=Pos(SRV_DOMAIN, mod_params);
  if posit>0 then begin
    FZLogMgr.Get.Write('Use domain name', FZ_LOG_DBG);
    for i:=posit+length(SRV_DOMAIN) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
    res:=DnsQuery(PAnsiChar(result), DNS_TYPE_A, DNS_QUERY_STANDARD, nil, @rec, nil);
    if res <> 0 then begin
      FZLogMgr.Get.Write('Cannot resolve '+result, FZ_LOG_ERROR);
      result:='';
    end else begin
      ip:=rec^.Data.A.IpAddress;
      result:=inttostr(ip and $FF)+'.'+inttostr((ip and $FF00) shr 8)+'.'+inttostr((ip and $FF0000) shr 16)+'.'+inttostr((ip and $FF000000) shr 24);
      FZLogMgr.Get.Write('Received IP '+result, FZ_LOG_DBG);
    end;
    if (rec<>nil) then begin
      DnsRecordListFree(rec, DnsFreeRecordList);
    end;
    exit;
  end;
  FZLogMgr.Get.Write('Parameters contain no server address!', FZ_LOG_ERROR);
end;

function IsGameSpyDlForced(cmdline: PChar):boolean;
const
  GS_FORCE:string= ' -gamespymode ';
begin
  result:=Pos(GS_FORCE, ' '+cmdline+' ') > 0;
end;

function GetCustomGamedataUrl(cmdline: PChar):string;
var
  posit:integer;
  i:integer;
  mod_params:string;
const
  GAME_LIST:string=' -gamelist ';
begin
  result:='';
  mod_params:=' '+cmdline+' ';
  posit:=Pos(GAME_LIST, mod_params);
  if posit>0 then begin
    result:='';
    for i:=posit+length(GAME_LIST) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
  end;
end;

function GetCustomBinUrl(cmdline: PChar):string;
var
  posit:integer;
  i:integer;
  mod_params:string;
const
  BIN_LIST:string=' -binlist ';
begin
  result:='';
  mod_params:=' '+cmdline+' ';
  posit:=Pos(BIN_LIST, mod_params);
  if posit>0 then begin
    result:='';
    for i:=posit+length(BIN_LIST) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
  end;
end;

end.

