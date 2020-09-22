unit Hits;

{$mode delphi}
{$I _pathes.inc}

interface
uses MatVectors, Objects, Packets;

const
  ALife__eHitTypeFireWound:cardinal = 8;
  EHitType__eHitTypeMax:cardinal=11;

type
  SHit = packed record
    Time:cardinal;
    PACKET_TYPE:word;
    DestID:word;
    power:single;
    dir:FVector3;
    who:pCObject;
    whoID:word;
    weaponID:word;
    boneID:word;
    p_in_bone_space:FVector3;
    _unused1:word;
    impulse:single;
    hit_type:cardinal;
    ap:single;
    aim_bullet:byte;
    _unused2:byte;
    _unused3:word;
    BulletID:cardinal;
    SenderID:cardinal;
  end;
  pSHit = ^SHit;

  CHitImmunity = packed record
    vtable:pointer;
    m_HitTypeK:array[0..10{EHitType__eHitTypeMax}] of single;
    count:cardinal;
  end;


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
    h.ap := (psingle(@p.B.data[pos]))^;
    pos:=pos+sizeof(h.ap);
  end else begin
    h.ap:=0;
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

