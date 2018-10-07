unit Banned;
{$mode delphi}
interface
uses Vector, xrstrings, Packets, xr_time, Clients;

function Init():boolean; stdcall;

type
banned_client = packed record
  client_hexstr_digest:shared_str;
  client_ip_addr:ip_address;
  client_name:shared_str;
  _unused1:cardinal;
  ban_start_time:time_t;
  ban_end_time:time_t;
  admin_ip_addr:ip_address;
  admin_name:shared_str;
  admin_hexstr_digest:shared_str;
end;

pbanned_client = ^banned_client;
ppbanned_client = ^pbanned_client;

cdkey_ban_list = packed record
  m_ban_list:xr_vector; {banned_client*}
end;
pcdkey_ban_list = ^cdkey_ban_list;

function IsPlayerBanned(banlist:pcdkey_ban_list; digest:string):boolean;
function CheckDigestForBan(banlist:pcdkey_ban_list; digest:string):pbanned_client;
function BanPlayerByDigest(banlist: pcdkey_ban_list; digest: string; time:integer; admin:pxrClientData):pbanned_client;
procedure SaveBanList(banlist: pcdkey_ban_list);

implementation
uses basedefs, SrcCalls, xr_debug;

var
  cdkey_ban_list__is_player_banned:srcEAXCallFunction;
  cdkey_ban_list__erase_expired_ban_items:srcEDICallFunction;
  cdkey_ban_list__ban_player_ll:srcEAXCallFunction;
  cdkey_ban_list__save:srcEAXCallFunction;

function IsPlayerBanned(banlist:pcdkey_ban_list; digest:string):boolean;
var
  str:shared_str;
begin
 init_string(@str);
 result:=cdkey_ban_list__is_player_banned.Call([banlist, PAnsiChar(digest), @str]).VBoolean;
 assign_string(@str, nil);
end;

function CheckDigestForBan(banlist: pcdkey_ban_list; digest: string): pbanned_client;
var
  i:integer;
  cl:pbanned_client;
begin
  result:=nil;
  cdkey_ban_list__erase_expired_ban_items.Call([banlist]);

  for i:=items_count_in_vector(@banlist.m_ban_list, sizeof(pbanned_client))-1 downto 0 do begin
    cl:=ppbanned_client(get_item_from_vector(@banlist.m_ban_list, i, sizeof(pbanned_client)))^;
    R_ASSERT(cl<>nil, 'Invalid banned client', 'CheckDigestForBan');
    if digest = get_string_value(@cl.client_hexstr_digest) then begin
      result:=cl;
      break;
    end;
  end;
end;

function BanPlayerByDigest(banlist: pcdkey_ban_list; digest: string; time:integer; admin:pxrClientData):pbanned_client;
begin
  result:=nil;
  if CheckDigestForBan(banlist, digest) <> nil then exit;
  //Внимание! Вызов задом наперед - в EAX пойдет время бана, на стек - указатель на банлист! так и задумано!
  cdkey_ban_list__ban_player_ll.Call([PAnsiChar(digest), banlist, time, admin]);
  result:=CheckDigestForBan(banlist, digest);
end;

procedure SaveBanList(banlist: pcdkey_ban_list);
begin
  cdkey_ban_list__save.Call([banlist]);
end;

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    cdkey_ban_list__is_player_banned:=srcEAXCallFunction.Create(pointer(xrGame+$309390), [vtPointer, vtPChar, vtPointer], 'is_player_banned', 'cdkey_ban_list');
    cdkey_ban_list__erase_expired_ban_items:=srcEDICallFunction.Create(pointer(xrGame+$309e90), [vtPointer], 'erase_expired_ban_items', 'cdkey_ban_list');
    cdkey_ban_list__ban_player_ll:=srcEAXCallFunction.Create(pointer(xrGame+$309660), [vtPChar, vtPointer, vtInteger, vtPointer], 'ban_player_ll', 'cdkey_ban_list');
    cdkey_ban_list__save:=srcEAXCallFunction.Create(pointer(xrGame+$3092e0), [vtPointer], 'save', 'cdkey_ban_list');
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    cdkey_ban_list__is_player_banned:=srcEAXCallFunction.Create(pointer(xrGame+$31f1d0), [vtPointer, vtPChar, vtPointer], 'is_player_banned', 'cdkey_ban_list');
    cdkey_ban_list__erase_expired_ban_items:=srcEDICallFunction.Create(pointer(xrGame+$31fcd0), [vtPointer], 'erase_expired_ban_items', 'cdkey_ban_list');
    cdkey_ban_list__ban_player_ll:=srcEAXCallFunction.Create(pointer(xrGame+$31f4a0), [vtPChar, vtPointer, vtInteger, vtPointer], 'ban_player_ll', 'cdkey_ban_list');
    cdkey_ban_list__save:=srcEAXCallFunction.Create(pointer(xrGame+$31f120), [vtPointer], 'save', 'cdkey_ban_list');
  end;
  result:=true;
end;

end.
