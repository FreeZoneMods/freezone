unit Spatial;

interface
uses MatVectors;

type

ISpatial = packed record
  vftable:pointer;
  _type:cardinal;
  sphere:Fsphere;
  node_center:FVector3;
  node_radius:single;
  node_ptr:pointer; {ISpatial_NODE*}
  sector:pointer; {IRender_Sector*}
  space:pointer; {ISpatial_DB*}
end;

implementation

end.

