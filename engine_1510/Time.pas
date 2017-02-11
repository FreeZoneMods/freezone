unit Time;
{$mode delphi}
interface
function Init():boolean; stdcall;

type
CTimer = packed record
  //TODO:fill
end;
pCTimer = ^CTimer;


implementation


function Init():boolean; stdcall;
begin
 result:=true;
end;

end.
