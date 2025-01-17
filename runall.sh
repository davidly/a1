outputfile=test_a1.txt
echo $(date) >$outputfile

echo tttaztec
echo tttaztec >>$outputfile
../ntvcm/ntvcm -p A1 -x -a:0x1030 tttaztec.hex >>$outputfile

echo tttcc65
echo tttcc65 >>$outputfile
../ntvcm/ntvcm -p A1 -x tttcc651.hex >>$outputfile

echo t1 assembly
echo t1 assembly >>$outputfile
../ntvcm/ntvcm -p A1 -x t1.hex >>$outputfile

echo 6502 functional test
echo 6502 functional tests >>$outputfile
../ntvcm/ntvcm A1 -a:400 -h 6502fun.hex >>$outputfile

echo hello world
echo hello world >>$outputfile
../ntvcm/ntvcm A1 -x hello.hex >>$outputfile

echo digits of e
echo digits of e >>$outputfile
../ntvcm/ntvcm -p A1 -l:e.bas >>$outputfile

echo BASIC hello world
echo BASIC hello world >>$outputfile
../ntvcm/ntvcm A1 -l:hello.bas >>$outputfile

echo BASIC tic-tac-toe first move
echo BASIC tic-tac-toe first move >>$outputfile
../ntvcm/ntvcm -p A1 -l:ttt1st.bas >>$outputfile

echo invalid memory access basic test 0xc000
echo invalid memory access basic test 0xc000 >>$outputfile
../ntvcm/ntvcm A1 -l:badaddr.bas >>$outputfile

echo invalid memory access monitor test 0xc000
echo invalid memory access monitor test 0xc000 >>$outputfile
../ntvcm/ntvcm A1 -l:badaddr.txt >>$outputfile

echo $(date) >>$outputfile
unix2dos $outputfile >/dev/null 2>&1
diff -i -B -w baseline_$outputfile $outputfile

