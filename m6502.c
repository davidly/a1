/*
   6502 emulator targeted at an 8080 running CP/M 2.2.
   Written by David Lee
*/

#include "m6502.h"

struct MOS_6502 cpu;

static uint8_t g_State = 0;

#define stateEndEmulation 2
#define stateSoftReset 4

void end_emulation() { g_State |= stateEndEmulation; }
void soft_reset() { g_State |= stateSoftReset; }

/*
    The Apple 1 shipped with 4k of RAM, and that's generally plenty.
    Allocate 32k, which runs most apps.
    The 6502 functional tests require 16k.
    Apps built with cc65 or Aztec C read and write to address 0x7fff.
    Aztec C doesn't support 32k arrays, so break up RAM into two arrays.
    The Altair Simulator doesn't have sufficient RAM for 32k. Turn APPLE1_32K off for that emulator.
*/

static uint8_t m_0000[ 0x4000 ];

#define APPLE1_32K
#ifdef APPLE1_32K
static uint8_t m_4000[ 0x4000 ];
#endif

uint8_t * mem_base[ 16 ] =
{
    m_0000,                /* 0000 */
    m_0000,                /* 1000 */
    m_0000,                /* 2000 */
    m_0000,                /* 3000 */
#ifdef APPLE1_32K
    m_4000 - 0x4000,       /* 4000 */
    m_4000 - 0x4000,       /* 5000 */
    m_4000 - 0x4000,       /* 6000 */
    m_4000 - 0x4000,       /* 7000 */
#else
    0,                     /* 4000 */
    0,                     /* 5000 */
    0,                     /* 6000 */
    0,                     /* 7000 */
#endif
    0,                     /* 8000 */
    0,                     /* 9000 */
    0,                     /* a000 */
    0,                     /* b000 */
    0,                     /* c000 */
    m_d000 - 0xd000,       /* d000 */
    m_e000 - 0xe000,       /* e000 */
    m_ff00 - 0xff00        /* f000 */
};

void bad_address( address ) uint16_t address;
{
    printf( "the apple 1 app referenced the invalid address %04x\n", address );
    exit( 1 );
}

/* the HITECH version is in getmem.asm */
#ifdef AZTECCPM
#asm
; in C:
;    uint8_t * get_mem( address ) uint16_t address;
;    {
;        uint8_t * base;
;        base = mem_base[ address >> 12 ];
;        if ( 0 == base )
;            bad_address( address );
;        return base + address;
;    }
;uint8_t * get_mem( address ) uint16_t address;
        PUBLIC get_mem_
get_mem_:
        lxi h, 3
        dad sp
        mov a, m           ; use the top nibble
        rrc
        rrc
        rrc
        ani 30             ; just shift 3 times
        mov l, a
        mvi h, 0
        lxi d, mem_base_
        dad d              ; hl now points to the array entry
        mov e, m
        inx h
        mov d, m           ; DE now has the array entry (base)
        mov a, d
        ora e              ; if DE is 0, it's a bad address
        jz bad_address_    ; address is on the stack. no going back
        lxi h, 2
        dad sp
        mov a, m
        inx h
        mov h, m
        mov l, a           ; hl now has address
        dad d              ; hl now has base + address
        ret
#endasm
#endif

#if 0 /* this version is more correct, but the assembly versions are much faster */
uint8_t * get_mem( address ) uint16_t address;
{
    if ( address < _countof( m_0000 ) ) /* for assembly apps, putting this check first is faster */
        return m_0000 + address;

    if ( address >= 0xe000 && address < 0xf000 ) /* woz BASIC. for BASIC apps, putting this check first is faster */
        return m_e000 - 0xe000 + address;

    if ( address >= 0xff00 ) /* the woz monitor */
        return m_ff00 - 0xff00 + address;

    if ( address >= 0xd000 && address <= 0xd013 ) /* memory-mapped I/O */
        return m_d000 - 0xd000 + address;

#ifdef APPLE1_32K
    if ( address < 0x8000 ) /* this rarely happens */
        return m_4000 - 0x4000 + address;
#endif

    printf( "invalid memory access: %04x\n", address );
    exit( 1 );
    return 0; /* avoid compiler warning */
}
#endif

/* I wish these were inline functions but old C compilers can't do that */
#define push( x ) ( * ( (uint8_t *) m_0000 + 0x0100 + cpu.sp-- ) = ( x ) )
#define push_word( x ) ( * ( (uint16_t *) ( m_0000 + 0x0100 + --cpu.sp ) ) = ( x ) ), cpu.sp--
#define pop() ( * ( (uint8_t *) m_0000 + 0x0100 + ++cpu.sp ) )

/* Aztec C generates better code for !! than 0 !=. There is no difference for HI-TECH C */
#define set_nz( x ) cpu.fNegative = ( !! ( ( x ) & 0x80 ) ), cpu.fZero = ! ( x )

void power_on()
{
    cpu.pc = get_word( 0xfffc );
    cpu.fInterruptDisable = true;
}

/* really only need 2 bits per value, but extraction would hurt emulator peformance */
static uint8_t ins_len_6502[ 256 ] =    /* length of instructions */
{
    /*00*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*08*/ 1, 2, 1, 0, 0, 3, 3, 1,
    /*10*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*18*/ 1, 3, 0, 0, 0, 3, 3, 0,
    /*20*/ 3, 2, 0, 0, 2, 2, 2, 0,
    /*28*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*30*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*38*/ 1, 3, 0, 0, 0, 3, 3, 0,
    /*40*/ 1, 2, 0, 0, 0, 2, 2, 0,
    /*48*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*50*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*58*/ 1, 3, 0, 0, 0, 3, 3, 0,
    /*60*/ 1, 2, 0, 0, 0, 2, 2, 0,
    /*68*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*70*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*78*/ 1, 3, 0, 0, 0, 3, 3, 0,
    /*80*/ 0, 2, 0, 0, 2, 2, 2, 0,
    /*88*/ 1, 0, 1, 0, 3, 3, 3, 0,
    /*90*/ 2, 2, 0, 0, 2, 2, 2, 0,
    /*98*/ 1, 3, 1, 0, 0, 3, 0, 0,
    /*a0*/ 2, 2, 2, 0, 2, 2, 2, 0,
    /*a8*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*b0*/ 2, 2, 0, 0, 2, 2, 2, 0,
    /*b8*/ 1, 3, 1, 0, 3, 3, 3, 0,
    /*c0*/ 2, 2, 0, 0, 2, 2, 2, 0,
    /*c8*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*d0*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*d8*/ 1, 3, 0, 0, 0, 3, 3, 0,
    /*e0*/ 2, 2, 0, 0, 2, 2, 2, 0,
    /*e8*/ 1, 2, 1, 0, 3, 3, 3, 0,
    /*f0*/ 2, 2, 0, 0, 0, 2, 2, 0,
    /*f8*/ 1, 3, 0, 0, 0, 3, 3, 1
};

uint8_t op_rotate( op, val ) uint8_t op; uint8_t val;
{
    bool oldCarry;
    uint8_t rotate;

    rotate = op >> 5;
    if ( 0 == rotate ) /* asl */        
    {
        cpu.fCarry = !! ( 0x80 & val );
        val <<= 1;
    }
    else if ( 1 == rotate ) /* rol */   
    {
        oldCarry = cpu.fCarry;
        cpu.fCarry = !! ( 0x80 & val );
        val <<= 1;
        if ( oldCarry )
            val |= 1;
    }
    else if ( 2 == rotate ) /* lsr */   
    {
        cpu.fCarry = ( val & 1 );
        val >>= 1;
    }
    else /* ror */
    {
        oldCarry = cpu.fCarry;
        cpu.fCarry = ( val & 1 );
        val >>= 1;
        if ( oldCarry )
            val |= 0x80;
    }

    set_nz( val );
    return val;
}

void op_cmp( lhs, rhs ) uint8_t lhs; uint8_t rhs;
{
    uint8_t result;
    result = (uint8_t) ( (uint16_t) lhs - (uint16_t) rhs );
    set_nz( result );
    cpu.fCarry = ( lhs >= rhs );
}

void op_bit( val ) uint8_t val;
{
    cpu.fNegative = !! ( val & 0x80 );
    cpu.fOverflow = !! ( val & 0x40 );
    cpu.fZero = ! ( cpu.a & val );
}

void op_bcd_math( math, rhs ) uint8_t math; uint8_t rhs;
{
    uint8_t alo, ahi, rlo, rhi, ad, rd, result;

    alo = cpu.a & 0xf;
    ahi = cpu.a >> 4;
    rlo = rhs & 0xf;
    rhi = rhs >> 4;

    cpu.fZero = false;

    if ( alo > 9 || ahi > 9 || rlo > 9 || rhi > 9 )
        return;

    ad = ahi * 10 + alo;
    rd = rhi * 10 + rlo;

    if ( 7 == math )
    {
        if ( !cpu.fCarry )
            rd += 1;

        if ( ad >= rd )
        {
            result = ad - rd;
            cpu.fCarry = true;
        }
        else
        {
            result = 100 + ad - rd;
            cpu.fCarry = false;
        }
    }
    else
    {
        result = ad + rd + cpu.fCarry;
        if ( result > 99 )
        {
            result -= 100;
            cpu.fCarry = true;
        }
        else
            cpu.fCarry = false;
    }

    cpu.a = ( ( result / 10 ) << 4 ) + ( result % 10 );
}

void op_math( op, rhs ) uint8_t op; uint8_t rhs;
{
    uint16_t res16; 
    uint8_t result;
    uint8_t math;
    math = op >> 5;
    if ( 6 == math )
    {
        op_cmp( cpu.a, rhs );
        return;
    }

    if ( cpu.fDecimal && ( 7 == math || 3 == math ) )
    {
        op_bcd_math( math, rhs );
        return;
    }

    if ( 7 == math )
    {
        rhs = 255 - rhs;
        math = 3;
    }

    if ( 3 == math )
    {
        res16 = (uint16_t) cpu.a + (uint16_t) rhs + (uint16_t) cpu.fCarry;
        result = (uint8_t) res16; /* cast generates faster code for Aztec than & 0xff */
        cpu.fCarry = ( 0 != ( res16 & 0xff00 ) );
        cpu.fOverflow = ( ! ( ( cpu.a ^ rhs ) & 0x80 ) ) && ( ( cpu.a ^ result ) & 0x80 );
        cpu.a = result;
    }
    else if ( 0 == math )
        cpu.a |= rhs;
    else if ( 1 == math )
        cpu.a &= rhs;
    else if ( 2 == math )
        cpu.a ^= rhs;

    set_nz( cpu.a );
}

void op_pop_pf()
{
    cpu.pf = pop();
    cpu.fNegative = !! ( cpu.pf & 0x80 );
    cpu.fOverflow = !! ( cpu.pf & 0x40 );
    cpu.fDecimal = !! ( cpu.pf & 8 );
    cpu.fInterruptDisable = !! ( cpu.pf & 4 );
    cpu.fZero = !! ( cpu.pf & 2 );
    cpu.fCarry = ( cpu.pf & 1 ); 
}

void op_php()
{
    cpu.pf = 0x30;
    if ( cpu.fNegative ) cpu.pf |= 0x80;
    if ( cpu.fOverflow ) cpu.pf |= 0x40;
    if ( cpu.fDecimal ) cpu.pf |= 8;
    if ( cpu.fInterruptDisable ) cpu.pf |= 4;
    if ( cpu.fZero ) cpu.pf |= 2;
    if ( cpu.fCarry ) cpu.pf |= 1;
    push( cpu.pf );
}

#ifndef NDEBUG
static char ac_flags[ 7 ];
char * render_flags()
{
    ac_flags[ 0 ] = cpu.fNegative ? 'N' : 'n';
    ac_flags[ 1 ] = cpu.fOverflow ? 'V' : 'v';
    ac_flags[ 2 ] = cpu.fDecimal ? 'D' : 'd';
    ac_flags[ 3 ] = cpu.fInterruptDisable ? 'I' : 'i';
    ac_flags[ 4 ] = cpu.fZero ? 'Z' : 'z';
    ac_flags[ 5 ] = cpu.fCarry ? 'C' : 'c';
    ac_flags[ 6 ] = 0;
    return ac_flags;
}
#endif

void emulate()
{
    uint8_t op, val;
    uint16_t address;
    uint8_t * pb;

    for (;;) /* most efficient infinite loop for older compilers */
    {
        op = get_byte( cpu.pc );

#ifndef NDEBUG
        printf( "pc %04x, op %02x, a %02x, x %02x, y %02x, sp %02x, %s\n", cpu.pc, op, cpu.a, cpu.x, cpu.y, cpu.sp, render_flags() ); 
#endif

        switch( op )
        {
            case 0x00:                                                                 /* brk */
            {
                push_word( cpu.pc + 2 );
                op_php(); 
                cpu.fInterruptDisable = true;
                cpu.pc = get_word( 0xfffe );
                continue;
            }
            case 0x01: case 0x21: case 0x41: case 0x61: case 0xc1: case 0xe1:          /* ora/and/eor/adc/cmp/sbc (a8, x) */
            {
                val = get_byte( cpu.pc + 1 ) + cpu.x; /* reduce expression complexity for hisoft C by using local */
                op_math( op, get_byte( get_word( val ) ) );
                break;
            }
            case 0x05: case 0x25: case 0x45: case 0x65: case 0xc5: case 0xe5:          /* ora/and/eor/adc/cmp/sbc a8 */
            {
                op_math( op, get_byte( get_byte( cpu.pc + 1 ) ) );
                break;
            }
            case 0x09: case 0x29: case 0x49: case 0x69: case 0xc9: case 0xe9:          /* ora/and/eor/adc/cmp/sbc #d8 */
            {
                op_math( op, get_byte( cpu.pc + 1 ) );
                break;
            }
            case 0x0d: case 0x2d: case 0x4d: case 0x6d: case 0xcd: case 0xed:          /* ora/and/eor/adc/cmp/sbc a16 */
            {
                op_math( op, get_byte( get_word( cpu.pc + 1 ) ) );
                break;
            }
            case 0x11: case 0x31: case 0x51: case 0x71: case 0xd1: case 0xf1:          /* ora/and/eor/adc/cmp/sbc (a8), y */
            {
                val = get_byte( cpu.pc + 1 ); /* reduce expression complexity for hisoft C by using local */
                op_math( op, get_byte( cpu.y + get_word( val ) ) );
                break;
            }
            case 0x15: case 0x35: case 0x55: case 0x75: case 0xd5: case 0xf5:          /* ora/and/eor/adc/cmp/sbc a8, x */  
            {
                op_math( op, get_byte( (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ) ) );
                break;
            }
            case 0x19: case 0x39: case 0x59: case 0x79: case 0xd9: case 0xf9:          /* ora/and/eor/adc/cmp/sbc a16, y */
            {
                op_math( op, get_byte( get_word( cpu.pc + 1 ) + cpu.y ) );
                break;
            }
            case 0x1d: case 0x3d: case 0x5d: case 0x7d: case 0xdd: case 0xfd:          /* ora/and/eor/adc/cmp/sbc a16, x */
            {
                op_math( op, get_byte( cpu.x + get_word( cpu.pc + 1 ) ) );
                break;
            }
            case 0x06: case 0x26: case 0x46: case 0x66: { address = get_byte( cpu.pc + 1 ); goto _rot_complete; }             /* asl/rol/lsr/ror a8 */
            case 0x0e: case 0x2e: case 0x4e: case 0x6e: { address = get_word( cpu.pc + 1 ); goto _rot_complete; }             /* asl/rol/lsr/ror a16 */
            case 0x16: case 0x36: case 0x56: case 0x76: { address = ( cpu.x + get_byte( cpu.pc + 1 ) ); goto _rot_complete; } /* asl/rol/lsr/ror a8, x */
            case 0x1e: case 0x3e: case 0x5e: case 0x7e:                                                                       /* asl/rol/lsr/ror a16, x */
            {
                address = cpu.x + get_word( cpu.pc + 1 );
_rot_complete:
                pb = get_mem( address ); /* avoid two calls to get_mem */
                *pb = op_rotate( op, *pb );
                break;
            }
            case 0x08: { op_php(); break; }                                            /* php */
            case OP_HOOK:                                                              /* hook */
            {
                op = m_hook();
                if ( 0 != g_State )
                    goto _gstate_set;
                goto _op_rts;
            }                             
            case 0x10: { if ( !cpu.fNegative ) goto _branch_complete; break; }         /* bpl */
            case 0x30: { if ( cpu.fNegative ) goto _branch_complete; break; }          /* bmi */
            case 0x50: { if ( !cpu.fOverflow ) goto _branch_complete; break; }         /* bvc */
            case 0x70: { if ( cpu.fOverflow ) goto _branch_complete; break; }          /* bvs */
            case 0x90: { if ( !cpu.fCarry ) goto _branch_complete; break; }            /* bcc */
            case 0xb0: { if ( cpu.fCarry ) goto _branch_complete; break; }             /* bcs */
            case 0xd0: { if ( !cpu.fZero ) goto _branch_complete; break; }             /* bne */
            case 0xf0:                                                                 /* beq */
            {
                if ( !cpu.fZero )
                    break;                                               
_branch_complete:
                /* casting to a larger signed type doesn't sign-extend on Aztec C, so do it manually */
                cpu.pc += ( 2 + sign_extend( get_byte( cpu.pc + 1 ), 7 ) );
                continue;
            }
            case 0x18: { cpu.fCarry = false; break; }                                  /* clc */
            case 0x20:                                                                 /* jsr a16 */
            {
                push_word( cpu.pc + 2 );
                cpu.pc = get_word( cpu.pc + 1 );
                continue;
            }
            case 0x24: { op_bit( get_byte( get_byte( cpu.pc + 1 ) ) ); break; }        /* bit a8 NVZ */
            case 0x28: { op_pop_pf(); break; }                                         /* plp NZCIDV */
            case 0x2c: { op_bit( get_byte( get_word( cpu.pc + 1 ) ) ); break; }        /* bit a16 NVZ */
            case 0x38: { cpu.fCarry = true; break; }                                   /* sec */
            case 0x40:                                                                 /* rti */
            {
                op_pop_pf();
                cpu.pc = pop();
                cpu.pc |= ( ( (uint16_t) pop() ) << 8 );
                continue;
            }
            case 0x48: { push( cpu.a ); break; }                                       /* pha */
            case 0x4c: { cpu.pc = get_word( cpu.pc + 1 ); continue; }                  /* jmp a16 */
            case 0x58: { cpu.fInterruptDisable = false; break; }                       /* cli */
            case 0x60:                                                                 /* rts */
            {
_op_rts:
                cpu.pc = pop();
                cpu.pc = 1 + ( ( (uint16_t) pop() << 8 ) | cpu.pc );
                continue;
            }
            case 0x68: { cpu.a = pop(); set_nz( cpu.a ); break; }                                  /* pla NZ */
            case 0x6a: case 0x4a: case 0x2a: case 0x0a: { cpu.a = op_rotate( op, cpu.a ); break; } /* asl, rol, lsr, ror */
            case 0x6c: { cpu.pc = get_word( get_word( cpu.pc + 1 ) ); continue; }                  /* jmp (a16) */
            case 0x78: { cpu.fInterruptDisable = true; break; }                                    /* sei */
            case 0x81: { address = get_word( (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ) ); goto _st_complete; } /* stx (a8, x) */
            case 0x84: case 0x85: case 0x86: { address = get_byte( cpu.pc + 1 ); goto _st_complete; }             /* sty/sta/stx a8 */
            case 0x8c: case 0x8d: case 0x8e: { address = get_word( cpu.pc + 1 ); goto _st_complete; }             /* sty/sta/stx a16 */
            case 0x91: { address = cpu.y + get_word( get_byte( cpu.pc + 1 ) ); goto _st_complete; }               /* sta (a8), y */
            case 0x94: case 0x95: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ); goto _st_complete; }  /* sta/sty a8, x */
            case 0x96: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.y ); goto _st_complete; }             /* stx a8, y */
            case 0x99: { address = get_word( cpu.pc + 1 ) + cpu.y; goto _st_complete; }                           /* sta a16, y */
            case 0x9d:                                                                                            /* sta a16, x */
            {
                address = get_word( cpu.pc + 1 ) + cpu.x;
_st_complete:
                set_byte( address, ( op & 1 ) ? cpu.a : ( op & 2 ) ? cpu.x : cpu.y );
                if ( 0xd012 == address )                                               /* apple 1 memory-mapped I/O */
                    m_store( address );
                break;
            }
            case 0x88: { cpu.y--; set_nz( cpu.y ); break; }                            /* dey */
            case 0x8a: { cpu.a = cpu.x; set_nz( cpu.a ); break; }                      /* txa */
            case 0x98: { cpu.a = cpu.y; set_nz( cpu.a ); break; }                      /* tya */
            case 0x9a: { cpu.sp = cpu.x; break; }                                      /* txs no flags set */
            case 0xa0: case 0xa2: case 0xa9: { address = cpu.pc + 1; goto _ld_complete; }                         /* ldy/ldx/lda #d8 */
            case 0xa1: { address = get_word( (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ) ); goto _ld_complete; } /* lda (a8, x) */
            case 0xa4 : case 0xa5: case  0xa6: { address = get_byte( cpu.pc + 1 ); goto _ld0_complete; }          /* ldy/lda/ldx a8 */
            case 0xac: case 0xad: case 0xae:{ address = get_word( cpu.pc + 1 ); goto _ld_complete; }              /* ldy/lda/ldx a16 */
            case 0xb1: { address = cpu.y + get_word( (uint16_t) get_byte( cpu.pc + 1 ) ); goto _ld_complete; }    /* lda (a8), y */
            case 0xb4: case 0xb5: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ); goto _ld0_complete; } /* ldy/lda a8, x */
            case 0xb6: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.y ); goto _ld0_complete; }            /* ldx a8, y */
            case 0xb9 : case 0xbe: { address = get_word( cpu.pc + 1 ) + cpu.y; goto _ld_complete; }               /* lda/ldx a16, y */
            case 0xbc: case 0xbd:                                                                                 /* ldy/lda a16, x */
            {
                address = get_word( cpu.pc + 1 ) + cpu.x;             
_ld_complete:   /* load */
                if ( address >= 0xd010 && address <= 0xd012 )                          /* apple 1 memory-mapped I/O */
                {
                    set_byte( address, m_load( address ) );
_gstate_set:
                    if ( g_State & stateEndEmulation )
                        goto _all_done;

                    if ( g_State & stateSoftReset )
                    {
                        g_State &= ~stateSoftReset;
                        cpu.pc = get_word( 0xfffc );
                        continue;
                    }
                }

_ld0_complete:  /* load from page 0 so no need for memory-mapped I/O check */
                val = get_byte( address );
                set_nz( val );
        
                if ( op & 1 )
                    cpu.a = val;
                else if ( op & 2 )
                    cpu.x = val;
                else
                    cpu.y = val;
                break;
            }
            case 0xa8: { cpu.y = cpu.a; set_nz( cpu.y ); break; }                      /* tay */
            case 0xaa: { cpu.x = cpu.a; set_nz( cpu.x ); break; }                      /* tax */
            case 0xb8: { cpu.fOverflow = false; break; }                               /* clv */
            case 0xba: { cpu.x = cpu.sp; set_nz( cpu.x ); break; }                     /* tsx */
            case 0xc0: { op_cmp( cpu.y, get_byte( cpu.pc + 1 ) ); break; }             /* cpy #d8 */
            case 0xc4: { op_cmp( cpu.y, get_byte( get_byte( cpu.pc + 1 ) ) ); break; } /* cpy a8 */
            case 0xc6 : case 0xe6: { address = get_byte( cpu.pc + 1 ); goto _crement_complete; }         /* inc/dec a8 */
            case 0xce : case 0xee: { address = get_word( cpu.pc + 1 ); goto _crement_complete; }         /* inc/dec a16 */
            case 0xd6 : case 0xf6: { address = (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ); goto _crement_complete; } /* inc/dec a8, x */
            case 0xde : case 0xfe:                                                                       /* inc/dec a16, x */
            {
                address = cpu.x + get_word( cpu.pc + 1 );
_crement_complete:
                pb = get_mem( address );
                if ( op >= 0xe6 )
                    (*pb)++;
                else
                    (*pb)--;
                set_nz( *pb );
                break;
            }
            case 0xc8: { cpu.y++; set_nz( cpu.y ); break; }                            /* iny */
            case 0xca: { cpu.x--; set_nz( cpu.x ); break; }                            /* dex */
            case 0xcc: { op_cmp( cpu.y, get_byte( get_word( cpu.pc + 1 ) ) ); break; } /* cpy a16 */
            case 0xd8: { cpu.fDecimal = false; break; }                                /* cld */
            case 0xe0: { op_cmp( cpu.x, get_byte( cpu.pc + 1 ) ); break; }             /* cpx #d8 */
            case 0xe4: { op_cmp( cpu.x, get_byte( get_byte( cpu.pc + 1 ) ) ); break; } /* cpx a8 */
            case 0xe8: { cpu.x++; set_nz( cpu.x ); break; }                            /* inx */
            case 0xea: { break; }                                                      /* nop */
            case 0xec: { op_cmp( cpu.x, get_byte( get_word( cpu.pc + 1 ) ) ); break; } /* cpx a16 */
            case 0xf8: { cpu.fDecimal = true; break; }                                 /* sed */
            case 0xff: { m_halt(); goto _all_done; }                                   /* halt */
            default: m_hard_exit( "unknown mos6502 opcode %02x\n", op );
        }

        cpu.pc += ins_len_6502[ op ];
    }

_all_done:
    return;
}

