unit CommonHelper;
{$mode delphi}
interface

uses sysutils, windows;

type

{ FZCommonHelper }

 FZCommonHelper = class
  public
    class function GetGameTickCount():cardinal;
    class function GetEnglishUppercaseChar(low:char):char;
    class function GetEnglishCharFromRussian(rus:char):char;
    class function GetNextParam(var data:string; var buf:string; separator:char=char($00)):boolean;
    class function GetLastParam(var data:string; var buf:string; separator:char=char($00)):boolean;
    class function GetTimeDeltaSafe(starttime:cardinal):cardinal;
    class function StrToPort(port:string):integer;
    class function GetCurTime():string;
    class function GetCurDate():string;
    class function GetVolSN():string;
    class function HexToInt(hex:string; default:cardinal=0):cardinal;
    class function TryHexToInt(hex:string; var out_val:cardinal):boolean;
    class function StringToFloatDef(str:string; def:single):single;
    class function TryStringToFloat(str:string; var out_val:single):boolean;
    class function TryStringToInt(str:string; var out_val:integer):boolean;
    class function FloatToString(value: single; precision:integer = 4; digits:integer = 2): string;
    class function ReadFileAsString(fname:string; var str:string):boolean;
    class function MovingPointerReader(var src: pointer; var srcsize: cardinal; dst: pointer; sizetoread: cardinal):boolean;
end;

const
fz_protocol_ver:string='FZ3.0';


implementation

class function FZCommonHelper.GetNextParam(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=1 to length(data) do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=leftstr(data, p-1);
    data:=rightstr(data, length(data)-p);
    result:=true;
  end else result:=false;
end;

class function FZCommonHelper.GetLastParam(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=length(data) downto 1 do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=rightstr(data, length(data)-p);
    data:=leftstr(data, p-1);
    result:=true;
  end else result:=false;
end;

class function FZCommonHelper.StrToPort(port:string):integer;
begin
  result:=strtointdef(port, -1);
  if (result<-1) or (result>65535) then result:=-1;
end;


class function FZCommonHelper.GetVolSN():string;
var
  VolumeName,
  FileSystemName : array [0..MAX_PATH-1] of Char;
  VolumeSerialNo : DWord;
  MaxComponentLength, FileSystemFlags : dword;
begin
  MaxComponentLength:=0;
  FileSystemFlags:=0;
  VolumeName[0]:=CHR(0);
  FileSystemName[0]:=CHR(0);
  GetVolumeInformation(nil,
      VolumeName,
      MAX_PATH,
      @VolumeSerialNo,
      MaxComponentLength,
      FileSystemFlags,
      FileSystemName,
      MAX_PATH);
 result:=IntToHex(VolumeSerialNo,8);
end;

class function FZCommonHelper.GetTimeDeltaSafe(starttime:cardinal):cardinal;
var
  curtime:cardinal;
begin
  curtime:=GetGameTickCount;
  result:=curtime-starttime;
  //обработаем переполнение
  if result>curtime then result:=$FFFFFFFF-starttime+curtime;
end;

class function FZCommonHelper.GetCurTime():string;
var
  st:_SYSTEMTIME;
begin
  FillMemory(@st, sizeof(st), 0);
  GetLocalTime(st);
  if st.wHour<10 then result:='0' else result:='';
  result:=result+inttostr(st.wHour)+'-';
  if st.wMinute<10 then result:=result+'0';
  result:=result+inttostr(st.wMinute)+'-';
  if st.wSecond<10 then result:=result+'0';
  result:=result+inttostr(st.wSecond);
end;

class function FZCommonHelper.GetCurDate():string;
var
  st:_SYSTEMTIME;
begin
  FillMemory(@st, sizeof(st), 0);
  GetLocalTime(st);
  if st.wDay<10 then result:='0' else result:='';
  result:=result+inttostr(st.wDay)+'.';
  if st.wMonth<10 then result:=result+'0';
  result:=result+inttostr(st.wMonth)+'.';
  result:=result+inttostr(st.wYear);
end;

class function FZCommonHelper.GetEnglishCharFromRussian(rus: char): char;
begin
  case rus of
    'а': result:='a';
    'б': result:='b';
    'в': result:='v';
    'г': result:='g';
    'д': result:='d';
    'е': result:='e';
    'ё': result:='e';
    'ж': result:='j';
    'з': result:='z';
    'и': result:='i';
    'й': result:='i';    
    'к': result:='k';
    'л': result:='l';
    'м': result:='m';
    'н': result:='n';
    'о': result:='o';
    'п': result:='p';
    'р': result:='r';
    'с': result:='s';
    'т': result:='t';
    'у': result:='u';
    'ф': result:='f';
    'х': result:='h';
    'ц': result:='c';
    'ч': result:='4';
    'ш': result:='s';
    'щ': result:='s';
    'ъ': result:='_';
    'ы': result:='i';
    'ь': result:='6';
    'э': result:='e';
    'ю': result:='u';
    'я': result:='a';
       
    'А': result:='A';
    'Б': result:='B';
    'В': result:='V';
    'Г': result:='G';
    'Д': result:='D';
    'Е': result:='E';
    'Ё': result:='E';
    'Ж': result:='J';
    'З': result:='Z';
    'И': result:='I';
    'Й': result:='I';
    'К': result:='K';
    'Л': result:='L';
    'М': result:='M';
    'Н': result:='N';
    'О': result:='O';
    'П': result:='P';
    'Р': result:='R';
    'С': result:='S';
    'Т': result:='T';
    'У': result:='U';
    'Ф': result:='F';
    'Х': result:='H';
    'Ц': result:='C';
    'Ч': result:='4';
    'Ш': result:='S';
    'Щ': result:='S';
    'Ъ': result:='_';
    'Ы': result:='I';
    'Ь': result:='6';
    'Э': result:='E';
    'Ю': result:='U';
    'Я': result:='J';
  else
    result:='_';
  end;
end;

class function FZCommonHelper.GetGameTickCount(): cardinal;
begin
  result:=GetTickCount;
  if result=0 then result:=1;
end;

class function FZCommonHelper.GetEnglishUppercaseChar(low: char): char;
begin
  case low of
    'a':result:='A';
    'b':result:='B';
    'c':result:='C';
    'd':result:='D';
    'e':result:='E';
    'f':result:='F';
    'g':result:='G';
    'h':result:='H';
    'i':result:='I';
    'j':result:='J';
    'k':result:='K';
    'l':result:='L';
    'm':result:='M';
    'n':result:='N';
    'o':result:='O';
    'p':result:='P';
    'q':result:='Q';
    'r':result:='R';
    's':result:='S';
    't':result:='T';
    'u':result:='U';
    'v':result:='V';
    'w':result:='W';
    'x':result:='X';
    'y':result:='Y';
    'z':result:='Z';
  else
    result:=low;
  end;
end;

class function FZCommonHelper.HexToInt(hex: string; default:cardinal=0): cardinal;
var
  i: integer; //err code
  r: Int64;   //result
begin
  val('$'+trim(hex),r, i);
  if i<>0 then
    result := default
  else
    result := cardinal(r);
end;

class function FZCommonHelper.TryHexToInt(hex: string; var out_val: cardinal): boolean;
var
  i: integer; //err code
  r: Int64;   //result
begin
  val('$'+trim(hex),r, i);
  if i<>0 then begin
    result := false;
  end else begin
    result := true;
    out_val:=cardinal(r);
  end;
end;

class function FZCommonHelper.StringToFloatDef(str: string; def: single): single;
var
  formatSettings : TFormatSettings;
begin
  formatSettings.DecimalSeparator:='.';
  formatSettings.ThousandSeparator:=' ';
  result:=strtofloatdef(str, def, formatSettings);
end;

class function FZCommonHelper.TryStringToFloat(str: string; var out_val: single): boolean;
var
  r:single;
const
  fake_value_1:single = 107.0;
  fake_value_2:single = 204.0;
begin
  result:=true;

  r:=StringToFloatDef(str, fake_value_1);
  if r = fake_value_1 then begin
    r:=StringToFloatDef(str, fake_value_2);
    if r = fake_value_2 then begin
      result:=false;
    end else begin
      out_val:=r;
    end;
  end else begin
    out_val:=r;
  end;
end;

class function FZCommonHelper.TryStringToInt(str: string; var out_val: integer): boolean;
var
  r:integer;
const
  fake_value_1:integer = -1965;
  fake_value_2:integer = -2954;
begin
  result:=true;

  r:=StrToIntDef(str, fake_value_1);
  if r = fake_value_1 then begin
    r:=StrToIntDef(str, fake_value_2);
    if r = fake_value_2 then begin
      result:=false;
    end else begin
      out_val:=r;
    end;
  end else begin
    out_val:=r;
  end;
end;

class function FZCommonHelper.FloatToString(value: single; precision:integer; digits:integer): string;
var
  formatSettings : TFormatSettings;
begin
  formatSettings.DecimalSeparator:='.';
  formatSettings.ThousandSeparator:=' ';
  result:=floattostrf(value, ffFixed, precision, digits, formatSettings);
end;

class function FZCommonHelper.ReadFileAsString(fname: string; var str: string): boolean;
var
  f:file;
  b:char;
begin
  str:='';
  b:=chr(0);
  try
    assignfile(f, fname);
    reset(f, sizeof(b));
    try
      while not eof(f) do begin
        BlockRead(f, b, 1);
        str:=str+b;
      end;
    finally
      closefile(f)
    end;
    result:=true;
  except
    result:=false;
  end;
end;

class function FZCommonHelper.MovingPointerReader(var src: pointer; var srcsize: cardinal; dst: pointer; sizetoread: cardinal): boolean;
begin
  result:=false;
  if (src=nil) or (dst=nil) then exit;
  if srcsize < sizetoread then exit;

  CopyMemory(dst, src, sizetoread);
  srcsize:=srcsize - sizetoread;
  src:=@pByte(src)[sizetoread];
  result:=true;
end;

end.
