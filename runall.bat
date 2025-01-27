@echo off
setlocal

set outputfile=test_a1.txt
echo %date% %time% >%outputfile%

echo tttaztec
echo tttaztec >>%outputfile%
ntvcm -p a1 -x -a:0x1030 tttaztec.hex >>%outputfile%

echo tttcc65
echo tttcc65 >>%outputfile%
ntvcm -p a1 -x tttcc651.hex >>%outputfile%

echo t1 assembly
echo t1 assembly >>%outputfile%
ntvcm -p a1 -x t1.hex >>%outputfile%

echo 6502 functional test
echo 6502 functional tests >>%outputfile%
ntvcm -p .\a1 -a:400 -h 6502fun.hex >>%outputfile%

echo hello world
echo hello world >>%outputfile%
ntvcm a1 -x hello.hex >>%outputfile%

echo digits of e
echo digits of e >>%outputfile%
ntvcm -p a1 -l:e.bas >>%outputfile%

echo BASIC hello world
echo BASIC hello world >>%outputfile%
ntvcm a1 -l:hello.bas >>%outputfile%

echo BASIC tic-tac-toe first move
echo BASIC tic-tac-toe first move >>%outputfile%
ntvcm -p a1 -l:ttt1st.bas >>%outputfile%

echo invalid memory access basic test 0xc000
echo invalid memory access basic test 0xc000 >>%outputfile%
ntvcm a1 -l:badaddr.bas >>%outputfile%

echo invalid memory access monitor test 0xc000
echo invalid memory access monitor test 0xc000 >>%outputfile%
ntvcm a1 -l:badaddr.txt >>%outputfile%

echo e aztec
echo e aztec >>%outputfile%
ntvcm -p a1 -a:0x1030 -x eaztec.hex >>%outputfile%

echo e cc65
echo e cc65 >>%outputfile%
ntvcm -p a1 -x ecc65.hex >>%outputfile%

echo sieve aztec
echo sieve aztec >>%outputfile%
ntvcm -p a1 -a:0x1030 -x sieveaz.hex >>%outputfile%

echo sieve cc65
echo sieve cc65 >>%outputfile%
ntvcm -p a1 -x sievec65.hex >>%outputfile%

echo %date% %time% >>%outputfile%
diff baseline_%outputfile% %outputfile%

