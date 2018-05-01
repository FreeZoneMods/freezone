#ifndef _SYSMSGS_H_
#define _SYSMSGS_H_

#include "windows.h"

#pragma pack(push, 1)

typedef void* FZSysmsgPayloadWriter;
typedef void* FZSysMsgSender;

//Тип компрессии, использованный в находящемся на сервере файле   
typedef DWORD FZArchiveCompressionType;
    const FZArchiveCompressionType FZ_COMPRESSION_NO_COMPRESSION = 0;    //Компрессии нет, файл на сервере не сжат
    const FZArchiveCompressionType FZ_COMPRESSION_LZO_COMPRESSION = 1;   //Файл сжат внутриигровым LZO-компрессором
    const FZArchiveCompressionType FZ_COMPRESSION_CAB_COMPRESSION = 2;   //Файл сжат стандартной утилитой MAKECAB из состава Windows   

//Определяет момент, в который должна вызываться функция мода
typedef DWORD FZModdingPolicy;

    //Функция из DLL мода может вызываться в любое время. Автоматический реконнект не производится.
    const FZModdingPolicy FZ_MODDING_ANYTIME = 0;
    
    //Функция из DLL мода должна вызываться только в процессе коннекта к серверу (т.е. при необходимости автоматически инициируется реконнект после скачки)
    //Удобно для модов, не требующих рестарта клиента
    const FZModdingPolicy FZ_MODDING_WHEN_CONNECTING = 1;
    
    //Функция из DLL мода должна вызываться только когда клиент не в состоянии коннекта (т.е. если файл на клиенте уже есть - все равно будет произведен дисконнект)
    //Автоматического реконнекта не производится, мод сам отвечает за реконнект в случае необходимости такового
    //Имейте в виду: в случае скачки файла игрок может уйти на другой сервер! В этом случае автоматического дисконнекта с другого сервера произведено не будет!
    const FZModdingPolicy FZ_MODDING_WHEN_NOT_CONNECTING = 2;

//Параметры загружаемого файла
struct FZFileDownloadInfo
{
    //Имя файла (вместе с путем) на клиенте, по которому он должен быть сохранен
    char* filename;
    //URL, с которого будет производиться загрузка файла
    char* url;
    //Контрольная сумма CRC32 для файла (в распакованном виде)
    DWORD crc32;
    //Используемый тип компрессии
    FZArchiveCompressionType compression;
    //Сообщение, выводимое пользователю во время закачки
    char* progress_msg;
    //Сообщение, выводимое пользователю при возникновении ошибки во время закачки
    char* error_already_has_dl_msg;
};

//Параметры реконнекта клиента к серверу
struct FZReconnectInetAddrData
{
    //IPv4-адрес сервера (например, 127.0.0.1)
    char* ip;
    //Порт сервера
    DWORD port;
};

typedef DWORD FZMapLoadingFlags;
    const FZMapLoadingFlags FZ_MAPLOAD_MANDATORY_RECONNECT = 1; //Обязательный реконнект после успешной подгрузки скачанной карты

//Параметры загрузки клиентом db-архива с картой
struct FZMapInfo
{
    //Параметры файла
    FZFileDownloadInfo fileinfo;
    //IP-адрес и порт для реконнекта после завершения закачки. Если IP пустой, то параметры реконнекта автоматически берутся игрой из тех, во время которых произошел дисконнект.
    FZReconnectInetAddrData reconnect_addr;
    //Внутриигровое имя загружаемой карты (например, mp_pool)
    char* mapname;
    //Версия загружаемой карты (обычно 1.0)
    char* mapver;
    //Название xml-файла с локализованными названием и описанием карты (nil, если такое не требуется)
    char* xmlname;
    //флаги для настройки особенностей применения карты
    FZMapLoadingFlags flags;
};

typedef DWORD FZDllModFunResult;
    const FZDllModFunResult FZ_DLL_MOD_FUN_SUCCESS_LOCK = 0;    //Мод успешно загрузился, требуется залочить клиента по name_lock
    const FZDllModFunResult FZ_DLL_MOD_FUN_SUCCESS_NOLOCK = 1;  //Успех, лочить клиента (с использованием name_lock) пока не надо
    const FZDllModFunResult FZ_DLL_MOD_FUN_FAILURE = 2;         //Ошибка загрузки мода

typedef FZDllModFunResult (__stdcall *FZDllModFun) (char* procarg1, char* procarg2);
    
//Параметры загрузки клиентом DLL-мода посредством ProcessClientModDll
struct FZDllDownloadInfo
{
    //Параметры файла для dll мода
    FZFileDownloadInfo fileinfo;

    //Имя процедуры в dll мода, которая должна быть вызвана; должна иметь тип FZDllModFun
    char* procname;

    //Аргументы для передачи в процедуру
    char* procarg1;
    char* procarg2;

    //Цифровая подпись для загруженной DLL - проверяется перед тем, как передать управление в функцию мода
    char* dsign;

    //IP-адрес и порт для реконнекта. Если IP нулевой, то параметры реконнекта автоматически берутся игрой из тех, во время которых произошел дисконнект.
    FZReconnectInetAddrData reconnect_addr;

    //Параметры времени активации мода
    FZModdingPolicy modding_policy;

    //Значение для проверки в параметре -fzmod.
    //Если аргумент nil - ничего не проверяется.
    //Если параметр совпадает с таковым в командной строке - мод считается уже установленным, коннект продолжается
    //Если параметр не совпадает с указанным в командной строке - происходит дисконнект игрока
    //Если в командной строке параметра нет - происходит установка мода.
    char* name_lock;

    //Строка, выводимая при обнаружении несовместимого мода
    char* incompatible_mod_message;

    //Строка, выводимая при применении мода после дисконнекта (если активен FZ_MODDING_WHEN_NOT_CONNECTING)
    char* mod_is_applying_message;
};

//Параметры отдельной карты для добавления в список голосования
struct FZClientVotingElement
{
    //Внутриигровое имя карты (например, mp_pool). В случае если nil - производится очистка списка карт!
    //Целесообразно передавать nil первым элементом в пакете
    char* mapname;
    //Версия карты
    char* mapver;
    //Локализованное название карты; если nil, будет использован результат вызова стандартного внутриигрового транслятора на клиенте
    char* description;
};

//Параметры добавления карт в список, доступных для голосования, используется с ProcessClientVotingMaplist
struct FZClientVotingMapList
{
  //Указатель на массив из FZClientVotingElement. Каждый элемент массива содержит параметры одной карты,
  //которую требуется добавить в список карт, доступных для голосования
  FZClientVotingElement* maps;

  //Число элементов в массиве maps
  DWORD count;

  //Идентификатор типа игры, для которого требуется изменить список карт. В движке текущий тип игры содержится в в game_GameState.m_type
  DWORD gametype;

  //Выходной параметр, показывает, сколько карт из массива было отправлено клиенту, отсчет идет с начала массива.
  DWORD was_sent;
};

#pragma pack(pop)

typedef DWORD FZSysmsgsCommonFlags;
    const FZSysmsgsCommonFlags FZ_SYSMSGS_ENABLE_LOGS = 1; // Включить отображение логов на клиенте
    const FZSysmsgsCommonFlags FZ_SYSMSGS_PATCH_UI_PROGRESSBAR = 2; // Включить патчинг прогрессбара в ТЧ (для корректного отображения процесса загрузки)
    const FZSysmsgsCommonFlags FZ_SYSMSGS_PATCH_VERTEX_BUFFER = 4; // Включить увеличение вертекс-буфера в ТЧ (патч для вылета на больших картах)
    const FZSysmsgsCommonFlags FZ_SYSMSGS_FLAGS_ALL_ENABLED = 0xFFFFFFFF;



typedef void(__stdcall *FZSysMsgSendCallback) (void* msg, unsigned int len, void* userdata);
typedef bool(__stdcall *FZSysMsgsInit)();
typedef bool(__stdcall *FZSysMsgsFlags)(FZSysmsgsCommonFlags);
typedef void(__stdcall *FZSysMsgsSendSysMessage)(void*, void*, FZSysMsgSendCallback, void*);
typedef bool(__stdcall *FZSysMsgsFree)();


struct SFreeZoneProcedures 
{
    FZSysMsgsInit init_proc;
    FZSysMsgsFree free_proc;
    FZSysMsgsFlags flags_proc;
    FZSysMsgsSendSysMessage send_proc;
    void* process_client_mod;
};

class CFreeZoneFeatures
{
    HMODULE _handle;
    SFreeZoneProcedures _procedures;

public:
    CFreeZoneFeatures()
    {       
        ZeroMemory(&_procedures, sizeof(_procedures));
        _handle = LoadLibrary("sysmsgs.dll");  
        if (_handle != nullptr)
        {
            _procedures.init_proc = (FZSysMsgsInit) GetProcAddress(_handle, "FZSysMsgsInit");
            _procedures.free_proc = (FZSysMsgsFree) GetProcAddress(_handle, "FZSysMsgsFree");
            _procedures.flags_proc = (FZSysMsgsFlags) GetProcAddress(_handle, "FZSysMsgsSetCommonSysmsgsFlags");
            _procedures.send_proc = (FZSysMsgsSendSysMessage) GetProcAddress(_handle, "FZSysMsgsSendSysMessage");
            _procedures.process_client_mod = GetProcAddress(_handle, "FZSysMsgsProcessClientModDll");
        }

        if (_procedures.init_proc!=nullptr)
        {
            _procedures.init_proc();
        }

        if (_procedures.flags_proc!=nullptr)
        {
            _procedures.flags_proc(FZ_SYSMSGS_ENABLE_LOGS | FZ_SYSMSGS_PATCH_UI_PROGRESSBAR);
        }
    }

    void SendModDownloadMessage(char* mod_name, char* mod_params, FZSysMsgSendCallback cb, void* userdata)
    {
        FZDllDownloadInfo info = {};
        info.fileinfo.error_already_has_dl_msg = "Download is in progress already";
        info.fileinfo.progress_msg = "Downloading mod, please wait";
        info.incompatible_mod_message = "The server uses incompatible mod, try to restart the game";
        info.mod_is_applying_message = "Mod is applying, please wait";
        info.name_lock = mod_name;
        info.procarg1 = mod_name;
        info.procarg2 = mod_params;
        info.procname = "ModLoad";

        if (_procedures.send_proc != nullptr && _procedures.process_client_mod != nullptr)
        {
            _procedures.send_proc(_procedures.process_client_mod, &info, cb, userdata);
        }
    }

    ~CFreeZoneFeatures()
    {
        if (_handle != nullptr)
        {
            if (_procedures.free_proc != nullptr)
            {
                _procedures.free_proc();
            }
            FreeLibrary(_handle);
        }
    }
};

#endif