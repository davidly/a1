/*
   6502 emulator targeted at an 8080 running CP/M 2.2.
   Written by David Lee
*/

#include "m6502.h"

struct MOS_6502 cpu;

static uint32_t g_State = 0;

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
*/

uint8_t m_0000[ 0x4000 ];
uint8_t m_4000[ 0x4000 ];

void * getmem( address ) uint16_t address;
{
    if ( address < _countof( m_0000 ) ) /* for assembly apps, putting this check first is faster */
        return m_0000 + address;

    if ( address >= 0xe000 && address < 0xf000 ) /* woz BASIC. for BASIC apps, putting this check first is faster */
        return m_e000 - 0xe000 + address;

    if ( address >= 0xff00 ) /* the woz monitor */
        return m_ff00 - 0xff00 + address;

    if ( address >= 0xd000 && address < 0xd020 ) /* memory-mapped I/O */
        return m_d000 - 0xd000 + address;

    if ( address < 0x8000 ) /* this rarely happens */
        return m_4000 - 0x4000 + address;

    printf( "invalid memory access: %04x\n", address );
    exit( 1 );
    return 0; /* avoid compiler warning */
}

static void push( x ) uint8_t x; { setbyte( 0x0100 + cpu.sp, x ); cpu.sp--; }
static uint8_t pop() { cpu.sp++; return getbyte( 0x0100 + cpu.sp ); }

#define set_nz( x ) cpu.fNegative = ( 0 != ( (x) & 0x80 ) ), cpu.fZero = !(x)

void power_on()
{
    cpu.pc = getword( 0xfffc );
    cpu.fInterruptDisable = true;
}

static uint8_t ins_len_6502[ 256 ] =
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
    /*f8*/ 1, 3, 0, 0, 0, 3, 3, 1,
};

uint8_t op_rotate( rotate, val ) uint8_t rotate; uint8_t val;
{
    bool oldCarry;

    if ( 0 == rotate )         
    {
        cpu.fCarry = ( 0 != ( 0x80 & val ) );
        val <<= 1;
        val &= 0xfe;
    }
    else if ( 1 == rotate )    
    {
        oldCarry = cpu.fCarry;
        cpu.fCarry = ( 0 != ( 0x80 & val ) );
        val <<= 1;
        if ( oldCarry )
            val |= 1;
        else
            val &= 0xfe;
    }
    else if ( 2 == rotate )    
    {
        cpu.fCarry = ( 0 != ( 1 & val ) );
        val >>= 1;
        val &= 0x7f;
    }
    else                       
    {
        oldCarry = cpu.fCarry;
        cpu.fCarry = ( 0 != ( 1 & val ) );
        val >>= 1;
        if ( oldCarry )
            val |= 0x80;
        else
            val &= 0x7f;
    }

    set_nz( val );
    return val;
}

void op_cmp( lhs, rhs ) uint8_t lhs; uint8_t rhs;
{
    uint16_t result;
    result = (uint16_t) lhs - (uint16_t) rhs;
    set_nz( (uint8_t) result );
    cpu.fCarry = ( lhs >= rhs );
}

void op_bit( val ) uint8_t val;
{
    uint8_t result;
    result = cpu.a & val;
    cpu.fNegative = ( 0 != ( val & 0x80 ) );
    cpu.fOverflow = ( 0 != ( val & 0x40 ) );
    cpu.fZero = ( 0 == result );
}

void op_bcd_math( math, rhs ) uint8_t math; uint8_t rhs;
{
    uint8_t alo, ahi, rlo, rhi, ad, rd, result;

    alo = cpu.a & 0xf;
    ahi = ( cpu.a >> 4 ) & 0xf;
    rlo = rhs & 0xf;
    rhi = ( rhs >> 4 ) & 0xf;

    cpu.fZero = false;

    if ( alo > 9 || ahi > 9 || rlo > 9 || rhi > 9 )
        return;

    ad = ahi * 10 + alo;
    rd = rhi * 10 + rlo;
    result;

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
        result = ad + rd + ( cpu.fCarry ? 1 : 0 );
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

void op_math( math, rhs ) uint8_t math; uint8_t rhs;
{
    uint16_t res16;
    uint8_t result;

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

    if ( 0 == math )
        cpu.a |= rhs;
    else if ( 1 == math )
        cpu.a &= rhs;
    else if ( 2 == math )
        cpu.a ^= rhs;
    else if ( 3 == math )
    {
        res16 = (uint16_t) cpu.a + (uint16_t) rhs + (uint16_t) ( cpu.fCarry ? 1 : 0 );
        result = res16 & 0xff;
        cpu.fCarry = ( 0 != ( res16 & 0xff00 ) );
        cpu.fOverflow = ( ! ( ( cpu.a ^ rhs ) & 0x80 ) ) && ( ( cpu.a ^ result ) & 0x80 );
        cpu.a = result;
    }

    set_nz( cpu.a );
}

void op_pop_pf()
{
    cpu.pf = pop();
    cpu.fNegative = ( 0 != ( cpu.pf & 0x80 ) );
    cpu.fOverflow = ( 0 != ( cpu.pf & 0x40 ) );
    cpu.fDecimal = ( 0 != ( cpu.pf & 0x08 ) );
    cpu.fInterruptDisable = ( 0 != ( cpu.pf & 0x04 ) );
    cpu.fZero = ( 0 != ( cpu.pf & 0x02 ) );
    cpu.fCarry = ( 0 != ( cpu.pf & 0x01 ) ); 
}

void op_php()
{
    cpu.pf = 0x20;
    if ( cpu.fNegative ) cpu.pf |= 0x80;
    if ( cpu.fOverflow ) cpu.pf |= 0x40;
    cpu.pf |= 0x10;
    if ( cpu.fDecimal ) cpu.pf |= 0x08;
    if ( cpu.fInterruptDisable ) cpu.pf |= 0x04;
    if ( cpu.fZero ) cpu.pf |= 0x02;
    if ( cpu.fCarry ) cpu.pf |= 0x01;
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
    uint8_t op, lo, val;
    uint16_t returnAddress, address;
    bool branch;

    do
    {
        _top_of_loop:

        if ( 0 != g_State )
        {
            if ( g_State & stateEndEmulation )
            {
                g_State &= ~stateEndEmulation;
                break;
            }
            else if ( g_State & stateSoftReset )
            {
                g_State &= ~stateSoftReset;
                cpu.pc = getword( 0xfffc );
                continue;
            }
        }

        op = getbyte( cpu.pc );

#ifndef NDEBUG
        printf( "pc %04x, op %02x, a %02x, x %02x, y %02x, sp %02x, %s\n", cpu.pc, op, cpu.a, cpu.x, cpu.y, cpu.sp, render_flags() ); 
#endif

        switch( op )
        {
            case 0x00: 
            {
                returnAddress = cpu.pc + 2;
                push( returnAddress >> 8 );
                push( returnAddress & 0xff );
                op_php(); 
                cpu.fInterruptDisable = true;
                cpu.pc = getword( 0xfffe );
                continue;
            }
            case 0x01: case 0x11: case 0x21: case 0x31: case 0x41: case 0x51: case 0x61: case 0x71: 
            case 0xc1: case 0xd1: case 0xe1: case 0xf1: case 0xc5: case 0xd5: case 0xe5: case 0xf5:
            case 0x05: case 0x15: case 0x25: case 0x35: case 0x45: case 0x55: case 0x65: case 0x75:
            case 0x09: case 0x19: case 0x29: case 0x39: case 0x49: case 0x59: case 0x69: case 0x79:
            case 0xc9: case 0xd9: case 0xe9: case 0xf9: case 0xcd: case 0xdd: case 0xed: case 0xfd:
            case 0x0d: case 0x1d: case 0x2d: case 0x3d: case 0x4d: case 0x5d: case 0x6d: case 0x7d:
            {
                lo = ( op & 0x0f );
                if ( 1 == lo )
                {
                    if ( op & 0x10 )                                    
                        val = getbyte( (uint16_t) cpu.y + getword( getbyte( cpu.pc + 1 ) ) );
                    else                                                
                        val = getbyte( getword( 0xff & ( getbyte( cpu.pc + 1  ) + cpu.x ) ) );  
                }
                else if ( 5 == lo )
                {
                    address = getbyte( cpu.pc + 1 );
                    if ( op & 0x10 )                                    
                        address = 0xff & ( address + cpu.x );               
                    val = getbyte( address );
                }
                else if ( 9 == lo )
                {
                    if ( op & 0x10 )                                    
                        val = getbyte( getword( cpu.pc + 1 ) + cpu.y );
                    else                                                
                        val = getbyte( cpu.pc + 1 );
                }
                else if ( 0xd == lo )
                {
                    address = getword( cpu.pc + 1 );                 
                    if ( op & 0x10 )                                    
                        address += (uint16_t) cpu.x;
                    val = getbyte( address );
                }
                else
                    m_hard_exit( "mos6502 unsupported comparison instruction %02x\n", op );
        
                op_math( ( op >> 5 ), val );
                break;
            }
            case 0x06: case 0x16: case 0x26: case 0x36: case 0x46: case 0x56: case 0x66: case 0x76: 
            case 0x0e: case 0x1e: case 0x2e: case 0x3e: case 0x4e: case 0x5e: case 0x6e: case 0x7e:
            {
                lo = ( op & 0x0f );
                if ( 0x06 == lo )
                {
                    address = getbyte( cpu.pc + 1 );
                    if ( op & 0x10 )
                        address += (uint16_t) cpu.x;               
                }
                else if ( 0x0e == lo )
                {
                    address = getword( cpu.pc + 1 );                 
                    if ( op & 0x10 )
                        address += (uint16_t) cpu.x;               
                }
                else
                    m_hard_exit("mos6502 unsupported rotate instruction %02x\n", op );
        
                setbyte( address, op_rotate( op >> 5, getbyte( address ) ) );
                break;
            }
            case 0x08: { op_php(); break; } 
            case OP_HOOK: { op = m_hook(); goto _op_rts; } 
            case 0x10: case 0x30: case 0x50: case 0x70: case 0x90: case 0xb0: case 0xd0: case 0xf0: 
            {
                if ( op <= 0x30 )
                    branch = cpu.fNegative;
                else if ( op <= 0x70 )
                    branch = cpu.fOverflow;
                else if ( op <= 0xb0 )
                    branch = cpu.fCarry;
                else
                    branch = cpu.fZero;
        
                if ( 0 == ( op & 0x20 ) )
                    branch = !branch;
        
                if ( branch )
                {
                    /* casting to a larger signed type doesn't sign-extend on Aztec C, so do it manually */
                    cpu.pc += ( 2 + sign_extend( (uint16_t) getbyte( cpu.pc + 1 ), 7 ) );
                    continue;
                }
                break;
            }
            case 0x18: { cpu.fCarry = false; break; } 
            case 0x20: 
            {
                address = getword( cpu.pc + 1 );
                returnAddress = cpu.pc + 2;  
                push( returnAddress >> 8 );
                push( returnAddress & 0xff );
                cpu.pc = address;
                continue;
            }
            case 0x24: { op_bit( getbyte( getbyte( cpu.pc + 1 ) ) ); break; } 
            case 0x28: { op_pop_pf(); break; } 
            case 0x2c: { op_bit( getbyte( getword( cpu.pc + 1 ) ) ); break; } 
            case 0x38: { cpu.fCarry = true; break; } 
            case 0x40: 
            {
                op_pop_pf();
                cpu.pc = pop();
                cpu.pc |= ( ( (uint16_t) pop() ) << 8 );
                continue;
            }
            case 0x48: { push( cpu.a ); break; } 
            case 0x4c: { cpu.pc = getword( cpu.pc + 1 ); continue; } 
            case 0x58: { cpu.fInterruptDisable = false; break; } 
            case 0x60: 
            {
                _op_rts:
                lo = pop();
                cpu.pc = 1 + ( ( (uint16_t) pop() << 8 ) | lo );
                continue;
            }
            case 0x68: { cpu.a = pop(); set_nz( cpu.a ); break; } 
            case 0x6a: case 0x4a: case 0x2a: case 0x0a: { cpu.a = op_rotate( ( op >> 5 ), cpu.a ); break; } 
            case 0x6c: { cpu.pc = getword( getword( cpu.pc + 1 ) ); continue; } 
            case 0x78: { cpu.fInterruptDisable = true; break; } 
            case 0x81: case 0x84: case 0x85: case 0x86: case 0x8c: case 0x8d: case 0x8e: 
            case 0x91: case 0x94: case 0x95: case 0x96: case 0x99: case 0x9d:
            {
                if ( 0x81 == op )                              
                    address = getword( 0xff & ( getbyte( cpu.pc + 1 ) + cpu.x ) );   
                else if ( 0x91 == op )                         
                {
                    address = getword( getbyte( cpu.pc + 1 ) );
                    address += cpu.y;
                }
                else if ( op >= 0x84 && op <= 0x86 )           
                    address = getbyte( cpu.pc + 1 );
                else if ( op == 0x94 || op == 0x95 )           
                    address = 0xff & ( getbyte( cpu.pc + 1 ) + cpu.x ); 
                else if ( 0x96 == op )                         
                    address = 0xff & ( getbyte( cpu.pc + 1 ) + cpu.y ); 
                else if ( 0x99 == op )                         
                    address = getword( cpu.pc + 1 ) + cpu.y;             
                else if ( op >= 0x8c && op <= 0x8e )           
                    address = getword( cpu.pc + 1 );                 
                else if ( 0x9d == op )                         
                    address = getword( cpu.pc + 1 ) + cpu.x;             
                else
                    m_hard_exit( "mos6502 unsupported store instruction %02x\n", op );

                setbyte( address, ( op & 1 ) ? cpu.a : ( op & 2 ) ? cpu.x : cpu.y );
                
                if ( 0xd012 == address )   
                    m_store( address );
                break;
            }
            case 0x88: { cpu.y--; set_nz( cpu.y ); break; } 
            case 0x8a: { cpu.a = cpu.x; set_nz( cpu.a ); break; } 
            case 0x98: { cpu.a = cpu.y; set_nz( cpu.a ); break; } 
            case 0x9a: { cpu.sp = cpu.x; break; } 
            case 0xa0: case 0xa1: case 0xa2: case 0xa4: case 0xa5: case 0xa6: case 0xa9: case 0xac: case 0xad: case 0xae: 
            case 0xb1: case 0xb4: case 0xb5: case 0xb6: case 0xb9: case 0xbc: case 0xbd: case 0xbe: 
            {
                lo = ( op & 0x0f );
                if ( ( 0xa0 == ( op & 0xf0 ) ) && ( 0 == lo || 2 == lo || 9 == lo ) ) 
                    address = cpu.pc + 1;                          
                else if ( op == 0xa1 )                                     
                    address = getword( 0xff & ( getbyte( cpu.pc + 1 ) + cpu.x ) );    
                else if ( op == 0xb1 )                                     
                {
                    val = getbyte( cpu.pc + 1 );
                    address = getword( (uint16_t) val );
                    address += cpu.y;
                }
                else if ( op >= 0xa4 && op <= 0xa6 )               
                    address = getbyte( cpu.pc + 1 );
                else if ( 0xb4 == op || 0xb5 == op )               
                    address = 0xff & ( getbyte( cpu.pc + 1 ) + cpu.x );     
                else if ( 0xb6 == op )                             
                    address = 0xff & ( getbyte( cpu.pc + 1 ) + cpu.y );     
                else if ( op >= 0xac && op <= 0xae )               
                    address = getword( cpu.pc + 1 );                 
                else if ( 0xbc == op || 0xbd == op )               
                    address = getword( cpu.pc + 1 ) + cpu.x;             
                else if ( 0xb9 == op || 0xbe == op )               
                    address = getword( cpu.pc + 1 ) + cpu.y;             
                else
                    m_hard_exit( "mos6502 unsupported load instruction opcode %02x\n", op );
                
                if ( address >= 0xd010 && address <= 0xd012 ) 
                    setbyte( address, m_load( address ) );
    
                val = getbyte( address );
                set_nz( val );
        
                if ( op & 1 )
                    cpu.a = val;
                else if ( op & 2 )
                    cpu.x = val;
                else
                    cpu.y = val;
                break;
            }
            case 0xa8: { cpu.y = cpu.a; set_nz( cpu.y ); break; } 
            case 0xaa: { cpu.x = cpu.a; set_nz( cpu.x ); break; } 
            case 0xb8: { cpu.fOverflow = false; break; } 
            case 0xba: { cpu.x = cpu.sp; set_nz( cpu.x ); break; } 
            case 0xc0: { op_cmp( cpu.y, getbyte( cpu.pc + 1 ) ); break; } 
            case 0xc4: { op_cmp( cpu.y, getbyte( getbyte( cpu.pc + 1 ) ) ); break; } 
            case 0xc6: case 0xce: case 0xd6: case 0xde: case 0xe6: case 0xee: case 0xf6: case 0xfe:  
            {
                if ( 6 == ( op & 0xf ) )
                    address = getbyte( cpu.pc + 1 );
                else
                    address = getword( cpu.pc + 1 );
        
                if ( op & 0x10 )
                    address += cpu.x;

                val = getbyte( address );
                if ( op >= 0xe6 )
                    val++;
                else
                    val--;

                setbyte( address, val );
                set_nz( val );
                break;
            }
            case 0xc8: { cpu.y++; set_nz( cpu.y ); break; } 
            case 0xca: { cpu.x--; set_nz( cpu.x ); break; } 
            case 0xcc: { op_cmp( cpu.y, getbyte( getword( cpu.pc + 1 ) ) ); break; } 
            case 0xd8: { cpu.fDecimal = false; break; } 
            case 0xe0: { op_cmp( cpu.x, getbyte( cpu.pc + 1 ) ); break; } 
            case 0xe4: { op_cmp( cpu.x, getbyte( getbyte( cpu.pc + 1 ) ) ); break; } 
            case 0xe8: { cpu.x++; set_nz( cpu.x ); break; } 
            case 0xea: { break; } 
            case 0xec: { op_cmp( cpu.x, getbyte( getword( cpu.pc + 1 ) ) ); break; } 
            case 0xf8: { cpu.fDecimal = true; break; } 
            case 0xff: { m_halt(); goto _all_done; } 
            default: m_hard_exit( "mos6502 unimplemented instruction opcode %02x\n", op );
        }

        cpu.pc += ins_len_6502[ op ];
        goto _top_of_loop; /* old compilers generate code to check if while( true ) is in fact true */
    } while( true );

_all_done:
    return;
}

