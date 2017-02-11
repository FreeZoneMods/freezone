unit PlayerSkins;
{$mode delphi}
interface
uses CSE, Gametypes;

function OnSetPlayerSkin(e:pCSE_Abstract; team:cardinal; skin:cardinal): boolean; stdcall;
function OnActorItemSpawn_ChangeItemSection(game:pgame_sv_mp; actorID:word; N:PChar; Addons:byte):PChar; stdcall;

implementation
uses ConfigMgr, SysUtils, dynamic_caster, BaseDefs, LogMgr, Clients, ConfigCache;

function OnSetPlayerSkin(e:pCSE_Abstract; team:cardinal; skin:cardinal): boolean; stdcall;
var
  vis:string;
  cse_vis_ptr:pCSE_Visual;
  str:string;
begin
  if not FZConfigCache.Get.GetDataCopy.use_skins_change then begin
    result:=false;
    exit;
  end;

  str:='team_'+inttostr(team)+'_skin_'+inttostr(skin);
  vis:=FZConfigMgr.Get.GetString(str, '');

  if length(vis)=0 then begin
    result:= false;
  end else begin
    //FZLogMgr.Get.Write('Set skin: '+vis);
    cse_vis_ptr:=CSE_Abstract__visual.Call([e]).VPointer;
    CSE_Visual__set_visual.Call([cse_vis_ptr, PChar(vis)]);

    result:=true;
  end;

end;

function OnActorItemSpawn_ChangeItemSection(game:pgame_sv_mp; actorID:word; N:PChar; Addons:byte):PChar; stdcall;
var
  param:string;
  change:string;
  ps:pgame_PlayerState;
begin
  result:=N;
  if N=nil then exit;

  if not FZConfigCache.Get.GetDataCopy.use_item_change then exit;

  ps:=virtual_game_sv_GameState__get_eid.Call([game, actorID]).VPointer;
  if ps=nil then exit;
  param:='team_'+inttostr(ps.team)+'_item_'+N;
  change:=FZConfigMgr.Get.GetString(param, '');
  if length(change)>0 then begin
    result:=PChar(change);
  end;
end;

end.
