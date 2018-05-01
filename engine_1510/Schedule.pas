unit Schedule;
{$mode delphi}
interface

type ISheduled = packed record
  vftable:pointer;
  shedule:word; //bitset really
  _unused:word;
end;
type pISheduled = ^ISheduled;

implementation

end.
