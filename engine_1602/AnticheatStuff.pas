unit AnticheatStuff;
{$mode delphi}
{$I _pathes.inc}
interface

type

IAnticheatDumpable = packed record
  vtable:pointer;
end;

file_transfer__client_site = packed record
  //todo:fill;
end;
pfile_transfer__client_site = ^file_transfer__client_site;

implementation

end.
