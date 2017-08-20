unit Decompressor;

{$mode delphi}

interface

function DecompressFile(filename:string; t:cardinal):cardinal;
function Init():boolean;

implementation
uses basedefs, Windows, LogMgr;
type
  compressor_fun = function(dst:pointer; dst_len:cardinal; src:pointer; src_len:cardinal):cardinal; cdecl;

var
  rtc_lzo_decompressor:compressor_fun;

function DecompressFile(filename:string; t:cardinal):cardinal;
var
  file_handle, mapping_handle:cardinal;
  filesize_src, filesize_dst, bytes, crc32:cardinal;
  src_ptr, dst_ptr:pointer;
begin
  result:=0;

  if t=0 then begin
    file_handle:=CreateFile(PAnsiChar(filename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if file_handle=INVALID_HANDLE_VALUE then exit;
    result:=GetFileSize(file_handle, nil);
    CloseHandle(file_handle);
    exit;
  end;

  if t<>1 then exit;

  result:=0;
  dst_ptr:=nil;
  src_ptr:=nil;
  file_handle:=INVALID_HANDLE_VALUE;
  mapping_handle:=INVALID_HANDLE_VALUE;

  try
    file_handle:=CreateFile(PAnsiChar(filename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if file_handle=INVALID_HANDLE_VALUE then exit;
    filesize_src:=GetFileSize(file_handle, nil);

    mapping_handle:=CreateFileMapping(file_handle, nil, PAGE_READONLY, 0, 0, nil);
    if mapping_handle = INVALID_HANDLE_VALUE then exit;
    src_ptr:=MapViewOfFile(mapping_handle, FILE_MAP_READ, 0, 0, 0);

    if not ReadFile(file_handle, filesize_dst, sizeof(filesize_dst), bytes, nil) then exit;
    dst_ptr:=VirtualAlloc(nil, filesize_dst, MEM_COMMIT, PAGE_READWRITE);
    if dst_ptr=nil then exit;

    if not ReadFile(file_handle, crc32, sizeof(crc32), bytes, nil) then exit;

    FZLogMgr.Get.Write('Running decompressor for '+filename, FZ_LOG_DBG);
    bytes := rtc_lzo_decompressor(dst_ptr, filesize_dst, src_ptr+8, filesize_src-8);
    if (bytes<>filesize_dst) then exit;

    UnmapViewOfFile(src_ptr);
    src_ptr:=nil;
    CloseHandle(mapping_handle);
    mapping_handle:=INVALID_HANDLE_VALUE;
    CloseHandle(file_handle);

    FZLogMgr.Get.Write('Writing decompressed data to '+filename, FZ_LOG_DBG);
    file_handle:=CreateFile(PAnsiChar(filename), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if file_handle=INVALID_HANDLE_VALUE then exit;

    if not WriteFile(file_handle, PByte(dst_ptr)^, filesize_dst, bytes, nil) then exit;

    result:=filesize_dst;
  finally
    if dst_ptr<>nil then begin
      VirtualFree(dst_ptr, 0, MEM_RELEASE);
    end;
    if src_ptr<>nil then begin
      UnmapViewOfFile(src_ptr);
    end;
    if mapping_handle<>INVALID_HANDLE_VALUE then begin
      CloseHandle(mapping_handle);
    end;
    if file_handle<>INVALID_HANDLE_VALUE then begin
      CloseHandle(file_handle);
    end;
  end;

end;

function Init():boolean;
begin
  rtc_lzo_decompressor:=GetProcAddress(xrCore, '?rtc9_decompress@@YAIPAXIPBXI@Z');
  result:=(@rtc_lzo_decompressor<>nil);
end;

end.

