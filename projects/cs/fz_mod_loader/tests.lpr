program tests;
uses FastMd5, FastCrc, strutils, sysutils, LogMgr, CommandLineParser, HttpDownloader, windows, curl;


type TMd5Info = record
  data:string;
  target_hash:string;
end;

function CheckMd5(info:TMd5Info):boolean;
var
  ctx:TMD5Context;
  res:string;
begin
  ctx:=MD5Start();
  res:=MD5End(ctx, PChar(info.data), length(info.data));
  writeln('CheckMD5: expected '+info.target_hash+', got '+res);
  result:= res=info.target_hash;
end;

function Md5Tests():boolean;
var
  p:TMd5Info;
begin
  result:=false;
  writeln('**********************************');
  writeln('MD5 TESTS START');
  writeln('**********************************');

  try
    p.data:='';
    p.target_hash:=LowerCase('D41D8CD98F00B204E9800998ECF8427E');
    if not CheckMd5(p) then exit;

    p.data:='abcde';
    p.target_hash:='ab56b4d92b40713acc5af89985d4b786';
    if not CheckMd5(p) then exit;

    p.data:='1234567890';
    p.target_hash:='e807f1fcf82d132f9bb018ca6738a19f';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890';
    p.target_hash:='fb46ea63c015ee690bd3f2e50a461296';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901';
    p.target_hash:='eb7cf7ded133bf12d6dff2695287cdc0';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012';
    p.target_hash:='9013203e1628986340d91403494a71ef';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123';
    p.target_hash:='cc741494163f0816c4c0ab6502553ac9';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234';
    p.target_hash:='f40a0ec3fbf6cf062c9faf3752bd6e6c';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345';
    p.target_hash:='c9ccf168914a1bcfc3229f1948e67da0';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123456';
    p.target_hash:='49f193adce178490e34d1b3a4ec0064c';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234567';
    p.target_hash:='23339de0ceca03763ff42d807768964d';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345678';
    p.target_hash:='69328a851f0c7bc2a581a841f50a3bf2';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123456789';
    p.target_hash:='0b9619419451aacdba0001592fca361c';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234567890';
    p.target_hash:='c5b549377c826cc3712418b064fc417e';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345678901';
    p.target_hash:='931844f87f22a0ac1b7167979c8bea99';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123456789012';
    p.target_hash:='a29fba1f76305e4754853afb94525918';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234567890123';
    p.target_hash:='c3eb67ece68488bb394241d4f6a54244';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345678901234';
    p.target_hash:='eb6c4179c0a7c82cc2828c1e6338e165';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123456789012345';
    p.target_hash:='823cc889fc7318dd33dde0654a80b70a';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234567890123456';
    p.target_hash:='df8da95407c62887e88df922874538bc';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345678901234567';
    p.target_hash:='e390814a2fb7e0655129e471b9fce1e1';
    if not CheckMd5(p) then exit;

    p.data:='12345678901234567890123456789012345678901234567890123456789012345678';
    p.target_hash:='e5837e65e7c6d20b4cdad038d497c1d9';
    if not CheckMd5(p) then exit;

    p.data:='123456789012345678901234567890123456789012345678901234567890123456789';
    p.target_hash:='e11fc23101fe571e4f4597effda63e96';
    if not CheckMd5(p) then exit;

    p.data:='1234567890123456789012345678901234567890123456789012345678901234567890';
    p.target_hash:='689de1e396ad9c089ae2b9aaffd6faf7';
    if not CheckMd5(p) then exit;

    result:=true;
  finally
    writeln('**********************************');
    if result then begin
      writeln('MD5 TESTS PASSED');
    end else begin
      writeln('MD5 TESTS FAILED');
    end;
    writeln('**********************************');
    writeln;
  end;
end;

function CmdLineTests():boolean;
var
  sample_cmdline, ip, tmp:string;
  port:integer;
const
  ip_const:string='1.2.3.4';
  name_const:string='localhost';
  local_ip_const:string='127.0.0.1';
  port_const:string='9876';
  gamelist_const:string='http://localhost/game.txt';
  enginelist_const:string='http://localhost/engine.txt';
  enable_custom_gamelist_param:string='-fz_custombins';
begin
  result:=false;
  writeln('**********************************');
  writeln('COMMAND LINE TESTS START');
  writeln('**********************************');
  try
    //1. srv имеет приоритет над srvname
    sample_cmdline:='-srv '+ip_const+' -srvname '+name_const+' -srvport '+port_const;

    ip:=GetServerIp(PChar(sample_cmdline));
    writeln('GetServerIp: expected '+ ip_const +', got '+ ip);
    if ip <> ip_const then exit;

    port := GetServerPort(PChar(sample_cmdline));
    writeln('GetServerPort: expected '+ port_const +', got '+ inttostr(port));
    if port <> strtoint(port_const) then exit;

    //2. проверка разрешения доменного имени
    sample_cmdline:=' -srvname '+name_const+' -srvport '+port_const+' -gamelist '+gamelist_const+' -binlist '+enginelist_const;
    ip:=GetServerIp(PChar(sample_cmdline));
    writeln('GetServerIp: expected '+ local_ip_const +', got '+ ip);

    //3.проверка списков
    tmp:=GetCustomGamedataUrl(PChar(sample_cmdline));
    writeln('GetCustomGamedataUrl: expected '+gamelist_const+', got '+tmp);
    if tmp<>gamelist_const then exit;

    result:=true;
  finally
    writeln('**********************************');
    if result then begin
      writeln('COMMAND LINE TESTS PASSED');
    end else begin
      writeln('COMMAND LINE TESTS FAILED');
    end;
    writeln('**********************************');
    writeln;
  end;

end;

function GameSpyDownloaderTests():boolean;
var
  link:string;
  th:FZDownloaderThread;
  dl:FZFileDownloader;
  res:boolean;
const
  filename:string='test.tmp';
begin
  result:=false;
  writeln('**********************************');
  writeln('GAMESPY DOWNLOADER TESTS START');
  writeln('**********************************');

  link:='http://stalker.gamepolis.ru/mods_clear_sky/guns_cs/gamedata.txt';
  th:=FZGameSpyDownloaderThread.Create();
  dl:=th.CreateDownloader(link, filename, 0);

  try
    writeln('Start download from '+link);
    res:=dl.StartSyncDownload();
    writeln('Download result: '+booltostr(res, true)+', size '+ inttostr(dl.DownloadedBytes()));
    if not res then exit;

    result:=true;
  finally
    dl.Free();
    th.Free();
    DeleteFile(PChar(filename));

    writeln('**********************************');
    if result then begin
      writeln('GAMESPY DOWNLOADER TESTS PASSED');
    end else begin
      writeln('GAMESPY DOWNLOADER TESTS FAILED');
    end;
    writeln('**********************************');
    writeln;
  end;
end;

function write_callback(ptr:PChar; size:cardinal; nitems:Cardinal; userdata:pointer):cardinal; cdecl;
begin
  writeln('write request for ', nitems*size, ' bytes, userdata ', uintptr(userdata));
  result:=nitems*size;
end;

function progress_callback(clientp:pointer; dltotal:int64; dlnow:int64; ultotal:int64; ulnow:int64):integer; cdecl;
begin
  writeln('progress cb, userdata ', uintptr(clientp), ', dltotal ', dltotal, ', dlnow ', dlnow);
  result:=CURLE_OK;
end;

function LibCurlTests():boolean;
var
  purl:pTCURL;
  ver:pcurl_version_info_data;

  tmp:PChar;
  link:string;
  th:FZDownloaderThread;
  dl:FZFileDownloader;
  res:boolean;
const
  filename:string='test.tmp';
begin
  result:=false;
  writeln('**********************************');
  writeln('LIBCURL TESTS START');
  writeln('**********************************');

  try
    ver:=curl_version_info(CURLVERSION_FOURTH);
    if ver= nil then exit;
    writeln('libcurl version dump: ');
    writeln('- age: ', ver^.age);
    writeln('- version: ', ver^.version);
    writeln('- version_num: ', ver^.version_num);
    writeln('- host: ', ver^.host);
    writeln('- features: ', ver^.features);
    writeln('- ssl_version: ', ver^.ssl_version);
    writeln('- libz_version: ', ver^.libz_version);
    writeln('- ares: ', ver^.ares);
    writeln('- libidn: ', ver^.libidn);
    writeln('- iconv_ver_num: ', ver^.iconv_ver_num);
    writeln('- libssh_version: ', ver^.libssh_version);

    writeln('Starting test download');
    link:='https://raw.githubusercontent.com/FreeZoneMods/freezone/master/README.md';
    //link:='http://95.154.127.85/mp_bunker_l10u_cs.db';
    purl := curl_easy_init();
    if purl=nil then exit;

    if curl_easy_setopt(purl, CURLOPT_URL, uintptr(PAnsiChar(link))) <> CURLE_OK then exit;
    curl_easy_setopt(purl, CURLOPT_WRITEFUNCTION, uintptr(@write_callback) );
    curl_easy_setopt(purl, CURLOPT_WRITEDATA, 12345);
    curl_easy_setopt(purl, CURLOPT_NOPROGRESS, 0);

    curl_easy_setopt(purl, CURLOPT_XFERINFODATA, 12345);
    curl_easy_setopt(purl, CURLOPT_XFERINFOFUNCTION, uintptr(@progress_callback));

    if curl_easy_perform(purl) <> CURLE_OK then exit;

    if curl_easy_getinfo( purl, CURLINFO_EFFECTIVE_URL, @tmp ) <> CURLE_OK then exit;

    writeln();
    writeln('Getinfo returns URL ', tmp);

    curl_easy_cleanup(purl);

    writeln('Checking DL system using FZCurlDownloaderThread ');
    th:=FZCurlDownloaderThread.Create();
    dl:=th.CreateDownloader(link, filename, 0);
    writeln('Start download from '+link);

    res:=dl.StartSyncDownload();
    writeln('Download result: '+booltostr(res, true)+', size '+ inttostr(dl.DownloadedBytes()));
    if not res then exit;

    dl.Free();
    th.Free();
    DeleteFile(PChar(filename));

    result:=true;

  finally
    writeln('**********************************');
    if result then begin
      writeln('LIBCURL TESTS PASSED');
    end else begin
      writeln('LIBCURL TESTS FAILED');
    end;
    writeln('**********************************');
    writeln;
  end;
end;

function Crc32Tests():boolean;
var
  ctx:TCRC32Context;
  text:string;
  crc_need, crc_real, time:cardinal;
  i:integer;

  memptr:pointer;
const
  cycles_count:integer = 100;
  memsz:cardinal=10*1024*1024; //10mb
begin
  result:=false;
  writeln('**********************************');
  writeln('CRC32 TESTS START');
  writeln('**********************************');
  try
    text:='This text is here only for check if CRC32 algorithm runs normally';
    crc_need:=$8EE586D7;

    ctx:=Crc32Start();
    crc_real:=CRC32End(ctx, PChar(text), length(text));
    writeln('Expected CRC32 is '+inttohex(crc_need,8),', got '+inttohex(crc_real,8));
    if crc_real<>crc_need then exit;

    memptr:=GetMem(memsz);
    writeln('Buffer addr '+inttohex(PtrInt(memptr), 8));
    if memptr=nil then exit;
    FillMemory(memptr, memsz, 0);
    crc_need:=$9eca2acc;

    writeln('Start CRC32 performance measurement');
    time:=GetCurrentTime();
    for i:=0 to cycles_count do begin
      ctx:=Crc32Start();
      crc_real:=CRC32End(ctx, PChar(memptr), memsz);
      if crc_real<>crc_need then begin;
        writeln('Expected CRC32 is '+inttohex(crc_need,8),', got '+inttohex(crc_real,8));
        exit;
      end;
    end;
    time:=GetCurrentTime()-time;
    writeln('CRC32 execution time is '+inttostr(time)+'(ms), cycles count '+inttostr(cycles_count));
    FreeMemory(memptr);

    result:=true;
  finally
    writeln('**********************************');
    if result then begin
      writeln('CRC32 TESTS PASSED');
    end else begin
      writeln('CRC32 TESTS FAILED');
    end;
    writeln('**********************************');
    writeln;
  end;
end;

var
  SuiteResult:boolean;
begin
  SuiteResult:=false;
  LogMgr.Init;
  try
    //if not Md5Tests() then exit;
    //if not CmdLineTests() then exit;
    //if not Crc32Tests() then exit;

    if not LibCurlTests() then exit;
    //if not GameSpyDownloaderTests() then exit;

    SuiteResult:=true;
  finally
    writeln('**********************************');
    if SuiteResult then begin
      writeln('FINISHED SUCCESSFULLY!');
    end else begin
      writeln('FAILURE HAPPENS!');
    end;
    writeln('**********************************');
    readln();
    LogMgr.Free;
  end;
end.

