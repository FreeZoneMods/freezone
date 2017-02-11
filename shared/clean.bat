del *.~pas
del *.dcu
del *.bak

cd SourceKit
@start clean.bat
cd ..

cd 3rdparty
@start clean.bat
cd ..

exit