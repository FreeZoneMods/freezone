unit Collidable;

{$mode delphi}
{$I _pathes.inc}

interface
type
ICollidable = packed record
  vftable:pointer;
  model:pointer; {ICollisionForm*}
end;

implementation

end.

