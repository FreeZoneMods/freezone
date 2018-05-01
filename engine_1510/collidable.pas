unit Collidable;

{$mode delphi}

interface
type
ICollidable = packed record
  vftable:pointer;
  model:pointer; {ICollisionForm*}
end;

implementation

end.

