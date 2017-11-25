unit FastMd5;

{$mode delphi}

interface

type
TMD5Hash = Array[0..3] of DWORD;

TMD5Context = record
  hashed_size:Int64;
  temp_hash:TMD5Hash;
end;

function MD5Start():TMD5Context;
function MD5Next(var ctx: TMD5Context; blocks: pointer; blocks_count:cardinal):pointer;
function MD5BlockSize: cardinal;
function MD5End(var ctx:TMD5Context; last_block:pointer; last_block_size:cardinal):string;
function MD5GetRaw(ctx:TMD5Context; var md5:TMD5Hash):boolean;

//Buf_size must be not lower than ALIGN_UP(data_size+65, 64), unused stuff must be 0
function CalcMD5(src:pointer; data_size:LongWord; buf_size:LongWord): String;

implementation
uses SysUtils, windows;

{$R-,Q-}

const
  HashSize = 16;
  BuffSize = 64;


function LRot32(A: DWORD; B: Byte): DWORD;
begin
  Result:= (A shl B) or (A shr (32-B));
end;

procedure Compressor(Hash, Buffer: Pointer; IV: LongWord = 0);
var
  A, B, C, D: DWORD;
begin
  A := pDWORD(Hash)[0];
  B := pDWORD(Hash)[1];
  C := pDWORD(Hash)[2];
  D := pDWORD(Hash)[3];
  Buffer := Pointer(DWORD(Buffer) + IV);
  //
  A := B + LRot32(A + (D xor (B and (C xor D))) + pDWORD(Buffer)[ 0] + $D76AA478,  7);
  D := A + LRot32(D + (C xor (A and (B xor C))) + pDWORD(Buffer)[ 1] + $E8C7B756, 12);
  C := D + LRot32(C + (B xor (D and (A xor B))) + pDWORD(Buffer)[ 2] + $242070DB, 17);
  B := C + LRot32(B + (A xor (C and (D xor A))) + pDWORD(Buffer)[ 3] + $C1BDCEEE, 22);
  A := B + LRot32(A + (D xor (B and (C xor D))) + pDWORD(Buffer)[ 4] + $F57C0FAF,  7);
  D := A + LRot32(D + (C xor (A and (B xor C))) + pDWORD(Buffer)[ 5] + $4787C62A, 12);
  C := D + LRot32(C + (B xor (D and (A xor B))) + pDWORD(Buffer)[ 6] + $A8304613, 17);
  B := C + LRot32(B + (A xor (C and (D xor A))) + pDWORD(Buffer)[ 7] + $FD469501, 22);
  A := B + LRot32(A + (D xor (B and (C xor D))) + pDWORD(Buffer)[ 8] + $698098D8,  7);
  D := A + LRot32(D + (C xor (A and (B xor C))) + pDWORD(Buffer)[ 9] + $8B44F7AF, 12);
  C := D + LRot32(C + (B xor (D and (A xor B))) + pDWORD(Buffer)[10] + $FFFF5BB1, 17);
  B := C + LRot32(B + (A xor (C and (D xor A))) + pDWORD(Buffer)[11] + $895CD7BE, 22);
  A := B + LRot32(A + (D xor (B and (C xor D))) + pDWORD(Buffer)[12] + $6B901122,  7);
  D := A + LRot32(D + (C xor (A and (B xor C))) + pDWORD(Buffer)[13] + $FD987193, 12);
  C := D + LRot32(C + (B xor (D and (A xor B))) + pDWORD(Buffer)[14] + $A679438E, 17);
  B := C + LRot32(B + (A xor (C and (D xor A))) + pDWORD(Buffer)[15] + $49B40821, 22);

  A := B + LRot32(A + (C xor (D and (B xor C))) + pDWORD(Buffer)[ 1] + $F61E2562,  5);
  D := A + LRot32(D + (B xor (C and (A xor B))) + pDWORD(Buffer)[ 6] + $C040B340,  9);
  C := D + LRot32(C + (A xor (B and (D xor A))) + pDWORD(Buffer)[11] + $265E5A51, 14);
  B := C + LRot32(B + (D xor (A and (C xor D))) + pDWORD(Buffer)[ 0] + $E9B6C7AA, 20);
  A := B + LRot32(A + (C xor (D and (B xor C))) + pDWORD(Buffer)[ 5] + $D62F105D,  5);
  D := A + LRot32(D + (B xor (C and (A xor B))) + pDWORD(Buffer)[10] + $02441453,  9);
  C := D + LRot32(C + (A xor (B and (D xor A))) + pDWORD(Buffer)[15] + $D8A1E681, 14);
  B := C + LRot32(B + (D xor (A and (C xor D))) + pDWORD(Buffer)[ 4] + $E7D3FBC8, 20);
  A := B + LRot32(A + (C xor (D and (B xor C))) + pDWORD(Buffer)[ 9] + $21E1CDE6,  5);
  D := A + LRot32(D + (B xor (C and (A xor B))) + pDWORD(Buffer)[14] + $C33707D6,  9);
  C := D + LRot32(C + (A xor (B and (D xor A))) + pDWORD(Buffer)[ 3] + $F4D50D87, 14);
  B := C + LRot32(B + (D xor (A and (C xor D))) + pDWORD(Buffer)[ 8] + $455A14ED, 20);
  A := B + LRot32(A + (C xor (D and (B xor C))) + pDWORD(Buffer)[13] + $A9E3E905,  5);
  D := A + LRot32(D + (B xor (C and (A xor B))) + pDWORD(Buffer)[ 2] + $FCEFA3F8,  9);
  C := D + LRot32(C + (A xor (B and (D xor A))) + pDWORD(Buffer)[ 7] + $676F02D9, 14);
  B := C + LRot32(B + (D xor (A and (C xor D))) + pDWORD(Buffer)[12] + $8D2A4C8A, 20);

  A := B + LRot32(A + (B xor C xor D) + pDWORD(Buffer)[ 5] + $FFFA3942,  4);
  D := A + LRot32(D + (A xor B xor C) + pDWORD(Buffer)[ 8] + $8771f681, 11);
  C := D + LRot32(C + (D xor A xor B) + pDWORD(Buffer)[11] + $6D9D6122, 16);
  B := C + LRot32(B + (C xor D xor A) + pDWORD(Buffer)[14] + $FDE5380C, 23);
  A := B + LRot32(A + (B xor C xor D) + pDWORD(Buffer)[ 1] + $A4BEEA44,  4);
  D := A + LRot32(D + (A xor B xor C) + pDWORD(Buffer)[ 4] + $4BDECFA9, 11);
  C := D + LRot32(C + (D xor A xor B) + pDWORD(Buffer)[ 7] + $F6BB4B60, 16);
  B := C + LRot32(B + (C xor D xor A) + pDWORD(Buffer)[10] + $BEBFBC70, 23);
  A := B + LRot32(A + (B xor C xor D) + pDWORD(Buffer)[13] + $289B7EC6,  4);
  D := A + LRot32(D + (A xor B xor C) + pDWORD(Buffer)[ 0] + $EAA127FA, 11);
  C := D + LRot32(C + (D xor A xor B) + pDWORD(Buffer)[ 3] + $D4EF3085, 16);
  B := C + LRot32(B + (C xor D xor A) + pDWORD(Buffer)[ 6] + $04881D05, 23);
  A := B + LRot32(A + (B xor C xor D) + pDWORD(Buffer)[ 9] + $D9D4D039,  4);
  D := A + LRot32(D + (A xor B xor C) + pDWORD(Buffer)[12] + $E6DB99E5, 11);
  C := D + LRot32(C + (D xor A xor B) + pDWORD(Buffer)[15] + $1FA27CF8, 16);
  B := C + LRot32(B + (C xor D xor A) + pDWORD(Buffer)[ 2] + $C4AC5665, 23);

  A := B + LRot32(A + (C xor (B or (not D))) + pDWORD(Buffer)[ 0] + $F4292244,  6);
  D := A + LRot32(D + (B xor (A or (not C))) + pDWORD(Buffer)[ 7] + $432AFF97, 10);
  C := D + LRot32(C + (A xor (D or (not B))) + pDWORD(Buffer)[14] + $AB9423A7, 15);
  B := C + LRot32(B + (D xor (C or (not A))) + pDWORD(Buffer)[ 5] + $FC93A039, 21);
  A := B + LRot32(A + (C xor (B or (not D))) + pDWORD(Buffer)[12] + $655B59C3,  6);
  D := A + LRot32(D + (B xor (A or (not C))) + pDWORD(Buffer)[ 3] + $8F0CCC92, 10);
  C := D + LRot32(C + (A xor (D or (not B))) + pDWORD(Buffer)[10] + $FFEFF47D, 15);
  B := C + LRot32(B + (D xor (C or (not A))) + pDWORD(Buffer)[ 1] + $85845DD1, 21);
  A := B + LRot32(A + (C xor (B or (not D))) + pDWORD(Buffer)[ 8] + $6FA87E4F,  6);
  D := A + LRot32(D + (B xor (A or (not C))) + pDWORD(Buffer)[15] + $FE2CE6E0, 10);
  C := D + LRot32(C + (A xor (D or (not B))) + pDWORD(Buffer)[ 6] + $A3014314, 15);
  B := C + LRot32(B + (D xor (C or (not A))) + pDWORD(Buffer)[13] + $4E0811A1, 21);
  A := B + LRot32(A + (C xor (B or (not D))) + pDWORD(Buffer)[ 4] + $F7537E82,  6);
  D := A + LRot32(D + (B xor (A or (not C))) + pDWORD(Buffer)[11] + $BD3AF235, 10);
  C := D + LRot32(C + (A xor (D or (not B))) + pDWORD(Buffer)[ 2] + $2AD7D2BB, 15);
  B := C + LRot32(B + (D xor (C or (not A))) + pDWORD(Buffer)[ 9] + $EB86D391, 21);
  //
  Inc(pDWORD(Hash)[0], A);
  Inc(pDWORD(Hash)[1], B);
  Inc(pDWORD(Hash)[2], C);
  Inc(pDWORD(Hash)[3], D);
end;

function HashToStr(Hash: Pointer): String;
var
  i: Byte;
begin
  Result := '';
  for i := 0 to HashSize - 1 do
    Result := Result + IntToHex(pBYTE(Hash)[i], 2);
end;

function MD5Start(): TMD5Context;
begin
  result.temp_hash[0] := $67452301;
  result.temp_hash[1] := $EFCDAB89;
  result.temp_hash[2] := $98BADCFE;
  result.temp_hash[3] := $10325476;
  result.hashed_size:=0;
end;

function MD5BlockSize: cardinal;
begin
  result:=BuffSize;
end;

function MD5Next(var ctx: TMD5Context; blocks: pointer; blocks_count:cardinal):pointer;
var
  i:cardinal;
begin
  for i:=0 to blocks_count-1 do begin
    Compressor(@ctx.temp_hash, blocks, 0);
    blocks:=@(PChar(blocks)[BuffSize]);
  end;
  ctx.hashed_size:=ctx.hashed_size+(Int64(BuffSize) * Int64(blocks_count));
  result:=blocks;
end;

function MD5End(var ctx:TMD5Context; last_block:pointer; last_block_size:cardinal):string;
var
  workarea:array[0..127] of char;
  aligned_block:PChar;
  r:cardinal;
begin
  if (last_block_size >= BuffSize) then begin
    last_block:=MD5Next(ctx, last_block, last_block_size div BuffSize);
    last_block_size:=last_block_size{%H-}-(last_block_size div BuffSize)*BuffSize;
  end;
  ctx.hashed_size:=ctx.hashed_size+last_block_size;
  FillMemory(@workarea[0], length(workarea), 0);
  MoveMemory(@workarea[0], last_block, last_block_size);
  workarea[last_block_size]:=CHR($80);
  Inc(last_block_size);

  r:= last_block_size mod BuffSize;
  if ( r=0 ) or ( r > 56) then begin
    Compressor(@ctx.temp_hash, @workarea[0], 0);
    aligned_block:=@workarea[BuffSize];
  end else begin
    aligned_block:=@workarea[0];
  end;

  pInt64(@aligned_block[BuffSize-sizeof(ctx.hashed_size)])^:=ctx.hashed_size * 8;

  Compressor(@ctx.temp_hash, aligned_block, 0);
  Result := LowerCase(HashToStr(@ctx.temp_hash));
end;

//Buf_size must be not lower than ALIGN_UP(data_size+65, 64), unused stuff must be 0
function CalcMD5(src:pointer; data_size:LongWord; buf_size:LongWord): String;
var
  CurrentHash: TMD5Hash;
  Len: LongWord;
  i: LongWord;
  BitLen64:Int64;

begin
  Result := '';
  if (buf_size < (((data_size+65) div 64)+1)*64) or (buf_size > 100*1024*1024) then begin
    exit;
  end;

  Len := data_size;
  BitLen64 := Int64(Len) * 8;

  PChar(src)[data_size] := CHR($80);
  Inc(Len);

  for i := data_size+1 to buf_size - 1 do begin
    PChar(src)[i] := CHR($00);
  end;

  if Len mod BuffSize > 56 then begin
    Len:=((Len div BuffSize)+2)*BuffSize;
  end else begin
    Len:=((Len div BuffSize)+1)*BuffSize;
  end;

  pInt64(@(PChar(src)[Len-8]))^:=BitLen64;

  CurrentHash[0] := $67452301;
  CurrentHash[1] := $EFCDAB89;
  CurrentHash[2] := $98BADCFE;
  CurrentHash[3] := $10325476;

  for i := 0 to (Len div BuffSize) - 1 do
      Compressor(@CurrentHash, PChar(src), i * BuffSize);

  Result := LowerCase(HashToStr(@CurrentHash));
end;

function MD5GetRaw(ctx:TMD5Context; var md5:TMD5Hash):boolean;
begin
  result:=true;
  md5[0]:=ctx.temp_hash[0];
  md5[1]:=ctx.temp_hash[1];
  md5[2]:=ctx.temp_hash[2];
  md5[3]:=ctx.temp_hash[3];
end;

end.

