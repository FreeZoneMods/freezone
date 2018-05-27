cd distorm
@start clean.bat
cd ..

cd libcurl
@start clean.bat
cd ..

del *.~pas
del *.dcu
del *.bak
rmdir /S /Q backup
exit