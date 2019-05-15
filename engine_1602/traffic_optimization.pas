unit traffic_optimization;

{$mode delphi}
{$I _pathes.inc}

interface

type
compression__ppmd_trained_stream = packed record
  //todo:fill;
end;
pcompression__ppmd_trained_stream = ^compression__ppmd_trained_stream;

compression__lzo_dictionary_buffer = packed record
  data:pointer;
  size:cardinal;
end;

implementation

end.

