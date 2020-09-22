unit ConfigCache;
{$mode delphi}
interface
uses Windows;
type
FZCacheData = record
  //new_votings_allowed_by_default:boolean; - не нужно тут
  allow_early_success_in_vote:boolean;
  allow_early_fail_in_vote:boolean;
  //unlimited_chat_for_dead:boolean; - не нужно тут

  is_cdkey_checking_disabled:boolean;
  is_same_cdkey_validated:boolean;
  min_players:integer;
  servername:string;

  ban_for_badpackets:integer;
  is_strict_filter:boolean;

  use_skins_change:boolean;
  use_item_change:boolean;

  no_same_cdkeys:boolean;
  vote_mute_time_ms:cardinal;
  vote_series_for_mute:cardinal;
  vote_mute_interval:cardinal;
  vote_first_mute_time:cardinal;

  censor_chat:boolean;
  chat_badwords_treasure:cardinal;
  mutetime_per_badword:cardinal;
  radmins_see_other_team_chat:boolean;
  enable_chat_commands:boolean;

  chat_series_for_mute:cardinal;
  chat_series_interval:cardinal;
  chat_mute_time:cardinal;

  speech_series_for_mute:cardinal;
  speech_series_interval:cardinal;
  speech_mute_time:cardinal;

  teamchange_minimal_period:cardinal;
  preserve_team_after_reconnect:boolean;

  hit_correction_highscore_treasure:single;
  hit_correction_highscore_speed:single;
  hit_correction_highscore_limit:single;

  damage_correction_highscore_treasure:single;
  damage_correction_highscore_speed:single;
  damage_correction_highscore_limit:single;

  player_ready_signal_interval:cardinal;
  ping_warnings_max_interval:cardinal;
  auto_update_rate:boolean;
  can_player_change_name:integer;
  enable_map_downloader:boolean;
  reconnect_ip:string;
  reconnect_port:cardinal;
  mod_name:string;
  mod_params:string;
  mod_link:string;
  mod_crc32:cardinal;
  mod_dsign:string;
  mod_compression_type:cardinal;
  mod_is_reconnect_needed:boolean;
  mod_prefer_parent_appdata_for_maps:boolean;

  allow_russian_nicknames:boolean;
  hit_statistics_mode:cardinal;
  hit_analysis_level:cardinal;
  enable_maplist_sync:boolean;
  strict_hwid:boolean;

  log_severity:cardinal;
  external_log:boolean;
  log_events:boolean;
  log_ge_filter_errors:boolean;
  antihacker:boolean;
  new_chat_color_scheme:boolean;
  radmins_see_sec_events:boolean;

  sell_items_for_shophackers:boolean;
  banned_symbols:string;

  ip_checker_time_delta:cardinal;
  ip_checker_max_connections_per_delta_count:cardinal;

  preserve_map:boolean;
  mapchange_voting_lock_time:cardinal;

  teamkill_decrease_rank:boolean;
  teamkill_decrease_money:integer;
  teamkill_reparations_to_victim:integer;

  experience_speed:single;
  invincibility_after_shot:boolean;
end;
pFZCacheData = ^FZCacheData;

{ FZConfigCache }

FZConfigCache = class
protected
  _cs:TRTLCriticalSection;
  _data:FZCacheData;
  procedure _LL_FillData();
  procedure _ApplyConfig();
public
  class function Get():FZConfigCache;
  constructor Create();
  destructor Destroy(); override;
  procedure GetDataCopy(dest:pFZCacheData); overload;
  function GetDataCopy():FZCacheData; overload;
  procedure Reload();
  procedure OverrideConfig(cfg:FZCacheData);
end;

function Init():boolean; stdcall;

const
  FZ_CFG_CACHE_CHANGE_NAME_DISABLED = 0;
  FZ_CFG_CACHE_CHANGE_NAME_ENABLED = 1;
  FZ_CFG_CACHE_CHANGE_NAME_WHEN_NO_VOTING = 2;
  FZ_CFG_CACHE_CHANGE_NAME_WHEN_NO_BAN_OR_KICK_VOTE = 3;

implementation
uses ConfigMgr, LogMgr, sysutils, CommonHelper, sysmsgs, xr_debug;
var
  _instance:FZConfigCache;

{ FZConfigCache }

constructor FZConfigCache.Create;
begin
  InitializeCriticalSection(_cs);
  _data.servername:='';
  Reload();
end;

destructor FZConfigCache.Destroy;
begin
  inherited;
  DeleteCriticalSection(_cs);
end;

class function FZConfigCache.Get: FZConfigCache;
begin
  R_ASSERT(_instance<>nil, 'Config cache is not created yet');
  result:=_instance;
end;

procedure FZConfigCache.GetDataCopy(dest: pFZCacheData);
begin
  EnterCriticalSection(_cs);
  dest^:=self._data;
  LeaveCriticalSection(_cs);
end;

function FZConfigCache.GetDataCopy: FZCacheData;
begin
  EnterCriticalSection(_cs);
  result:=self._data;
  LeaveCriticalSection(_cs);
end;

procedure FZConfigCache.Reload;
begin
  FZConfigMgr.Get.Reload;
  EnterCriticalSection(_cs);
  try
    self._LL_FillData;
    _ApplyConfig();
  finally
    LeaveCriticalSection(_cs);
  end;
end;

procedure FZConfigCache.OverrideConfig(cfg: FZCacheData);
begin
  EnterCriticalSection(_cs);
  try
    cfg.servername:=self._data.servername;
    self._data := cfg;
    _ApplyConfig();
  finally
    LeaveCriticalSection(_cs);
  end;
end;

procedure FZConfigCache._ApplyConfig;
var
  sysmsgs_flags:FZSysmsgsCommonFlags;
begin
  FZLogMgr.Get.SetTargetSeverityLevel(self._data.log_severity);
  FZLogMgr.Get.SetFileLoggingStatus(self._data.external_log);

  sysmsgs_flags:=GetCommonSysmsgsFlags() and (FZ_SYSMSGS_FLAGS_ALL_ENABLED - FZ_SYSMSGS_ENABLE_LOGS);
  if self._data.log_severity <= FZLogMgr.NumberForSeverity(FZ_LOG_DBG) then begin
    sysmsgs_flags:=sysmsgs_flags or FZ_SYSMSGS_ENABLE_LOGS;
  end;
  SetCommonSysmsgsFlags(sysmsgs_flags);
end;

procedure FZConfigCache._LL_FillData;
var
  tmp:string;
begin
  self._data.allow_early_success_in_vote:=FZConfigMgr.Get.GetBool('allow_early_success_in_vote', true);
  self._data.allow_early_fail_in_vote:=FZConfigMgr.Get.GetBool('allow_early_fail_in_vote', true);
  self._data.is_cdkey_checking_disabled:=FZConfigMgr.Get.GetBool('is_cdkey_checking_disabled', true);
  self._data.is_same_cdkey_validated:=FZConfigMgr.Get.GetBool('is_same_cdkey_validated', true);
  self._data.min_players:=FZConfigMgr.Get.GetInt('mplc', 0);
  if _data.servername='' then begin
    if not FZConfigMgr.Get.GetData('servername', self._data.servername) then self._data.servername:='';
  end;
  self._data.ban_for_badpackets:=FZConfigMgr.Get.GetInt('ban_for_badpackets',0);
  self._data.is_strict_filter:=FZConfigMgr.Get.GetBool('is_strict_filter', false);
  self._data.use_skins_change:=FZConfigMgr.Get.GetBool('use_skins_change', false);
  self._data.use_item_change:=FZConfigMgr.Get.GetBool('use_item_change', false);
  self._data.no_same_cdkeys:=FZConfigMgr.Get.GetBool('no_same_cdkeys', true);
  self._data.vote_mute_time_ms:=FZConfigMgr.Get.GetInt('vote_mute_after_started_time_ms', 0);
  self._data.vote_mute_interval:=FZConfigMgr.Get.GetInt('vote_mute_interval', 0);
  self._data.vote_series_for_mute:=FZConfigMgr.Get.GetInt('vote_series_for_mute', 0);
  self._data.vote_first_mute_time:=FZConfigMgr.Get.GetInt('vote_first_mute_time', 0);
  self._data.censor_chat:=FZConfigMgr.Get.GetBool('censor_chat', true);
  self._data.chat_badwords_treasure:=FZConfigMgr.Get.GetInt('chat_badwords_treasure', 0);
  self._data.mutetime_per_badword:=FZConfigMgr.Get.GetInt('mutetime_per_badword', 0);
  self._data.radmins_see_other_team_chat:=FZConfigMgr.Get.GetBool('radmins_see_other_team_chat', true);
  self._data.enable_chat_commands:=FZConfigMgr.Get.GetBool('enable_chat_commands', true);
  self._data.chat_series_for_mute:=FZConfigMgr.Get.GetInt('chat_series_for_mute', 0);
  self._data.chat_series_interval:=FZConfigMgr.Get.GetInt('chat_series_interval', 0);
  self._data.chat_mute_time:=FZConfigMgr.Get.GetInt('chat_mute_time', 0);
  self._data.speech_series_for_mute:=FZConfigMgr.Get.GetInt('speech_series_for_mute', 0);
  self._data.speech_series_interval:=FZConfigMgr.Get.GetInt('speech_series_interval', 0);
  self._data.speech_mute_time:=FZConfigMgr.Get.GetInt('speech_mute_time', 0);
  self._data.teamchange_minimal_period:=FZConfigMgr.Get.GetInt('teamchange_minimal_period', 0);
  self._data.preserve_team_after_reconnect:=FZConfigMgr.Get.GetBool('preserve_team_after_reconnect', true);
  self._data.auto_update_rate:=FZConfigMgr.Get.GetBool('auto_update_rate', true);
  self._data.player_ready_signal_interval:=FZConfigMgr.Get.GetInt('player_ready_signal_interval', 500);
  self._data.ping_warnings_max_interval:=FZConfigMgr.Get.GetInt('ping_warnings_max_interval', 600000);

  //can_player_change_name в ТЧ может принимать также значение 2 - запрет переименований во время любого голосования и 3 - во время голосований на бан и кик
  self._data.can_player_change_name:=FZConfigMgr.Get.GetInt('can_player_change_name', -1);
  if (self._data.can_player_change_name < 0) then begin
    if FZConfigMgr.Get.GetBool('can_player_change_name', false) then begin
      self._data.can_player_change_name := FZ_CFG_CACHE_CHANGE_NAME_ENABLED;
    end else begin
      self._data.can_player_change_name := FZ_CFG_CACHE_CHANGE_NAME_DISABLED;
    end;
  end;

  FZConfigMgr.Get.GetBool('can_player_change_name', false);
  self._data.enable_map_downloader:=FZConfigMgr.Get.GetBool('enable_map_downloader', false);
  self._data.enable_maplist_sync:=FZConfigMgr.Get.GetBool('enable_maplist_sync', false);
  if not FZConfigMgr.Get.GetData('reconnect_ip', self._data.reconnect_ip) then self._data.reconnect_ip:='';
  self._data.reconnect_port:=FZConfigMgr.Get.GetInt('reconnect_port', 0);

  if not FZConfigMgr.Get.GetData('mod_crc32', tmp) then tmp:='0';
  self._data.mod_crc32:=FZCommonHelper.HexToInt(tmp);
  self._data.mod_compression_type:=FZConfigMgr.Get.GetInt('mod_compression_type', 0);
  if not FZConfigMgr.Get.GetData('mod_name', self._data.mod_name) then self._data.mod_name:='';
  if not FZConfigMgr.Get.GetData('mod_params', self._data.mod_params) then self._data.mod_params:='';
  if not FZConfigMgr.Get.GetData('mod_link', self._data.mod_link) then self._data.mod_link:='';
  if not FZConfigMgr.Get.GetData('mod_dsign', self._data.mod_dsign) then self._data.mod_dsign:='';

  self._data.mod_is_reconnect_needed:=FZConfigMgr.Get.GetBool('mod_is_reconnect_needed', false);
  self._data.mod_prefer_parent_appdata_for_maps:=FZConfigMgr.Get.GetBool('mod_prefer_parent_appdata_for_maps', false);

  self._data.allow_russian_nicknames:=FZConfigMgr.Get.GetBool('allow_russian_nicknames', false);
  self._data.hit_statistics_mode:=FZConfigMgr.Get.GetInt('hit_statistics_mode', 0);
  self._data.hit_analysis_level:=FZConfigMgr.Get.GetInt('hit_analysis_level', 0);

  self._data.strict_hwid:=FZConfigMgr.Get.GetBool('strict_hwid', false);

  self._data.log_severity:=FZConfigMgr.Get.GetInt('log_severity',FZ_LOG_DEFAULT_SEVERITY);
  self._data.external_log:=FZConfigMgr.Get.GetBool('external_log', false);
  self._data.log_events:=FZConfigMgr.Get.GetBool('log_events', false);
  self._data.log_ge_filter_errors:=FZConfigMgr.Get.GetBool('log_ge_filter_errors', true);
  self._data.antihacker:=FZConfigMgr.Get.GetBool('antihacker', false);

  self._data.new_chat_color_scheme:=FZConfigMgr.Get.GetBool('new_chat_color_scheme', true);

  self._data.radmins_see_sec_events:=FZConfigMgr.Get.GetBool('radmins_see_sec_events', true);
  self._data.sell_items_for_shophackers:=FZConfigMgr.Get.GetBool('sell_items_for_shophackers', false);

  if not FZConfigMgr.Get.GetData('banned_symbols', self._data.banned_symbols) then self._data.banned_symbols:='/|\"%$#@!&?'':*~ ';

  self._data.ip_checker_time_delta:=FZConfigMgr.Get.GetInt('ip_checker_time_delta', 60000);
  self._data.ip_checker_max_connections_per_delta_count:=FZConfigMgr.Get.GetInt('ip_checker_max_connections_per_delta_count', 3);

  self._data.preserve_map:=FZConfigMgr.Get.GetBool('preserve_map', false);
  self._data.mapchange_voting_lock_time:=FZConfigMgr.Get.GetInt('mapchange_voting_lock_time', 0);

  self._data.hit_correction_highscore_treasure:=FZConfigMgr.Get.GetFloat('hit_correction_highscore_treasure', 0);
  self._data.hit_correction_highscore_speed:=FZConfigMgr.Get.GetFloat('hit_correction_highscore_speed', 1);
  self._data.hit_correction_highscore_limit:=FZConfigMgr.Get.GetFloat('hit_correction_highscore_limit', 3);

  self._data.damage_correction_highscore_treasure:=FZConfigMgr.Get.GetFloat('damage_correction_highscore_treasure', 0);
  self._data.damage_correction_highscore_speed:=FZConfigMgr.Get.GetFloat('damage_correction_highscore_speed', 1);
  self._data.damage_correction_highscore_limit:=FZConfigMgr.Get.GetFloat('damage_correction_highscore_limit', 3);

  self._data.teamkill_decrease_rank:=FZConfigMgr.Get.GetBool('teamkill_decrease_rank', false);
  self._data.teamkill_decrease_money:=FZConfigMgr.Get.GetInt('teamkill_decrease_money', 0);
  self._data.teamkill_reparations_to_victim:=FZConfigMgr.Get.GetInt('teamkill_reparations_to_victim', 0);

  self._data.experience_speed:=FZConfigMgr.Get.GetFloat('experience_speed', 1.0);

  self._data.invincibility_after_shot:=FZConfigMgr.Get.GetBool('invincibility_after_shot', false);
end;

function Init():boolean; stdcall;
begin
  _instance:=FZConfigCache.Create();
  result:=true;
end;

end.
