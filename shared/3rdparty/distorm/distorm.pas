unit distorm;

{$mode delphi}

interface
{$linklib libdistorm3.a}
{$linklib libmsvcrt.a}

type
  TOffsetType = Int64;
  TDecodeType = cardinal;
  TDecodeResult = cardinal;

  TDistormString = packed record
  	length:cardinal;
  	p:array[0..47] of char;
  end;

  TDecodedInst = packed record
  	mnemonic:TDistormString;        // Mnemonic of decoded instruction, prefixed if required by REP, LOCK etc.
  	operands:TDistormString;        // Operands of the decoded instruction, up to 3 operands, comma-seperated.
  	instructionHex:TDistormString;  // Hex dump - little endian, including prefixes.
  	size:cardinal;                  // Size of decoded instruction in bytes.
  	offset:TOffsetType;             // Start offset of the decoded instruction.
  end;
  pTDecodedInst = ^TDecodedInst;

const
  DecodeType_Decode16Bits: cardinal = 0;
  DecodeType_Decode32Bits: cardinal = 1;
  DecodeType_Decode64Bits: cardinal = 2;

  DECRES_NONE = 0;
  DECRES_SUCCESS = 1;
  DECRES_MEMORYERR = 2;
  DECRES_INPUTERR = 3;
  DECRES_FILTERED = 4;

function distorm_decode(codeOffset:TOffsetType; code:PAnsiChar; codeLen:integer; dt:TDecodeType; res:pTDecodedInst; maxInstructions:cardinal; usedInstructionsCount:pCardinal):TDecodeResult;

implementation
function distorm_decode64(codeOffset:TOffsetType; code:PAnsiChar; codeLen:integer; dt:TDecodeType; res:pTDecodedInst; maxInstructions:cardinal; usedInstructionsCount:pCardinal):TDecodeResult; cdecl; external;

function distorm_decode(codeOffset:TOffsetType; code:PAnsiChar; codeLen:integer; dt:TDecodeType; res:pTDecodedInst; maxInstructions:cardinal; usedInstructionsCount:pCardinal):TDecodeResult;
begin
  result:=distorm_decode64(codeOffset, code, codeLen, dt, res, maxInstructions, usedInstructionsCount);
end;

end.

