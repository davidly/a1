rem use the built-in optim.com since it works for a1
ntvcm -c c309.com -O -C -DNDEBUG -DHISOFTCPM -S -X a1.c
ntvcm zas A1.AS

rem use the native-built optim.exe for m6502.c since emulate() is large
ntvcm -c c309.com -C -DNDEBUG -DHISOFTCPM -S -X m6502.c
optim.exe m6502.as m6502.asm
ntvcm zas M6502.ASM

ntvcm linq -MA1.MAP -X -C100H -OA1.COM CRTCPM.OBJ A1.OBJ M6502.OBJ LIBC.LIB

