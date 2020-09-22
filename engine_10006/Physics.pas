unit Physics;
{$mode delphi}
{$I _pathes.inc}

interface

uses xrstrings, MatVectors;

type
CPHCommander = packed record
//todo:fill;
end;
pCPHCommander=^CPHCommander;

CPhysicsShellHolder = packed record
  _unknown1:array[0..171] of byte;
  NameSection:shared_str; //offset: 0xAC
  //todo:finish
end;
pCPhysicsShellHolder=^CPhysicsShellHolder;

SPHNetState = packed record
	linear_vel:Fvector3;
  angular_vel:Fvector3;
  force:Fvector3;
  torque:Fvector3;
  position:Fvector3;
  previous_position:Fvector3;
  quaternion:FQuaternion;
  previous_quaternion:FQuaternion;
end;

implementation

end.
