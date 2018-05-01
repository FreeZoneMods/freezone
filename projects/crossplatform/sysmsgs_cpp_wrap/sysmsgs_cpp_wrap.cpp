#include <iostream>
#include "sysmsgs.h"

void __stdcall SendCB(void* msg, unsigned int len, void* userdata)
{
    std::cout << "Message len = " << len <<std::endl;
}

int main()
{
    CFreeZoneFeatures fz;
    std::cin.ignore(std::cin.rdbuf()->in_avail());
    std::cin.get();
    fz.SendModDownloadMessage("test_mod", "srv 127.0.0.1", SendCB, nullptr);
    std::cin.ignore(std::cin.rdbuf()->in_avail());
    std::cin.get();
	return 0;
}

