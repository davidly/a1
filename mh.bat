@echo off

rem use the built-in optim.com since it works for a1
ntvcm -c c309.com -O -C -DNDEBUG -DHISOFTCPM -S -X a1.c
ntvcm zas A1.AS

rem use the native-built optim.exe for m6502.c since emulate() is large
ntvcm -c c309.com -C -DNDEBUG -DHISOFTCPM -S -X m6502.c

rem if you haven't built optim.exe do the copy instead but it'll be very slow
rem see https://github.com/nikitinprior/doptim
optim.exe m6502.as m6502.asm
rem copy m6502.as m6502.asm

ntvcm zas M6502.ASM

ntvcm zas getmem.ASM

ntvcm linq -MA1.MAP -X -C100H -OA1.COM CRTCPM.OBJ A1.OBJ GETMEM.OBJ M6502.OBJ LIBC.LIB

