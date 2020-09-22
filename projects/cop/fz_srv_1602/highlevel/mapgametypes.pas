unit MapGametypes;

{$mode delphi}

interface

uses
  ConfigBase;

type

  { FZMapGametypesMgr }

  FZMapGametypesMgr = class
  protected
    _cfg:FZConfigBase;
  public
    constructor Create();
    destructor Destroy(); override;
    function IsMapBanned(map:string; ver:string):boolean;
    function GetDefaultGameType(map:string; ver:string):string;

    procedure Reload;

    class function Get():FZMapGametypesMgr;
  end;

function Init:boolean; stdcall;
function Free:boolean; stdcall;

implementation

var
  _instance:FZMapGametypesMgr;

{ FZMapGametypesMgr }

constructor FZMapGametypesMgr.Create();
begin
  inherited;
  _cfg:=FZConfigBase.Create();
  Reload();
end;

destructor FZMapGametypesMgr.Destroy();
begin
  _cfg.Free;
  inherited Destroy;
end;

function FZMapGametypesMgr.IsMapBanned(map: string; ver: string): boolean;
begin
  result:=(_cfg.GetString(map+'_'+ver, '') = 'banned');
end;

function FZMapGametypesMgr.GetDefaultGameType(map: string; ver: string): string;
begin
  if IsMapBanned(map, ver) then begin
    result:='';
  end else begin
    result:=_cfg.GetString(map+'_'+ver, '');
  end;
end;

procedure FZMapGametypesMgr.Reload;
begin
  _cfg.Load('fz_map_modes.ini');
end;

class function FZMapGametypesMgr.Get(): FZMapGametypesMgr;
begin
  result:=_instance;
end;

function Init:boolean; stdcall;
begin
  _instance:=FZMapGametypesMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

end.

