unit ItemsCfgMgr;

{$mode delphi}

interface
uses ConfigBase;

type

  { FZItemCfgMgr }

  FZItemCfgMgr = class
  protected
    _cfg:FZConfigBase;
  public
    constructor Create();
    destructor Destroy(); override;

    function IsActionOnItemNeeded(item_section:string; config_section:string; use_random:boolean):boolean;

    procedure Reload;

    class function Get():FZItemCfgMgr;

    function IsItemNeedToBeRemoved(section:string):boolean;
    function IsItemNeedToBeTransfered(section:string):boolean;
    function IsItemPotentiallyCouldBeTransfered(section:string):boolean;

    function ItemToReplace(src_section:string; team_id:cardinal):string;
    function SkinToReplace(team_id:cardinal; skin_id:cardinal):string;

    function IsItemBannedToBuy(section:string):boolean;
  end;

function Init:boolean; stdcall;
function Free:boolean; stdcall;

implementation
uses sysutils;
var
  _instance:FZItemCfgMgr;

{ FZItemCfgMgr }

constructor FZItemCfgMgr.Create;
begin
  inherited;
  _cfg:=FZConfigBase.Create();
  Reload();
end;

destructor FZItemCfgMgr.Destroy;
begin
  _cfg.Free;
  inherited Destroy;
end;

function FZItemCfgMgr.IsActionOnItemNeeded(item_section: string; config_section: string; use_random:boolean): boolean;
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

procedure FZItemCfgMgr.Reload;
begin
  _cfg.Load('fz_items_settings.ini');
end;

class function FZItemCfgMgr.Get: FZItemCfgMgr;
begin
  result:=_instance;
end;

function FZItemCfgMgr.IsItemNeedToBeRemoved(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_remove_after_death',true);
end;

function FZItemCfgMgr.IsItemNeedToBeTransfered(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_transfer_after_death',true);
end;

function FZItemCfgMgr.IsItemPotentiallyCouldBeTransfered(section: string): boolean;
begin
  result:=IsActionOnItemNeeded(section, 'items_to_transfer_after_death', false);
end;

function FZItemCfgMgr.ItemToReplace(src_section: string; team_id: cardinal): string;
var
  cfg_section_name:string;
begin
  cfg_section_name:='team_'+inttostr(team_id)+'_items_to_replace_in_spawn';
  result:=_cfg.GetString(src_section, '', cfg_section_name);
end;

function FZItemCfgMgr.SkinToReplace(team_id: cardinal; skin_id: cardinal): string;
begin
  result:=_cfg.GetString('skin_'+inttostr(skin_id), '', 'team_'+inttostr(team_id)+'_skin_replacement' );
end;

function FZItemCfgMgr.IsItemBannedToBuy(section: string): boolean;
begin
  result:=_cfg.GetBool(section, false, 'banned_shop_items');
end;

function Init:boolean; stdcall;
begin
  _instance:=FZItemCfgMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

