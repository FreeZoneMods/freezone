unit HitMgr;

{$mode delphi}

interface
uses Hits, Classes, Weapons, Clients, IniFiles;

type
  FZHitCheckResult = (FZ_HIT_OK, FZ_HIT_IGNORE, FZ_HIT_BAD);

  FZHitRestriction = record
    hit_type:cardinal;
    max_hit:single;
    max_impulse:single;
    max_ap:single;
  end;
  pFZHitRestriction = ^FZHitRestriction;


  { FZHitMgr }

  FZHitMgr = class
    _cached_ammo_restrictions: array of FZHitRestriction;
    _cached_ammo_stringhashes:TStringHash;

    function _GetRestrictionForAmmo(section:PAnsiChar):pFZHitRestriction;
    function _DetermineMaxAmmoRestrictions(pwpn:pCWeapon; hit:pSHit; var restrictions:FZHitRestriction):boolean;
    function _IsHitSatisfyRestrictions(hit:pSHit; restrictions:pFZHitRestriction):boolean;
    function _ExtractWeaponFromHit(hit:pSHit):pCWeapon;

    function _CheckHitLimitsUsingEngineInfo(hit:pSHit; pwpn:pCWeapon):FZHitCheckResult;

  public
    procedure Reload();
    class function Get():FZHitMgr;

    function CheckHit(hit:pSHit; hitter:pxrClientData; victim:pxrClientData):FZHitCheckResult;

    constructor Create();
    destructor Destroy(); override;
  end;


function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses BaseDefs, Objects, Level, LogMgr, sysutils, dynamic_caster, Vector, xrstrings, xr_configs, CommonHelper, ConfigCache;

var
  _instance:FZHitMgr = nil;

function FZHitMgr._GetRestrictionForAmmo(section: PAnsiChar): pFZHitRestriction;
var
  idx:integer;
const
  k_gravity:single = 1.005;
begin
  idx:=_cached_ammo_stringhashes.ValueOf(section);
  if idx<0 then begin
    idx:=length(_cached_ammo_restrictions);
    setlength(_cached_ammo_restrictions, idx+1);
    //Теперь нужно учесть тот факт, что когда цель находится ниже стрелка, скорость пули будет увеличиваться
    //А так как урон определяется отношением скорости пули во время попадания к ее начальной скорости
    //То при низком (или нулевом) коэффициенте сопротивления воздуха мы получим повышенный хит!
    //Для компенсации - надо бы смотреть худший случай: насколько пуля прибавит скорости при полете вертикально вниз на максимальную дальность полета
    //И высчитывать отношение ее к начальной, после чего домножать на этот коэффициент все остальные параметры
    //Но, так как это требует вычитывать кучу всего - просто предположим, что более, чем на 0.5% это никакого влияния не окажет
    _cached_ammo_restrictions[idx].max_hit:=game_ini_read_float_def(section, 'k_hit', -1) * k_gravity;
    _cached_ammo_restrictions[idx].max_ap:=game_ini_read_float_def(section, 'k_ap', -1);
    _cached_ammo_restrictions[idx].max_impulse:=game_ini_read_float_def(section, 'k_impulse', -1) * k_gravity;
  end;
  result:=@_cached_ammo_restrictions[idx];
end;

function FZHitMgr._DetermineMaxAmmoRestrictions(pwpn: pCWeapon; hit:pSHit; var restrictions: FZHitRestriction): boolean;
var
  pammo_sect:pshared_str;
  sect_pchar:PAnsiChar;
  i:integer;
  cached_restr:pFZHitRestriction;
const
  EPS:single = 0.0001;
begin
  result:=false;

  //Главная проблема - хит прилетает уже ПОСЛЕ того, как патрон был отстрелян и уничтожен
  //Поэтому в общем случае узнать тип патрона, который стрелял, нельзя
  //Для обычного оружия - это можно попробовать сделать через DefaultCartridge
  //Но для дробовиков такой трюк не пройдет :(
  //кроме того, проблема в том, что разные типы патронов могут иметь одно и то же значение k_ap,
  //и проверка k_ap только DefaultCartridge не может дать однозначной уверенности в том, что стрелял именно он

  for i:=0 to items_count_in_vector(@pwpn.m_ammoTypes, sizeof(shared_str))-1 do begin
    pammo_sect:=get_item_from_vector(@pwpn.m_ammoTypes, i, sizeof(shared_str));
    sect_pchar:=get_string_value(pammo_sect);
    cached_restr:=_GetRestrictionForAmmo(sect_pchar);

    if abs(cached_restr.max_ap - hit.ap) < EPS then begin
      //Подходящий кандидат найден.
      if not result then begin
        //Это первая такая секция, скопируем цифры полностью и выставим флаг найденного патрона
        restrictions:=cached_restr^;
        result:=true;
      end else begin
        //Еще одна секция с таким AP, увеличим максимальные значения при необходимости
        if restrictions.max_hit < cached_restr.max_hit then restrictions.max_hit := cached_restr.max_hit;
        if restrictions.max_impulse < cached_restr.max_impulse then restrictions.max_impulse := cached_restr.max_impulse;
      end;
    end;
  end;
end;

function FZHitMgr._IsHitSatisfyRestrictions(hit: pSHit; restrictions: pFZHitRestriction): boolean;
const
  EPS:single = 0.0001;
begin
  if FZLogMgr.Get.IsSeverityLogged(FZ_LOG_DBG) then begin
    FZLogMgr.Get.Write('type: '+inttostr(hit.hit_type)+'('+inttostr(restrictions.hit_type)+')', FZ_LOG_DBG);
    FZLogMgr.Get.Write('ap: '+FZCommonHelper.FloatToString(hit.ap, 8, 4)+'('+FZCommonHelper.FloatToString(restrictions.max_ap, 8, 4)+')', FZ_LOG_DBG);
    FZLogMgr.Get.Write('power: '+FZCommonHelper.FloatToString(hit.power, 8, 4)+'('+FZCommonHelper.FloatToString(restrictions.max_hit, 8, 4)+')', FZ_LOG_DBG);
    FZLogMgr.Get.Write('impulse: '+FZCommonHelper.FloatToString(hit.impulse, 8, 4)+'('+FZCommonHelper.FloatToString(restrictions.max_impulse, 8, 4)+')', FZ_LOG_DBG);
  end;

  result:= (hit.hit_type = restrictions.hit_type) and
           (abs(hit.ap - restrictions.max_ap) < EPS) and
           (hit.impulse <= restrictions.max_impulse+EPS) and
           (hit.power <= restrictions.max_hit+EPS);
end;

function FZHitMgr._ExtractWeaponFromHit(hit: pSHit): pCWeapon;
var
  pobj:pCObject;
begin
  result:=nil;

  pobj:=ObjectById(@GetLevel.base_IGame_Level, hit.weaponID);
  if pobj = nil then begin
    FZLogMgr.Get.Write('FZHitMgr._ExtractWeaponFromHit: Cannot get weapon object by ID='+inttostr(hit.weaponID), FZ_LOG_DBG);
    exit;
  end;

  result:=dynamic_cast(pobj, 0, xrGame+RTTI_CObject, xrGame+RTTI_CWeapon, false);
  if result = nil then begin
    FZLogMgr.Get.Write('FZHitMgr._ExtractWeaponFromHit: weapon is not an instance of CWeapon '+inttostr(hit.weaponID), FZ_LOG_DBG);
    exit;
  end;
end;

function FZHitMgr._CheckHitLimitsUsingEngineInfo(hit: pSHit; pwpn: pCWeapon): FZHitCheckResult;
var
  pknife:pCWeaponKnife;
  restrictions:FZHitRestriction;
begin
  result:=FZ_HIT_BAD;

  pknife:=dynamic_cast(pwpn, 0, xrGame+RTTI_CWeapon, xrGame+RTTI_CWeaponKnife, false);
  if pknife <> nil then begin
    restrictions.max_ap:=0;
    if hit.hit_type = pknife.m_eHitType_1 then restrictions.hit_type:=pknife.m_eHitType_1 else restrictions.hit_type:=pknife.m_eHitType_2;
    if pknife.fHitImpulse_1 > pknife.fHitImpulse_2 then restrictions.max_impulse:=pknife.fHitImpulse_1 else restrictions.max_impulse:=pknife.fHitImpulse_2;
    if pknife.fvHitPower_1[difficulty_gdMaster] > pknife.fvHitPower_2[difficulty_gdMaster] then restrictions.max_hit:=pknife.fvHitPower_1[difficulty_gdMaster] else restrictions.max_hit:=pknife.fvHitPower_2[difficulty_gdMaster];
  end else if dynamic_cast(pwpn, 0, xrGame+RTTI_CWeapon, xrGame+RTTI_CWeaponMagazined, false) <> nil then begin
    //Сначала найдем коэффициенты для подходящего патрона (или максимум, если несколько патронов сразу подходят)
    if not _DetermineMaxAmmoRestrictions(pwpn, hit, restrictions) then begin
      FZLogMgr.Get.Write('FZHitMgr._CheckHitUsingEngineInfo: cannot find ammo with k_ap='+FZCommonHelper.FloatToString(hit.ap), FZ_LOG_DBG);
      exit;
    end;
    restrictions.hit_type:=ALife__eHitTypeFireWound;
    //Максимально возможные коэффициенты патрона вычитаны, теперь домножим на текущие оружия
    restrictions.max_impulse:=restrictions.max_impulse * pwpn.base_CShootingObject.fHitImpulse;
    restrictions.max_hit:=restrictions.max_hit * pwpn.base_CShootingObject.fvHitPower[difficulty_gdMaster];
  end else begin
    FZLogMgr.Get.Write('FZHitMgr._CheckHitLimitsUsingEngineInfo: shot from invalid weapon '+inttostr(hit.weaponID), FZ_LOG_DBG);
    exit;
  end;

  //И сравним с полученными
  if _IsHitSatisfyRestrictions(hit, @restrictions) then result:=FZ_HIT_OK;
end;

procedure FZHitMgr.Reload();
begin
  //Nothing to reload now, reserver for future use
end;

class function FZHitMgr.Get():FZHitMgr;
begin
  result:=_instance;
end;

function FZHitMgr.CheckHit(hit: pSHit; hitter: pxrClientData; victim: pxrClientData): FZHitCheckResult;
var
  pwpn:pCWeapon;
  check_lvl:cardinal;
begin
  result:=FZ_HIT_OK;

  check_lvl:=FZConfigCache.Get.GetDataCopy().hit_analysis_level;
  if check_lvl = 0 then begin
    result:=FZ_HIT_OK;
    exit;
  end;

  pwpn:=_ExtractWeaponFromHit(hit);
  if (pwpn=nil) then begin
    if (victim<>hitter) then begin
      result:=FZ_HIT_IGNORE;
    end else begin
      result:=FZ_HIT_OK;
    end;
    exit;
  end;

  //анализ хита - с первого взгляда кажется, что имеет смысл только для хитов от одного игрока другому
  //Однако некорректные хиты по физическим объектам могут причинить нам проблемы, так что лучше их обрабатывать тоже
  //Так что пусть решает админ; если chick_lvl=1, проверяем только хиты от одного игрока к другому; если больше - все хиты
  if ((check_lvl) > 1) or ((check_lvl = 1) and (hitter<>nil) and (victim<>nil) and (victim<>hitter) and (victim.ps<>nil) and (victim.ps.flags__ and GAME_PLAYER_FLAG_VERY_VERY_DEAD = 0)) then begin
    result:=_CheckHitLimitsUsingEngineInfo(hit, pwpn);
  end;

  //TODO: анализ статистики настрела
end;

constructor FZHitMgr.Create();
begin
  inherited;
  _cached_ammo_stringhashes:=TStringHash.Create;
  setlength(_cached_ammo_restrictions, 0);
  Reload();
end;

destructor FZHitMgr.Destroy();
begin
  setlength(_cached_ammo_restrictions, 0);
  _cached_ammo_stringhashes.Free();
  inherited Destroy();
end;

function Init:boolean; stdcall;
begin
  _instance:=FZHitMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

