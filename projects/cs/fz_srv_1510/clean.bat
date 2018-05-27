del *.~pas
del *.bak
del *.dcu
del *.lps

del highlevel\*.~pas
del highlevel\*.bak
del highlevel\*.dcu
rmdir /S /Q highlevel\backup

del lowlevel\*.~pas
del lowlevel\*.bak
del lowlevel\*.dcu
rmdir /S /Q lowlevel\backup

rmdir /S /Q lib
rmdir /S /Q backup
exit