
rm A1.O 2>/dev/null
rm M6502.O 2>/dev/null
rm A1.COM 2>/dev/null

../ntvcm/ntvcm ../ntvcm/aztec/CC -DNDEBUG -DAZTECCPM -Q -T -F A1.C
../ntvcm/ntvcm ../ntvcm/aztec/CC -DNDEBUG -DAZTECCPM -Y256 -Q -T -F M6502.C
../ntvcm/ntvcm ../ntvcm/aztec/AS -L A1.ASM
../ntvcm/ntvcm ../ntvcm/aztec/AS -L M6502.ASM
../ntvcm/ntvcm ../ntvcm/aztec/LN -T A1.O M6502.O M.LIB C.LIB

