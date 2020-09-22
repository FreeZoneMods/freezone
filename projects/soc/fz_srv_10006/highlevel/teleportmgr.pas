unit TeleportMgr;

{$mode delphi}

interface
uses ConfigBase, MatVectors;

type

  FZTeleportPointType = (FZ_TELEPORT_POINT_SPHERE, FZ_TELEPORT_POINT_BOX, FZ_TELEPORT_POINT_COUNT);
  FZTeleportPoint = packed record
    shape_type:FZTeleportPointType;
    center:FVector3;
    radius:single;
    bbvector:FVector3;
  end;

  { FZTeleport }

  FZTeleport = class
  private
    _in:FZTeleportPoint;
    _out:FZTeleportPoint;
    _out_dir:FVector3;
    _preserve_dir:boolean;
    _valid:boolean;

    function _ReadTeleportPoint(cfg:FZConfigBase; section:string; prefix:string; var point:FZTeleportPoint):boolean;
  public
    constructor Create(cfg:FZConfigBase; section_name:string); overload;
    destructor Destroy(); override;

    function IsPointInTeleport(point:pFVector3): boolean;
    function GenerateOutPoint():FVector3;
    function GenerateOutDirection(old_dir:pFVector3):FVector3;
    function ShapeTypeFromInt(st:integer):FZTeleportPointType;
    function IsValid():boolean;
  end;

  { FZTeleportMgr }
  FZTeleportMgr = class
  private
    _cfg:FZConfigBase;
    _teleports:array of FZTeleport;
    _mapname, _mapver:string;

    procedure _UpdateTeleportsForCurrentMap();
    procedure _ClearTeleports();
  public
    procedure Reload();
    class function Get():FZTeleportMgr;
    procedure OnMapUpdate(mapname:string; mapver:string);

    function IsTeleportingNeeded(current_point:pFVector3; current_dir:PFVector3; out_point:pFVector3; out_dir:pFVector3):boolean;

    constructor Create();
    destructor Destroy(); override;
  end;


function Init():boolean; stdcall;
function Free():boolean; stdcall;

implementation
uses xr_debug, sysutils, LogMgr;

var
  _instance:FZTeleportMgr = nil;

{ FZTeleport }

function FZTeleport.ShapeTypeFromInt(st: integer): FZTeleportPointType;
begin
  case st of
    0: result:=FZ_TELEPORT_POINT_SPHERE;
    1: result:=FZ_TELEPORT_POINT_BOX;
  else
    result:=FZ_TELEPORT_POINT_COUNT;
  end;
end;

function FZTeleport.IsValid(): boolean;
begin
  result:=_valid;
end;

function FZTeleport._ReadTeleportPoint(cfg: FZConfigBase; section: string; prefix: string; var point: FZTeleportPoint): boolean;
var
  param_name:string;
  shape_type:integer;
begin
  result:=false;

  param_name:=prefix+'shape_type';
  shape_type:=cfg.GetInt(param_name, 0, section);
  point.shape_type:=ShapeTypeFromInt(shape_type);
  if point.shape_type = FZ_TELEPORT_POINT_COUNT then begin
    FZLogMgr.Get().Write('Error while reading '+param_name+' from section '+section, FZ_LOG_ERROR);
    exit;
  end;

  param_name:=prefix+'center_pos';
  if not StringToFVector3(cfg.GetString(param_name, '', section), point.center) then begin
    FZLogMgr.Get().Write('Error while reading '+param_name+' from section '+section, FZ_LOG_ERROR);
    exit;
  end;

  case point.shape_type of
    FZ_TELEPORT_POINT_SPHERE: begin
      param_name:=prefix+'radius';
      point.radius:=cfg.GetFloat(param_name, -1, section);
      if point.radius <= 0 then begin;
        FZLogMgr.Get().Write('Error while reading '+param_name+' from section '+section, FZ_LOG_ERROR);
        exit;
      end;
    end;

    FZ_TELEPORT_POINT_BOX: begin
      param_name:=prefix+'vector';
      if not StringToFVector3(cfg.GetString(param_name, '', section), point.bbvector) or (point.bbvector.x <=0) or (point.bbvector.y <=0) or (point.bbvector.z <=0) then begin
        FZLogMgr.Get().Write('Error while reading '+param_name+' from section '+section, FZ_LOG_ERROR);
        exit;
      end;
    end;
  else
    R_ASSERT(false, 'unimplemented point type '+inttostr(shape_type), 'FZTeleport._ReadTeleportPoint');
  end;

  result:=true;
end;

constructor FZTeleport.Create(cfg: FZConfigBase; section_name: string);
const
  OUT_DIR_KEY:string = 'out_direction';
begin
  _valid:=_ReadTeleportPoint(cfg, section_name, 'in_', _in) and _ReadTeleportPoint(cfg, section_name, 'out_', _out);
  v_zero(@_out_dir);

  if cfg.IsKeyExist(section_name, OUT_DIR_KEY) then begin
    StringToFVector3(cfg.GetString(OUT_DIR_KEY, '', section_name), _out_dir);
    _preserve_dir:=false;
  end else begin
    _preserve_dir:=true;
  end;
end;

destructor FZTeleport.Destroy();
begin
  inherited Destroy();
end;

function FZTeleport.IsPointInTeleport(point: pFVector3): boolean;
var
  tmp:FVector3;
begin
  result:=false;
  if not _valid then exit;

  R_ASSERT(point <> nil, 'point is nil', 'FZTeleport.IsPointInTeleport');
  tmp:=FVector3_copyfromengine(point);

  case _in.shape_type of
    FZ_TELEPORT_POINT_SPHERE: begin
      v_sub(@tmp, @_in.center);
      result:= (v_length(@tmp) < _in.radius);
    end;

    FZ_TELEPORT_POINT_BOX: begin
      v_sub(@tmp, @_in.center);
      result:= (abs(tmp.x) < _in.bbvector.x) and
               (abs(tmp.y) < _in.bbvector.y) and
               (abs(tmp.z) < _in.bbvector.z);
    end;
  else
    R_ASSERT(false, 'unimplemented point type', 'FZTeleport.IsPointInTeleport');
  end;
end;

function FZTeleport.GenerateOutPoint(): FVector3;
begin
  v_zero(@result);
  if not _valid then exit;

  case _in.shape_type of
    FZ_TELEPORT_POINT_SPHERE: begin
      result.x:=random()*2 - 1;
      result.y:=random()*2 - 1;
      result.z:=random()*2 - 1;
      v_normalize(@result);
      v_mul(@result, random() * _out.radius);
      v_add(@result, @_out.center);
    end;

    FZ_TELEPORT_POINT_BOX: begin
      result.x:=(random()*2 - 1) * _out.bbvector.x;
      result.y:=(random()*2 - 1) * _out.bbvector.y;
      result.z:=(random()*2 - 1) * _out.bbvector.z;
      v_add(@result, @_out.center);
    end;
  else
    R_ASSERT(false, 'unimplemented point type', 'FZTeleport.GenerateOutPoint');
  end;
end;

function FZTeleport.GenerateOutDirection(old_dir: pFVector3): FVector3;
begin
  if _preserve_dir then begin
    result:=old_dir^;
  end else begin
    result:=_out_dir;
  end;
end;

{ FZTeleportMgr }

procedure FZTeleportMgr._UpdateTeleportsForCurrentMap();
var
  teleports_count, i:integer;
  map_teleport_prefix:string;
  invalids:integer;

begin
  _ClearTeleports();
  if (length(_mapname) = 0) or (length(_mapver) = 0) then exit;

  map_teleport_prefix:=_mapname+'_'+_mapver+'_teleport_';
  //Смотрим, сколько у нас телепортов для этого уровня
  teleports_count:=0;
  while _cfg.IsSectionExist(map_teleport_prefix+inttostr(teleports_count)) do begin
    teleports_count:=teleports_count+1;
  end;

  invalids:=0;
  setlength(_teleports, teleports_count);
  for i:=0 to teleports_count-1 do begin;
    _teleports[i]:=FZTeleport.Create(_cfg, map_teleport_prefix+inttostr(i));
    if not _teleports[i].IsValid() then begin
      invalids:=invalids+1;
    end;
  end;

  if teleports_count > 0 then begin
    FZLogMgr.Get.Write('Successfully loaded '+inttostr(teleports_count-invalids)+' teleport(s)', FZ_LOG_INFO);
  end;

  if invalids > 0 then begin
    FZLogMgr.Get.Write('Error while loading '+inttostr(invalids)+' teleport(s)', FZ_LOG_ERROR);
  end;
end;

procedure FZTeleportMgr._ClearTeleports();
var
  i:integer;
begin
  for i:=0 to length(_teleports)-1 do begin
    _teleports[i].Free;
  end;
  SetLength(_teleports, 0);
end;

procedure FZTeleportMgr.Reload();
begin
  _cfg.Load('fz_teleports.ini');
  _UpdateTeleportsForCurrentMap()
end;

class function FZTeleportMgr.Get():FZTeleportMgr;
begin
  result:=_instance;
end;

procedure FZTeleportMgr.OnMapUpdate(mapname: string; mapver: string);
begin
  _mapname:=mapname;
  _mapver:=mapver;
  _UpdateTeleportsForCurrentMap();
end;

function FZTeleportMgr.IsTeleportingNeeded(current_point: pFVector3; current_dir:pFVector3; out_point: pFVector3; out_dir:pFVector3): boolean;
var
  i:integer;
begin
  result:=false;
  R_ASSERT(current_point<>nil, 'current_point is nil', 'FZTeleportMgr.IsTeleportingNeeded');
  R_ASSERT(current_dir<>nil, 'current_dir is nil', 'FZTeleportMgr.IsTeleportingNeeded');
  R_ASSERT(out_point<>nil, 'out_point is nil', 'FZTeleportMgr.IsTeleportingNeeded');
  R_ASSERT(out_dir<>nil, 'out_dir is nil', 'FZTeleportMgr.IsTeleportingNeeded');

  for i:=0 to length(_teleports)-1 do begin
    if _teleports[i].IsPointInTeleport(current_point) then begin
      out_point^:=_teleports[i].GenerateOutPoint();
      out_dir^:=_teleports[i].GenerateOutDirection(current_dir);
      result:=true;
      break;
    end;
  end;
end;

constructor FZTeleportMgr.Create();
begin
  inherited;
  _cfg:=FZConfigBase.Create();
  setlength(_teleports, 0);
  _mapname:='';
  _mapver:='';
  Reload();
end;

destructor FZTeleportMgr.Destroy();
begin
  _ClearTeleports();
  _cfg.Free();
  inherited Destroy();
end;

function Init:boolean; stdcall;
begin
  _instance:=FZTeleportMgr.Create();
  result:=true;
end;

function Free:boolean; stdcall;
begin
  _instance.Free();
  _instance:=nil;
  result:=true;
end;

end.

