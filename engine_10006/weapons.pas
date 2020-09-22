unit Weapons;

{$mode delphi}
{$I _pathes.inc}

interface
uses MatVectors, Vector, xrstrings;

type
  EWeaponAddonState = byte;
  EWeaponAddonStatus = byte;

const
	eWeaponAddonScope: EWeaponAddonState           = 1;
	eWeaponAddonGrenadeLauncher: EWeaponAddonState = 2;
	eWeaponAddonSilencer: EWeaponAddonState        = 4;

  fzBuyItemOldScopeStateBit:EWeaponAddonState = 16;
  fzBuyItemOldGlStateBit:EWeaponAddonState = 32;
  fzBuyItemOldSilencerStateBit:EWeaponAddonState = 64;
  fzBuyItemRenewing:EWeaponAddonState = 128;

	eAddonDisabled:EWeaponAddonStatus	  = 0;
	eAddonPermanent:EWeaponAddonStatus  = 1;
	eAddonAttachable:EWeaponAddonStatus = 2;

type

  MotionID = word;
  MotionSVec = packed record
    items: array [0..7] of MotionID;
    count:cardinal;
  end;

  HUD_SOUND = packed record
    m_activeSnd:pointer; {SSnd*}
    sounds:xr_vector; {SSnd*}
  end;

  CCartridge = packed record  //sizeof = 0x38
    m_ammoSect:shared_str;
  	m_kDist:single;
    m_kDisp:single;
    m_kHit:single;
    m_kImpulse:single;
    m_kPierce:single;
    m_kAP:single;
    m_kAirRes:single;
  	m_buckShot:integer;
  	m_impair:single;
  	fWallmarkSize:single;
  	u8ColorID:byte;
    m_LocalAmmoType:byte;
    bullet_material_idx:word;
    m_flags:byte;
    _unused1:byte;
    _unused2:word;
    m_InvShortName:shared_str;
  end;

  CShootingObject = packed record //sizeof = 0xc8
    vtable:pointer;
    m_vCurrentShootDir:FVector3;
    m_vCurrentShootPos:FVector3;
    m_iCurrentParentID:word;
    bWorking:byte;
    _unused1:byte;
    //offset:0x20
    fTimeToFire:single;
    fvHitPower:array[0..3] of single; //FVector4;
    fHitImpulse:single;
    m_fStartBulletSpeed:single;
    fireDistance:single;
    //offset: 0x40
    fireDispersionBase:single;
    fTime:single;
    m_fMinRadius:single;
    m_fMaxRadius:single;
    //offset: 0x50
    light_base_color:Fcolor;
    light_base_range:single;
    light_build_color:Fcolor;
    light_build_range:single;
    //offset: 0x78
    light_render:pointer; {ref_light}
    light_var_color:single;
    light_var_range:single;
    light_lifetime:single;
    light_frame:single;
    light_time:single;
    //offset: 0x90
    m_bLightShotEnabled:byte;
    _unused2:byte;
    _unused3:word;
    m_sShellParticles:shared_str;
    vLoadedShellPoint:FVector3;
    m_fPredBulletTime:single;
    m_fTimeToAim:single;
    m_bUseAimBullet:cardinal;
    m_sFlameParticlesCurrent:shared_str;
    m_sFlameParticles:shared_str;
    m_pFlameParticles:pointer; {CParticlesObject*}
    m_sSmokeParticlesCurrent:shared_str;
    //offset:0xc0
    m_sSmokeParticles:shared_str;
    m_sShotParticles:shared_str;
  end;

  _firedeps = packed record
    m_FireParticlesXForm:FMatrix4x4;
    vLastFP:FVector3;
    vLastFP2:FVector3;
	  vLastFD:FVector3;
	  vLastSP:FVector3;
  end;

  CWeapon = packed record //sizeof = 0x628
    _unknown:array[0..$2c7] of byte;

    //offset:0x2c8
    base_CShootingObject:CShootingObject;
    //offset:0x390
    m_dwWeaponRemoveTime:int64;
    m_dwWeaponIndependencyTime:int64;

  	m_bTriStateReload:byte;
  	m_sub_state:byte;
    bWorking2:byte; {boolean}
  	bMisfire:byte;
  	m_bAutoSpawnAmmo:cardinal;

    //offset: 0x3A8
    m_flagsAddOnState:byte;
    _unusedx1:byte;
    _unusedx2:word;
    m_eScopeStatus:integer;           //EWeaponAddonStatus
    m_eSilencerStatus:integer;        //EWeaponAddonStatus;
    m_eGrenadeLauncherStatus:integer; //EWeaponAddonStatus;

    //offset:0x3b8
    m_sScopeName: shared_str;
    m_sSilencerName:shared_str;
    m_sGrenadeLauncherName:shared_str;
    m_iScopeX:integer;
    m_iScopeY:integer;
    m_iSilencerX:integer;
    m_iSilencerY:integer;
    m_iGrenadeLauncherX:integer;
    m_iGrenadeLauncherY:integer;

    //offset: 0x3dc
    m_bZoomEnabled:byte;
    _unusedx3:byte;
    _unusedx4:word;
    m_fZoomFactor:single;
    m_fZoomRotateTime:single;
    m_UIScope:pointer; {CUIStaticItem*}
    m_fIronSightZoomFactor:single;
    m_fScopeZoomFactor:single;
    m_bZoomMode:byte; {boolean}
    _unusedx5:byte;
    _unusedx6:word;
    //offset: 0x3f8
    m_fZoomRotationFactor:single;
    m_bHideCrosshairInZoom:byte; {boolean}
    _unusedx7:byte;
    _unusedx8:word;
    m_strap_bone0:PAnsiChar;
    m_strap_bone1:PAnsiChar;
    //offset:0x408
    m_StrapOffset:FMatrix4x4;
    //offset:0x448
    m_strapped_mode:byte; {boolean}
    m_can_be_strapped:byte; {boolean}
    m_Offset:FMatrix4x4;
    _unusedx9:word;
    eHandDependence:cardinal;
    m_bIsSingleHanded:boolean;
    vLoadedFirePoint:FVector3;
    vLoadedFirePoint2:FVector3;
    m_firedeps: _firedeps;
    _unusedx10:byte;
    _unusedx11:word;
    //offset: 0x51c
    camMaxAngle:single;
  	camRelaxSpeed:single;
  	camRelaxSpeed_AI:single;
  	camDispersion:single;
  	camDispersionInc:single;
  	camDispertionFrac:single;
  	camMaxAngleHorz:single;
  	camStepAngleHorz:single;
    //offset:0x53c
    fireDispersionConditionFactor:single;
    misfireProbability:single;
    misfireConditionK:single;
    conditionDecreasePerShot:single;
  	m_fPDM_disp_base:single;
  	m_fPDM_disp_vel_factor:single;
  	m_fPDM_disp_accel_factor:single;
  	m_fPDM_disp_crouch:single;
  	m_fPDM_disp_crouch_no_acc:single;
    m_vRecoilDeltaAngle:FVector3;  //UNUSED???
    //offset:0x56C
    m_fMinRadius:single;
    m_fMaxRadius:single;
    m_sFlameParticles2:shared_str;
    m_pFlameParticles2:pointer; {CParticlesObject*}
    iAmmoElapsed:integer;
    iMagazineSize:integer;
    iAmmoCurrent:integer;
    //offset:0x588
    m_dwAmmoCurrentCalcFrame:integer;
    m_bAmmoWasSpawned:boolean;
    _unusedx12:byte;
    _unusedx13:word;
    m_ammoTypes:xr_vector; {<shared_str>}
    m_pAmmo:pointer; {CWeaponAmmo*}
    m_ammoType:cardinal;
    //offset:0x5A8
    m_ammoName:shared_str;
    m_bHasTracers:cardinal;
    m_u8TracerColorID:byte;
    _unusedx14:byte;
    _unusedx15:word;
    m_set_next_ammoType_on_reload:cardinal;
    m_magazine:xr_vector; {<CCartridge>}
    //offset:0x5C8
    m_DefaultCartridge:CCartridge;
    //offset:0x600
    m_fCurrentCartirdgeDisp:single;
    m_ef_main_weapon_type:single;
    m_ef_weapon_type:single;
    m_addon_holder_range_modifier:single;
    m_addon_holder_fov_modifier:single;
    m_hit_probability:array [0..3] of single;
    _unknown1:cardinal;
  end;
  pCWeapon=^CWeapon;

  CWeaponKnife = packed record
    base_CWeapon:CWeapon;
    //offset:0x628
    mhud_idle:MotionSVec;
    mhud_hide:MotionSVec;
    mhud_show:MotionSVec;
    mhud_attack:MotionSVec;
    mhud_attack2:MotionSVec;
    mhud_attack_e:MotionSVec;
    mhud_attack2_e:MotionSVec;
    //offset:0x6B4
    m_sndShot:HUD_SOUND;
    m_attackStart:byte; {boolean}
    _unused1:byte;
    _unused2:word;
    fWallmarkSize:single;
    //offset:0x6D0
    knife_material_idx:word;
    _unused3:word;
    m_eHitType:cardinal;
    m_eHitType_1:cardinal;
    fvHitPower_1:array[0..3] of single; //FVector4;
    fHitImpulse_1:single;
    //offset:0x6F0
    m_eHitType_2:cardinal;
    fvHitPower_2:array[0..3] of single;  //FVector4;
    fCurrentHit:single;
    fHitImpulse_2:single;
  end;
  pCWeaponKnife=^CWeaponKnife;

implementation

end.

