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
uses sysutils;
var
   _instance:FZConfigMgr;
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
  if _instance=nil then begin
    _instance:=FZConfigMgr.Create();
  end;
  result:=_instance;
end;

procedure FZConfigMgr.Reload();
begin
  inherited;
end;

function Init():boolean; stdcall;
begin
  _instance:=nil;
  result:=true;
end;

end.
