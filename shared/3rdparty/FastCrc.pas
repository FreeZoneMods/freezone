unit FastCrc;

{$mode delphi}
interface

type
TCRC32Context = record
  temp_crc32:cardinal;
end;

function CRC32Start():TCRC32Context;
procedure CRC32Update(var ctx:TCRC32Context; StPtr: pointer; StLen: integer);
function CRC32End(var ctx:TCRC32Context; StPtr: pointer; StLen: integer):cardinal;

//Calc for memory block
function GetMemCRC32(StPtr: pointer; StLen: integer): cardinal;

//Calc for specified file
function GetFileCRC32(const FileName: string): cardinal;

implementation
var
  CRC32table: array[0..255] of cardinal;

function GetNewCRC32(OldCRC: cardinal; StPtr: pointer; StLen: integer): cardinal;
asm
  test edx,edx;
  jz @ret;
  neg ecx;
  jz @ret;
  sub edx,ecx; // Address after last element

  push ebx;
  xor ebx,ebx; // Set ebx=0 & align @next
@next:
  mov bl,al;
  xor bl,byte [edx+ecx];
  shr eax,8;
  xor eax,cardinal [CRC32table+ebx*4];
  inc ecx;
  jnz @next;
  pop ebx;

@ret:
end;

function CRC32Start: TCRC32Context;
begin
  result.temp_crc32:=$FFFFFFFF;
end;

procedure CRC32Update(var ctx: TCRC32Context; StPtr: pointer; StLen: integer);
begin
  ctx.temp_crc32 := GetNewCRC32(ctx.temp_crc32, StPtr, StLen);
end;

function CRC32End(var ctx:TCRC32Context; StPtr: pointer; StLen: integer):cardinal;
begin
  if StLen>0 then begin
    ctx.temp_crc32:=GetNewCRC32(ctx.temp_crc32, StPtr, StLen);
  end;
  result:=not ctx.temp_crc32;
end;

function GetMemCRC32(StPtr: pointer; StLen: integer): cardinal;
begin
  Result := not GetNewCRC32($FFFFFFFF, StPtr, StLen);
end;

function GetFileCRC32(const FileName: string): cardinal;
const
  BufSize = 64 * 1024;
var
  Fi: file;
  pBuf: PChar;
  Count: integer;
begin
  Assign(Fi, FileName);
  Reset(Fi, 1);
  GetMem(pBuf, BufSize);
  Result := $FFFFFFFF;
  Count:=0;
  repeat
    BlockRead(Fi, pBuf^, BufSize, Count);
    if Count = 0 then
      break;
    Result := GetNewCRC32(Result, pBuf, Count);
  until false;
  Result := not Result;
  FreeMem(pBuf);
  CloseFile(Fi);
end;

procedure CRC32Init;
var
  c: cardinal;
  i, j: integer;
begin
  for i := 0 to 255 do
  begin
    c := i;
    for j := 1 to 8 do
      if odd(c) then
        c := (c shr 1) xor $EDB88320
      else
        c := (c shr 1);
    CRC32table[i] := c;
  end;
end;

initialization
  CRC32init;
end.
