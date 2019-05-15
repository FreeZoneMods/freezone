unit BuyWnd;

{$mode delphi}
{$I _pathes.inc}

interface

uses Vector, xrstrings;

const
  _RANK_COUNT:cardinal = 5;

type
CItemMgr__item = packed record
  slot_idx:byte;
  _unused1:byte;
  _unused2:word;
  cost:array[0..4] of cardinal; //_RANK_COUNT
end;

CItemMgr__m_items_pair = packed record
  first:shared_str;
  second:CItemMgr__item;
end;
pCItemMgr__m_items_pair = ^CItemMgr__m_items_pair;

CItemMgr = packed record
  m_items:xr_assotiative_vector; {CItemMgr__m_items_pair}
end;
pCItemMgr = ^CItemMgr;

CRestrictions = packed record
  m_rank:cardinal;
  m_bInited:byte; {boolean}
  _unused1:byte;
  _unused2:word;
  m_goups:array[0..23] of byte; {xr_map<xr_vector<shared_str> >}
  m_restrictions:array[0..5] of xr_vector; //_RANK_COUNT+1
  m_names:array[0..4] of shared_str; //_RANK_COUNT

end;
pCRestrictions = ^CRestrictions;

function CItemMgr__GetElement(mgr:pCItemMgr; id:integer):pCItemMgr__m_items_pair;
function CItemMgr__GetItemsCount(mgr:pCItemMgr):integer;
function CItemMgr__GetItemIdx(mgr:pCItemMgr; item_section:string):integer;
function CItemMgr__GetItemCost(mgr:pCItemMgr; item_section:string; rank:cardinal):integer;

function GetRankForItem(section:string):cardinal;
function GetItemGroup(section:string):string;
function GetItemGroupMaxCounter(groupname:string; rank:cardinal):cardinal;

function Init():boolean;

implementation
uses basedefs, srcCalls, xr_debug;

var
  g_mp_restrictions:pCRestrictions;
  CRestrictions__InitGroups:srcECXCallFunction;
  CRestrictions__GetItemGroup:srcECXCallFunctionWEBXEDIArg;
  CRestrictions__GetGroupCount:srcECXCallFunctionWEDXArg;
  get_rank:srcCdeclFunction;

function CItemMgr__GetItemCost(mgr:pCItemMgr; item_section:string; rank:cardinal):integer;
var
  item:pCItemMgr__m_items_pair;
begin
  R_ASSERT(mgr<>nil, 'Cannot get cost for the item - CItemMgr is nil');

  result:=-1;

  item:=mgr.m_items.base_vector.start;
  while item < mgr.m_items.base_vector.last do begin
    if item_section = get_string_value(@item.first) then begin
      if rank >= _RANK_COUNT then rank:=_RANK_COUNT-1;
      result:=item.second.cost[rank];
      break;
    end;
    item:=pointer(uintptr(item)+sizeof(CItemMgr__m_items_pair));
  end;
end;

function CItemMgr__GetItemIdx(mgr:pCItemMgr; item_section:string):integer;
var
  i:integer;
  item:pCItemMgr__m_items_pair;
begin
  result:=-1;
  for i:=0 to CItemMgr__GetItemsCount(mgr)-1 do begin
    item:=get_item_from_vector(@mgr.m_items.base_vector, i, sizeof(CItemMgr__m_items_pair));
    R_ASSERT(item<>nil, 'GetItemIdx: nil item in vector?');
    if item_section = get_string_value(@item.first) then begin
      result:=i;
      break;
    end;
  end;
end;

function CItemMgr__GetElement(mgr:pCItemMgr; id:integer):pCItemMgr__m_items_pair;
begin
  R_ASSERT(CItemMgr__GetItemsCount(mgr) > id, 'Cannot get element from CItemMgr (shop) - ID is greater than number of registered items');
  result:=get_item_from_vector(@mgr.m_items.base_vector, id, sizeof(CItemMgr__m_items_pair));
end;

function CItemMgr__GetItemsCount(mgr:pCItemMgr):integer;
begin
  R_ASSERT(mgr<>nil, 'Cannot get items count - CItemMgr is nil');
  result:=items_count_in_vector(@mgr.m_items.base_vector, sizeof(CItemMgr__m_items_pair));
end;

function GetRankForItem(section:string):cardinal;
var
  itm:shared_str;
begin
  init_string(@itm);
  assign_string(@itm, PAnsiChar(section));
  result:=get_rank.Call([@itm]).VInteger;
  assign_string(@itm, nil);
end;

function GetItemGroup(section:string):string;
var
  sect_str, out_str:shared_str; //in + out
begin
  CRestrictions__InitGroups.Call([g_mp_restrictions]);
  init_string(@sect_str);
  init_string(@out_str);

  assign_string(@sect_str, PAnsiChar(section));

  CRestrictions__GetItemGroup.Call([g_mp_restrictions, @sect_str, @out_str]);
  result:=get_string_value(@out_str);

  assign_string(@sect_str, nil);
  assign_string(@out_str, nil);
end;


type restr_item = packed record
  first:shared_str;
  second:cardinal;
end;
prestr_item = ^restr_item;

function GetItemGroupMaxCounter(groupname:string; rank:cardinal):cardinal;
var
  v:pxr_vector;
  i:integer;
  restr:prestr_item;
begin
  CRestrictions__InitGroups.Call([g_mp_restrictions]);
  result:=0;

  if rank >= _RANK_COUNT then rank:=_RANK_COUNT-1;

  v:=@g_mp_restrictions.m_restrictions[rank];
  for i:=0 to items_count_in_vector(v, sizeof(restr_item)) - 1 do begin
    restr:=get_item_from_vector(v, i, sizeof(restr_item));
    if groupname = get_string_value(@restr.first) then begin
      result:=restr.second;
      break;
    end;
  end;
end;

function Init():boolean;
begin
  result:=false;
  if xrGameDllType()=XRGAME_SV_1510 then begin
    g_mp_restrictions:=pointer(xrGame+$5e9b40);
    CRestrictions__InitGroups:=srcECXCallFunction.Create(pointer(xrGame+$48CBD0), [vtPointer], 'CRestrictions', 'InitGroups');
    CRestrictions__GetItemGroup:=srcECXCallFunctionWEBXEDIArg.Create(pointer(xrGame+$48d160), [vtPointer, vtPointer, vtPointer], 'CRestrictions', 'GetItemGroup');
    CRestrictions__GetGroupCount:=srcECXCallFunctionWEDXArg.Create(pointer(xrGame+$48D220), [vtPointer, vtPointer], 'CRestrictions', 'GetGroupCount');

    get_rank:=srcCdeclFunction.Create(pointer(xrGame+$48c910), [vtPointer], 'get_rank');
    result:=true;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    g_mp_restrictions:=pointer(xrGame+$606c40);

    CRestrictions__InitGroups:=srcECXCallFunction.Create(pointer(xrGame+$4A3080), [vtPointer], 'CRestrictions', 'InitGroups');
    CRestrictions__GetItemGroup:=srcECXCallFunctionWEBXEDIArg.Create(pointer(xrGame+$4A3610), [vtPointer, vtPointer, vtPointer], 'CRestrictions', 'GetItemGroup');
    CRestrictions__GetGroupCount:=srcECXCallFunctionWEDXArg.Create(pointer(xrGame+$4A36D0), [vtPointer, vtPointer], 'CRestrictions', 'GetGroupCount');

    get_rank:=srcCdeclFunction.Create(pointer(xrGame+$4A2DC0), [vtPointer], 'get_rank');
    result:=true;
  end;
end;

end.

