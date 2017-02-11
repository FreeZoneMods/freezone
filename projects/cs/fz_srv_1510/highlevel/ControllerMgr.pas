//¬сЄ, что св€зано с контролером - вынести сюда.
//в том числе и из StUtils
unit ControllerMgr;
{$mode delphi}
interface
uses Windows, sysutils;

type
  FZControllerMgr = class
    private
      SACEstatus:cardinal;
      ver:string;
      sign, base:cardinal;
      constructor create();
      function GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
    public
      class function Get(): FZControllerMgr;
      function PatchController():boolean; //возвращает успех/неуспех патчинга
      function GetControllerVer(var version:string):boolean; //≈сли контролера нет - возвращаетс€ false
      function IsSACESupported():boolean;
  end;

implementation
var
  ControllerMgr_examp:FZControllerMgr;

constructor FZControllerMgr.create();
begin
  inherited;
  ver := '';
  SACEstatus :=0;
end;

class function FZControllerMgr.Get(): FZControllerMgr;
begin
  result := ControllerMgr_examp;
end;

function FZControllerMgr.IsSACESupported():boolean;
begin
  result:= (SACEstatus>0);
end;

function FZControllerMgr.GetControllerVer(var version:string):boolean;
begin
  result:=false;
  if ver = '' then PatchController();
  version := ver;
  if (ver<>'Unused') and (ver<>'DETECT_FAIL') then result:=true;
end;

function FZControllerMgr.PatchController():boolean;
var
  err_ignore:bool;
begin
  result:=false;
  ver:= 'DETECT_FAIL';
  err_ignore := FZConfigMgr.Get.GetBool('ignore_version_conflicts');

  if GetSignature(sign, base) = false then begin
    fzlogmgr.Get.Write('Controller detection failed!', true);
    if err_ignore then begin
      fzlogmgr.Get.Write('Trying to continue');
      result:=true;
    end;
    exit;
  end else if (base=0) and (sign=0) then begin
    ver:= 'Unused';
    fzlogmgr.Get.Write('Controller: Unused');
    result:=true;
    exit;
  end;

//  fzlogmgr.Get.Write('- base address: 0x'+inttohex(base, 8));
//  fzlogmgr.Get.Write('- signature:    0x'+inttohex(sign, 8));

  case sign of
    $78C9: begin fillchar(pointer(base+$8A8A)^, 19, $90); ver:='CCS 5.13.001 JET (26.03.11)'; SACEstatus:=1; end;
    $7839: begin fillchar(pointer(base+$89fa)^, 19, $90); fillchar(pointer(base+$8bf9)^, 12, $90); ver:='CCS 5.13.001 JET (14.03.11)'; SACEstatus:=1; end;
    $592D: begin fillchar(pointer(base+$69a6)^, 19, $90); ver:='CCS 5.12.34.00 JET' end;
    $5AB1: begin fillchar(pointer(base+$6b36)^, 19, $90); ver:='CCS 5.12.34.01 JET' end;
    $5C06: begin fillchar(pointer(base+$6da8)^, 19, $90); ver:='CCS 5.12.33 AIR'; SACEstatus:=1; end;
    $7586: begin fillchar(pointer(base+$85b6)^, 19, $90); ver:='CCS 5.12.31 JET' end;    
    else begin
      fzlogmgr.Get.Write('Controller: UNKNOWN VERSION! SIGN = 0x'+inttohex(sign, 4), true);
      if err_ignore then begin
        fzlogmgr.Get.Write('Trying to continue');
        result:=true;
      end;
      exit;
    end;
  end;

  fzlogmgr.Get.Write('Controller: '+ver);
  result:=true;
end;

function FZControllerMgr.GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
var
  hndl:THandle;
  xrengine:cardinal;
  ccs_ptr, temp:cardinal;
  tb:byte;
  buf:array[0..18]of char;
  i:integer;
  res:cardinal;
begin
  hndl:=GetCurrentProcess();
  xrengine:=GetModuleHandle('xrengine.exe');
  if xrengine=0 then TerminateProcess(hndl, 0);


  try
    //„итаем код, в который врезаютс€ контролеры
    ReadProcessMemory(hndl, PChar(xrengine+$3ee3d), @temp, 4, res);
    if res<>4 then TerminateProcess(hndl, 0);

    //“еперь проверим, чиста€ у нас игра или с контролем
    if temp = $490c883d then begin //характерно дл€ чистой игры
      //убедимс€ в этом, считав байт с инструкцией, и проверив на неравенство jmp
      ReadProcessMemory(hndl, PChar(xrengine+$3ee3c), @tb, 1, res);
      if res<>1 then TerminateProcess(hndl, 0);
      if tb = $83 then begin
        result:=true;
        signature := 0;
        base_addr := 0;
        exit;
      end
    end;

    //теперь считаем из врезки, созданной контролем, текущий адрес контролера и смещение этой процедуры (сигнатуру)
    temp:=temp+xrengine+$3ee42;
    ReadProcessMemory(hndl, PChar(temp), @ccs_ptr, 4, res);
    if res<>4 then TerminateProcess(hndl, 0);
    ccs_ptr:=ccs_ptr+temp+4;

    //ѕолучили адрес старта кода контролера дл€ врезки; старшее слово - адрес модул€, младшее - сигнатура контролера
    signature := (ccs_ptr shl 16) shr 16;
    base_addr := (ccs_ptr shr 16) shl 16;
    result :=true;
  except
    result :=false;
    signature := 0;
    base_addr := 0;
  end;

end;


begin
  ControllerMgr_examp := FZControllerMgr.create;
end.
