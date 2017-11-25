unit Objects;
{$mode delphi}
interface
uses vector, Synchro, CDB, MatVectors;

function Init():boolean; stdcall;
type
CObject = packed record
  //todo:fill;
end;
pCObject=^CObject;

CObjectList = packed record
  map_NETID:array[0..65534] of pCObject;
  destroy_queue:xr_vector;
  objects_active:xr_vector;
  objects_sleeping:xr_vector;
  m_crows:array[0..1] of xr_vector;
  m_owner_thread_id:cardinal;
  m_relcase_callbacks:xr_vector
end;

CObjectSpace = packed record
  Lock:xrCriticalSection;
  m_static:CDB__MODEL;
  m_BoundingVolume:FBox3;
  xrc:xrXRC;
  r_temp:collide__rq_results;
  r_spatial:xr_vector;
end;

implementation

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
