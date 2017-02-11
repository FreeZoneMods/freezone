unit Banned;
{$mode delphi}
interface
uses Vector;

function Init():boolean; stdcall;

type cdkey_ban_list = packed record
  m_ban_list:xr_vector;
end;

implementation


function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
