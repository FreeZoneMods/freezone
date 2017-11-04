unit DownloadMgr;
{$mode delphi}
interface
uses ConfigBase, sysmsgs;
type

  { FZDownloadMgr }

  FZDownloadMgr = class(FZConfigBase)
  private
    constructor Create();
  public
   class function Get():FZDownloadMgr;
   function GetLinkByMapName(map:string; ver:string):string;
   function GetMapPrefix(map:string; ver:string):string;
   function GetXMLName(map:string; ver:string):string;
   function GetCRC32(map:string; ver:string; var res:boolean):cardinal;
   destructor Destroy(); override;
   function GetCompressionType(map:string; ver:string):FZArchiveCompressionType;
   function IsSaceFakeNeeded(map: string; ver: string):boolean;

   class function GetCompressionTypeByIndex(i:longint):FZArchiveCompressionType;
  end;

function Init():boolean; stdcall;

implementation
uses ConfigMgr, CommonHelper, sysutils;
var
  _instance:FZDownloadMgr;

{ FZDownloadMgr }

constructor FZDownloadMgr.Create;
begin
  inherited Create();
  self.load('fz_download_links.ini');
end;

destructor FZDownloadMgr.Destroy;
begin

  inherited;
end;

class function FZDownloadMgr.Get: FZDownloadMgr;
begin
  result:=_instance;
end;

function FZDownloadMgr.GetCRC32(map: string; ver: string; var res: boolean
  ): cardinal;
var
  hex:string;
  s:string;
begin

  s:='%crc32_'+map+'_'+ver+'%';
  res:=self.GetData(s, hex);
  if res then begin
    result:=FZCommonHelper.HexToInt(hex);
  end else begin
    result:=0;
  end;
end;

function FZDownloadMgr.GetLinkByMapName(map: string;ver: string): string;
var
  s:string;
begin
  s:=map+'_'+ver;
  result:=self.GetString(s, '');
end;


function Init():boolean; stdcall;
begin
  _instance:=FZDownloadMgr.Create();
  result:=true;
end;

function FZDownloadMgr.GetMapPrefix(map: string; ver: string): string;
var
  s:string;
begin
  s:='%prefix_'+map+'_'+ver+'%';
  result:=self.GetString(s,'');
end;

function FZDownloadMgr.GetXMLName(map: string; ver: string): string;
var
  s:string;
begin
  s:='%xml_'+map+'_'+ver+'%';
  result:=self.GetString(s,'');
end;

function FZDownloadMgr.GetCompressionType(map:string; ver:string):FZArchiveCompressionType;
var
  s:string;
begin
  s:='%compression_'+map+'_'+ver+'%';
  s:=self.GetString(s,'');
  result:=GetCompressionTypeByIndex(strtointdef(s, 0));
end;

function FZDownloadMgr.IsSaceFakeNeeded(map: string; ver: string): boolean;
var
  s:string;
begin
  s:='%sacedldisable_'+map+'_'+ver+'%';
  s:=self.GetString(s,'');
  result:=(strtointdef(s, 1) <> 0);
end;

class function FZDownloadMgr.GetCompressionTypeByIndex(i: longint): FZArchiveCompressionType;
begin
  case i of
    1: result:=FZ_COMPRESSION_LZO_COMPRESSION;
    2: result:=FZ_COMPRESSION_CAB_COMPRESSION;
  else
    result:=FZ_COMPRESSION_NO_COMPRESSION
  end;
end;

end.
