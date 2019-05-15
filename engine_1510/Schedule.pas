unit Schedule;
{$mode delphi}
{$I _pathes.inc}
interface

type ISheduled = packed record
  vftable:pointer;
  shedule:word; //bitset really
  _unused:word;
end;
type pISheduled = ^ISheduled;

implementation

end.
