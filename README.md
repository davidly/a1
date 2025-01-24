# a1
6502 and Apple 1 emulator for 8080/Z80 CP/M 2.2 machines

This repo has C code that can be built with CP/M 2.2 compilers to create a 6502 Apple 1 emulator.

This code is forked from [NTVAO](https://github.com/davidly/ntvao), which is a C++ Apple 1 emulator that targets many platforms.

The code here was modified to build with C compilers from the mid 1980's and simplified to fit on CP/M machines with 64k or less of RAM.

Files:

   - m.bat        Builds a1 using Aztec C Vers. 1.06D 8080  (C) 1982 1983 1984 by Manx Software Systems
   - mh.bat       Builds a1 using HI-TECH C COMPILER (CP/M-80) V3.09
   - m6.bat       Builds a1 using Aztec C and m6.asm instead of m6502.c Faster, but hard to modify.
   - a1.c         Apple 1 emulator main app
   - m6502.c      MOS 6502 emulator
   - m6502.h      header for MOS 6502 emulator
   - m6.asm       assembly alternative to m6502.c. Runs > 2 times faster. use m6.bat to build
   - getmem.asm   get_mem() implementation for HI-TECH C COMPILER
   - 6502fun.hex  [6502 functional tests](https://github.com/Klaus2m5/6502_65C02_functional_tests)
   - run_fun_tests.bat Invokes ntvcm and a1 to run 6502fun.hex and validate the 6502 is working
   - e.bas        BASIC app that computes the first digits of e. Invoke via ntvcm a1 -l:e.bas
   - hello.bas    BASIC hello world app
   - hello.hex    Assembler hello world app built from hello.s
   - hello.s      Assembler hello world app
   - tttstdin.bas BASIC app that proves you can't win at tic-tac-toe if the opponent is competent
   - t1.hex       app generated from assembly version of tic-tac-toe. runs one iteration.
   - ttt1st.bas   like tttstdin.bas but only checks first move, not all 3 unique first moves
   - tttaztec.hex app generated from Aztec C for 6502 that solves tic-tac-toe
   - tttcc651.hex app generated from cc65 C compiler that solves tic-tac-toe
   - eaztec.hex   computes e using Aztec C for 6502
   - ecc65.hex    computes e using CC65
   - sieveaz.hex  BYTE benchmark to count primes using Aztec C for 6502
   - sievec65.hex BYTE benchmark to count primes using CC65
   - badaddr.bas  test program that references unavailable RAM
   - badaddr.txt  test program that references  unavailable RAM
   - runall.bat   runs test apps
   - baseline_test_a1.txt Baseline test results
   - m.sh         linux build script
   - runall.sh    linux test script

Usage:

    Apple 1: emulates a 6502 Apple 1
    usage: a1 <arguments> [hexfile>]
      arguments:
       -a       address at which pc is set, e.g. /a:0x1000
                overrides default of 0xff00 or the first address in the hex file.
       -h       use hooks instead of woz monitor for console I/O
       -l:file  loads file as keyboard input. e.g.: -l:estdin.bas
       -x       exit when control transfers to the monitor (when the app is done)
       hexfile  file loaded before emulator starts
                .hex files must be in Apple 1 or Intel format.
       -- control keys
            ^c        gracefully exit the emulator
            ^l        load a file into the keyboard input stream. This is
                      likely an Apple 1 format .hex for monitor or .bas for BASIC
            ^q        quit the emulator at the next app keyboard read
            ^r        soft reset via the 6502's 0xfffc reset vector
            ^break    forcibly exit the app

The CP/M C compilers can be found here: [CP/M Compilers](https://github.com/davidly/cpm_compilers)

[NTVCM](https://github.com/davidly/cpm_compilers) is an 8080/Z80 CP/M 2.2 emulator that can be used to both compile and run a1.

To build and validate on Linux, use m.sh and runall.sh. Many files need to be renamed or copied to uppercase names. For macOS the uppercase filenames aren't needed.

Notes:
  - Performance on physical CP/M machines isn't great. Compared to a physical 1.022727 Mhz 6502:
   - Using m6502.c when run on a 2Mhz 8080, A1 built with Aztec C is 207 times slower.
   - Using m6502.c when run on a 4Mhz Z80, A1 built with the HI-TECH compiler is 95 times slower.
   - Using m6.asm when run on a 2Mhz 8080, A1 is 83 times slower.
   - Using m6.asm when run on a 4Mhz Z80, A1 is 42 times slower. This is typical for interpreter emulators across platforms.
  - The Aztec Z80 variant compiler CZ.COM produces slower code than the 8080 CC.COM variant and should be avoided.
  - When using the HI-TECH compiler, get the [optimizer](https://github.com/nikitinprior/doptim) built for your native platform and run it as shown in mh.bat for the best performance. The emulator C code is too large for the Z80 version of the optimizer to run.
  - CP/M machines have at most 64k of RAM, so the Apple 1 machine has less than that:
      - 32K of RAM starting at address 0
      - 21 bytes for memory-mapped I/O to the keyboard and display at address 0xd000
      - 4k Woz BASIC at address 0xe000
      - 256 bytes of Woz Monitor at address 0xff00
  - CP/M doesn't understand folders, so you need to copy ctype.h, stdio.h, m.lib, and c.lib to the a1 folder for Aztec C and similar files for HI-TECH C.
  - If a HEX file is specified on the command line, it's loaded prior to the start of emulation
  - If a -l:file input file is specified, it's fed to keyboard input after the start of emulation
  - The -l:file input file can contain control characters including ^c to terminate execution once an app is complete
  - The buid scripts are Windows-based, but all of this works on Linux and MacOS as well. On those platforms be sure input text files have CR/LF using unix2dos.
  - The Altair 8800 (Z80) simulator V4.0-0 doesn't have enough RAM for a 32K Apple 1. Turn off APPLE1_32K in m6502.c to run a1 in that emulator with just 16K of RAM.
  - Overlays could be used for most of the code in a1.c and the code in m6502.c such that the code for just one or the other is loaded at a time. This would free more RAM for the Apple 1. But I haven't found any Apple 1 apps that actually need it.
  - Why did I make this? Now I can run Steve Wozniak BASIC apps in my 6502 Apple 1 emulator in my 8080/Z80 CP/M emulator in my 8086 DOS emulator in my Arm64 Linux emulator in my RISC-V 64 Linux emulator on any reasonably modern machine and OS.
