del *.~pas
del *.bak
del *.dcu
del *.dll
del *.dbg
del *.exe
del *.lps

del highlevel\*.~pas
del highlevel\*.bak
del highlevel\*.dcu
rmdir /S /Q highlevel\backup

del lowlevel\*.~pas
del lowlevel\*.bak
del lowlevel\*.dcu
rmdir /S /Q lowlevel\backup

del 3rdparty\*.~pas
del 3rdparty\*.bak
del 3rdparty\*.dcu

rmdir /S /Q lib
rmdir /S /Q backup
exit