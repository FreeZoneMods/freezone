{ Lazarus interface for libcurl.
  Library built with WinSSL support, requires msvcr.dll to be present
  For successful static linking we need libs from MinGW.

                                                        by Sin!, 2017
}

unit curl;

{$mode objfpc}

//A lot of external stuff, don't change the order!
{$linklib libcurl.a}
{$linklib libgcc.a}
{$linklib libmingwex.a}

{$linklib libadvapi32.a}
{$linklib libcrypt32.a}
{$linklib libkernel32.a}

{$linklib libmoldname.a}
{$linklib libmsvcrt.a}

{$linklib libwldap32.a}
{$linklib libws2_32.a}

interface

type
  pTCURL = pointer;

  CURLcode = cardinal;
  CURLoption = cardinal;
  CURLINFO = cardinal;

  curl_version_info_data = record
    age:cardinal;
    version:PAnsiChar;
    version_num:cardinal;
    host:PAnsiChar;
    features:integer;
    ssl_version:PAnsiChar;
    ssl_version_num:cardinal;
    libz_version:PAnsiChar;
    protocols:PPAnsiChar;
    ares:PAnsiChar;
    libidn:PAnsiChar;
    iconv_ver_num:integer;
    libssh_version:PAnsiChar;
  end;
  pcurl_version_info_data = ^curl_version_info_data;

const
  //CURLVERSION - arguments for curl_version_info
  CURLVERSION_FIRST:  cardinal = 0;
  CURLVERSION_SECOND: cardinal = 1;
  CURLVERSION_THIRD:  cardinal = 2;
  CURLVERSION_FOURTH: cardinal = 3;

  //CURLcode - status of operations
  CURLE_OK :                      CURLcode = 0;
  CURLE_UNSUPPORTED_PROTOCOL:     CURLcode = 1;
  CURLE_FAILED_INIT:              CURLcode = 2;
  CURLE_URL_MALFORMAT:            CURLcode = 3;
  CURLE_NOT_BUILT_IN:             CURLcode = 4;  // [was obsoleted in August 2007 for 7.17.0, reused in April 2011 for 7.21.5]
  CURLE_COULDNT_RESOLVE_PROXY:    CURLcode = 5;
  CURLE_COULDNT_RESOLVE_HOST:     CURLcode = 6;
  CURLE_COULDNT_CONNECT:          CURLcode = 7;
  CURLE_WEIRD_SERVER_REPLY:       CURLcode = 8;
  CURLE_REMOTE_ACCESS_DENIED:     CURLcode = 9;  //a service was denied by the server due to lack of access - when login fails this is not returned.
  CURLE_FTP_ACCEPT_FAILED:        CURLcode = 10; //[was obsoleted in April 2006 for 7.15.4, reused in Dec 2011 for 7.24.0]
  CURLE_FTP_WEIRD_PASS_REPLY:     CURLcode = 11;
  CURLE_FTP_ACCEPT_TIMEOUT:       CURLcode = 12; //timeout occurred accepting server [was obsoleted in August 2007 for 7.17.0, reused in Dec 2011 for 7.24.0]
  CURLE_FTP_WEIRD_PASV_REPLY:     CURLcode = 13;
  CURLE_FTP_WEIRD_227_FORMAT:     CURLcode = 14;
  CURLE_FTP_CANT_GET_HOST:        CURLcode = 15;
  CURLE_HTTP2:                    CURLcode = 16; // A problem in the http2 framing layer. [was obsoleted in August 2007 for 7.17.0, reused in July 2014 for 7.38.0]
  CURLE_FTP_COULDNT_SET_TYPE:     CURLcode = 17;
  CURLE_PARTIAL_FILE:             CURLcode = 18;
  CURLE_FTP_COULDNT_RETR_FILE:    CURLcode = 19;
  CURLE_OBSOLETE20:               CURLcode = 20; // NOT USED
  CURLE_QUOTE_ERROR:              CURLcode = 21; // quote command failure
  CURLE_HTTP_RETURNED_ERROR:      CURLcode = 22;
  CURLE_WRITE_ERROR:              CURLcode = 23;
  CURLE_OBSOLETE24:               CURLcode = 24; // NOT USED
  CURLE_UPLOAD_FAILED:            CURLcode = 25; // failed upload "command"
  CURLE_READ_ERROR:               CURLcode = 26; // couldn't open/read from file
  CURLE_OUT_OF_MEMORY:            CURLcode = 27; // Note: CURLE_OUT_OF_MEMORY may sometimes indicate a conversion error instead of a memory allocation error if CURL_DOES_CONVERSIONS is defined
  CURLE_OPERATION_TIMEDOUT:       CURLcode = 28; // the timeout time was reached
  CURLE_OBSOLETE29:               CURLcode = 29; // NOT USED
  CURLE_FTP_PORT_FAILED:          CURLcode = 30; // FTP PORT operation failed
  CURLE_FTP_COULDNT_USE_REST:     CURLcode = 31; // the REST command failed
  CURLE_OBSOLETE32:               CURLcode = 32; // NOT USED
  CURLE_RANGE_ERROR:              CURLcode = 33; // RANGE "command" didn't work
  CURLE_HTTP_POST_ERROR:          CURLcode = 34;
  CURLE_SSL_CONNECT_ERROR:        CURLcode = 35; // wrong when connecting with SSL
  CURLE_BAD_DOWNLOAD_RESUME:      CURLcode = 36; // couldn't resume download
  CURLE_FILE_COULDNT_READ_FILE:   CURLcode = 37;
  CURLE_LDAP_CANNOT_BIND:         CURLcode = 38;
  CURLE_LDAP_SEARCH_FAILED:       CURLcode = 39;
  CURLE_OBSOLETE40:               CURLcode = 40; // NOT USED
  CURLE_FUNCTION_NOT_FOUND:       CURLcode = 41; // NOT USED starting with 7.53.0
  CURLE_ABORTED_BY_CALLBACK:      CURLcode = 42;
  CURLE_BAD_FUNCTION_ARGUMENT:    CURLcode = 43;
  CURLE_OBSOLETE44:               CURLcode = 44; // NOT USED
  CURLE_INTERFACE_FAILED:         CURLcode = 45; // CURLOPT_INTERFACE failed
  CURLE_OBSOLETE46:               CURLcode = 46; // NOT USED
  CURLE_TOO_MANY_REDIRECTS:       CURLcode = 47; // catch endless re-direct loops
  CURLE_UNKNOWN_OPTION:           CURLcode = 48; // User specified an unknown option
  CURLE_TELNET_OPTION_SYNTAX:     CURLcode = 49; // Malformed telnet option
  CURLE_OBSOLETE50:               CURLcode = 50; // NOT USED
  CURLE_PEER_FAILED_VERIFICATION: CURLcode = 51; // peer's certificate or fingerprint wasn't verified fine
  CURLE_GOT_NOTHING:              CURLcode = 52; // when this is a specific error
  CURLE_SSL_ENGINE_NOTFOUND:      CURLcode = 53; // SSL crypto engine not found
  CURLE_SSL_ENGINE_SETFAILED:     CURLcode = 54; // can not set SSL crypto engine as default
  CURLE_SEND_ERROR:               CURLcode = 55; // failed sending network data
  CURLE_RECV_ERROR:               CURLcode = 56; // failure in receiving network data
  CURLE_OBSOLETE57:               CURLcode = 57; // NOT IN USE
  CURLE_SSL_CERTPROBLEM:          CURLcode = 58; // problem with the local certificate
  CURLE_SSL_CIPHER:               CURLcode = 59; // couldn't use specified cipher
  CURLE_SSL_CACERT:               CURLcode = 60; // problem with the CA cert (path?)
  CURLE_BAD_CONTENT_ENCODING:     CURLcode = 61; // Unrecognized/bad encoding
  CURLE_LDAP_INVALID_URL:         CURLcode = 62; // Invalid LDAP URL
  CURLE_FILESIZE_EXCEEDED:        CURLcode = 63; // Maximum file size exceeded
  CURLE_USE_SSL_FAILED:           CURLcode = 64; // Requested FTP SSL level failed
  CURLE_SEND_FAIL_REWIND:         CURLcode = 65; // Sending the data requires a rewind that failed
  CURLE_SSL_ENGINE_INITFAILED:    CURLcode = 66; // failed to initialise ENGINE
  CURLE_LOGIN_DENIED:             CURLcode = 67; // user, password or similar was not accepted and we failed to login
  CURLE_TFTP_NOTFOUND:            CURLcode = 68; // file not found on server
  CURLE_TFTP_PERM:                CURLcode = 69; // permission problem on server
  CURLE_REMOTE_DISK_FULL:         CURLcode = 70; // out of disk space on server
  CURLE_TFTP_ILLEGAL:             CURLcode = 71; // Illegal TFTP operation
  CURLE_TFTP_UNKNOWNID:           CURLcode = 72; // Unknown transfer ID
  CURLE_REMOTE_FILE_EXISTS:       CURLcode = 73; // File already exists
  CURLE_TFTP_NOSUCHUSER:          CURLcode = 74; // No such user
  CURLE_CONV_FAILED:              CURLcode = 75; // conversion failed
  CURLE_CONV_REQD:                CURLcode = 76; // caller must register conversion callbacks using curl_easy_setopt options
                                                 // CURLOPT_CONV_FROM_NETWORK_FUNCTION,
                                                 // CURLOPT_CONV_TO_NETWORK_FUNCTION, and
                                                 // CURLOPT_CONV_FROM_UTF8_FUNCTION
  CURLE_SSL_CACERT_BADFILE:       CURLcode = 77; // could not load CACERT file, missing or wrong format
  CURLE_REMOTE_FILE_NOT_FOUND:    CURLcode = 78; // remote file not found
  CURLE_SSH:                      CURLcode = 79; // error from the SSH layer, somewhat generic so the error message will be of interest when this has happened
  CURLE_SSL_SHUTDOWN_FAILED:      CURLcode = 80; // Failed to shut down the SSL connection
  CURLE_AGAIN:                    CURLcode = 81; // socket is not ready for send/recv, wait till it's ready and try again (Added in 7.18.2)
  CURLE_SSL_CRL_BADFILE:          CURLcode = 82; // could not load CRL file, missing or wrong format (Added in 7.19.0)
  CURLE_SSL_ISSUER_ERROR:         CURLcode = 83; // Issuer check failed.  (Added in 7.19.0)
  CURLE_FTP_PRET_FAILED:          CURLcode = 84; // a PRET command failed
  CURLE_RTSP_CSEQ_ERROR:          CURLcode = 85; // mismatch of RTSP CSeq numbers
  CURLE_RTSP_SESSION_ERROR:       CURLcode = 86; // mismatch of RTSP Session Ids
  CURLE_FTP_BAD_FILE_LIST:        CURLcode = 87; // unable to parse FTP file list
  CURLE_CHUNK_FAILED:             CURLcode = 88; // chunk callback reported error
  CURLE_NO_CONNECTION_AVAILABLE:  CURLcode = 89; // No connection available, the session will be queued
  CURLE_SSL_PINNEDPUBKEYNOTMATCH: CURLcode = 90; // specified pinned public key did not match
  CURLE_SSL_INVALIDCERTSTATUS:    CURLcode = 91; // invalid certificate status
  CURLE_HTTP2_STREAM:             CURLcode = 92; // stream error in HTTP/2 framing layer


  //CURLOPTTYPE - for using with curl_easy_setopt function
  CURLOPTTYPE_LONG:                   CURLoption = 0;
  CURLOPT_PORT:                       CURLoption = 3;   // Port number to connect to, if other than default.
  CURLOPT_TIMEOUT:                    CURLoption = 13;  // Time-out the read operation after this amount of seconds
  CURLOPT_INFILESIZE:                 CURLoption = 14;  // If the CURLOPT_INFILE is used, this can be used to inform libcurl about how large the file being sent really is. That allows better error checking and better verifies that the upload was successful. -1 means unknown size.
                                                        // For large file support, there is also a _LARGE version of the key which takes an off_t type, allowing platforms with larger off_t sizes to handle larger files.  See below for INFILESIZE_LARGE.
  CURLOPT_LOW_SPEED_LIMIT:            CURLoption = 19;  // Set the "low speed limit"
  CURLOPT_LOW_SPEED_TIME:             CURLoption = 20;  // Set the "low speed time"
  CURLOPT_RESUME_FROM:                CURLoption = 21;  // Set the continuation offset. Note there is also a _LARGE version of this key which uses off_t types, allowing for large file offsets on platforms which use larger-than-32-bit off_t's.  Look below for RESUME_FROM_LARGE.
  CURLOPT_CRLF:                       CURLoption = 27;  // send TYPE parameter?
  CURLOPT_SSLVERSION:                 CURLoption = 32;  // What version to specifically try to use. See CURL_SSLVERSION defines below.
  CURLOPT_TIMECONDITION:              CURLoption = 33;  // What kind of HTTP time condition to use, see defines
  CURLOPT_TIMEVALUE:                  CURLoption = 34;  // Time to use with the above condition. Specified in number of seconds since 1 Jan 1970
  CURLOPT_VERBOSE:                    CURLoption = 41;  // talk a lot
  CURLOPT_HEADER:                     CURLoption = 42;  // throw the header out too
  CURLOPT_NOPROGRESS:                 CURLoption = 43;  // shut off the progress meter
  CURLOPT_NOBODY:                     CURLoption = 44;  // use HEAD to get http document
  CURLOPT_FAILONERROR:                CURLoption = 45;  // no output on http error codes >= 400
  CURLOPT_UPLOAD:                     CURLoption = 46;  // this is an upload
  CURLOPT_POST:                       CURLoption = 47;  // HTTP POST method
  CURLOPT_DIRLISTONLY:                CURLoption = 48;  // bare names when listing directories
  CURLOPT_APPEND:                     CURLoption = 50;  // Append instead of overwrite on upload!
  CURLOPT_NETRC:                      CURLoption = 51;  // Specify whether to read the user+password from the .netrc or the URL. This must be one of the CURL_NETRC_* enums below.
  CURLOPT_FOLLOWLOCATION:             CURLoption = 52;  // use Location: Luke!
  CURLOPT_TRANSFERTEXT:               CURLoption = 53;  // transfer data in text/ASCII format
  CURLOPT_PUT:                        CURLoption = 54;  // HTTP PUT
  CURLOPT_AUTOREFERER:                CURLoption = 58;  // We want the referrer field set automatically when following locations
  CURLOPT_PROXYPORT:                  CURLoption = 59;  // Port of the proxy, can be set in the proxy string as well with: "[host]:[port]"
  CURLOPT_POSTFIELDSIZE:              CURLoption = 60;  // size of the POST input data, if strlen() is not good to use
  CURLOPT_HTTPPROXYTUNNEL:            CURLoption = 61;  // tunnel non-http operations through a HTTP proxy
  CURLOPT_SSL_VERIFYPEER:             CURLoption = 64;  // Set if we should verify the peer in ssl handshake, set 1 to verify.
  CURLOPT_MAXREDIRS:                  CURLoption = 68;  // Maximum number of http redirects to follow
  CURLOPT_FILETIME:                   CURLoption = 69;  // Pass a long set to 1 to get the date of the requested document (if possible)! Pass a zero to shut it off.
  CURLOPT_MAXCONNECTS:                CURLoption = 71;  // Max amount of cached alive connections
  CURLOPT_OBSOLETE72:                 CURLoption = 72;  // OBSOLETE, do not use!
  CURLOPT_FRESH_CONNECT:              CURLoption = 74;  // Set to explicitly use a new connection for the upcoming transfer. Do not use this unless you're absolutely sure of this, as it makes the operation slower and is less friendly for the network.
  CURLOPT_FORBID_REUSE:               CURLoption = 75;  // Set to explicitly forbid the upcoming transfer's connection to be re-used when done. Do not use this unless you're absolutely sure of this, as it makes the operation slower and is less friendly for the network.
  CURLOPT_CONNECTTIMEOUT:             CURLoption = 78;  // Time-out connect operations after this amount of seconds, if connects are OK within this time, then fine... This only aborts the connect phase.
  CURLOPT_HTTPGET:                    CURLoption = 80;  // Set this to force the HTTP request to get back to GET. Only really usable if POST, PUT or a custom request have been used first.
  CURLOPT_SSL_VERIFYHOST:             CURLoption = 81;  // Set if we should verify the Common name from the peer certificate in ssl handshake, set 1 to check existence, 2 to ensure that it matches the provided hostname.
  CURLOPT_HTTP_VERSION:               CURLoption = 84;  // Specify which HTTP version to use! This must be set to one of the CURL_HTTP_VERSION* enums set below.
  CURLOPT_FTP_USE_EPSV:               CURLoption = 85;  // Specifically switch on or off the FTP engine's use of the EPSV command. By default, that one will always be attempted before the more traditional PASV command.
  CURLOPT_SSLENGINE_DEFAULT:          CURLoption = 90;  // set the crypto engine for the SSL-sub system as default the param has no meaning...
  CURLOPT_DNS_USE_GLOBAL_CACHE:       CURLoption = 91;  // Non-zero value means to use the global dns cache. DEPRECATED, do not use!
  CURLOPT_DNS_CACHE_TIMEOUT:          CURLoption = 92;  // DNS cache timeout
  CURLOPT_COOKIESESSION:              CURLoption = 96;  // mark this as start of a cookie session
  CURLOPT_BUFFERSIZE:                 CURLoption = 98;  // Instruct libcurl to use a smaller receive buffer
  CURLOPT_NOSIGNAL:                   CURLoption = 99;  // Instruct libcurl to not use any signal/alarm handlers, even when using timeouts. This option is useful for multi-threaded applications. See libcurl-the-guide for more background information.
  CURLOPT_PROXYTYPE:                  CURLoption = 101; // indicates type of proxy. accepted values are CURLPROXY_HTTP (default), CURLPROXY_HTTPS, CURLPROXY_SOCKS4, CURLPROXY_SOCKS4A and CURLPROXY_SOCKS5.
  CURLOPT_UNRESTRICTED_AUTH:          CURLoption = 105; // Continue to send authentication (user+password) when following locations, even when hostname changed. This can potentially send off the name and password to whatever host the server decides.
  CURLOPT_FTP_USE_EPRT:               CURLoption = 106; // Specifically switch on or off the FTP engine's use of the EPRT command (it also disables the LPRT attempt). By default, those ones will always be attempted before the good old traditional PORT command.
  CURLOPT_HTTPAUTH:                   CURLoption = 107; // Set this to a bitmask value to enable the particular authentications methods you like. Use this in combination with CURLOPT_USERPWD. Note that setting multiple bits may cause extra network round-trips.
  CURLOPT_FTP_CREATE_MISSING_DIRS:    CURLoption = 110; // FTP Option that causes missing dirs to be created on the remote server. In 7.19.4 we introduced the convenience enums for this option using the CURLFTP_CREATE_DIR prefix.
  CURLOPT_PROXYAUTH:                  CURLoption = 111; // Set this to a bitmask value to enable the particular authentication methods you like. Use this in combination with CURLOPT_PROXYUSERPWD. Note that setting multiple bits may cause extra network round-trips.
  CURLOPT_FTP_RESPONSE_TIMEOUT:       CURLoption = 112; // FTP option that changes the timeout, in seconds, associated with getting a response.  This is different from transfer timeout time and essentially places a demand on the FTP server to acknowledge commands in a timely manner.
  CURLOPT_SERVER_RESPONSE_TIMEOUT:    CURLoption = 112; // same as CURLOPT_FTP_RESPONSE_TIMEOUT
  CURLOPT_IPRESOLVE:                  CURLoption = 113; // Set this option to one of the CURL_IPRESOLVE_* defines (see below) to tell libcurl to resolve names to those IP versions only. This only has affect on systems with support for more than one, i.e IPv4 _and_ IPv6.
  CURLOPT_MAXFILESIZE:                CURLoption = 114; // Set this option to limit the size of a file that will be downloaded from an HTTP or FTP server. Note there is also _LARGE version which adds large file support for platforms which have larger off_t sizes.  See MAXFILESIZE_LARGE below.
  CURLOPT_USE_SSL:                    CURLoption = 119; // Enable SSL/TLS for FTP, pick one of: CURLUSESSL_TRY - try using SSL, proceed anyway otherwise; CURLUSESSL_CONTROL - SSL for the control connection or fail; CURLUSESSL_ALL - SSL for all communication or fail
  CURLOPT_TCP_NODELAY:                CURLoption = 121; // Enable/disable the TCP Nagle algorithm
  CURLOPT_FTPSSLAUTH:                 CURLoption = 129; // When FTP over SSL/TLS is selected (with CURLOPT_USE_SSL), this option
                                                        // can be used to change libcurl's default action which is to first try
                                                        // "AUTH SSL" and then "AUTH TLS" in this order, and proceed when a OK
                                                        // response has been received.
                                                        //
                                                        // Available parameters are:
                                                        // CURLFTPAUTH_DEFAULT - let libcurl decide
                                                        // CURLFTPAUTH_SSL     - try "AUTH SSL" first, then TLS
                                                        // CURLFTPAUTH_TLS     - try "AUTH TLS" first, then SSL
  CURLOPT_IGNORE_CONTENT_LENGTH:      CURLoption = 136; // ignore Content-Length
  CURLOPT_FTP_SKIP_PASV_IP:           CURLoption = 137; // Set to non-zero to skip the IP address received in a 227 PASV FTP server response. Typically used for FTP-SSL purposes but is not restricted to that. libcurl will then instead use the same IP address it used for the control connection.
  CURLOPT_FTP_FILEMETHOD:             CURLoption = 138; // Select "file method" to use when doing FTP, see the curl_ftpmethod above.
  CURLOPT_LOCALPORT:                  CURLoption = 139; // Local port number to bind the socket to
  CURLOPT_LOCALPORTRANGE:             CURLoption = 140; // Number of ports to try, including the first one set with LOCALPORT. Thus, setting it to 1 will make no additional attempts but the first.
  CURLOPT_CONNECT_ONLY:               CURLoption = 141; // no transfer, set up connection and let application use the socket by extracting it with CURLINFO_LASTSOCKET
  CURLOPT_SSL_SESSIONID_CACHE:        CURLoption = 150; // set to 0 to disable session ID re-use for this transfer, default is enabled (== 1)
  CURLOPT_SSH_AUTH_TYPES:             CURLoption = 151; // allowed SSH authentication methods
  CURLOPT_FTP_SSL_CCC:                CURLoption = 154; // Send CCC (Clear Command Channel) after authentication
  CURLOPT_TIMEOUT_MS:                 CURLoption = 155; // Same as TIMEOUT and CONNECTTIMEOUT, but with ms resolution
  CURLOPT_CONNECTTIMEOUT_MS:          CURLoption = 156;
  CURLOPT_HTTP_TRANSFER_DECODING:     CURLoption = 157; // set to zero to disable the libcurl's decoding and thus pass the raw body data to the application even when it is encoded/compressed
  CURLOPT_HTTP_CONTENT_DECODING:      CURLoption = 158;
  CURLOPT_NEW_FILE_PERMS:             CURLoption = 159; // Permission used when creating new files and directories on the remote server for protocols that support it, SFTP/SCP/FILE
  CURLOPT_NEW_DIRECTORY_PERMS:        CURLoption = 160;
  CURLOPT_POSTREDIR:                  CURLoption = 161; // Set the behaviour of POST when redirecting. Values must be set to one of CURL_REDIR* defines below. This used to be called CURLOPT_POST301
  CURLOPT_PROXY_TRANSFER_MODE:        CURLoption = 166; // set transfer mode (;type=<a|i>) when doing FTP via an HTTP proxy
  CURLOPT_ADDRESS_SCOPE:              CURLoption = 171; // (IPv6) Address scope
  CURLOPT_CERTINFO:                   CURLoption = 172; // Collect certificate chain info and allow it to get retrievable with CURLINFO_CERTINFO after the transfer is complete.
  CURLOPT_TFTP_BLKSIZE:               CURLoption = 178; // block size for TFTP transfers
  CURLOPT_SOCKS5_GSSAPI_NEC:          CURLoption = 180; // Socks Service
  CURLOPT_PROTOCOLS:                  CURLoption = 181; // set the bitmask for the protocols that are allowed to be used for the transfer, which thus helps the app which takes URLs from users or other external inputs and want to restrict what protocol(s) to deal with. Defaults to CURLPROTO_ALL.
  CURLOPT_REDIR_PROTOCOLS:            CURLoption = 182; // set the bitmask for the protocols that libcurl is allowed to follow to, as a subset of the CURLOPT_PROTOCOLS ones. That means the protocol needs to be set in both bitmasks to be allowed to get redirected to. Defaults to all protocols except FILE and SCP.
  CURLOPT_FTP_USE_PRET:               CURLoption = 188; // FTP: send PRET before PASV
  CURLOPT_RTSP_REQUEST:               CURLoption = 189; // RTSP request method (OPTIONS, SETUP, PLAY, etc...)
  CURLOPT_RTSP_CLIENT_CSEQ:           CURLoption = 193; // Manually initialize the client RTSP CSeq for this handle
  CURLOPT_RTSP_SERVER_CSEQ:           CURLoption = 194; // Manually initialize the server RTSP CSeq for this handle
  CURLOPT_WILDCARDMATCH:              CURLoption = 197; // Turn on wildcard matching
  CURLOPT_TRANSFER_ENCODING:          CURLoption = 207; // Set to 1 to enable the "TE:" header in HTTP requests to ask for compressed transfer-encoded responses. Set to 0 to disable the use of TE: in outgoing requests. The current default is 0, but it might change in a future libcurl release. libcurl will ask for the compressed methods it knows of, and if that isn't any, it will not ask for transfer-encoding at all even if this option is set to 1.
  CURLOPT_GSSAPI_DELEGATION:          CURLoption = 210; // allow GSSAPI credential delegation
  CURLOPT_ACCEPTTIMEOUT_MS:           CURLoption = 212; // Time-out accept operations (currently for FTP only) after this amount of milliseconds.
  CURLOPT_TCP_KEEPALIVE:              CURLoption = 213; // Set TCP keepalive
  CURLOPT_TCP_KEEPIDLE:               CURLoption = 214; // non-universal keepalive knobs (Linux, AIX, HP-UX, more)
  CURLOPT_TCP_KEEPINTVL:              CURLoption = 215; // non-universal keepalive knobs (Linux, AIX, HP-UX, more)
  CURLOPT_SSL_OPTIONS:                CURLoption = 216; // Enable/disable specific SSL features with a bitmask, see CURLSSLOPT_*
  CURLOPT_SASL_IR:                    CURLoption = 218; // Enable/disable SASL initial response
  CURLOPT_SSL_ENABLE_NPN:             CURLoption = 225; // Enable/disable TLS NPN extension (http2 over ssl might fail without)
  CURLOPT_SSL_ENABLE_ALPN:            CURLoption = 226; // Enable/disable TLS ALPN extension (http2 over ssl might fail without)
  CURLOPT_EXPECT_100_TIMEOUT_MS:      CURLoption = 227; // Time to wait for a response to a HTTP request containing an Expect: 100-continue header before sending the data anyway
  CURLOPT_HEADEROPT:                  CURLoption = 229; // Pass in a bitmask of "header options"
  CURLOPT_SSL_VERIFYSTATUS:           CURLoption = 232; // Set if we should verify the certificate status.
  CURLOPT_SSL_FALSESTART:             CURLoption = 233; // Set if we should enable TLS false start.
  CURLOPT_PATH_AS_IS:                 CURLoption = 234; // Do not squash dot-dot sequences
  CURLOPT_PIPEWAIT:                   CURLoption = 237; // Wait/don't wait for pipe/mutex to clarify
  CURLOPT_STREAM_WEIGHT:              CURLoption = 239; // Set stream weight, 1 - 256 (default is 16)
  CURLOPT_TFTP_NO_OPTIONS:            CURLoption = 242; // Do not send any tftp option requests to the server
  CURLOPT_TCP_FASTOPEN:               CURLoption = 244; // Set TCP Fast Open
  CURLOPT_KEEP_SENDING_ON_ERROR:      CURLoption = 245; // Continue to send data if the server responds early with an HTTP status code >= 300
  CURLOPT_PROXY_SSL_VERIFYPEER:       CURLoption = 248; // Set if we should verify the proxy in ssl handshake, set 1 to verify.
  CURLOPT_PROXY_SSL_VERIFYHOST:       CURLoption = 249; // Set if we should verify the Common name from the proxy certificate in ssl handshake, set 1 to check existence, 2 to ensure that it matches the provided hostname.
  CURLOPT_PROXY_SSLVERSION:           CURLoption = 250; // What version to specifically try to use for proxy. See CURL_SSLVERSION defines below.
  CURLOPT_PROXY_SSL_OPTIONS:          CURLoption = 261; // Enable/disable specific SSL features with a bitmask for proxy, see CURLSSLOPT_
  CURLOPT_SUPPRESS_CONNECT_HEADERS:   CURLoption = 265; // Suppress proxy CONNECT response headers from user callbacks
  CURLOPT_SOCKS5_AUTH:                CURLoption = 267; // bitmask of allowed auth methods for connections to SOCKS5 proxies


  CURLOPTTYPE_OBJECTPOINT:            CURLoption = 10000;
  CURLOPT_WRITEDATA:                  CURLoption = 10000 + 1;   // This is the FILE * or void * the regular output should be written to.
  CURLOPT_READDATA:                   CURLoption = 10000 + 9;   // Specified file stream to upload from (use as input)
  CURLOPT_ERRORBUFFER:                CURLoption = 10000 + 10;  // Buffer to receive error messages in, must be at least CURL_ERROR_SIZE bytes big. If this is not used, error messages go to stderr instead
  CURLOPT_POSTFIELDS:                 CURLoption = 10000 + 15;  // POST static input fields.
  CURLOPT_HTTPHEADER:                 CURLoption = 10000 + 23;  // This points to a linked list of headers, struct curl_slist kind. This list is also used for RTSP (in spite of its name)
  CURLOPT_HTTPPOST:                   CURLoption = 10000 + 24;  // This points to a linked list of post entries, struct curl_httppost
  CURLOPT_QUOTE:                      CURLoption = 10000 + 28;  // send linked-list of QUOTE commands
  CURLOPT_HEADERDATA:                 CURLoption = 10000 + 29;  // send FILE * or void * to store headers to, if you use a callback it is simply passed to the callback unmodified
  CURLOPT_STDERR:                     CURLoption = 10000 + 37;  // FILE handle to use instead of stderr
  CURLOPT_POSTQUOTE:                  CURLoption = 10000 + 39;  // send linked-list of post-transfer QUOTE commands
  CURLOPT_OBSOLETE40:                 CURLoption = 10000 + 40;  // OBSOLETE, do not use!
  CURLOPT_PROGRESSDATA:               CURLoption = 10000 + 57;  // Data passed to the CURLOPT_PROGRESSFUNCTION and CURLOPT_XFERINFOFUNCTION callbacks
  CURLOPT_XFERINFODATA:               CURLoption = 10000 + 57;  // same as CURLOPT_PROGRESSDATA
  CURLOPT_TELNETOPTIONS:              CURLoption = 10000 + 70;  // This points to a linked list of telnet options
  CURLOPT_PREQUOTE:                   CURLoption = 10000 + 93;  // send linked-list of pre-transfer QUOTE commands
  CURLOPT_DEBUGDATA:                  CURLoption = 10000 + 95;  // set the data for the debug function
  CURLOPT_SHARE:                      CURLoption = 10000 + 100; // Provide a CURLShare for mutexing non-ts data
  CURLOPT_PRIVATE:                    CURLoption = 10000 + 103; // Set pointer to private data
  CURLOPT_HTTP200ALIASES:             CURLoption = 10000 + 104; // Set aliases for HTTP 200 in the HTTP Response header
  CURLOPT_SSL_CTX_DATA:               CURLoption = 10000 + 109; // Set the userdata for the ssl context callback function's third argument
  CURLOPT_IOCTLDATA:                  CURLoption = 10000 + 131;
  CURLOPT_SOCKOPTDATA:                CURLoption = 10000 + 149; // passed to callback function for setting socket options
  CURLOPT_OPENSOCKETDATA:             CURLoption = 10000 + 164; // data to pass into callback function for opening socket
  CURLOPT_COPYPOSTFIELDS:             CURLoption = 10000 + 165; // POST volatile input fields.
  CURLOPT_SEEKDATA:                   CURLoption = 10000 + 168; // data to pass into callback function for seeking in the input stream
  CURLOPT_SSH_KEYDATA:                CURLoption = 10000 + 185; // set the SSH host key callback custom pointer
  CURLOPT_MAIL_RCPT:                  CURLoption = 10000 + 187; // set the list of SMTP mail receiver(s)
  CURLOPT_INTERLEAVEDATA:             CURLoption = 10000 + 195; // The stream to pass to INTERLEAVEFUNCTION.
  CURLOPT_CHUNK_DATA:                 CURLoption = 10000 + 201; // Let the application define custom chunk data pointer
  CURLOPT_FNMATCH_DATA:               CURLoption = 10000 + 202; // FNMATCH_FUNCTION user pointer
  CURLOPT_RESOLVE:                    CURLoption = 10000 + 203; // send linked-list of name:port:address sets
  CURLOPT_CLOSESOCKETDATA:            CURLoption = 10000 + 209; // data to pass into callback function for closing socket
  CURLOPT_PROXYHEADER:                CURLoption = 10000 + 228; // This points to a linked list of headers used for proxy requests only, struct curl_slist kind
  CURLOPT_STREAM_DEPENDS:             CURLoption = 10000 + 240; // Set stream dependency on another CURL handle
  CURLOPT_STREAM_DEPENDS_E:           CURLoption = 10000 + 241; // Set E-xclusive stream dependency on another CURL handle
  CURLOPT_CONNECT_TO:                 CURLoption = 10000 + 243; // Linked-list of host:port:connect-to-host:connect-to-port, overrides the URL's host:port (only for the network layer)

  CURLOPTTYPE_STRINGPOINT:            CURLoption = 10000;
  CURLOPT_URL:                        CURLoption = 10000 + 2;   // The full URL to get/put
  CURLOPT_PROXY:                      CURLoption = 10000 + 4;   // Name of proxy to use.
  CURLOPT_USERPWD:                    CURLoption = 10000 + 5;   // "user:password;options" to use when fetching.
  CURLOPT_PROXYUSERPWD:               CURLoption = 10000 + 6;   // "user:password" to use with proxy.
  CURLOPT_RANGE:                      CURLoption = 10000 + 7;   // Range to get, specified as an ASCII string.
  CURLOPT_REFERER:                    CURLoption = 10000 + 16;  // Set the referrer page (needed by some CGIs)
  CURLOPT_FTPPORT:                    CURLoption = 10000 + 17;  // Set the FTP PORT string (interface name, named or numerical IP address). Use i.e '-' to use default address.
  CURLOPT_USERAGENT:                  CURLoption = 10000 + 18;  // Set the User-Agent string (examined by some CGIs)
  CURLOPT_COOKIE:                     CURLoption = 10000 + 22;  // Set cookie in request
  CURLOPT_SSLCERT:                    CURLoption = 10000 + 25;  // name of the file keeping your private SSL-certificate
  CURLOPT_KEYPASSWD:                  CURLoption = 10000 + 26;  // password for the SSL or SSH private key
  CURLOPT_COOKIEFILE:                 CURLoption = 10000 + 31;  // point to a file to read the initial cookies from, also enables "cookie awareness"
  CURLOPT_CUSTOMREQUEST:              CURLoption = 10000 + 36;  // Custom request, for customizing the get command like: HTTP: DELETE, TRACE and others; FTP: to use a different list command
  CURLOPT_INTERFACE:                  CURLoption = 10000 + 62;  // Set the interface string to use as outgoing network interface
  CURLOPT_KRBLEVEL:                   CURLoption = 10000 + 63;  // Set the krb4/5 security level, this also enables krb4/5 awareness.  This is a string, 'clear', 'safe', 'confidential' or 'private'.  If the string is set but doesn't match one of these, 'private' will be used.
  CURLOPT_CAINFO:                     CURLoption = 10000 + 65;  // The CApath or CAfile used to validate the peer certificate this option is used only if SSL_VERIFYPEER is true
  CURLOPT_RANDOM_FILE:                CURLoption = 10000 + 76;  // Set to a file name that contains random data for libcurl to use to seed the random engine when doing SSL connects.
  CURLOPT_EGDSOCKET:                  CURLoption = 10000 + 77;  // Set to the Entropy Gathering Daemon socket pathname
  CURLOPT_COOKIEJAR:                  CURLoption = 10000 + 82;  // Specify which file name to write all known cookies in after completed operation. Set file name to "-" (dash) to make it go to stdout.
  CURLOPT_SSL_CIPHER_LIST:            CURLoption = 10000 + 83;  // Specify which SSL ciphers to use
  CURLOPT_SSLCERTTYPE:                CURLoption = 10000 + 86;  // type of the file keeping your SSL-certificate ("DER", "PEM", "ENG")
  CURLOPT_SSLKEY:                     CURLoption = 10000 + 87;  // name of the file keeping your private SSL-key
  CURLOPT_SSLKEYTYPE:                 CURLoption = 10000 + 88;  // type of the file keeping your private SSL-key ("DER", "PEM", "ENG")
  CURLOPT_SSLENGINE:                  CURLoption = 10000 + 89;  // crypto engine for the SSL-sub system
  CURLOPT_CAPATH:                     CURLoption = 10000 + 97;  // The CApath directory used to validate the peer certificate, this option is used only if SSL_VERIFYPEER is true
  CURLOPT_ACCEPT_ENCODING:            CURLoption = 10000 + 102; // Set the Accept-Encoding string. Use this to tell a server you would like the response to be compressed. Before 7.21.6, this was known as CURLOPT_ENCODING
  CURLOPT_NETRC_FILE:                 CURLoption = 10000 + 118; // Set this option to the file name of your .netrc file you want libcurl to parse (using the CURLOPT_NETRC option). If not set, libcurl will do a poor attempt to find the user's home directory and check for a .netrc file in there.
  CURLOPT_FTP_ACCOUNT:                CURLoption = 10000 + 134; // zero terminated string for pass on to the FTP server when asked for "account" info
  CURLOPT_COOKIELIST:                 CURLoption = 10000 + 135; // feed cookie into cookie engine
  CURLOPT_FTP_ALTERNATIVE_TO_USER:    CURLoption = 10000 + 147; // Pointer to command string to send if USER/PASS fails.
  CURLOPT_SSH_PUBLIC_KEYFILE:         CURLoption = 10000 + 152; // Used by scp/sftp to do public/private key authentication
  CURLOPT_SSH_PRIVATE_KEYFILE:        CURLoption = 10000 + 153; // Used by scp/sftp to do public/private key authentication
  CURLOPT_SSH_HOST_PUBLIC_KEY_MD5:    CURLoption = 10000 + 162; // used by scp/sftp to verify the host's public key
  CURLOPT_CRLFILE:                    CURLoption = 10000 + 169; // CRL file
  CURLOPT_ISSUERCERT:                 CURLoption = 10000 + 170; // Issuer certificate
  CURLOPT_USERNAME:                   CURLoption = 10000 + 173; // "name" to use when fetching.
  CURLOPT_PASSWORD:                   CURLoption = 10000 + 174; // "pwd" to use when fetching.
  CURLOPT_PROXYUSERNAME:              CURLoption = 10000 + 175; // "name"to use with Proxy when fetching.
  CURLOPT_PROXYPASSWORD:              CURLoption = 10000 + 176; // "pwd" to use with Proxy when fetching.
  CURLOPT_NOPROXY:                    CURLoption = 10000 + 177; // Comma separated list of hostnames defining no-proxy zones. These should match both hostnames directly, and hostnames within a domain. For example, local.com will match local.com and www.local.com, but NOT notlocal.com or www.notlocal.com. For compatibility with other implementations of this, .local.com will be considered to be the same as local.com. A single * is the only valid wildcard, and effectively disables the use of proxy.
  CURLOPT_SOCKS5_GSSAPI_SERVICE:      CURLoption = 10000 + 179; // DEPRECATED, do not use!
  CURLOPT_SSH_KNOWNHOSTS:             CURLoption = 10000 + 183; // set the SSH knownhost file name to use
  CURLOPT_MAIL_FROM:                  CURLoption = 10000 + 186; // set the SMTP mail originator
  CURLOPT_RTSP_SESSION_ID:            CURLoption = 10000 + 190; // The RTSP session identifier
  CURLOPT_RTSP_STREAM_URI:            CURLoption = 10000 + 191; // The RTSP stream URI
  CURLOPT_RTSP_TRANSPORT:             CURLoption = 10000 + 192; // The Transport: header to use in RTSP requests
  CURLOPT_TLSAUTH_USERNAME:           CURLoption = 10000 + 204; // Set a username for authenticated TLS
  CURLOPT_TLSAUTH_PASSWORD:           CURLoption = 10000 + 205; // Set a password for authenticated TLS
  CURLOPT_TLSAUTH_TYPE:               CURLoption = 10000 + 206; // Set authentication type for authenticated TLS
  CURLOPT_DNS_SERVERS:                CURLoption = 10000 + 211; // Set the name servers to use for DNS resolution
  CURLOPT_MAIL_AUTH:                  CURLoption = 10000 + 217; // Set the SMTP auth originator
  CURLOPT_XOAUTH2_BEARER:             CURLoption = 10000 + 220; // The XOAUTH2 bearer token
  CURLOPT_DNS_INTERFACE:              CURLoption = 10000 + 221; // Set the interface string to use as outgoing network interface for DNS requests. Only supported by the c-ares DNS backend
  CURLOPT_DNS_LOCAL_IP4:              CURLoption = 10000 + 222; // Set the local IPv4 address to use for outgoing DNS requests. Only supported by the c-ares DNS backend
  CURLOPT_DNS_LOCAL_IP6:              CURLoption = 10000 + 223; // Set the local IPv4 address to use for outgoing DNS requests. Only supported by the c-ares DNS backend
  CURLOPT_LOGIN_OPTIONS:              CURLoption = 10000 + 224; // Set authentication options directly
  CURLOPT_PINNEDPUBLICKEY:            CURLoption = 10000 + 230; // The public key in DER form used to validate the peer public key this option is used only if SSL_VERIFYPEER is true
  CURLOPT_UNIX_SOCKET_PATH:           CURLoption = 10000 + 231; // Path to Unix domain socket
  CURLOPT_PROXY_SERVICE_NAME:         CURLoption = 10000 + 235; // Proxy Service Name
  CURLOPT_SERVICE_NAME:               CURLoption = 10000 + 236; // Service Name
  CURLOPT_DEFAULT_PROTOCOL:           CURLoption = 10000 + 238; // Set the protocol used when curl is given a URL without a protocol
  CURLOPT_PROXY_CAINFO:               CURLoption = 10000 + 246; // The CApath or CAfile used to validate the proxy certificate this option is used only if PROXY_SSL_VERIFYPEER is true
  CURLOPT_PROXY_CAPATH:               CURLoption = 10000 + 247; // The CApath directory used to validate the proxy certificate this option is used only if PROXY_SSL_VERIFYPEER is true
  CURLOPT_PROXY_TLSAUTH_USERNAME:     CURLoption = 10000 + 251; // Set a username for authenticated TLS for proxy
  CURLOPT_PROXY_TLSAUTH_PASSWORD:     CURLoption = 10000 + 252; // Set a password for authenticated TLS for proxy
  CURLOPT_PROXY_TLSAUTH_TYPE:         CURLoption = 10000 + 253; // Set authentication type for authenticated TLS for proxy
  CURLOPT_PROXY_SSLCERT:              CURLoption = 10000 + 254; // name of the file keeping your private SSL-certificate for proxy
  CURLOPT_PROXY_SSLCERTTYPE:          CURLoption = 10000 + 255; // type of the file keeping your SSL-certificate ("DER", "PEM", "ENG") for proxy
  CURLOPT_PROXY_SSLKEY:               CURLoption = 10000 + 256; // name of the file keeping your private SSL-key for proxy
  CURLOPT_PROXY_SSLKEYTYPE:           CURLoption = 10000 + 257; // type of the file keeping your private SSL-key ("DER", "PEM", "ENG") for proxy
  CURLOPT_PROXY_KEYPASSWD:            CURLoption = 10000 + 258; // password for the SSL private key for proxy
  CURLOPT_PROXY_SSL_CIPHER_LIST:      CURLoption = 10000 + 259; // Specify which SSL ciphers to use for proxy
  CURLOPT_PROXY_CRLFILE:              CURLoption = 10000 + 260; // CRL file for proxy
  CURLOPT_PRE_PROXY:                  CURLoption = 10000 + 262; // Name of pre proxy to use.
  CURLOPT_PROXY_PINNEDPUBLICKEY:      CURLoption = 10000 + 263; // The public key in DER form used to validate the proxy public key this option is used only if PROXY_SSL_VERIFYPEER is true
  CURLOPT_ABSTRACT_UNIX_SOCKET:       CURLoption = 10000 + 264; // Path to an abstract Unix domain socket
  CURLOPT_REQUEST_TARGET:             CURLoption = 10000 + 266; // The request target, instead of extracted from the URL

  CURLOPTTYPE_FUNCTIONPOINT:          CURLoption = 20000;
  CURLOPT_WRITEFUNCTION:              CURLoption = 20000 + 11;  // Function that will be called to store the output (instead of fwrite). The parameters will use fwrite() syntax, make sure to follow them.
  CURLOPT_READFUNCTION:               CURLoption = 20000 + 12;  // Function that will be called to read the input (instead of fread). The parameters will use fread() syntax, make sure to follow them.
  CURLOPT_PROGRESSFUNCTION:           CURLoption = 20000 + 56;  // DEPRECATED Function that will be called instead of the internal progress display function. This function should be defined as the curl_progress_callback prototype defines.
  CURLOPT_HEADERFUNCTION:             CURLoption = 20000 + 79;  // Function that will be called to store headers (instead of fwrite). The parameters will use fwrite() syntax, make sure to follow them.
  CURLOPT_DEBUGFUNCTION:              CURLoption = 20000 + 94;  // set the debug function
  CURLOPT_SSL_CTX_FUNCTION:           CURLoption = 20000 + 108; // Set the ssl context callback function, currently only for OpenSSL ssl_ctx in second argument. The function must be matching the curl_ssl_ctx_callback proto.
  CURLOPT_IOCTLFUNCTION:              CURLoption = 20000 + 130; //
  CURLOPT_CONV_FROM_NETWORK_FUNCTION: CURLoption = 20000 + 142; // Function that will be called to convert from the network encoding (instead of using the iconv calls in libcurl)
  CURLOPT_CONV_TO_NETWORK_FUNCTION:   CURLoption = 20000 + 143; // Function that will be called to convert to the network encoding (instead of using the iconv calls in libcurl)
  CURLOPT_CONV_FROM_UTF8_FUNCTION:    CURLoption = 20000 + 144; // Function that will be called to convert from UTF8 (instead of using the iconv calls in libcurl). Note that this is used only for SSL certificate processing
  CURLOPT_SOCKOPTFUNCTION:            CURLoption = 20000 + 148; // callback function for setting socket options
  CURLOPT_OPENSOCKETFUNCTION:         CURLoption = 20000 + 163; // Callback function for opening socket (instead of socket(2)). Optionally, callback is able change the address or refuse to connect returning CURL_SOCKET_BAD.  The callback should have type curl_opensocket_callback
  CURLOPT_SEEKFUNCTION:               CURLoption = 20000 + 167; // Callback function for seeking in the input stream
  CURLOPT_SSH_KEYFUNCTION:            CURLoption = 20000 + 184; // set the SSH host key callback, must point to a curl_sshkeycallback function
  CURLOPT_INTERLEAVEFUNCTION:         CURLoption = 20000 + 196; // Let the application define a custom write method for RTP data
  CURLOPT_CHUNK_BGN_FUNCTION:         CURLoption = 20000 + 198; // Directory matching callback called before downloading of an individual file (chunk) started
  CURLOPT_CHUNK_END_FUNCTION:         CURLoption = 20000 + 199; // Directory matching callback called after the file (chunk) was downloaded, or skipped
  CURLOPT_FNMATCH_FUNCTION:           CURLoption = 20000 + 200; // Change match (fnmatch-like) callback for wildcard matching
  CURLOPT_CLOSESOCKETFUNCTION:        CURLoption = 20000 + 208; // Callback function for closing socket (instead of close(2)). The callback should have type curl_closesocket_callback
  CURLOPT_XFERINFOFUNCTION:           CURLoption = 20000 + 219; // Function that will be called instead of the internal progress display function. This function should be defined as the curl_xferinfo_callback prototype defines. (Deprecates CURLOPT_PROGRESSFUNCTION)


  CURLOPTTYPE_OFF_T:                  CURLoption = 30000;
  CURLOPT_INFILESIZE_LARGE:           CURLoption = 30000 + 115; // See the comment for INFILESIZE above, but in short, specifies the size of the file being uploaded.  -1 means unknown.
  CURLOPT_RESUME_FROM_LARGE:          CURLoption = 30000 + 116; // Sets the continuation offset.  There is also a LONG version of this; look above for RESUME_FROM.
  CURLOPT_MAXFILESIZE_LARGE:          CURLoption = 30000 + 117; // Sets the maximum size of data that will be downloaded from an HTTP or FTP server.  See MAXFILESIZE above for the LONG version.
  CURLOPT_POSTFIELDSIZE_LARGE:        CURLoption = 30000 + 120; // The _LARGE version of the standard POSTFIELDSIZE option
  CURLOPT_MAX_SEND_SPEED_LARGE:       CURLoption = 30000 + 145; // if the connection proceeds too quickly then need to slow it down; limit-rate: maximum number of bytes per second to send or receive
  CURLOPT_MAX_RECV_SPEED_LARGE:       CURLoption = 30000 + 146;

  //CURLINFO - options for using with curl_version_info funtion
  CURLINFO_NONE:                      CURLINFO = 0;
  CURLINFO_STRING:                    CURLINFO = $100000;
  CURLINFO_EFFECTIVE_URL:             CURLINFO = $100000 + 1;
  CURLINFO_CONTENT_TYPE:              CURLINFO = $100000 + 18;
  CURLINFO_PRIVATE:                   CURLINFO = $100000 + 21;
  CURLINFO_FTP_ENTRY_PATH:            CURLINFO = $100000 + 30;
  CURLINFO_REDIRECT_URL:              CURLINFO = $100000 + 31;
  CURLINFO_PRIMARY_IP:                CURLINFO = $100000 + 32;
  CURLINFO_RTSP_SESSION_ID:           CURLINFO = $100000 + 36;
  CURLINFO_LOCAL_IP:                  CURLINFO = $100000 + 41;
  CURLINFO_SCHEME:                    CURLINFO = $100000 + 49;

  CURLINFO_LONG:                      CURLINFO = $200000;
  CURLINFO_RESPONSE_CODE:             CURLINFO = $200000 + 2;
  CURLINFO_HEADER_SIZE:               CURLINFO = $200000 + 11;
  CURLINFO_REQUEST_SIZE:              CURLINFO = $200000 + 12;
  CURLINFO_SSL_VERIFYRESULT:          CURLINFO = $200000 + 13;
  CURLINFO_FILETIME:                  CURLINFO = $200000 + 14;
  CURLINFO_REDIRECT_COUNT:            CURLINFO = $200000 + 20;
  CURLINFO_HTTP_CONNECTCODE:          CURLINFO = $200000 + 22;
  CURLINFO_HTTPAUTH_AVAIL:            CURLINFO = $200000 + 23;
  CURLINFO_PROXYAUTH_AVAIL:           CURLINFO = $200000 + 24;
  CURLINFO_OS_ERRNO:                  CURLINFO = $200000 + 25;
  CURLINFO_NUM_CONNECTS:              CURLINFO = $200000 + 26;
  CURLINFO_LASTSOCKET:                CURLINFO = $200000 + 29;
  CURLINFO_CONDITION_UNMET:           CURLINFO = $200000 + 35;
  CURLINFO_RTSP_CLIENT_CSEQ:          CURLINFO = $200000 + 37;
  CURLINFO_RTSP_SERVER_CSEQ:          CURLINFO = $200000 + 38;
  CURLINFO_RTSP_CSEQ_RECV:            CURLINFO = $200000 + 39;
  CURLINFO_PRIMARY_PORT:              CURLINFO = $200000 + 40;
  CURLINFO_LOCAL_PORT:                CURLINFO = $200000 + 42;
  CURLINFO_HTTP_VERSION:              CURLINFO = $200000 + 46;
  CURLINFO_PROXY_SSL_VERIFYRESULT:    CURLINFO = $200000 + 47;
  CURLINFO_PROTOCOL:                  CURLINFO = $200000 + 48;

  CURLINFO_DOUBLE:                    CURLINFO = $300000;
  CURLINFO_TOTAL_TIME:                CURLINFO = $300000 + 3;
  CURLINFO_NAMELOOKUP_TIME:           CURLINFO = $300000 + 4;
  CURLINFO_CONNECT_TIME:              CURLINFO = $300000 + 5;
  CURLINFO_PRETRANSFER_TIME:          CURLINFO = $300000 + 6;
  CURLINFO_SIZE_UPLOAD:               CURLINFO = $300000 + 7;
  CURLINFO_SIZE_DOWNLOAD:             CURLINFO = $300000 + 8;
  CURLINFO_SPEED_DOWNLOAD:            CURLINFO = $300000 + 9;
  CURLINFO_SPEED_UPLOAD:              CURLINFO = $300000 + 10;
  CURLINFO_CONTENT_LENGTH_DOWNLOAD:   CURLINFO = $300000 + 15;
  CURLINFO_CONTENT_LENGTH_UPLOAD:     CURLINFO = $300000 + 16;
  CURLINFO_STARTTRANSFER_TIM:         CURLINFO = $300000 + 17;
  CURLINFO_REDIRECT_TIME:             CURLINFO = $300000 + 19;
  CURLINFO_APPCONNECT_TIME:           CURLINFO = $300000 + 33;

  CURLINFO_SLIST:                     CURLINFO = $400000;
  CURLINFO_SSL_ENGINES:               CURLINFO = $400000 + 27;
  CURLINFO_COOKIELIST:                CURLINFO = $400000 + 28;

  CURLINFO_PTR:                       CURLINFO = $400000;
  CURLINFO_CERTINFO:                  CURLINFO = $400000 + 34;
  CURLINFO_TLS_SESSION:               CURLINFO = $400000 + 43;
  CURLINFO_TLS_SSL_PTR:               CURLINFO = $400000 + 45;

  CURLINFO_SOCKET:                    CURLINFO = $500000;
  CURLINFO_ACTIVESOCKET:              CURLINFO = $500000 + 44;

  CURLINFO_OFF_T:                     CURLINFO = $600000;
  CURLINFO_SIZE_UPLOAD_T:             CURLINFO = $600000 + 7;
  CURLINFO_SIZE_DOWNLOAD_T:           CURLINFO = $600000 + 8;
  CURLINFO_SPEED_DOWNLOAD_T:          CURLINFO = $600000 + 9;
  CURLINFO_SPEED_UPLOAD_T:            CURLINFO = $600000 + 10;
  CURLINFO_CONTENT_LENGTH_DOWNLOAD_T: CURLINFO = $600000 + 15;
  CURLINFO_CONTENT_LENGTH_UPLOAD_T:   CURLINFO = $600000 + 16;

  CURLINFO_MASK:                      CURLINFO = $0fffff;
  CURLINFO_TYPEMASK:                  CURLINFO = $f00000;


function curl_easy_init( ):pTCURL; cdecl; external;
procedure curl_easy_cleanup(handle:pTCURL); cdecl; external;

function curl_easy_setopt(handle:pTCURL; option:CURLoption; parameter:int64):CURLcode; cdecl; external;
function curl_easy_perform(easy_handle:pTCURL):CURLcode; cdecl; external;

function curl_easy_getinfo(curl:pTCURL; info:CURLINFO; ptr:pointer ):CURLcode; cdecl; external;

function curl_version_info(CURLVERSION:cardinal):pcurl_version_info_data; cdecl; external;



// MULTI
type
  CURLMcode = integer;
  CURLMESSAGE = cardinal;
  TCURLM = record
  end;
  pTCURLM = ^TCURLM;

  CURLMsg__var = packed record
    case byte of
      0:(whatever:pointer);    // message-specific data
      1:(result:CURLcode);     // return code for transfer
  end;

  CURLMsg = packed record
    msg:CURLMESSAGE;       // what this message means
    easy_handle:pTCURL;    // the handle it concerns
    data:CURLMsg__var;
  end;
  pCURLMsg=^CURLMsg;


const
  CURLM_CALL_MULTI_PERFORM: CURLMcode = -1;
  CURLM_OK: CURLMcode = 0;
  CURLM_BAD_HANDLE: CURLMcode = 1;
  CURLM_BAD_EASY_HANDLE: CURLMcode = 2;
  CURLM_OUT_OF_MEMORY: CURLMcode = 3;
  CURLM_INTERNAL_ERROR: CURLMcode = 4;
  CURLM_BAD_SOCKET: CURLMcode = 5;
  CURLM_UNKNOWN_OPTION: CURLMcode = 6;
  CURLM_ADDED_ALREADY: CURLMcode = 7;
  CURLM_LAST: CURLMcode = 8;


  CURLMSG_NONE:CURLMESSAGE = 0; // first, not used
  CURLMSG_DONE:CURLMESSAGE = 1; // This easy handle has completed. 'result' contains the CURLcode of the transfer
  CURLMSG_LAST:CURLMESSAGE = 2; // last, not used

function curl_multi_init( ):pTCURLM; cdecl; external;
function curl_multi_add_handle(multi_handle:pTCURLM; easy_handle:pTCURL):CURLMcode; cdecl; external;
function curl_multi_perform(multi_handle:pTCURLM; running_handles:pinteger):CURLMcode; cdecl; external;
function curl_multi_remove_handle(multi_handle:pTCURLM; easy_handle:pTCURL):CURLMcode; cdecl; external;
function curl_multi_cleanup( multi_handle:pTCURLM ):CURLMcode; cdecl; external;

function curl_multi_wait(multi_handle:pTCURLM; extra_fds:pointer; extra_nfds:cardinal; timeout_ms:integer; numfds:pinteger):CURLMcode; cdecl; external;
function curl_multi_info_read( multi_handle:pTCURLM; msgs_in_queue:pinteger):pCURLMsg; cdecl; external;

implementation

end.

