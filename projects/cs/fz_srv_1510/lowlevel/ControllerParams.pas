unit ControllerParams;
{$mode delphi}
interface
uses Clients;

type
FZControllerParams = record
  ccs_present:boolean;
  sign:cardinal;
  base:cardinal;
  ver:string;
  SACE_status:boolean; //поддерживает ли sv_onlysace
  SACE_check_native_func:function (id:ClientID):boolean; stdcall; //адрес "родной" функции проверки игрока на SACE
end;

FZUACPlayerInfo = packed record
  dwSize:cardinal;
  dwCheatFlags:cardinal;
  bOutdated:cardinal;
  bFullscreen:cardinal;
  Reserved:array[0..23] of cardinal;
end;
pFZUACPlayerInfo=^FZUACPlayerInfo;

FZGetUACPlayerInfo_fun = function (szHash_MD5:PChar; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall;

FZControllerMgr = class
    _params:FZControllerParams;
    function _GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
  public
    constructor Create();
    function GetParams:FZControllerParams;
    class function Get():FZControllerMgr;
    class function IsSACE3APIPresent():boolean; stdcall;
end;

implementation
uses LogMgr, SysUtils, Windows, basedefs, srcBase;
var
  instance:FZControllerMgr = nil;
  sace3_checker:FZGetUACPlayerInfo_fun= nil;

{ FZControllerMgr }

function CheckSACE_ccs513002(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2b79;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$398F;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;


function CheckSACE_ccs513003(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2b31;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$3947;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;


function CheckSACE_ccs514(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2961;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$3889;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;

class function FZControllerMgr.IsSACE3APIPresent():boolean; stdcall;
begin
  result:=(GetProcAddress(xrAPI, 'GetUACPlayerInfo')<>nil);
end;


constructor FZControllerMgr.Create;
begin
  if _GetSignature(_params.sign, _params.base) = false then begin
    //ќшибка детекта
    _params.ccs_present:=false;
    _params.ver:='UNUSED';
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;
    FZLogMgr.Get.Write('Controlled detection error!', true);
  end else if (_params.base=0) and (_params.sign=0) then begin
    //контролера нет
    _params.ccs_present:=false;
    _params.ver:='UNUSED';
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;
  end else begin
    _params.ccs_present:=true;
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;

    case _params.sign of
      //дл€ нормального коннекта игроков с пустым хешем надо исправить реакцию контролера на M_CLIENTREADY и M_CL_AUTH внутри M_SECURE_MESSAGE
      //TODO:исправить дл€ старых контролеров
      //TODO: возможно, стоит сделать патч контролера опциональным, в зависимости от настроек панели?

      //TODO: перенести определение SACE3 на новый лад 
      $6F78: begin _params.ver:='CCS 5.14 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs514; end;
      $7469: begin _params.ver:='CCS 5.13.003 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs513003; end;
      $7509: begin _params.ver:='CCS 5.13.002 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs513002; end;
      $78C9: begin _params.ver:='CCS 5.13.001 JET (26.03.11)'; _params.SACE_status:=true; end;
      $7839: begin _params.ver:='CCS 5.13.001 JET (14.03.11)'; fillchar(pointer(_params.base+$8bf9)^, 12, $90); _params.SACE_status:=true; end;
      $592D: begin _params.ver:='CCS 5.12.34.00 JET' end;
      $5AB1: begin _params.ver:='CCS 5.12.34.01 JET' end;
      $5C06: begin _params.ver:='CCS 5.12.33 AIR'; _params.SACE_status:=true; end;
      $7586: begin _params.ver:='CCS 5.12.31 JET' end;
      else begin
        FZLogMgr.Get.Write('Controller: UNKNOWN VERSION! SIGN = 0x'+inttohex(_params.sign, 4), true);
        _params.ver:='UNKNOWN';
      end;
    end;
  end;
end;

class function FZControllerMgr.Get: FZControllerMgr;
begin
  if instance=nil then begin
    instance:=FZControllerMgr.Create();
  end;
  result:=instance;
end;

function FZControllerMgr.GetParams: FZControllerParams;
begin
  result:=_params;
end;

function FZControllerMgr._GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
var
  ccs_ptr, temp:cardinal;
  tb:byte;
  res:cardinal;
begin

  try
    //„итаем код, в который врезаютс€ контролеры
    ReadProcessMemory(GetCurrentProcess(), PChar(xrengine+$3ee3d), @temp, 4, res);
    if res<>4 then begin
      result:=false;
      exit;
    end;

    //“еперь проверим, чиста€ у нас игра или с контролем
    if temp = $490c883d then begin //характерно дл€ чистой игры
      //убедимс€ в этом, считав байт с инструкцией, и проверив на неравенство jmp
      ReadProcessMemory(GetCurrentProcess(), PChar(xrEngine+$3ee3c), @tb, 1, res);
      if res<>1 then begin
        result:=false;
        exit;
      end else if tb = $83 then begin
        result:=true;
        signature := 0;
        base_addr := 0;
        exit;
      end
    end;

    //теперь считаем из врезки, созданной контролем, текущий адрес контролера и смещение этой процедуры (сигнатуру)
    temp:=temp+xrengine+$3ee42;
    ReadProcessMemory(GetCurrentProcess(), PChar(temp), @ccs_ptr, 4, res);
    if res<>4 then begin
      result:=false;
      exit;
    end;
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

end.
