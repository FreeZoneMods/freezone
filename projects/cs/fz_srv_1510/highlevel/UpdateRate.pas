unit UpdateRate;
{$mode delphi}
interface
uses Clients, PureServer;

function SelectUpdRateByPing(ping:integer):cardinal;
function SelectUpdRate({%H-}srv:pIPureServer; cl:pIClient; cur_updrate:cardinal):cardinal; stdcall;
function xrServer__Process_event_change_shooting_packets_proority():cardinal;stdcall;

function Init():boolean;

implementation
uses sysutils, Players, dynamic_caster, basedefs, ConfigCache, Packets, Console;


var
  max_updrate:cardinal;

function SelectUpdRate(srv:pIPureServer; cl:pIClient; cur_updrate:cardinal):cardinal; stdcall;
var
  cld:pxrClientData;
begin
  result:=cur_updrate;
  if not FZConfigCache.Get.GetDataCopy.auto_update_rate then exit;

  cld:=dynamic_cast(cl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cld=nil) or (cld.ps.ping=0) then exit;

  result:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).updrate;
  if (result=0) then begin
    //не проинициализирован
    FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).updrate:=SelectUpdRateByPing(cld.ps.ping);
    result:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).updrate;
  end;

  if result>max_updrate then begin
    result:=max_updrate;
  end;
end;

function SelectUpdRateByPing(ping:integer):cardinal;
begin
  case ping of
    0..20: result:=200;
    21..30: result:=150;
    31..40: result:=110;
    41..50: result:=100;
    51..60: result:=90;
    61..70: result:=80;
    71..80: result:=70;
    81..90: result:=60;
    91..100: result:=50;
    101..120: result:=40;
    121..140: result:=30;
    141..160: result:=20;
  else
    result:=10;
  end;
end;

function xrServer__Process_event_change_shooting_packets_proority():cardinal;stdcall;
begin
  result:=DPNSEND_IMMEDIATELLY or DPNSEND_PRIORITY_HIGH or DPNSEND_GUARANTEED;
end;

var
  c_max_updrate:CCC_Integer;
function Init():boolean;
begin
  max_updrate:=200;

  CCC_Integer__CCC_Integer.Call([@c_max_updrate, 'fz_max_update_rate', @max_updrate, 10, 1000]) ;
  CConsole__AddCommand.Call([g_ppConsole^, @c_max_updrate]);
  result:=true;
end;

end.
