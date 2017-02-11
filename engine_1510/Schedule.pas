unit Schedule;
{$mode delphi}
interface

type IScheduled = packed record
  vftable:pointer;
  shedule:word; //bitset really
  _unused:word;
end;
type pIScheduled = ^IScheduled;

implementation

end.
