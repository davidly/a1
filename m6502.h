typedef unsigned char uint8_t;
typedef char int8_t;
typedef unsigned int uint16_t;
typedef int int16_t;
typedef unsigned long uint32_t;
typedef long int32_t;

#ifndef HISOFTCPM
#define memset( p, val, len ) setmem( p, len, val )
typedef int size_t;
#endif

typedef uint8_t bool;

#define true 1
#define false 0

#define _countof( X ) ( sizeof( X ) / sizeof( X[0] ) )
#define sign_extend( x, bits ) ( ( (x) ^ ( (uint16_t) 1 << bits ) ) - ( ( (uint16_t) 1 ) << bits ) )

/* a1.c manages these memory ranges */
extern uint8_t m_d000[ 21 ]; /* memory-mapped keyboard and console */
extern uint8_t m_e000[ 4096 ]; /* woz apple 1 basic */
extern uint8_t m_ff00[ 256 ]; /* woz monitor */

#define OP_HOOK 0x0f
#define OP_HALT 0xff
#define OP_RTS 0x60

extern void emulate();
extern void end_emulation();
extern void soft_reset();
extern void power_on();

extern void * getmem();

/* use #define instead of functions because old compilers don't inline functions */

#define getword( addr ) ( * (uint16_t *) getmem( addr ) )
#define getbyte( addr ) ( * (uint8_t *) getmem( addr ) )

#define setword( addr, value ) * (uint16_t *) getmem( addr ) = value
#define setbyte( addr, value ) * (uint8_t *) getmem( addr ) = value

struct MOS_6502
{
    uint8_t a, x, y, sp;
    uint16_t pc;
    uint8_t pf;   /* NV-BDIZC. State is tracked in bools below and only updated for pf and php */
    bool fNegative, fOverflow, fUnused, fDecimal, fInterruptDisable, fZero, fCarry;
};

extern struct MOS_6502 cpu;

extern void m_halt(); 
extern uint8_t m_hook();
extern uint8_t m_load();
extern void m_store();
extern void m_hard_exit();
