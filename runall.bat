@echo off
setlocal

set outputfile=a1test.txt
echo %date% %time% >%outputfile%

ntvcm -p .\a1 -a:400 -h 6502fun.hex >>%outputfile%

ntvcm a1 -x hello.hex >>%outputfile%

ntvcm a1 -x t1.hex >>%outputfile%

ntvcm a1 -l:e.bas >>%outputfile%

ntvcm a1 -l:hello.bas >>%outputfile%

ntvcm a1 -l:ttt1st.bas >>%outputfile%

echo %date% %time% >>%outputfile%
diff baseline_%outputfile% %outputfile%

