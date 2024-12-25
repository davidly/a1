ntvcm -c c309.com -C -DNDEBUG -DHISOFTCPM -S -V -X a1.c
optim.exe a1.as a1.asm

ntvcm -c c309.com -C -DNDEBUG -DHISOFTCPM -S -V -X m6502.c
optim.exe m6502.as m6502.asm

ntvcm zas A1.ASM
ntvcm zas M6502.ASM
ntvcm linq -MA1.MAP -X -C100H -OA1.COM CRTCPM.OBJ A1.OBJ M6502.OBJ LIBC.LIB

