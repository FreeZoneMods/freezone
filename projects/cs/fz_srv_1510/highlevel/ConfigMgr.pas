unit ConfigMgr;
{$mode delphi}

interface
uses ConfigBase;
type FZConfigMgr=class(FZConfigBase)
private
  {%H-}constructor Create();
public
  procedure Reload();
  class function Get(): FZConfigMgr;

  destructor Destroy(); override;
end;

function Init():boolean; stdcall;

implementation
uses sysutils, xr_debug;
var
   _instance:FZConfigMgr = nil;

constructor FZConfigMgr.Create();
begin
  inherited;
  Load('fz_config.ini');
end;

destructor FZConfigMgr.Destroy();
begin
  _instance:=nil;
  inherited;
end;

class function FZConfigMgr.Get(): FZConfigMgr;
begin
  R_ASSERT(_instance<>nil, 'Config mgr is not created yet');
  result:=_instance;
end;

procedure FZConfigMgr.Reload();
begin
  inherited;
end;

function Init():boolean; stdcall;
begin
  R_ASSERT(_instance=nil, 'Config manager module is already initialized');
  _instance:=FZConfigMgr.Create();
  result:=true;
end;

end.
