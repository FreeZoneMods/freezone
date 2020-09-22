unit PlayersConnectionLog;

{$mode delphi}

interface
uses syncobjs, Packets;

type
  FZPlayersConnectionItem = record
    ip:ip_address;
    time:cardinal;
    valid:boolean;
  end;

  { FZPlayersConnectionMgr }

  FZPlayersConnectionMgr = class
  protected
    _arr:array [0..99] of FZPlayersConnectionItem;
    _curptr:integer;
    _cs:TCriticalSection;

    function CountOfConnectionsForTime(ip:ip_address; time_ms:cardinal):cardinal;
    procedure RegisterConnection(ip:ip_address);
  public
    constructor Create();
    destructor Destroy; override;
    class function Get():FZPlayersConnectionMgr;
    function ProcessNewConnection(ip:ip_address):boolean;
    procedure Reset();
  end;

  function Init():boolean; stdcall;

implementation
uses CommonHelper, ConfigCache, xr_debug;

var
  _instance:FZPlayersConnectionMgr = nil;

{ FZPlayersConnectionMgr }

function FZPlayersConnectionMgr.CountOfConnectionsForTime(ip: ip_address; time_ms: cardinal): cardinal;
var
  i:integer;
begin
  result:=0;
  for i:=0 to length(_arr)-1 do begin
    if _arr[i].valid and ip_address_equal(_arr[i].ip, ip) and (FZCommonHelper.GetTimeDeltaSafe(_arr[i].time) < time_ms) then begin
      result:=result+1;
    end;
  end;
end;

procedure FZPlayersConnectionMgr.RegisterConnection(ip: ip_address);
begin
  _arr[_curptr].time:=FZCommonHelper.GetGameTickCount();
  _arr[_curptr].ip:=ip;
  _arr[_curptr].valid:=true;

  _curptr:=_curptr+1;
  if _curptr >= length(_arr) then begin
    _curptr:=0;
  end;
end;

constructor FZPlayersConnectionMgr.Create;
begin
  _cs:=TCriticalSection.Create();
  Reset();
end;

destructor FZPlayersConnectionMgr.Destroy;
begin
  _cs.Free;
  inherited Destroy;
end;

class function FZPlayersConnectionMgr.Get: FZPlayersConnectionMgr;
begin
  R_ASSERT(_instance<>nil, 'Cannot get connections manager - instance is nil');
  result:=_instance;
end;

function FZPlayersConnectionMgr.ProcessNewConnection(ip: ip_address): boolean;
var
  dat:FZCacheData;
begin
  dat:=FZConfigCache.Get().GetDataCopy();
  _cs.Enter;
  result:=false;
  try
    if CountOfConnectionsForTime(ip, dat.ip_checker_time_delta) < dat.ip_checker_max_connections_per_delta_count then begin
      RegisterConnection(ip);
      result:=true;
    end;
  finally
    _cs.Leave;
  end;
end;

procedure FZPlayersConnectionMgr.Reset;
var
  i:integer;
begin
  _cs.Enter;
  try
    for i:=0 to length(_arr)-1 do begin
      _arr[i].valid:=false;
    end;
    _curptr:=0;
  finally
    _cs.Leave;
  end;
end;

function Init():boolean; stdcall;
begin
  R_ASSERT(_instance=nil, 'PlayersConnectionLog module is already initialized');
  _instance:=FZPlayersConnectionMgr.Create();
  result:=true;
end;

end.
