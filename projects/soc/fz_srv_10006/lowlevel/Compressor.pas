unit Compressor;

{$mode delphi}


interface
function Init():boolean; stdcall;


implementation
uses sysutils, LogMgr, windows, Console, basedefs, global_functions;

type
  compressor_fun = function(dst:pointer; dst_len:cardinal; src:pointer; src_len:cardinal):cardinal; cdecl;
  compressor_mode = (MODE_COMPRESS, MODE_DECOMPRESS, MODE_DECOMPRESS_RAW);

var
  rtc_lzo_compressor:compressor_fun;
  rtc_lzo_decompressor:compressor_fun;


procedure LzoCompressCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Compress file using LZO algorhitm. Requires 1 argument - source file name.');
end;

procedure LzoDecompressCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Decompress file using LZO algorhitm. Requires 1 argument - source file name.');
end;

procedure LzoExecuteFileCompressor(comp:compressor_fun; src_name:string; dst_name:string; mode:compressor_mode); stdcall;
var
  src_hfile, dst_hfile:THandle;
  src_fm:THandle;
  src_mapped:pointer;
  src_filesize:cardinal;

  dst_ptr:pointer;
  dst_filesize:cardinal;
  bytes, crc:cardinal;
begin
  if @comp=nil then begin
    FZLogMgr.Get.Write('Compressor is empty!', FZ_LOG_ERROR);
    exit;
  end;

  if length(src_name)=0 then begin
    FZLogMgr.Get.Write('Please, specify source file name!', FZ_LOG_ERROR);
    exit;
  end;

  src_hfile:=CreateFile(PAnsiChar(src_name), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if src_hfile=INVALID_HANDLE_VALUE then begin
    FZLogMgr.Get.Write('Cannot open file "'+src_name+'"!', FZ_LOG_ERROR);
    exit;
  end;

  src_fm:=CreateFileMapping(src_hfile, nil, PAGE_READONLY, 0, 0, nil);
  if (src_fm=0) then begin
    FZLogMgr.Get.Write('Cannot create source file mapping!', FZ_LOG_ERROR);
    CloseHandle(src_hfile);
    exit;
  end;

  src_mapped:=MapViewOfFile(src_fm, FILE_MAP_READ, 0, 0, 0);
  if src_mapped=nil then begin
    FZLogMgr.Get.Write('Cannot map file view!', FZ_LOG_ERROR);
    CloseHandle(src_fm);
    CloseHandle(src_hfile);
    exit;
  end;

  src_filesize:=GetFileSize(src_hfile, nil);
  if mode = MODE_COMPRESS then begin
    dst_ptr:=VirtualAlloc(nil, src_filesize, MEM_COMMIT, PAGE_READWRITE);
    dst_filesize:=comp(dst_ptr, src_filesize, src_mapped, src_filesize);
  end else if mode = MODE_DECOMPRESS_RAW then begin
    dst_filesize := src_filesize*10;
    dst_ptr:=VirtualAlloc(nil, dst_filesize, MEM_COMMIT, PAGE_READWRITE);
    bytes := comp(dst_ptr, dst_filesize, src_mapped, src_filesize);
  end else begin
    if not ReadFile(src_hfile, dst_filesize, sizeof(dst_filesize), bytes, nil) then begin
      FZLogMgr.Get.Write('Cannot read decompressed size!', FZ_LOG_ERROR);
      UnmapViewOfFile(src_mapped);
      CloseHandle(src_fm);
      CloseHandle(src_hfile);
      exit;
    end;
    dst_ptr:=VirtualAlloc(nil, dst_filesize, MEM_COMMIT, PAGE_READWRITE);
    bytes := comp(dst_ptr, dst_filesize, src_mapped+8, src_filesize-8);
    if bytes<>dst_filesize then begin
      FZLogMgr.Get.Write('Warning! Output file size differs from reference!', FZ_LOG_ERROR);
    end;
  end;

  UnmapViewOfFile(src_mapped);
  CloseHandle(src_fm);
  CloseHandle(src_hfile);

  FZLogMgr.Get.Write('Saving data to '+dst_name, FZ_LOG_IMPORTANT_INFO);
  dst_hfile:=CreateFile(PAnsiChar(dst_name), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if src_hfile=INVALID_HANDLE_VALUE then begin
    FZLogMgr.Get.Write('Cannot open output file!', FZ_LOG_ERROR);
    VirtualFree(dst_ptr, 0, MEM_RELEASE);
    exit;
  end;

  if mode = MODE_COMPRESS then begin
    FZLogMgr.Get.Write('CR = '+floattostr(dst_filesize/src_filesize), FZ_LOG_INFO);
    if not WriteFile(dst_hfile, src_filesize, sizeof(src_filesize), bytes, nil) then begin
      FZLogMgr.Get.Write('Output file write failed!', FZ_LOG_ERROR);
      VirtualFree(dst_ptr, 0, MEM_RELEASE);
      exit;
    end;
    crc:=crc32(dst_ptr, dst_filesize);
    if not WriteFile(dst_hfile, crc, sizeof(crc), bytes, nil) then begin
      FZLogMgr.Get.Write('Output file write failed!', FZ_LOG_ERROR);
      VirtualFree(dst_ptr, 0, MEM_RELEASE);
      exit;
    end;
  end;

  if not WriteFile(dst_hfile, PByte(dst_ptr)^, dst_filesize, bytes, nil) then begin
    FZLogMgr.Get.Write('Output file write failed!', FZ_LOG_ERROR);
  end else begin
    FZLogMgr.Get.Write('Done!', FZ_LOG_INFO);
  end;
  VirtualFree(dst_ptr, 0, MEM_RELEASE);

  CloseHandle(dst_hfile);
end;

procedure LzoCompressFile(filename:PChar); stdcall;
begin
  LzoExecuteFileCompressor(rtc_lzo_compressor, trim(filename), trim(filename)+'.lzo', MODE_COMPRESS);
end;

procedure LzoDecompressFile(filename:PChar); stdcall;
begin
  LzoExecuteFileCompressor(rtc_lzo_decompressor, trim(filename), trim(filename)+'.unlzo', MODE_DECOMPRESS);
end;

function Init():boolean; stdcall;
begin
  result:=false;

  if not InitSymbol(@rtc_lzo_compressor, xrCore, '?rtc9_compress@@YAIPAXIPBXI@Z') then exit;
  if not InitSymbol(@rtc_lzo_decompressor, xrCore, '?rtc9_decompress@@YAIPAXIPBXI@Z') then exit;

  AddConsoleCommand('fz_lzo_compress', @LzoCompressFile, @LzoCompressCmdInfo);
  AddConsoleCommand('fz_lzo_decompress', @LzoDecompressFile, @LzoDecompressCmdInfo);

  result:=true;
end;

end.

