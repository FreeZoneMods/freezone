unit Keys;
{$mode delphi}
interface

function ConvertToBase32(pcIn:PAnsiChar; nInBytes:integer):string; stdcall;
function ConvertFromBase32(pcIn:PAnsiChar; nInBytes:integer):string;
function GenerateKey(data:pbyte; data_size:cardinal; use_separators:boolean=true):string;
function GenerateRandomKey(use_separators:boolean=true):string;

implementation
uses Windows;

function CreateCheck(key:pbyte; keylen:integer; cskey:word):word; stdcall;
var
  i:integer;
  check:cardinal;
begin
  check:=0;
  for i:=0 to keylen-1 do begin
    check:=cardinal(Int64(check)*$9CCF9319);
    check:=cardinal(check+key^);
    key:=pbyte(uintptr(key)+sizeof(byte));
  end;
  result:=(check mod 65521) xor cskey;
end;

procedure RightShift(pc:PChar; s:integer; n:integer); stdcall;
var
  i:integer;
begin
  for i:=0 to s-2 do begin
    pc[i]:= char(byte(pc[i]) shr n);
    pc[i]:= char(byte(pc[i]) or (byte(pc[i+1]) shl (8-n)));
  end;
  pc[s-1] := char(byte(pc[s-1]) shr n);
end;

procedure LeftShift(pc:PChar; s:integer; n:integer); stdcall;
var
  i:integer;
begin
  for i:=s-1 downto 1 do begin
    pc[i]:= char(byte(pc[i]) shl n);
    pc[i]:= char(byte(pc[i]) or (byte(pc[i-1]) shr (8-n)));
  end;
  pc[0] := char(byte(pc[0]) shl n);
end;

function ConvertToBase32(pcIn:PAnsiChar; nInBytes:integer):string; stdcall;
const
  gpcBase32Set:PChar='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
var
  acShift:array[0..4] of byte;
  i, nCopyableBytes, nOutBytes:integer;
begin
  for i:=0 to 4 do begin
    acShift[i]:=0;
  end;

  result:='';
  while (nInBytes>0) do begin

    if nInBytes>5 then begin
      nCopyableBytes :=5;
    end else begin
      nCopyableBytes :=nInBytes;
    end;
    nOutBytes:= ((nCopyableBytes*8)+4) div 5;

    for i:=0 to nCopyableBytes-1 do begin
      acShift[i]:=byte(pcIn[i]);
    end;

    pcIn:= PChar(cardinal(pcIn)+cardinal(nCopyableBytes));
    nInBytes:=nInBytes-nCopyableBytes;

    for i:=0 to nOutBytes-1 do begin
      result:=result+gpcBase32Set[acShift[0] and $1F];
      RightShift(PAnsiChar(@acShift[0]), 5,5);
    end;
  end;
end;

function Base32Value(ch:char):integer;
const
  gpcBase32Set:string='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  result:=Pos(ch, gpcBase32Set)-1;
end;

function ConvertFromBase32(pcIn:PAnsiChar; nInBytes:integer):string;
var
  pcCursor:PAnsiChar;
  acShift:array[0..4] of byte;
  acWorkCopy:array[0..7] of byte;
  nValue, i, nCopyableBytes, nOutBytes:integer;
begin
	pcCursor := pcIn;
  result:='';

	while (nInBytes > 0) do begin
    if nInBytes > 8 then nCopyableBytes := 8 else nCopyableBytes := nInBytes;
		nOutBytes := (nCopyableBytes * 5) div 8;

    for i:=0 to 4 do begin
      acShift[i]:=0;
    end;

		for i := 0 to nCopyableBytes - 1 do begin
			acWorkCopy[i] := Byte(pcCursor[nCopyableBytes - i - 1]);
		end;

		pcCursor := @pcCursor[nCopyableBytes];

		for i := 0 to nCopyableBytes-1 do begin
			// Make room for new bits
			LeftShift(PAnsiChar(@acShift[0]), 5, 5);

			// Put the value onto the end of the register
			nValue := Base32Value(CHR(acWorkCopy[i]));
			if (nValue < 0) then begin
				result:='';
        exit;
			end;
			acShift[0] := acShift[0] or nValue;
		end;

		nInBytes -= nCopyableBytes;

    for i:=0 to nOutBytes-1 do begin
      result:=result+chr(acShift[i]);
    end;
	end;
end;

function GenerateKey(data:pbyte; data_size:cardinal; use_separators:boolean=true):string;
var
  check:word;
  i:integer;
  tmp_result:string;
const
  CLEAR_SKY_KEY:word = 2264;
begin
  assert(data_size>=10, 'Key generation failed - data must be at least 10 bytes long');

  check:=CreateCheck(data, data_size-sizeof(word),CLEAR_SKY_KEY);
  PWord(cardinal(data) + data_size{%H-}-sizeof(word))^:=check;
  tmp_result:=ConvertToBase32(PChar(data),data_size);

  if use_separators then begin
    result:='';
    for i:=1 to length(tmp_result) do begin
      result:=result+tmp_result[i];
      if (i mod 4 = 0) and (i<>length(tmp_result)) then begin
        result:=result+'-';
      end;
    end;
  end else begin
    result:=tmp_result;
  end;
end;

function GenerateRandomKey(use_separators:boolean=true):string;
var
  rnd_arr:array[0..9] of byte;
begin
  rnd_arr[0]:=random($FF);
  rnd_arr[1]:=random($FF);
  rnd_arr[2]:=random($FF);
  rnd_arr[3]:=random($FF);
  rnd_arr[4]:=random($FF);
  rnd_arr[5]:=random($FF);
  rnd_arr[6]:=random($FF);
  rnd_arr[7]:=random($FF);

  result:=GenerateKey(@rnd_arr[0], 10, use_separators);
end;

end.
