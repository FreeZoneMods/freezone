unit sysmsgs;
{$mode delphi}
interface
type
//Тип пользовательского колбэка, ответственный за обработку (отправку) сгенерированных пакетов
FZSysMsgSender = procedure(msg:pointer; len:cardinal; userdata:pointer); stdcall;

//Описатель билдера системных сообщений, каждый их тип имеет собственный описатель. Внутренняя структура зависит от реализации и скрыта от пользователя.
FZSysMsgsBuilder = packed record
end;
pFZSysMsgsBuilder = ^FZSysMsgsBuilder;

//Тип компрессии, использованный в находящемся на сервере файле
type FZArchiveCompressionType = cardinal;
const
  FZ_COMPRESSION_NO_COMPRESSION: FZArchiveCompressionType = 0;    //Компрессии нет, файл на сервере не сжат
  FZ_COMPRESSION_LZO_COMPRESSION: FZArchiveCompressionType = 1;   //Файл сжат внутриигровым LZO-компрессором
  FZ_COMPRESSION_CAB_COMPRESSION: FZArchiveCompressionType = 2;   //Файл сжат стандартной утилитой MAKECAB из состава Windows

//Определяет момент, в который должна вызываться функция мода
type FZModdingPolicy = cardinal;
const
  //Функция из DLL мода может вызываться в любое время. Автоматический реконнект не производится.
  FZ_MODDING_ANYTIME: FZModdingPolicy = 0;

  //Функция из DLL мода должна вызываться только в процессе коннекта к серверу (т.е. при необходимости автоматически инициируется реконнект после скачки)
  //Удобно для модов, не требующих рестарта клиента
  FZ_MODDING_WHEN_CONNECTING: FZModdingPolicy = 1;

  //Функция из DLL мода должна вызываться только когда клиент не в состоянии коннекта (т.е. если файл на клиенте уже есть - все равно будет произведен дисконнект)
  //Автоматического реконнекта не производится, мод сам отвечает за реконнект в случае необходимости такового
  //Имейте в виду: в случае скачки файла игрок может уйти на другой сервер! В этом случае автоматического дисконнекта с другого сервера произведено не будет!
  FZ_MODDING_WHEN_NOT_CONNECTING: FZModdingPolicy = 2;

//Параметры загружаемого файла
type
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

FZMapLoadingFlags = cardinal;
const
  FZ_MAPLOAD_MANDATORY_RECONNECT: FZMapLoadingFlags = 1; //Обязательный реконнект после успешной подгрузки скачанной карты
  FZ_MAPLOAD_PREFER_PARENT_APPDATA_STORE: FZMapLoadingFlags = 2; //Стараться скачивать карты в родительскую аппдату; полезно в случае, если у нас стоит мод, использующий оригинальные карты.

//Параметры загрузки клиентом db-архива с картой
type
FZMapInfo = packed record
  //Параметры файла
  fileinfo:FZFileDownloadInfo;
  //IP-адрес и порт для реконнекта после завершения закачки. Если IP пустой, то параметры реконнекта автоматически берутся игрой из тех, во время которых произошел дисконнект.
  reconnect_addr:FZReconnectInetAddrData;
  //Внутриигровое имя загружаемой карты (например, mp_pool)
  mapname:PAnsiChar;
  //Версия загружаемой карты (обычно 1.0)
  mapver:PAnsiChar;
  //Название xml-файла с локализованными названием и описанием карты (nil, если такое не требуется)
  xmlname:PAnsiChar;
  //флаги для настройки особенностей применения карты
  flags:FZMapLoadingFlags;
end;
pFZMapInfo = ^FZMapInfo;

FZDllModFunResult = cardinal;
const
  FZ_DLL_MOD_FUN_SUCCESS_LOCK: FZDllModFunResult = 0;    //Мод успешно загрузился, требуется залочить клиента по name_lock
  FZ_DLL_MOD_FUN_SUCCESS_NOLOCK: FZDllModFunResult = 1;  //Успех, лочить клиента (с использованием name_lock) пока не надо
  FZ_DLL_MOD_FUN_FAILURE: FZDllModFunResult = 2;         //Ошибка загрузки мода

type FZDllModFun = function (procarg1:PAnsiChar; procarg2:PAnsiChar):FZDllModFunResult; stdcall;


//Параметры загрузки клиентом DLL-мода посредством ProcessClientModDll
FZDllDownloadInfo = packed record
  //Параметры файла для dll мода
  fileinfo:FZFileDownloadInfo;

  //Имя процедуры в dll мода, которая должна быть вызвана; должна иметь тип FZDllModFun
  procname:PAnsiChar;

  //Аргументы для передачи в процедуру
  procarg1:PAnsiChar;
  procarg2:PAnsiChar;

  //Цифровая подпись для загруженной DLL - проверяется перед тем, как передать управление в функцию мода
  dsign:PAnsiChar;

  //IP-адрес и порт для реконнекта. Если IP нулевой, то параметры реконнекта автоматически берутся игрой из тех, во время которых произошел дисконнект.
  reconnect_addr:FZReconnectInetAddrData;

  //Параметры времени активации мода
  modding_policy:FZModdingPolicy;

  //Значение для проверки в параметре -fzmod.
  //Если аргумент nil - ничего не проверяется.
  //Если параметр совпадает с таковым в командной строке - мод считается уже установленным, коннект продолжается
  //Если параметр не совпадает с указанным в командной строке - происходит дисконнект игрока
  //Если в командной строке параметра нет - происходит установка мода.
  name_lock:PAnsiChar;

  //Строка, выводимая при обнаружении несовместимого мода
  incompatible_mod_message:PAnsiChar;

  //Строка, выводимая при применении мода после дисконнекта (если активен FZ_MODDING_WHEN_NOT_CONNECTING)
  mod_is_applying_message:PAnsiChar;
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

//Основной API для работы с системными сообщениями, обеспечивает их конструирование и отправку для всех поддерживаемых платформ. Используйте в случае, когда тип клиента точно неизвестен
//Параметры:
//payload - указатель на функцию, определяющую тип требуемого пакета
//pay_args - аргументы, передаваемые в payload. Каждый тип пакета требует своих аргументов. Убедитесь в том, что используете правильный тип!
//send_callback - указатель на функцию, которая будет вызвана для отправки пакета после того, как он будет создан.
//userdata - параметры, передаваемые в одноименном аргументе send_callback
procedure SendSysMessage(payload:pFZSysMsgsBuilder; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage';

//API отправки сообщений для ТЧ
procedure SendSysMessage_SOC(payload:pFZSysMsgsBuilder; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage_SOC';

//API отправки сообщений для ЧН
procedure SendSysMessage_CS(payload:pFZSysMsgsBuilder; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage_CS';

//API отправки сообщений для ЗП
procedure SendSysMessage_COP(payload:pFZSysMsgsBuilder; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage_COP';

var
//Указатели на билдеры, приведенные ниже, могут передаваться в качестве первого параметра SendSysMessage. Передаваемый указатель определяет тип пакета, который будет создан
//ВАЖНО! Каждый тип билдера требует свой тип структуры с параметрами создаваемого пакета во втором аргументе SendSysMessage. Убедитесь, что передали правильный тип!

//Билдер используется для создания пакетов, обеспечивающих закачку и подгрузку в игру db-архива с картой. Закачка идет в $app_data_root$, файл имеет расширение .map
//Параметр pay_args должен иметь тип pFZMapInfo
ProcessClientMap:FZSysMsgsBuilder external 'sysmsgs.dll' name 'FZSysMsgsProcessClientMap';

//Билдер обеспечивает добавление на клиенте новых элементов в список карт, доступных для голосования. Также предусмотрена возможность очистки этого списка
//ВАЖНО! В случае большого количества карт на сервере библиотека может не суметь отправить их все за один вызов (в одном пакете). В этом случае в pFZClientVotingMapList.was_sent
//заносится число реально отправленных за это попытку карт (все они располагались в начале массива). Для отправки остальных карт требуется повторять вызовы SendSysMessage.
//ВАЖНО! После дисконнекта клиента список карт не возвращается в исходное состояние до перезагрузки клиента! В случае захода на другой сервер, не поддерживающий
//синхронизацию списка карт, список на клиенте станет неактуальным.
//Параметр pay_args должен иметь тип pFZClientVotingMapList.
ProcessClientVotingMaplist:FZSysMsgsBuilder external 'sysmsgs.dll' name 'FZSysMsgsProcessClientVotingMaplist';

//Билдер позволяет инициировать закачку клиентом DLL-мода и вызов из нее указанной в параметрах функции.
//ВАЖНО! Для предотвращения плагиата модов и возможных атак на клиентов производится проверка цифровой подписи модуля после его загрузки.
//БЕЗ ПРАВИЛЬНОЙ ЦИФРОВОЙ ПОДПИСИ ВЫЗОВА ФУНКЦИИ ИЗ DLL-МОДА НЕ ПРОИЗОЙДЕТ! Во время разработки и отладки проверка цифровой подписи на клиенте может быть отключена добавлением в строку запуска параметра -fz_nosign.
//Для получения цифровой подписи на релизную версию DLL-мода обратитесь к разработчикам FreeZone!
//Параметр pay_args должен иметь тип pFZDllDownloadInfo.
//При отсутствии во входной структуре цифровой подписи и URL задействуется загрузчик по умолчанию
ProcessClientModDll:FZSysMsgsBuilder external 'sysmsgs.dll' name 'FZSysMsgsProcessClientModDll';

//Функция инициализации модуля системных сообщений. Вызовите ее перед началом работы с модулем!
function Init():boolean; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsInit';

//Функция очистки, вызовите ее перед завершением работы с модулем!
function Free():boolean; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsFree';

//Функция позволяет узнать используемую версию DLL.
function GetModuleVer():PChar; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsGetModuleVer';

//Проверка валидности HWID
type FZHwIdValidationResult = cardinal;
function ValidateHwId(hwid:PAnsiChar; hash:PAnsiChar):FZHwIdValidationResult; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsValidateHwId';

const
  FZ_HWID_VALID: FZHwIdValidationResult = 0;
  FZ_HWID_UNKNOWN_VERSION: FZHwIdValidationResult = 1;
  FZ_HWID_INVALID: FZHwIdValidationResult = 2;
  FZ_HWID_NOT_HWID: FZHwIdValidationResult = 3;

type
  FZSysmsgsCommonFlags = cardinal;
const
  FZ_SYSMSGS_ENABLE_LOGS: FZSysmsgsCommonFlags = 1; // Включить отображение логов на клиенте
  FZ_SYSMSGS_PATCH_UI_PROGRESSBAR: FZSysmsgsCommonFlags = 2; // Включить патчинг прогрессбара в ТЧ (для корректного отображения процесса загрузки)
  FZ_SYSMSGS_PATCH_VERTEX_BUFFER: FZSysmsgsCommonFlags = 4; // Включить увеличение вертекс-буфера в ТЧ (патч для вылета на больших картах)
  FZ_SYSMSGS_FLAGS_ALL_ENABLED: FZSysmsgsCommonFlags = $FFFFFFFF;

  FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE: FZSysmsgsCommonFlags = 4; //FZ_SYSMSGS_PATCH_VERTEX_BUFFER

procedure SetCommonSysmsgsFlags(flags:FZSysmsgsCommonFlags); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSetCommonSysmsgsFlags';

function GetCommonSysmsgsFlags():FZSysmsgsCommonFlags; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsGetCommonSysmsgsFlags';

//Параметры расширенного управления клиентом
type
FZExClientAction = cardinal;
const
  FZ_EX_CLIENT_ACTION_SC:FZExClientAction = 0;
  FZ_EX_CLIENT_ACTION_FR:FZExClientAction = 1;

  FZ_EX_CLIENT_ACTION_IMMEDIATELY_FLAG = 1;

type
FZClientExParameters = packed record
  action:FZExClientAction;
  cl_id:cardinal;
  flags:cardinal;
  buf:pointer;
  size:cardinal;
end;
pFZClientExParameters = ^FZClientExParameters;

//Сообщает, поддерживаются ли функции расширенного управления текущей сборкой
function IsExClientActionsSupported():boolean; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsIsExClientActionsSupported';

var
//Билдер для вызова функций расширенного управления клиентом
ProcessExClientAction:FZSysMsgsBuilder external 'sysmsgs.dll' name 'FZSysMsgsProcessExClientAction';

implementation
end.
