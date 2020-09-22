unit Schedule;
{$mode delphi}
{$I _pathes.inc}

interface

type ISheduled = packed record
  vftable:pointer;
  shedule:cardinal; //bitset really
end;
type pISheduled = ^ISheduled;

implementation

end.
