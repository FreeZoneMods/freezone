unit Items;
{$mode delphi}
interface

function Init():boolean; stdcall;

type
CItemMgr = packed record
//todo:fill
end;

pCItemMgr=^CItemMgr;

implementation

function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
