unit Vector;
{$mode delphi}
interface
function Init():boolean; stdcall;

type xr_vector = packed record
  start:pointer;
  last:pointer;
  memory_end:pointer;
end;

type xr_map = packed record
  _unknown:array[0..$1F] of Byte;
end;

type assotiative_vector = packed record
  start:pointer;
  last:pointer;
  memory_end:pointer;
  _unknown:pointer;
end;

type xr_set = packed record
  _unknown:array[0..$17] of Byte;
end;

type xr_deque = packed record
  _unknown:array[0..39] of Byte;
end;


type svector_float_11 = packed record
  _data:array [0..10] of single;
  count:cardinal;
end;

implementation

function Init():boolean; stdcall;
begin
 result:=true;
end;


end.
