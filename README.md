# a1
6502 and Apple 1 emulator for 8080/Z80 CP/M 2.2 machines

This repo has C code that can be built with CP/M 2.2 compilers to create a 6502 Apple 1 emulator.

This code is forked from [NTVAO](https://github.com/davidly/ntvao), which is a C++ Apple 1 emulator that targets many platforms.

The code here was modified to build with C compilers from the mid 1980's and simplified to fit on CP/M machines with 64k or less of RAM.

Files:

   - m.bat        Builds a1 using Aztec C Vers. 1.06D 8080  (C) 1982 1983 1984 by Manx Software Systems
   - mh.bat       Builds a1 using HI-TECH C COMPILER (CP/M-80) V3.09
   - a1.c         Apple 1 emulator main app
   - m6502.c      MOS 6502 emulator
   - m6502.h      header for MOS 6502 emulator
   - 6502fun.hex  [6502 functional tests](https://github.com/Klaus2m5/6502_65C02_functional_tests)
   - run_fun_tests.bat Invokes ntvcm and a1 to run 6502fun.hex and validate the 6502 is working
   - e.bas        BASIC app that computes the first digits of e. Invoke via ntvcm a1 -l:e.bas
   - hello.bas    BASIC hello world app
   - hello.hex    Assembler hello world app built from hello.s
   - hello.s      Assembler hello world app
   - tttstdin.bas BASIC app that proves you can't win at tic-tac-toe if the opponent is competent

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

Notes:
  - Performance on physical CP/M machines isn't great. When run on a 4Mhz Z80, A1 built with Aztec C is 231x slower than a physical 1Mhz 6502. A1 built with the HI-TECH compiler is 180x slower and requires a Z80. That said, performnce on modern hardware is great.
  - The Aztec Z80 variant compiler CZ.COM produces slower code than the 8080 CC.COM variant and should be avoided.
  - CP/M machines have at most 64k of RAM, so the Apple 1 machine has less than that:
      - 16K of RAM starting at address 0
      - 32 bytes for memory-mapped I/O to the keyboard and display at address 0xd000
      - 4k Woz BASIC at address 0xe000
      - 256 bytes of Woz Monitor at address 0xff00
  - If a HEX file is specified on the command line, it's loaded prior to the start of emulation
  - If a -l:file input file is specified, it's fed to keyboard input after the start of emulation
  - The -l:file input file can contain control characters including ^c to terminate execution once an app is complete
  - The buid scripts are Windows-based, but all of this would work on Linux and MacOS as well. On those platforms be sure input text files have CR/LF using unix2dos.

