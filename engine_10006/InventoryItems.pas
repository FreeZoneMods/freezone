unit inventoryitems;

{$mode delphi}
{$I _pathes.inc}

interface
uses xrstrings, MatVectors, Hits, Physics, Vector;

type
  CAttachableItem = packed record
    vtable:pointer;
    m_item:pointer {CInventoryItem};
    m_bone_name:shared_str;
    m_offset:FMatrix4x4;
    m_bone_id:word;
    m_enabled:byte; {boolean}
    _unused:byte;
  end;

  CInventoryItem = packed record   //sizeof = 0xD8
    base_CAttachableItem:CAttachableItem;
    base_CHitImmunity:CHitImmunity;
    m_flags:word; //offset: 0x84
    _unused1:word;
    m_pCurrentInventory:pointer; {CInventory}
    m_name:shared_str;
    m_nameShort:shared_str;
    m_nameComplex:shared_str;
    m_eItemPlace:cardinal; {EItemPlace}
    m_slot:cardinal;
    m_cost:cardinal;
    m_weight:single;
    m_fCondition:single;
    m_Description:shared_str;
    m_dwItemRemoveTime:int64;
    m_dwItemIndependencyTime:int64;
    m_fControlInertionFactor:single;
    m_icon_name:shared_str;
    m_net_updateData:pointer; {net_updateData}
  	m_holder_range_modifier:single;
  	m_holder_fov_modifier:single;
    m_object:pCPhysicsShellHolder;
  end;
  pCInventoryItem = ^CInventoryItem;

  CInventory = packed record //sizeof = 0x80
    vtable:pointer;
    m_all:xr_vector; {CInventoryItem*}
    m_ruck:xr_vector; {CInventoryItem*}
    m_belt:xr_vector; {CInventoryItem*}
    m_slots:xr_vector; {CInventorySlot}
    m_pTarget:pCInventoryItem;

    m_iActiveSlot:cardinal;
    m_iNextActiveSlot:cardinal;
    m_iPrevActiveSlot:cardinal;
  	m_iLoadActiveSlot:cardinal;
  	m_iLoadActiveSlotFrame:cardinal;
    m_ActivationSlotReason:cardinal;
    m_pOwner:pointer; {CInventoryOwner*}
    m_bBeltUseful:byte; {boolean}
    m_bSlotsUseful:byte; {boolean}
    _unused1:word;
    m_fMaxWeight:single;
    m_fTotalWeight:single;
    m_iMaxBelt:cardinal;
    m_fTakeDist:single;
    m_dwModifyFrame:cardinal;
    m_drop_last_frame:byte; {boolean}
    _unused2:byte;
    _unused3:word;
  end;
  pCInventory=^CInventory;

const
  INV_STATE_BLOCK_ALL:cardinal = $FFFFFFFF;

implementation

end.

