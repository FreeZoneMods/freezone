unit TranslationMgr;
{$mode delphi}
interface
uses ConfigBase;

type FZTranslationMgr = class(FZConfigBase)
  private
    constructor Create();
  public
   class function Get(): FZTranslationMgr;
   function TranslateSingle(text:string): string; //вернет исходную строку при отсутсвующем транслейте
   function TranslateOrEmptySingle(text:string): string; //вернет пустую строку при отсутствующем транслейте
   function Translate(text:string): string;
   function Translate_NoSpaces(text:string): string;
//   function BackTranslate(text:string; var res:string):boolean;
   destructor Destroy(); override;
end;

function Init:boolean; stdcall;

implementation
uses CommonHelper, sysutils, StrUtils, Console;
var _instance:FZTranslationMgr;

{FZTranslationMgr}

class function FZTranslationMgr.Get(): FZTranslationMgr;
begin
  result:=_instance;
end;

constructor FZTranslationMgr.Create();
begin
  inherited;
  load('fz_translations.ini');
end;

destructor FZTranslationMgr.Destroy();
begin
  _instance:=nil;
  inherited;
end;

function FZTranslationMgr.TranslateSingle(text:string): string;
begin
  if not GetData(text, result) then result:=text;
end;

function FZTranslationMgr.TranslateOrEmptySingle(text:string): string;
begin
  if not GetData(text, result) then result:='';
end;

function FZTranslationMgr.Translate(text:string): string;
var
  word_to_translate:string;
begin
  result:='';
  text:=trim(text);
  while FZCommonHelper.GetNextParam(text, word_to_translate, ' ') do begin
    text:=trim(text);
    result:=result+TranslateSingle(word_to_translate)+' ';
  end;
  result:=result+TranslateSingle(text);
end;

function FZTranslationMgr.Translate_NoSpaces(text:string): string;
var
  word_to_translate, tmp:string;
begin
  result:='';
  text:=trim(text);
  while FZCommonHelper.GetNextParam(text, word_to_translate, ' ') do begin
    text:=trim(text);
    tmp:=TranslateSingle(word_to_translate);
    tmp:=AnsiReplaceStr(tmp, ' ', '_');
    result:=result+tmp+' ';
  end;

  tmp:=TranslateSingle(text);
  tmp:=AnsiReplaceStr(tmp, ' ', '_');
  result:=result+TranslateSingle(tmp);
end;

{function FZTranslationMgr.BackTranslate(text:string; var res:string):boolean;
var
  i:integer;
begin
  self._BeginRead;
  try
    result:=false;

    for i:=_size-1 downto 0 do begin
      if _values[i] = text then begin
        res:=_keys[i];
        result:=true;
        break;
      end;
    end;
  finally
    self._EndRead;
  end;
end;}


procedure ReloadTranslations_Info(info:PChar); stdcall;
begin
  strcopy(info, 'Reloads string translation config');
end;

procedure ReloadTranslations(arg:PChar); stdcall;
begin
  _instance.Reload();
end;

function Init:boolean; stdcall;
begin
  _instance:=FZTranslationMgr.Create();
  result:=true;
  //AddConsoleCommand('fz_reload_translations', @ReloadTranslations, @ReloadTranslations_Info);
end;

end.
 
