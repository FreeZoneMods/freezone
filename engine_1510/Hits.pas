unit Hits;

{$mode delphi}
{$I _pathes.inc}

interface
uses MatVectors, Objects, Packets;

type
  SHit = packed record
    Time:cardinal;
    PACKET_TYPE:word;
    DestID:word;
    power:single;
    power_critical:single;
    dir:FVector3;
    who:pCObject;
    whoID:word;
    weaponID:word;
    boneID:word;
    _unknown1:word;
    p_in_bone_space:FVector3;
    impulse:single;
    hit_type:cardinal;
    armor_piercing:single;
    add_wound:byte;
    aim_bullet:byte;
    _unused2:word;
    BulletID:cardinal;
    SenderID:cardinal;
  end;
pSHit = ^SHit;

CHitImmunity = packed record
  vtable:pointer;
  m_HitTypeK:array[0..10{EHitType__eHitTypeMax}] of single;
  count:cardinal;
end;

const
  ALife__eHitTypeFireWound:cardinal = 8;
  SPECIAL_KILL_TYPE__SKT_NONE:cardinal = 0;

procedure ReadHitFromPacket(p:pNET_Packet; h:pSHit); stdcall;
procedure OverWriteHitPowerToPacket(p:pNET_Packet; power:single); stdcall;

implementation

procedure ReadHitFromPacket(p:pNET_Packet; h:pSHit); stdcall;
var
  pos:cardinal;
begin
  pos:=2;
  h.Time := (pcardinal(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.Time);

  h.PACKET_TYPE := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.PACKET_TYPE);

  h.DestID := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.DestID);

  h.WhoID := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.WhoID);

  h.WeaponID := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.WeaponID);

  //TODO:Read Dir
  pos:=pos+2;

  h.power := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.power);

  h.power_critical := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.power_critical);

  h.BoneID := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.BoneID);

  h.p_in_bone_space.x := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.p_in_bone_space.x);

  h.p_in_bone_space.y := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.p_in_bone_space.y);

  h.p_in_bone_space.z := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.p_in_bone_space.z);

  h.impulse := (psingle(@p.B.data[pos]))^;
  pos:=pos+sizeof(h.impulse);

  //TODO:if gametype is single, there should be aim_bullet
  h.aim_bullet := 0;

  h.hit_type := (pword(@p.B.data[pos]))^;
  pos:=pos+sizeof(word);

  if ALife__eHitTypeFireWound = h.hit_type then begin
    h.armor_piercing := (psingle(@p.B.data[pos]))^;
    pos:=pos+sizeof(h.armor_piercing);
  end else begin
    h.armor_piercing:=0;
  end;

  if h.PACKET_TYPE = GE_HIT_STATISTIC then begin
    h.BulletID := (pcardinal(@p.B.data[pos]))^;
    pos:=pos+sizeof(h.BulletID);
    h.SenderID := (pcardinal(@p.B.data[pos]))^;
    pos:=pos+sizeof(h.SenderID);
  end;
end;

procedure OverWriteHitPowerToPacket(p:pNET_Packet; power:single); stdcall;
begin
  psingle(@p.B.data[16])^:=power;
end;

end.

