unit GameMessages;
{$mode delphi}
{$I _pathes.inc}
interface
function Init():boolean; stdcall;

type
secure_messaging__key_t = packed record
  m_key_length:cardinal;
  m_key:array[0..31] of integer;
end;

implementation

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
