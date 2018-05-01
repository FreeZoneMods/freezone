unit InventoryItems;

{$mode delphi}

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
    m_can_trade:cardinal;
    m_pCurrentInventory:pointer; {CInventory}
    m_section_id:shared_str;
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
    m_upgrades:xr_vector; {Upgrades_type = shared_str}
    m_is_helper:byte; {boolean}
    _unused2:byte;
    _unused3:word;
  end;
  pCInventoryItem = ^CInventoryItem;
  ppCInventoryItem = ^pCInventoryItem;

  CInventory = packed record
    vtable:pointer;
    m_all:xr_vector; {CInventoryItem*}
    m_ruck:xr_vector; {CInventoryItem*}
    m_belt:xr_vector; {CInventoryItem*}
    m_activ_last_items:xr_vector; {CInventoryItem*}
    m_slots:xr_vector; {CInventorySlot}
    m_iActiveSlot:cardinal;
    m_iNextActiveSlot:cardinal;
    m_iPrevActiveSlot:cardinal;
    m_pOwner:pointer; {CInventoryOwner*}
    m_bBeltUseful:byte; {boolean}
    m_bSlotsUseful:byte; {boolean}
    _unused1:word;
    m_fMaxWeight:single;
    m_fTotalWeight:single;
    m_dwModifyFrame:cardinal;
    m_drop_last_frame:byte; {boolean}
    _unused2:byte;
    _unused3:word;
  end;
  pCInventory=^CInventory;

  CAttachmentOwner = packed record
    vtable:pointer;
    m_attach_item_sections:xr_vector; {shared_str}
    m_attached_objects:xr_vector; {CAttachableItem*}
  end;

  CInventoryOwner = packed record
    base_CAttachmentOwner:CAttachmentOwner;
    m_inventory:pCInventory;
    m_money:cardinal;
    m_pTrade:pointer; {CTrade*}
    m_bTrading:byte; {boolean}
    m_bTalking:byte; {boolean}
    _unused1:word;
    m_pTalkPartner:^CInventoryOwner;
    m_bAllowTalk:byte; {boolean}
    m_bAllowTrade:byte; {boolean}
    m_bAllowInvUpgrade:byte; {boolean}
    _unused2:byte;
    m_tmp_active_slot_num:cardinal;
    m_known_info_registry:pointer; {CInfoPortionWrapper}
    m_pCharacterInfo:pointer; {CCharacterInfo*}
    m_game_name:xr_string;
    m_item_to_spawn:shared_str;
    m_ammo_in_box_to_spawn:cardinal;
    m_trade_parameters:pointer; {CTradeParameters*}
    m_purchase_list:pointer; {CPurchaseList*}
    m_need_osoznanie_mode:cardinal;
  end;
  pCInventoryOwner = ^CInventoryOwner;

implementation

end.

