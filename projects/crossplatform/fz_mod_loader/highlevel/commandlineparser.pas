unit CommandLineParser;

{$mode delphi}

interface
uses LogMgr;

function GetCustomGamedataUrl(cmdline: PAnsiChar):string;
function GetCustomBinUrl(cmdline: PAnsiChar):string;
function GetConfigsDir(cmdline: PAnsiChar; default:string):string;
function GetExeName(cmdline: PAnsiChar; default:string):string;
function GetServerIp(cmdline: PAnsiChar):string;
function GetServerPort(cmdline: PAnsiChar):integer;
function IsGameSpyDlForced(cmdline: PAnsiChar):boolean;
function IsFullInstallMode(cmdline: PAnsiChar):boolean;
function IsSharedPatches(cmdline: PAnsiChar):boolean;
function GetLogSeverity(cmdline: PAnsiChar):FZLogMessageSeverity;
function IsCmdLineNameNameNeeded(cmdline:PAnsiChar):boolean;
function ForceShowMessage(cmdline:PAnsiChar):boolean;

implementation
uses sysutils,JwaWinDNS;

function GetServerPort(cmdline: PAnsiChar):integer;
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

function GetConfigsDir(cmdline: PAnsiChar; default:string): string;
var
  posit:integer;
  i:integer;
  mod_params:string;
const
  KEY:string=' -configsdir ';
begin
  result:=default;
  mod_params:=' '+cmdline+' ';
  posit:=Pos(KEY, mod_params);
  if posit>0 then begin
    result:='';
    for i:=posit+length(KEY) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
  end;
end;

function GetExeName(cmdline: PAnsiChar; default: string): string;
var
  posit:integer;
  i:integer;
  mod_params:string;
const
  KEY:string=' -exename ';
begin
  result:=default;
  mod_params:=' '+cmdline+' ';
  posit:=Pos(KEY, mod_params);
  if posit>0 then begin
    result:='';
    for i:=posit+length(KEY) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        result:=result+mod_params[i];
      end;
    end;
  end;
end;

function GetServerIp(cmdline: PAnsiChar):string;
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
    FZLogMgr.Get.Write('Use direct IP '+result, FZ_LOG_INFO);
    exit;
  end;
    //если в параметрах есть доменное имя сервера - используем его
  posit:=Pos(SRV_DOMAIN, mod_params);
  if posit>0 then begin
    FZLogMgr.Get.Write('Use domain name', FZ_LOG_INFO);
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
      FZLogMgr.Get.Write('Received IP '+result, FZ_LOG_INFO);
    end;
    if (rec<>nil) then begin
      DnsRecordListFree(rec, DnsFreeRecordList);
    end;
    exit;
  end;
  FZLogMgr.Get.Write('Parameters contain no server address!', FZ_LOG_ERROR);
end;

function IsGameSpyDlForced(cmdline: PAnsiChar):boolean;
const
  GS_FORCE:string= ' -gamespymode ';
begin
  result:=Pos(GS_FORCE, ' '+cmdline+' ') > 0;
end;

function IsSharedPatches(cmdline: PAnsiChar): boolean;
const
  KEY:string= ' -sharedpatches ';
begin
  result:=Pos(KEY, ' '+cmdline+' ') > 0;
end;

function GetLogSeverity(cmdline: PAnsiChar):FZLogMessageSeverity;
const
  PARAM:string= ' -logsev ';

  def_severity:FZLogMessageSeverity = FZ_LOG_INFO;
var
  posit, i, tmpres:integer;
  mod_params, tmp:string;
begin
  result:=def_severity;

  mod_params:=cmdline+' ';
  posit:=Pos(PARAM, mod_params);
  if posit>0 then begin
    tmp:='';
    for i:=posit+length(PARAM) to length(mod_params) do begin
      if mod_params[i]=' ' then begin
        break;
      end else begin
        tmp:=tmp+mod_params[i];
      end;
    end;
    tmpres:=strtointdef(tmp, integer(def_severity));

    if tmpres>integer(FZ_LOG_SILENT) then begin
      tmpres:=integer(FZ_LOG_SILENT);
    end;

    result:=FZLogMessageSeverity(tmpres);
  end;
end;

function IsCmdLineNameNameNeeded(cmdline: PAnsiChar): boolean;
const
  INCLUDENAME: string = ' -includename ';
begin
  result:=Pos(INCLUDENAME, ' '+cmdline+' ') > 0;
end;

function ForceShowMessage(cmdline: PAnsiChar): boolean;
const
  MESSAGEKEY: string = ' -preservemessage ';
begin
  result:=Pos(MESSAGEKEY, ' '+cmdline+' ') > 0;
end;

function IsFullInstallMode(cmdline: PAnsiChar): boolean;
const
  FULLINSTALL: string = ' -fullinstall ';
begin
  result:=Pos(FULLINSTALL, ' '+cmdline+' ') > 0;
end;

function GetCustomGamedataUrl(cmdline: PAnsiChar):string;
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

function GetCustomBinUrl(cmdline: PAnsiChar):string;
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

