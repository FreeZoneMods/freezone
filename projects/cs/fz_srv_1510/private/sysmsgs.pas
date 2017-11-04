unit sysmsgs;
{$mode delphi}
interface
type

//Указатель на внутреннюю структуру модуля, не используется в клиентском коде
pFZClAddrDescription = pointer;

FZSysmsgPayloadWriter = procedure(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
FZSysMsgSender = procedure(msg:pointer; len:cardinal; userdata:pointer); stdcall;

//Тип компрессии, использованный в находящемся на сервере файле
FZArchiveCompressionType = cardinal;

//Параметры загружаемого файла
FZFileDownloadInfo = packed record
  //Имя файла (вместе с путем) на клиенте, по которому он должен быть сохранен
  filename:PAnsiChar;
  //URL, с которого будет производиться загрузка файла
  url:PAnsiChar;
  //Контрольная сумма CRC32 для файла (в распакованном виде)
  crc32:cardinal;
  //Используемый тип компрессии
  compression:FZArchiveCompressionType;
  //Сообщение, выводимое пользователю во время закачки
  progress_msg:PAnsiChar;
  //Сообщение, выводимое пользователю при возникновении ошибки во время закачки
  error_already_has_dl_msg:PAnsiChar;
end;
pFZFileDownloadInfo = ^FZFileDownloadInfo;

//Параметры реконнекта клиента к серверу
FZReconnectInetAddrData = packed record
  //IPv4-адрес сервера (например, 127.0.0.1)
  ip:PAnsiChar;
  //Порт сервера
  port:cardinal;
end;

//Параметры загрузки клиентом db-архива с картой
FZMapInfo = packed record
  //Параметры файла
  fileinfo:FZFileDownloadInfo;
  //IP-адрес и порт для реконнекта после завершения закачки
  reconnect_addr:FZReconnectInetAddrData;
  //Внутриигровое имя загружаемой карты (например, mp_pool)
  mapname:PAnsiChar;
  //Версия загружаемой карты (обычно 1.0)
  mapver:PAnsiChar;
  //Название xml-файла с локализованными названием и описанием карты (nil, если такое не требуется)
  xmlname:PAnsiChar;
end;
pFZMapInfo = ^FZMapInfo;

//Параметры загрузки клиентом DLL-мода посредством ProcessClientModDll
FZDllDownloadInfo = packed record
  //Параметры файла для dll мода
  fileinfo:FZFileDownloadInfo;

  //Имя процедуры в dll мода, которая должна быть вызвана
  procname:PAnsiChar;

  //Аргументы для передачи в процедуру
  procarg1:PAnsiChar;
  procarg2:PAnsiChar;

  //Цифровая подпись для загруженной DLL - проверяется перед тем, как передать управление в функцию мода
  dsign:PAnsiChar;

  //IP-адрес и порт для реконнекта
  reconnect_addr:FZReconnectInetAddrData;

  //Если 0 - функция может вызываться в любое время (как только dll в наличии у клиента)
  //Иначе - функция из dll мода должна вызываться только в процессе коннекта к серверу (то есть после закачки будет инициирован реконнект). Удобно для модов, не требующих рестарта клиента
  is_reconnect_needed:cardinal;

  //Значение для проверки в параметре -fzmod.
  //Если аргумент nil - ничего не проверяется.
  //Если параметр совпадает с таковым в командной строке - мод считается уже установленным, коннект продолжается
  //Если параметр не совпадает с указанным в командной строке - происходит дисконнект игрока
  //Если в командной строке параметра нет - происходит установка мода.
  name_lock:PAnsiChar;
end;
pFZDllDownloadInfo = ^FZDllDownloadInfo;

//Параметры отдельной карты для добавления в список голосования
FZClientVotingElement = packed record
  //Внутриигровое имя карты (например, mp_pool). В случае если nil - производится очистка списка карт!
  //Целесообразно передавать nil первым элементом в пакете
  mapname:PAnsiChar;
  //Версия карты
  mapver:PAnsiChar;
  //Локализованное название карты; если nil, будет использован результат вызова стандартного внутриигрового транслятора на клиенте
  description:PAnsiChar;
end;
pFZClientVotingElement=^FZClientVotingElement;

//Параметры добавления карт в список, доступных для голосования, используется с ProcessClientVotingMaplist
FZClientVotingMapList = packed record
  //Указатель на массив из FZClientVotingElement. Каждый элемент массива содержит параметры одной карты,
  //которую требуется добавить в список карт, доступных для голосования
  maps:pFZClientVotingElement;

  //Число элементов в массиве maps
  count:cardinal;

  //Идентификатор типа игры, для которого требуется изменить список карт. В движке текущий тип игры содержится в в game_GameState.m_type
  gametype:cardinal;

  //Выходной параметр, показывает, сколько карт из массива было отправлено клиенту, отсчет идет с начала массива.
  was_sent:cardinal;
end;
pFZClientVotingMapList=^FZClientVotingMapList;

//Основной API для работы с системными сообщениями, обеспечивает их конструирование и отправку. Параметры:
//payload - указатель на функцию, определяющую тип требуемого пакета
//pay_args - аргументы, передаваемые в payload. Каждый тип пакета требует своих аргументов. Убедитесь в том, что используете правильный тип!
//send_callback - указатель на функцию, которая будет вызвана для отправки пакета после того, как он будет создан.
//userdata - параметры, передаваемые в одноименном аргументе send_callback
procedure SendSysMessage(payload:FZSysmsgPayloadWriter; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage';

//Указатели на следующие функции могут передаваться в качестве первого параметра SendSysMessage. Передаваемая функция определяет тип пакета, который будет создан
//ВАЖНО! Каждая функция требует свой тип структуры с параметрами создаваемого пакета во втором аргументе SendSysMessage. Убедитесь, что передали правильный тип!

//Функция используется для создания пакетов, обеспечивающих закачку и подгрузку в игру db-арзива с картой. Закачка идет в $app_data_root$, файл имеет расширение .map
//Параметр pay_args должен иметь тип pFZMapInfo
procedure ProcessClientMap(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsProcessClientMap';

//Функция обеспечивает добавление на клиенте новых элементов в список карт, доступных для голосования. Также предусмотрена возможность очистки этого списка
//ВАЖНО! В случае большого количества карт на сервере функция может не суметь отправить их все за один вызов (в одном пакете). В этом случае в pFZClientVotingMapList.was_sent
//заносится число реально отправленных за это попытку карт (все они располагались в начале массива). Для отправки остальных карт требуется повторять вызовы SendSysMessage.
//ВАЖНО! После дисконнекта клиента список карт не возвращается в исходное состояние до перезагрузки клиента! В случае захода на другой сервер, не поддерживающий
//синхронизацию списка карт, список на клиенте станет неактуальным.
//Параметр pay_args должен иметь тип pFZClientVotingMapList.
procedure ProcessClientVotingMaplist(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsProcessClientVotingMaplist';

//Функция позволяет инициировать закачку клиентом DLL-мода и вызов из нее указанной в параметрах функции.
//ВАЖНО! Для предотвращения плагиата модов и возможных атак на клиентов производится проверка цифровой подписи модуля после его загрузки.
//БЕЗ ПРАВИЛЬНОЙ ЦИФРОВОЙ ПОДПИСИ ВЫЗОВА ФУНКЦИИ ИЗ DLL-МОДА НЕ ПРОИЗОЙДЕТ!
//Во время разработки и отладки проверка цифровой подписи на клиенте может быть отключена добавлением в строку запуска параметра -fz_nosign.
//Для получения цифровой подписи на релизную версию DLL-мода обратитесь к разработчикам FreeZone!
//Параметр pay_args должен иметь тип pFZDllDownloadInfo.
procedure ProcessClientModDll(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsProcessClientModDll';

//Функция инициализации модуля системных сообщений. Вызовите ее перед началом работы с модулем!
function Init():boolean; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsInit';

//Функция позволяет узнать используемую версию DLL.
function GetModuleVer():PChar; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsGetModuleVer';

//Проверка валидности HWID
type FZHwIdValidationResult = cardinal;
function ValidateHwId(hwid:PAnsiChar; hash:PAnsiChar):FZHwIdValidationResult; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsValidateHwId';

const
  FZ_COMPRESSION_NO_COMPRESSION: FZArchiveCompressionType = 0;    //Компрессии нет, файл на сервере не сжат
  FZ_COMPRESSION_LZO_COMPRESSION: FZArchiveCompressionType = 1;   //Файл сжат внутриигровым LZO-компрессором
  FZ_COMPRESSION_CAB_COMPRESSION: FZArchiveCompressionType = 2;   //Файл сжат стандартной утилитой MAKECAB из состава Windows

  FZ_HWID_VALID: FZHwIdValidationResult = 0;
  FZ_HWID_UNKNOWN_VERSION: FZHwIdValidationResult = 1;
  FZ_HWID_INVALID: FZHwIdValidationResult = 2;
  FZ_HWID_NOT_HWID: FZHwIdValidationResult = 3;

implementation
end.
