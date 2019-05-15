unit whitehashes;

{$mode delphi}

interface

uses ConfigBase;

type

{ FZHashesMgr }

FZHashesMgr = class
protected
  _cfg:FZConfigBase;
public
  constructor Create();
  destructor Destroy(); override;

  procedure Reload;

  class function Get():FZHashesMgr;

  function IsHashWhitelisted(hash:string):boolean;
end;

function Init:boolean; stdcall;
function Free:boolean; stdcall;

implementation
uses xr_debug;

var
  _instance:FZHashesMgr = nil;

{ FZHashesMgr }

constructor FZHashesMgr.Create();
begin
  inherited;
  _cfg:=FZConfigBase.Create();
  Reload();
end;

destructor FZHashesMgr.Destroy();
begin
  _cfg.Free;
  inherited Destroy;
end;

procedure FZHashesMgr.Reload;
begin
  _cfg.Load('fz_hashes.ini');
end;

class function FZHashesMgr.Get(): FZHashesMgr;
begin
  result:=_instance;
end;

function FZHashesMgr.IsHashWhitelisted(hash: string):boolean;
begin
  result:=_cfg.GetBool(hash, false, 'whitelist');
end;

function Init:boolean; stdcall;
begin
  R_ASSERT(_instance=nil, 'FZHashesMgr module is already inited');
  _instance:=FZHashesMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

