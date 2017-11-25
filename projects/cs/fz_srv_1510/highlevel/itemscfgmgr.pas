unit ItemsCfgMgr;

{$mode delphi}

interface
uses ConfigBase;

type

  { FZItemCgfMgr }

  FZItemCgfMgr = class
  protected
    _cfg:FZConfigBase;
  public
    constructor Create();
    destructor Destroy(); override;

    function IsActionOnItemNeeded(item_section:string; config_section:string; use_random:boolean):boolean;

    procedure Reload;

    class function Get():FZItemCgfMgr;

    function IsItemNeedToBeRemoved(section:string):boolean;
    function IsItemNeedToBeTransfered(section:string):boolean;
    function IsItemPotentiallyCouldBeTransfered(section:string):boolean;

    function ItemToReplace(src_section:string; team_id:cardinal):string;
    function SkinToReplace(team_id:cardinal; skin_id:cardinal):string;
  end;


  function Init:boolean; stdcall;
implementation
uses sysutils;
var
  _instance:FZItemCgfMgr;

{ FZItemCgfMgr }

constructor FZItemCgfMgr.Create;
begin
  inherited;
  _cfg:=FZConfigBase.Create();
  Reload();
end;

destructor FZItemCgfMgr.Destroy;
begin
  _cfg.Free;
  inherited Destroy;
end;

function FZItemCgfMgr.IsActionOnItemNeeded(item_section: string; config_section: string; use_random:boolean): boolean;
var
  prob:single;
  mode:string;
  blacklist:boolean;
begin
  prob:=_cfg.GetFloat(item_section, 0, config_section);

  if prob < 0 then begin
    prob:=0
  end else if prob > 1 then begin
    prob:=1;
  end;

  mode:=_cfg.GetString('mode', '', config_section);

  blacklist:=(leftstr(mode, 1) = 'b');

  if blacklist then prob:=1-prob;

  if use_random then begin
    result := random < prob;
  end else begin
    result:= prob > 0;
  end;
end;

procedure FZItemCgfMgr.Reload;
begin
  _cfg.Load('fz_items_settings.ini');
end;

class function FZItemCgfMgr.Get: FZItemCgfMgr;
begin
  result:=_instance;
end;

function FZItemCgfMgr.IsItemNeedToBeRemoved(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_remove_after_death',true);
end;

function FZItemCgfMgr.IsItemNeedToBeTransfered(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_transfer_after_death',true);
end;

function FZItemCgfMgr.IsItemPotentiallyCouldBeTransfered(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_transfer_after_death', false);
end;

function FZItemCgfMgr.ItemToReplace(src_section: string; team_id: cardinal): string;
var
  cfg_section_name:string;
begin
  cfg_section_name:='team_'+inttostr(team_id)+'_items_to_replace_in_spawn';
  result:=_cfg.GetString(src_section, '', cfg_section_name);
end;

function FZItemCgfMgr.SkinToReplace(team_id: cardinal; skin_id: cardinal): string;
begin
  result:=_cfg.GetString('skin_'+inttostr(skin_id), '', 'team_'+inttostr(team_id)+'_skin_replacement' );
end;

function Init:boolean; stdcall;
begin
  _instance:=FZItemCgfMgr.Create();
  result:=true;
end;

end.

