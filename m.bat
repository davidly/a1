@echo off

del a1.o 2>nul
del m6502.o 2>nul
del a1begin.o 2>nul
del a1.com 2>nul

ntvcm ..\ntvcm\aztec\cc -DNDEBUG -DAZTECCPM -Q -T -F a1.c
ntvcm ..\ntvcm\aztec\cc -DNDEBUG -DAZTECCPM -Y256 -Q -T -F m6502.c
ntvcm ..\ntvcm\aztec\as -L a1.asm
ntvcm ..\ntvcm\aztec\as -L m6502.asm
ntvcm ..\ntvcm\aztec\as -L a1begin.asm
ntvcm ..\ntvcm\aztec\ln -T a1.o a1begin.o m6502.o m.lib c.lib

