unit Vector;
{$mode delphi}
{$I _pathes.inc}

interface
function Init():boolean; stdcall;

type xr_vector = packed record
  start:pointer;
  last:pointer;
  memory_end:pointer;
end;
pxr_vector = ^xr_vector;

type xr_assotiative_vector = packed record
  base_vector:xr_vector;
end;
pxr_assotiative_vector = ^xr_assotiative_vector;

type xr_map = packed record
  _unknown:array[0..$1F] of Byte;
end;

type assotiative_vector = packed record
  start:pointer;
  last:pointer;
  memory_end:pointer;
  _unknown:pointer;
end;

type xr_deque = packed record
  _unknown:array[0..39] of Byte;
end;


type svector_float_11 = packed record
  _data:array [0..10] of single;
  count:cardinal;
end;

function items_count_in_vector(v:pxr_vector; itemsz:cardinal):integer;
function get_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal):pointer;
procedure remove_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal);

implementation
uses sysutils, xr_debug;

function items_count_in_vector(v:pxr_vector; itemsz:cardinal):integer;
begin
  R_ASSERT(v<>nil, 'Cannot get items count - vector is nil');
  result:=(uintptr(v.last) - uintptr(v.start)) div itemsz;
end;

function get_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal):pointer;
begin
  R_ASSERT(v<>nil, 'Cannot get item - vector is nil');
  R_ASSERT((index>=0) and (index < items_count_in_vector(v, itemsz)), 'Cannot get item from vector - invalid index');
  result:= pointer(uintptr(v.start)+itemsz * cardinal(index));
end;

procedure remove_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal);
var
  pitem:PByte;
  cnt:integer;
  sz_to_copy:cardinal;
begin
  if items_count_in_vector(v, itemsz) = 1 then begin
    v.last:=v.start;
  end else begin
    pitem:=get_item_from_vector(v, index, itemsz);
    cnt:=items_count_in_vector(v, itemsz) - index - 1;
    R_ASSERT(cnt >= 0, 'Cannot remove item from empty vector');
    sz_to_copy:= cardinal(cnt) * itemsz;
    Move(pitem[itemsz], pitem[0], sz_to_copy);
    v.last:=pointer(uintptr(v.last)-itemsz);
  end;
end;

function Init():boolean; stdcall;
begin
 result:=true;
end;


end.
