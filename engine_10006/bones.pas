unit bones;

{$mode delphi}
{$I _pathes.inc}

interface
uses Vector, MatVectors;

type
SPHBonesData = packed record
  bones_mask:qword;
  root_bone:word;
  unused1:word;
  bones:xr_vector;
  m_min:FVector3;
  m_max:FVector3;
  unused2:cardinal;
end;

function Init():boolean; stdcall;

implementation

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.

