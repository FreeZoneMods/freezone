unit CDB;
{$mode delphi}
interface
uses Synchro, Opcode, MatVectors, vector;

type
CDB__TRI = packed record
  //todo:fill;
end;
pCDB__TRI = ^CDB__TRI;


CDB__MODEL = packed record
  cs:xrCriticalSection;
  tree:pOpcode__OPCODE_Model;
  status:cardinal; // 0=ready, 1=init, 2=building
  tris:pCDB__TRI;
  tris_count:integer;
  verts:pFVector3;
  verts_count:integer;
end;

type CDB_COLLIDER = packed record
  ray_mode:cardinal;
  box_mode:cardinal;
  fructum_mode:cardinal;
  rd:xr_vector;
end;

xrXRC = packed record
  CL:CDB_COLLIDER;
end;

collide__rq_results = packed record
  results:xr_vector;
end;

implementation

end.
