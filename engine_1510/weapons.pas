unit Weapons;

{$mode delphi}
{$I _pathes.inc}

interface
uses MatVectors, Vector, xrstrings, ai_sounds, AnticheatStuff;

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
  SZoomParams = packed record
    m_bZoomEnabled: byte; {boolean}
    m_bHideCrosshairInZoom: byte; {boolean}
    m_bZoomDofEnabled: byte; {boolean}
    m_bIsZoomModeNow: byte; {boolean}
    m_fCurrentZoomFactor: single;
    m_fZoomRotateTime: single;
    m_fIronSightZoomFactor: single;
    m_fScopeZoomFactor: single;
    m_fZoomRotationFactor: single;
    m_ZoomDof: FVector3;
    m_ReloadDof:FVector4;
  end;

  firedeps = packed record
    m_FireParticlesXForm:FMatrix4x4;
    vLastFP:FVector3;
    vLastFP2:FVector3;
    vLastFD:FVector3;
    vLastSP:FVector3;
  end;

  CameraRecoil = packed record
  	RelaxSpeed: single;
  	RelaxSpeed_AI: single;
  	Dispersion: single;
  	DispersionInc: single;
  	DispersionFrac: single;
  	MaxAngleVert: single;
  	MaxAngleHorz: single;
  	StepAngleHorz: single;
  	ReturnMode: byte; {boolean}
  	StopReturn: byte; {boolean}
    _unused1:word;
  end;

  SPDM = packed record
		m_fPDM_disp_base:single;
		m_fPDM_disp_vel_factor:single;
		m_fPDM_disp_accel_factor:single;
		m_fPDM_disp_crouch:single;
		m_fPDM_disp_crouch_no_acc:single;
  end;

  first_bullet_controller = packed record
  	m_last_short_time:cardinal;
  	m_shot_timeout:cardinal;
  	m_fire_dispertion:single;
  	m_actor_velocity_limit:single;
  	m_use_first_bullet:byte;
    _unused1:byte;
    _unused2:word;
  end;

  SCartridgeParam = packed record
  	kDist:single;
    kDisp:single;
    kHit:single;
    kCritical:single;
    kImpulse:single;
    kAP:single;
    kAirRes:single;
  	buckShot:integer;
  	impair:single;
  	fWallmarkSize:single;
  	u8ColorID:byte;
    _unused1:byte;
    _unused2:word;
  end;

  CCartridge = packed record
    vtable:pointer;
    m_ammoSect:shared_str;
    param_s:SCartridgeParam;
    m_LocalAmmoType:byte;
    _unused1:byte;
    bullet_material_idx:word;
    m_flags:byte;
    _unused2:byte;
    _unused3:word;
    m_InvShortName:shared_str;
  end;

  CRocketLauncher = packed record
    vtable:pointer;
    m_rockets:xr_vector; {<CCustomRocket*>}
    m_launched_rockets:xr_vector; {<CCustomRocket*>}
    m_fLaunchSpeed:single;
  end;

  CWeaponAmmo = packed record
    //todo:finish
    _unknown:array[0..$313] of byte;
    m_boxSize:word;
    m_boxCurr:word;
    m_tracer:byte; {boolean}
    _unused1:byte;
    _unused2:word;
  end;
  pCWeaponAmmo = ^CWeaponAmmo;

  SilencerKoeffs = packed record
    hit_power:single;
    hit_impulse:single;
    bullet_speed:single;
    fire_dispersion:single;
    cam_dispersion:single;
    cam_disper_inc:single;
  end;

  CShootingObject = packed record //sizeof = 0x108
    base_IAnticheatDumpable:IAnticheatDumpable;
    m_vCurrentShootDir:FVector3;
    m_vCurrentShootPos:FVector3;
    m_iCurrentParentID:word;
    bWorking:byte;
    _unused1:byte;
    //offset:0x20
    fOneShotTime:single;
    fvHitPower:array[0..3] of single; //FVector4;
    fvHitPowerCritical:array[0..3] of single; //FVector4;
    fHitImpulse:single;
    m_fStartBulletSpeed:single;
    fireDistance:single;
    //offset:0x50
    fireDispersionBase:single;
    fShotTimeCounter:single;
    m_silencer_koef:SilencerKoeffs;
    cur_silencer_koef:SilencerKoeffs;
    //offset:0x88
    m_fMinRadius:single;
    m_fMaxRadius:single;
    light_base_color:Fcolor;
    light_base_range:single;
    light_build_color:Fcolor;
    light_build_range:single;
    //offset:0xB8
    light_render:pointer; {ref_light}
    light_var_color:single;
    light_var_range:single;
    light_lifetime:single;
    light_frame:single;
    light_time:single;
    //offset:0xD0
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
    //offset:0x100
    m_sSmokeParticles:shared_str;
    m_sShotParticles:shared_str;
  end;

  CWeapon = packed record    //sizeof = 0x730
    //todo:finish
    _unknown1:array[0..$33F] of byte;

    //offset:0x340
    base_CShootingObject:CShootingObject;
    //offset:0x448
    m_dwWeaponRemoveTime:int64;
    m_dwWeaponIndependencyTime:int64;

    //offset:0x458
  	m_bTriStateReload:byte;
  	m_sub_state:byte;
  	bMisfire:byte;
    _unused1:byte;
  	m_bAutoSpawnAmmo:cardinal;

    m_flagsAddOnState:byte; //offset: $460
    _unusedx1:byte;
    _unusedx2:word;
    m_eScopeStatus:integer;           //EWeaponAddonStatus
    m_eSilencerStatus:integer;        //EWeaponAddonStatus;
    m_eGrenadeLauncherStatus:integer; //EWeaponAddonStatus;
    m_sScopeName: shared_str;
    m_sSilencerName:shared_str;
    m_sGrenadeLauncherName:shared_str;
    m_iScopeX:integer;
    m_iScopeY:integer;
    m_iSilencerX:integer;
    m_iSilencerY:integer;
    m_iGrenadeLauncherX:integer;
    m_iGrenadeLauncherY:integer;
    m_zoom_params:SZoomParams;
    //offset:0x4C8
    m_UIScope:pointer; {CUIWindow*}
    m_strap_bone0:PAnsiChar;
    m_strap_bone1:PAnsiChar;
    m_StrapOffset:FMatrix4x4;
    //offset:0x514
    m_strapped_mode:byte; {boolean}
    m_can_be_strapped:byte; {boolean}
    m_Offset:FMatrix4x4;
    _unusedx3:word;
    eHandDependence:integer;
    m_bIsSingleHanded:byte; {boolean}
    vLoadedFirePoint:FVector3;
    vLoadedFirePoint2:FVector3;
    //offset: 0x574
    m_current_firedeps:firedeps;
    _unusedx4:byte;
    _unusedx5:word;
    //offset: 0x5E8
    cam_recoil:CameraRecoil;
    zoom_cam_recoil:CameraRecoil;
    //offset: 0x630
    fireDispersionConditionFactor:single;
    misfireProbability:single;
    misfireConditionK:single;
    conditionDecreasePerShot:single;
    //offset: 0x640
    m_pdm:SPDM;
    m_crosshair_inertion:single;
    m_first_bullet_controller:first_bullet_controller;
    m_vRecoilDeltaAngle:FVector3;
    m_fMinRadius:single;
    m_fMaxRadius:single;
    //offset: 0x680
    m_sFlameParticles2:shared_str;
    m_pFlameParticles2:pointer; {CParticlesObject*}
    iAmmoElapsed:integer;
    iMagazineSize:integer;
    iAmmoCurrent:integer;
    m_dwAmmoCurrentCalcFrame:cardinal;
    m_bAmmoWasSpawned:byte; {boolean}
    _unusedx6:byte;
    _unusedx7:word;
    m_ammoTypes:xr_vector; {<shared_str>}
    m_pAmmo:pointer; {CWeaponAmmo*}
    m_ammoType:cardinal;
    //offset: 0x6B0
    m_ammoName:shared_str;
    m_bHasTracers:cardinal;
    m_u8TracerColorID:byte;
    _unusedx8:byte;
    _unusedx9:word;
    m_set_next_ammoType_on_reload:cardinal;
    //offset: 0x6C0
    m_magazine:xr_vector; {<CCartridge>}
    m_DefaultCartridge:CCartridge;
    m_fCurrentCartirdgeDisp:single;
    //offset: 0x710
  	m_ef_main_weapon_type:cardinal;
  	m_ef_weapon_type:cardinal;
  	m_addon_holder_range_modifier:single;
  	m_addon_holder_fov_modifier:single;
    //offset: 0x720
    m_hit_probability:array [0..3] of single;
  end;
  pCWeapon=^CWeapon;

  CWeaponKnife = packed record //sizeof = 0x798
    base_CWeapon:CWeapon;
    fWallmarkSize:single;
    knife_material_idx:word;
    _unused1:word;
    m_eHitType:cardinal;
    m_eHitType_1:cardinal;
    fvHitPower_1:array[0..3] of single; //FVector4;
    fvHitPowerCritical_1:array[0..3] of single; //FVector4;
    fHitImpulse_1:single;
    m_eHitType_2:cardinal;
    fvHitPower_2:array[0..3] of single; //FVector4;
    fvHitPowerCritical_2:array[0..3] of single; //FVector4;
    fHitImpulse_2:single;
    fCurrentHit:single;
    fCurrentHitCritical:single;
    fHitImpulse_cur:single;
  end;
  pCWeaponKnife=^CWeaponKnife;

  CWeaponMagazined = packed record //sizeof = 0x798
    base_CWeapon:CWeapon;
    //offset:0x730
    m_sSndShotCurrent:shared_str;
    m_sSilencerFlameParticles:PAnsiChar;
    m_sSilencerSmokeParticles:PAnsiChar;
    m_eSoundShow:ESoundTypes;
  	m_eSoundHide:ESoundTypes;
  	m_eSoundShot:ESoundTypes;
  	m_eSoundEmptyClick:ESoundTypes;
  	m_eSoundReload:ESoundTypes;
    //offset:0x750
    dwUpdateSounds_Frame:cardinal;
    m_iQueueSize:integer;
    m_iShotNum:integer;
    m_iShootEffectorStart:integer;
    m_vStartPos:FVector3;
    m_vStartDir:FVector3;
    m_bStopedAfterQueueFired:byte; {boolean} //MAY BE UNINITILIZED!
    m_bFireSingleShot:byte; {boolean}
    m_bHasDifferentFireModes:byte; {boolean}
    _unused1:byte;
    m_aFireModes:xr_vector; {<u8>}
    m_iCurFireMode:integer;
    m_iPrefferedFireMode:integer;
    //offset:0x790
    m_bLockType:boolean;
    _unused2:byte;
    _unused3:word;
    _unused4:cardinal;
  end;
  pCWeaponMagazined = ^CWeaponMagazined;

  CWeaponMagazinedWGrenade = packed record
    base_CWeaponMagazined:CWeaponMagazined;
    //offset:0x798
    base_CRocketLauncher:CRocketLauncher;
    //offset:0x7B8
    m_pAmmo2:pointer; {CWeaponAmmo*}
    m_ammoSect2:shared_str;
    m_ammoTypes2:xr_vector; {<shared_str>}
    m_ammoType2:cardinal;
    m_ammoName2:shared_str;
    iMagazineSize2:integer;
    m_magazine2:xr_vector; {<CCartridge>}
    m_bGrenadeMode:byte;
    _unused1:byte;
    _unused2:word;
    m_DefaultCartridge2:CCartridge;
    //offset: 0x828;
    iAmmoElapsed2:integer;
  end;
  pCWeaponMagazinedWGrenade = ^CWeaponMagazinedWGrenade;

implementation

end.


