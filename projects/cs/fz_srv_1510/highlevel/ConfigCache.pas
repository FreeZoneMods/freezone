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

  chat_series_for_mute:cardinal;
  chat_series_interval:cardinal;
  chat_mute_time:cardinal;

  speech_series_for_mute:cardinal;
  speech_series_interval:cardinal;
  speech_mute_time:cardinal;

  player_ready_signal_interval:cardinal;
  ping_warnings_max_interval:cardinal;
  auto_update_rate:boolean;
  can_player_change_name:boolean;
  enable_map_downloader:boolean;
  clean_download_mode:boolean;
  reconnect_ip:string;
  reconnect_port:cardinal;
  mod_name:string;
  mod_link:string;
  mod_CRC32:cardinal;
  mod_xml:string;
  mod_team1_color:cardinal;
  mod_team2_color:cardinal;
  mod_chat_team1:string;
  mod_chat_team2:string;
  mod_patch_butcher:boolean;
  mod_change_team_color:boolean;
  allow_russian_nicknames:boolean;
  hit_statistics_mode:cardinal;
  enable_maplist_sync:boolean;
end;
pFZCacheData = ^FZCacheData;

FZConfigCache = class
protected
  _cs:TRTLCriticalSection;
  _data:FZCacheData;
  procedure _LL_FillData();
public
  class function Get():FZConfigCache;
  constructor Create();
  destructor Destroy(); override;
  procedure GetDataCopy(dest:pFZCacheData); overload;
  function GetDataCopy():FZCacheData; overload;
  procedure Reload();
end;

function Init():boolean; stdcall;

implementation
uses ConfigMgr, Console, LogMgr, sysutils, CommonHelper;
var
  _instance:FZConfigCache;

procedure ReloadFZConfig_info(info:PChar); stdcall;
begin
  strcopy(info, 'Updates data from FreeZone config in the run-time');
end;

procedure ReloadFZConfig_execute(arg:PChar); stdcall;
begin
  FZConfigCache.Get.Reload;
  FZLogMgr.Get.Write('Config reloaded.');
end;

function Init():boolean; stdcall;
begin
  AddConsoleCommand('fz_reload_config',@ReloadFZConfig_execute, @ReloadFZConfig_info);
  _instance:=nil;
  result:=true;
end;


{ FZConfigCache }

constructor FZConfigCache.Create;
begin
  InitializeCriticalSection(_cs);
  Reload();
end;

destructor FZConfigCache.Destroy;
begin
  inherited;
  DeleteCriticalSection(_cs);
end;

class function FZConfigCache.Get: FZConfigCache;
begin
  if _instance=nil then begin
    _instance:=FZConfigCache.Create;
  end;
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
  finally
    LeaveCriticalSection(_cs);
  end;
end;

procedure FZConfigCache._LL_FillData;
var
  tmp:string;
begin
  self._data.allow_early_success_in_vote:=FZConfigMgr.Get.GetBool('allow_early_success_in_vote', true);
  self._data.allow_early_fail_in_vote:=FZConfigMgr.Get.GetBool('allow_early_fail_in_vote', true);
  self._data.is_cdkey_checking_disabled:=FZConfigMgr.Get.GetBool('is_cdkey_checking_disabled', true);
  self._data.is_same_cdkey_validated:=FZConfigMgr.Get.GetBool('is_same_cdkey_validated', true);
  if not FZConfigMgr.Get.GetData('servername', self._data.servername) then self._data.servername:='';
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
  self._data.chat_series_for_mute:=FZConfigMgr.Get.GetInt('chat_series_for_mute', 0);
  self._data.chat_series_interval:=FZConfigMgr.Get.GetInt('chat_series_interval', 0);
  self._data.chat_mute_time:=FZConfigMgr.Get.GetInt('chat_mute_time', 0);
  self._data.speech_series_for_mute:=FZConfigMgr.Get.GetInt('speech_series_for_mute', 0);
  self._data.speech_series_interval:=FZConfigMgr.Get.GetInt('speech_series_interval', 0);
  self._data.speech_mute_time:=FZConfigMgr.Get.GetInt('speech_mute_time', 0);
  self._data.auto_update_rate:=FZConfigMgr.Get.GetBool('auto_update_rate', true);
  self._data.player_ready_signal_interval:=FZConfigMgr.Get.GetInt('player_ready_signal_interval', 500);
  self._data.ping_warnings_max_interval:=FZConfigMgr.Get.GetInt('ping_warnings_max_interval', 600000);
  self._data.can_player_change_name:=FZConfigMgr.Get.GetBool('can_player_change_name', false);
  self._data.enable_map_downloader:=FZConfigMgr.Get.GetBool('enable_map_downloader', false);
  self._data.enable_maplist_sync:=FZConfigMgr.Get.GetBool('enable_maplist_sync', false);
  if not FZConfigMgr.Get.GetData('reconnect_ip', self._data.reconnect_ip) then self._data.reconnect_ip:='';
  self._data.reconnect_port:=FZConfigMgr.Get.GetInt('reconnect_port', 0);
  self._data.clean_download_mode:=FZConfigMgr.Get.GetBool('clean_download_mode', false);

  if not FZConfigMgr.Get.GetData('mod_crc32', tmp) then tmp:='0';
  self._data.mod_crc32:=FZCommonHelper.HexToInt(tmp);

  if not FZConfigMgr.Get.GetData('mod_name', self._data.mod_name) then self._data.mod_name:='';
  if not FZConfigMgr.Get.GetData('mod_link', self._data.mod_link) then self._data.mod_link:='';
  if not FZConfigMgr.Get.GetData('mod_xml', self._data.mod_xml) then self._data.mod_xml:='';
  self._data.mod_patch_butcher:=FZConfigMgr.Get.GetBool('mod_patch_butcher', true);

  if not FZConfigMgr.Get.GetData('mod_team1_color', tmp) then tmp:='0';
  self._data.mod_team1_color:=FZCommonHelper.HexToInt(tmp);
  if not FZConfigMgr.Get.GetData('mod_team2_color', tmp) then tmp:='0';
  self._data.mod_team2_color:=FZCommonHelper.HexToInt(tmp);


  self._data.mod_change_team_color:=FZConfigMgr.Get.GetBool('mod_change_team_color', true);
  if not FZConfigMgr.Get.GetData('mod_chat_team1', self._data.mod_chat_team1) then self._data.mod_chat_team1:='';
  if not FZConfigMgr.Get.GetData('mod_chat_team2', self._data.mod_chat_team2) then self._data.mod_chat_team2:='';

  self._data.allow_russian_nicknames:=FZConfigMgr.Get.GetBool('allow_russian_nicknames', false);
  self._data.hit_statistics_mode:=FZConfigMgr.Get.GetInt('hit_statistics_mode', 0);

end;

end.
