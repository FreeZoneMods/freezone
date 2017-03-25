unit SubnetBanList;
{$mode delphi}
interface
uses Contnrs, Packets, LogMgr, Windows;

type
FZBannedSubnet = class
public
  ip:ip_address;
  mask:cardinal;
  reason:string;
  valid:boolean;
  constructor Create(ip:string; reason:string);
  destructor Destroy; override;
end;

FZSubnetBanList = class
protected
  _list:TObjectList;
  _lock:TRTLCriticalSection;
  procedure _freeList();
  function ConvertIpToCardinal(ip:ip_address):cardinal;
public
  constructor Create();
  destructor Destroy(); override;
  procedure ReloadDefaultFile();
  procedure Reload(fname:string);
  function CheckForBan(ip:ip_address):boolean;
  function Count():integer;

  class function Get():FZSubnetBanList;
end;

function Init():boolean; stdcall;

implementation
uses CommonHelper, SysUtils, StrUtils;

var
  _instance:FZSubnetBanList;

{ FZSubnetBanList }

function FZSubnetBanList.CheckForBan(ip: ip_address): boolean;
var
  i1, i2:cardinal;
  i:integer;
  mask:cardinal;
begin
  result:=false;
  EnterCriticalSection(_lock);
  try
    i1:=ConvertIpToCardinal(ip);
    for i:=0 to _list.Count-1 do begin
      i2:=ConvertIpToCardinal((_list[i] as FZBannedSubnet).ip);
      mask:=(_list[i] as FZBannedSubnet).mask;
      if (i2 and mask) = (i1 and mask) then begin
        result:=true;
        break;
      end;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

function FZSubnetBanList.ConvertIpToCardinal(ip: ip_address): cardinal;
begin
  result:=ip.a4+ip.a3*(1 shl 8)+ip.a2*(1 shl 16)+ip.a1*(1 shl 24);
end;

function FZSubnetBanList.Count: integer;
begin
  EnterCriticalSection(_lock);
  result:=_list.Count;
  LeaveCriticalSection(_lock);
end;

constructor FZSubnetBanList.Create;
begin
  InitializeCriticalSection(_lock);
  _list:=TObjectList.Create();
end;

destructor FZSubnetBanList.Destroy;
begin
  _freeList();
  _list.Free();
  DeleteCriticalSection(_lock);
  inherited;
end;

class function FZSubnetBanList.Get: FZSubnetBanList;
begin
//  if _instance=nil then begin
//    _instance:=FZSubnetBanList.Create();
//    _instance.ReloadDefaultFile();
//  end;
  result:=_instance;
end;

procedure FZSubnetBanList.Reload(fname: string);
var
  f:textfile;
  ln, ln2:string;
  ips, reason:string;
  ip:FZBannedSubnet;
  p:integer;
begin
  EnterCriticalSection(_lock);
  try
    _freeList();
    assignfile(f, fname);
    try
      reset(f);
    except
      FZLogMgr.Get.Write('Cannot open file '+ fname+' for reading. Check existance!', FZ_LOG_ERROR);
      exit;
    end;
    while not eof(f) do begin
      readln(f, ln);
      p:=pos(';', ln);
      if p>0 then begin
        ln:=leftstr(ln, p-1);
      end;

      ln2:=ln;
      if FZCommonHelper.GetNextParam(ln, ips, '=') and FZCommonHelper.GetLastParam(ln2, reason, '=') then begin
        ip:=FZBannedSubnet.Create(ips, reason);

        if ip.valid then
          _list.Add(ip)
        else
          ip.Free;
      end;
    end;
    closefile(f);
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZSubnetBanList.ReloadDefaultFile;
begin
  FZLogMgr.Get.Write('Loading banned subnets...', FZ_LOG_INFO);
  self.Reload('banned_networks.ini');
  FZLogMgr.Get.Write('Found '+inttostr(self._list.Count)+' banned subnet(s)', FZ_LOG_INFO);
end;

procedure FZSubnetBanList._freeList;
begin
  _list.Clear;
end;

{ FZBannedSubnet }

constructor FZBannedSubnet.Create(ip, reason: string);
var
  tmp:string;
begin
  self.reason:=reason;
  self.valid:=false;
  if not FZCommonHelper.GetLastParam(ip, tmp, '/') then begin
    exit;
  end;

  self.mask:=strtointdef(trim(tmp), 32);
  if self.mask >= 32 then begin
    self.mask:=$FFFFFFFF;
  end else begin
    self.mask:= $FFFFFFFF- (1 shl (32-self.mask))+1;
  end;

  if not FZCommonHelper.GetLastParam(ip, tmp, '.') then begin
    exit;
  end;
  self.ip.a4:=strtointdef(trim(tmp), 0);

  if not FZCommonHelper.GetLastParam(ip, tmp, '.') then begin
    exit;
  end;
  self.ip.a3:=strtointdef(trim(tmp), 0);

  if not FZCommonHelper.GetLastParam(ip, tmp, '.') then begin
    exit;
  end;
  self.ip.a2:=strtointdef(trim(tmp), 0);
  self.ip.a1:=strtointdef(trim(ip), 0);

  self.valid:=true;
end;

destructor FZBannedSubnet.Destroy;
begin
  inherited;
end;

function Init():boolean; stdcall;
begin
  _instance:=FZSubnetBanList.Create;
  _instance.ReloadDefaultFile();  
  result:=true;
end;

end.
