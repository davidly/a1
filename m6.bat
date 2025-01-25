@echo off

del a1.o 2>nul
del m6.o 2>nul
del a1begin.o 2>nul
del a1.com 2>nul

ntvcm ..\ntvcm\aztec\cc -DNDEBUG -DAZTECCPM -Q -T -F a1.c
ntvcm ..\ntvcm\aztec\as -L a1.asm
ntvcm ..\ntvcm\aztec\as -L m6.asm
ntvcm ..\ntvcm\aztec\as -L a1begin.asm
ntvcm ..\ntvcm\aztec\ln -T a1.o a1begin.o m.lib m6.o c.lib 

