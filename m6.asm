; n.b. This file was originally m6502.c by Aztec C v1.06.
; Then it had many hand-edit optimizations (mostly deletes).
; It can't be recreated with a compiler without losing edits.
; Uncomment debugging lines to get instruction tracing printed to stdout.
;
; struct MOS_6502
; {
;     uint8_t a, x, y, sp;
;     uint16_t pc;
;     uint8_t pf;   /* NV-BDIZC. State is tracked in bools below and only updated for pf and php */
;     bool fNegative, fOverflow, fDecimal, fInterruptDisable, fZero, fCarry;
; };

    extrn   .begin,.chl,.swt
    extrn   csave,cret,.move

;/*
;   6502 emulator targeted at an 8080 running CP/M 2.2.
;   Written by David Lee
;*/
;struct MOS_6502 cpu;
        global  cpu_,13

.cpu.a equ cpu_ + 0
.cpu.x equ cpu_ + 1
.cpu.y equ cpu_ + 2
.cpu.sp equ cpu_ + 3
.cpu.pc equ cpu_ + 4
.cpu.pf equ cpu_ + 6
.cpu.fNegative equ cpu_ + 7
.cpu.fOverflow equ cpu_ + 8
.cpu.fDecimal equ cpu_ + 9
.cpu.fInterruptDisable equ cpu_ + 10
.cpu.fZero equ cpu_ + 11
.cpu.fCarry equ cpu_ + 12

;static uint8_t g_State = 0;
    DSEG
g_State_:
        DB 0
    CSEG
;
;#define stateEndEmulation 2
;#define stateSoftReset 4
;
;void end_emulation() { g_State |= stateEndEmulation; }
        PUBLIC end_emul_
end_emul_:
        lda g_State_
        ori 2
        sta g_State_
        ret

;void soft_reset() { g_State |= stateSoftReset; }
        PUBLIC soft_res_
soft_res_:
        lda g_State_
        ori 4
        sta g_State_
        ret

; make m_0000 as large as fits on your CP/M machine. Then update mem_base.
;static uint8_t m_0000[ 0x8000 ];
        bss     m_0000_,32768
;uint8_t * mem_base[ 16 ] =
        DSEG
        public  mem_base_
mem_base_:
;{
        DW m_0000_          ; 0000
        DW m_0000_          ; 1000
        DW m_0000_          ; 2000
        DW m_0000_          ; 3000
        DW m_0000_          ; 4000
        DW m_0000_          ; 5000
        DW m_0000_          ; 6000
        DW m_0000_          ; 7000
        DW 0                ; 8000
        DW 0                ; 9000
        DW 0                ; a000
        DW 0                ; b000
        DW 0                ; c000
        DW m_d000_ - 0d000h ; d000
        DW m_e000_ - 0e000h ; e000
        DW m_ff00_ - 0ff00h ; f000  ; f000-ff00 not handled
        CSEG
;
;void bad_address( address ) uint16_t address;
        PUBLIC bad_addr_
bad_addr_:
;{
;    printf( "the apple 1 app referenced the invalid address %04x\n", address );
        lxi h, 2
        dad sp
        mov e, m
        inx h
        mov d, m
        push d
        lxi h, .bad_addr_err
        push h
        call printf_
        pop d
        pop d
;    exit( 1 );
        jmp exit_  ; cp/m apps don't have exit codes. exit doesn't return

; in C:
;    uint8_t * get_mem( address ) uint16_t address;
;    {
;        uint8_t * base;
;        base = mem_base[ address >> 12 ];
;        if ( 0 == base )
;            bad_address( address );
;        return base + address;
;    }
; this version has address on the stack and is called from a1.c
        PUBLIC get_mem_
get_mem_:
        lxi h, 3
        dad sp
        mov a, m           ; use the top nibble
        rrc
        rrc
        rrc
        ani 1eh            ; just shift 3 times and mask
        mov l, a
        mvi h, 0
        lxi d, mem_base_
        dad d              ; hl now points to the array entry
        mov e, m
        inx h
        mov d, m           ; DE now has the array entry (base)
        mov a, d
        ora e              ; if DE is 0, it's a bad address
        jz bad_address_    ; jmp not call
        lxi h, 2
        dad sp
        mov a, m
        inx h
        mov h, m
        mov l, a           ; hl now has address
        dad d              ; hl now has base + address
        ret

; this version has address in HL and is called from this file
        PUBLIC get_hmem_
get_hmem_:
        push h
        mov a, h           ; use the top nibble
        rrc
        rrc
        rrc
        ani 1eh            ; just shift 3 times and mask
        mov l, a
        mvi h, 0
        lxi d, mem_base_
        dad d              ; hl now points to the array entry
        mov e, m
        inx h
        mov d, m           ; DE now has the array entry (base)
;        mov a, d           ; these 3 instructions take 5% of app runtime. worth it?
;        ora e              ; if DE is 0, it's a bad address
;        cz bad_address_    ; call not jmp; address is on the stack
        pop h
        dad d              ; hl now has base + address
        ret

; in C:
;    void set_nz( x ) uint8_t x;
;    {
;        cpu.fNegative = !! ( x & 0x80 );
;        cpu.fZero = !x;
;    }
; except that x is passed in the a register, not on the stack
        PUBLIC aset_nz_
aset_nz_:
        cpi 0
        jnz _anz_set
        sta .cpu.fNegative  ; set negative flag to false
        inr a             
        sta .cpu.fZero      ; set zero flag to true
        ret
  _anz_set:
        ani 128
        jz _anz_pos
        inr a
  _anz_pos:
        sta .cpu.fNegative  ; set negative flag
        xra a
        sta .cpu.fZero      ; set zero flag to false
        ret

;void power_on()
;{
        PUBLIC power_on_
power_on_:
;    cpu.pc = get_word( 0xfffc );
        lxi h, 0fffch
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        shld .cpu.pc
;    cpu.fInterruptDisable = true;
        mvi a, 1
        sta .cpu.fInterruptDisable
;}
        ret

;static uint8_t ins_len_6502[ 256 ] =
    DSEG
ins_len__:
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; 00
    DB 1, 2, 1, 0, 0, 3, 3, 1  ; 08
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; 10
    DB 1, 3, 0, 0, 0, 3, 3, 0  ; 18
    DB 3, 2, 0, 0, 2, 2, 2, 0  ; 20
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; 28
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; 30
    DB 1, 3, 0, 0, 0, 3, 3, 0  ; 38
    DB 1, 2, 0, 0, 0, 2, 2, 0  ; 40
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; 48
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; 50
    DB 1, 3, 0, 0, 0, 3, 3, 0  ; 58
    DB 1, 2, 0, 0, 0, 2, 2, 0  ; 60
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; 68
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; 70
    DB 1, 3, 0, 0, 0, 3, 3, 0  ; 78
    DB 0, 2, 0, 0, 2, 2, 2, 0  ; 80
    DB 1, 0, 1, 0, 3, 3, 3, 0  ; 88
    DB 2, 2, 0, 0, 2, 2, 2, 0  ; 90
    DB 1, 3, 1, 0, 0, 3, 0, 0  ; 98
    DB 2, 2, 2, 0, 2, 2, 2, 0  ; a0
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; a8
    DB 2, 2, 0, 0, 2, 2, 2, 0  ; b0
    DB 1, 3, 1, 0, 3, 3, 3, 0  ; b8
    DB 2, 2, 0, 0, 2, 2, 2, 0  ; c0
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; c8
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; d0
    DB 1, 3, 0, 0, 0, 3, 3, 0  ; d8
    DB 2, 2, 0, 0, 2, 2, 2, 0  ; e0
    DB 1, 2, 1, 0, 3, 3, 3, 0  ; e8
    DB 2, 2, 0, 0, 0, 2, 2, 0  ; f0
    DB 1, 3, 0, 0, 0, 3, 3, 1  ; f8

    CSEG

;uint8_t op_brotate( op, val ) uint8_t op; uint8_t val;
; op is in c and val is in b. return value is in a
        PUBLIC op_brotate
op_brotate:
;{
;
;    rotate = op >> 5;
        mov a, c
        rrc
        rrc
        rrc
        rrc
        rrc
        ani 7
;    if ( 0 == rotate ) /* asl */        
;    {
        cpi 0
        jnz .rot_rol
;        cpu.fCarry = !! ( 0x80 & val );
        mov a, b
        ani 80h
        mvi a, 0
        jz .r0_a
        inr a
  .r0_a
        sta .cpu.fCarry
;        val <<= 1;
        mov a, b
        ral
        ani 0feh
        jmp .rot_end
;    }
;    else if ( 1 == rotate ) /* rol */   
.rot_rol
;    {
        cpi 1
        jnz .rot_lsr
;        oldCarry = cpu.fCarry;
        lda .cpu.fCarry
        mov e, a
;        cpu.fCarry = !! ( 0x80 & val );
        mov a, b
        ani 80h
        mvi a, 0
        jz .r1_a
        inr a
  .r1_a
        sta .cpu.fCarry
;        val <<= 1;
        mov a, b
        ral
;        if ( oldCarry )
;            val |= 1;
        mov b, a
        mov a, e
        ora a
        mov a, b
        jnz .r1_zero
        ani 0feh
        jmp .rot_end
  .r1_zero:
        ori 1
        jmp .rot_end
;    }
;    else if ( 2 == rotate ) /* lsr */   
.rot_lsr
;    {
        cpi 2
        jnz .rot_ror
;        cpu.fCarry = ( val & 1 );
        mov a, b
        ani 1
        sta .cpu.fCarry
;        val >>= 1;
        mov a, b
        rar
        ani 7fh
        jmp .rot_end
;    }
;    else /* ror */
.rot_ror:
;    {
;        oldCarry = cpu.fCarry;
        LDA .cpu.fCarry
        mov e, a
;        cpu.fCarry = ( val & 1 );
        mov a, b
        ani 1
        sta .cpu.fCarry
;        val >>= 1;
        mov a, b
        rar
;        if ( oldCarry )
;            val |= 0x80;
        mov b, a
        mov a, e
        ora a
        mov a, b
        jz .r4_zero
        ori 80h
        jmp .rot_end
  .r4_zero:
        ani 7fh
;    }
  .rot_end:
;    set_nz( val );
        mov b, a
        call aset_nz_
;    return val;
        mov a, b
        ret
;}

;void op_bcmp( lhs, rhs ) uint8_t lhs; uint8_t rhs;
; lhs is in a, rhs is in b (not on the stack)
        PUBLIC op_bcmp_
op_bcmp_:
;{
;    uint8_t result;
;    result = (uint8_t) ( (uint16_t) lhs - (uint16_t) rhs );
;    cpu.fCarry = ( lhs >= rhs );
        sub b
        mov b, a
        mvi a, 0
        cmc
        aci 0
        sta .cpu.fCarry
        mov a, b
;    set_nz( result );
        jmp aset_nz_

;void op_bit( val ) uint8_t val;
; the val argument is in the a register
        PUBLIC op_bit_
op_bit_:
;{
;    cpu.fNegative = !! ( val & 0x80 );
        mov e, a
        ani 128
        jz .26
        mvi a, 1
.26:
        sta .cpu.fNegative
;    cpu.fOverflow = !! ( val & 0x40 );
        mov a, e
        ani 64
        jz .28
        mvi a, 1
.28:
        sta .cpu.fOverflow
;    cpu.fZero = ! ( cpu.a & val );
        lda .cpu.a
        ana e
        jz .ob_z
        xra a
        jmp .ob_stz
  .ob_z:
        inr a
  .ob_stz:
        sta .cpu.fZero
        ret

; this compiler-generated implementation is big and slow but rarely gets called,
; so I didn't optimize it much.
;void op_bcd_math( math, rhs ) uint8_t math; uint8_t rhs;
        PUBLIC op_bcd_m_
op_bcd_m_:
        push b
        lxi h, 0
        dad sp
        xchg
        lxi h, .31
        dad sp
        sphl
        push d
;{
;    uint8_t alo, ahi, rlo, rhi, ad, rd, result;
        bss     .32,1
        bss     .33,1
        bss     .34,1
        bss     .35,1
        bss     .36,1
        bss     .37,1
        bss     .38,1
;
;    alo = cpu.a & 0xf;
        LDA .cpu.a
        ani 0fh
        STA .32
;    ahi = cpu.a >> 4;
        LDA .cpu.a
        MOV e, A 
        MVI d, 0
        LXI h, 4
        CALL .ur
        MOV A, L
        STA .33
;    rlo = rhs & 0xf;
        LXI H,8-.31
        DAD SP
        MOV a, M
        ani 15
        STA .34
;    rhi = rhs >> 4;
        LXI H,8-.31
        DAD SP
        MOV E,M
        MVI D,0
        LXI H,4
        CALL .ur
        MOV A,L
        STA .35
;
;    cpu.fZero = false;
        xra a
        STA .cpu.fZero
;
;    if ( alo > 9 || ahi > 9 || rlo > 9 || rhi > 9 )
;        return;
        LDA .32
        cpi 10
        jp .40
        LDA .33
        cpi 10
        jp .40
        LDA .34
        cpi 10
        jp .40
        LDA .35
        cpi 10
        jm .39
.40:
        jmp cret
;
;    ad = ahi * 10 + alo;
.39:
        LDA .32
        MOV L,A
        MVI H,0
        PUSH H
        LDA .33
        MOV L,A
        MVI     H,0
        LXI D,10
        CALL .ml
        POP D
        DAD D
        MOV A,L
        STA .36
;    rd = rhi * 10 + rlo;
        LDA .34
        MOV L,A
        MVI H,0
        PUSH H
        LDA .35
        MOV L,A
        MVI H,0
        LXI D,10
        CALL .ml
        POP D
        DAD D
        MOV A,L
        STA .37
;
;    if ( 7 == math )
;    {
        LXI H,6-.31
        DAD SP
        MOV a,M
        cpi 7
        jne .41
;        if ( !cpu.fCarry )
;            rd += 1;
        lda .cpu.fCarry
        ora a
        JNZ .42
        LXI H,1
        XCHG
        LDA .37
        MOV L,A
        mvi h,0
        DAD D
        MOV A,L
        STA .37
;
;        if ( ad >= rd )
.42:
;        {
        LDA .37
        MOV L,A
        MVI H,0
        PUSH H
        LDA .36
        MOV L,A
        MVI H,0
        POP D
        XCHG
        CALL .uf
        JZ .43
;            result = ad - rd;
        LDA .37
        MOV L,A
        MVI H,0
        PUSH H
        LDA .36
        MOV L,A
        MVI H,0
        POP D
        XCHG
        CALL .sb
        MOV A,L
        STA .38
;            cpu.fCarry = true;
        LXI H,1
        MOV A,L
        STA .cpu.fCarry
;        }
;        else
        JMP .44
.43:
;        {
;            result = 100 + ad - rd;
        LDA .37
        MOV L,A
        MVI H,0
        PUSH H
        LDA .36
        MOV L,A
        MVI     H,0
        LXI D,100
        DAD D
        POP D
        XCHG
        CALL .sb
        MOV A,L
        STA .38
;            cpu.fCarry = false;
        LXI H,0
        MOV A,L
        STA .cpu.fCarry
;        }
.44:
;    }
;    else
        JMP .45
.41:
;    {
;        result = ad + rd + cpu.fCarry;
        LDA .cpu.fCarry
        MOV L,A
        MVI H,0
        PUSH H
        LDA .37
        MOV L,A
        PUSH H
        LDA .36
        MOV L,A
        POP D
        DAD D
        POP D
        DAD D
        MOV A,L
        STA .38
;        if ( result > 99 )
;        {
        LDA .38
        MOV e,A
        MVI d,0
        LXI h,99
        CALL .ug
        JZ .46
;            result -= 100;
        LXI H,100
        LDA .38
        MOV e,A
        mvi d,0
        CALL .sb
        MOV A,L
        STA .38
;            cpu.fCarry = true;
        LXI H,1
        MOV A,L
        STA .cpu.fCarry
;        }
;        else
        JMP .47
.46:
;            cpu.fCarry = false;
        LXI H,0
        MOV A,L
        STA .cpu.fCarry
.47:
;    }
.45:
;
;    cpu.a = ( ( result / 10 ) << 4 ) + ( result % 10 );
        LDA .38
        MOV e,A
        MVI d,0
        LXI h,10
        CALL .um
        PUSH H
        LDA .38
        MOV e,A
        MVI d,0
        LXI h,10
        CALL .ud
        DAD H
        DAD H
        DAD H
        DAD H
        POP D
        DAD D
        MOV A,L
        STA .cpu.a
;}
        jmp cret
.31 EQU 0

;void op_math( op, rhs ) uint8_t op; uint8_t rhs;
; non-standard calling convention: op in c, rhs in b
        PUBLIC op_math_
op_math_:
;{
;    uint16_t res16; 
        bss     .om_res16,2
;    uint8_t result;
        bss     .om_result,1
;    math = op >> 5;
        mov a, c
        rrc
        rrc
        rrc
        rrc
        rrc
        ani 7
        mov e, a  ; math operation is in e
;    if ( 6 == math )
;    {
        cpi 6
        jnz .math_dec
        lda .cpu.a
;        return;
        jmp op_bcmp_ ; returns from op_bcmp
;    }
;    if ( cpu.fDecimal && ( 7 == math || 3 == math ) )
.math_dec:
;    {
        lda .cpu.fDecimal
        ora a
        jz .math_7
        mov a, e
        cpi 7
        jz .math_bcd
        cpi 3
        jnz .math_7
.math_bcd:
;        op_bcd_math( math, rhs );
        mov l, e
        mov e, b
        mvi d, 0
        push d
        mvi h, 0
        push h
        call op_bcd_m_
        pop d
        pop d
;        return;
        ret
;    }
;    if ( 7 == math )
.math_7:
;    {
        mov a, e
        cpi 7
        jnz .math_3
;        rhs = 255 - rhs;
        mvi a, 255
        sub b
        mov b, a
;        math = 3;
        mvi a, 3
        mov e, a
;    }
;    if ( 3 == math )
.math_3:
;    {
        cpi 3
        jnz .math_0
;        res16 = (uint16_t) cpu.a + (uint16_t) rhs + (uint16_t) cpu.fCarry;
        lda .cpu.a
        mov l, a
        mvi h, 0
        mov e, b
        mvi d, 0
        dad d
        lda .cpu.fCarry
        mov e, a
        dad d
        shld .om_res16
;        result = (uint8_t) res16; /* cast generates faster code for Aztec than & 0xff */
        mov a, l
        sta .om_result
;        cpu.fCarry = ( 0 != ( res16 & 0xff00 ) );
        lhld .om_res16
        lxi d, -256
        call .an
        lxi d, 0
        call .ne
        mov a, l
        sta .cpu.fCarry
;        cpu.fOverflow = ( ! ( ( cpu.a ^ rhs ) & 0x80 ) ) && ( ( cpu.a ^ result ) & 0x80 );
        mvi l, 0
        lda .cpu.a
        xra b
        ani 128
        jnz .59
        lda .cpu.a
        mov e, a
        lda .om_result
        xra e
        ani 128
        jz .59
        mvi l, 1
.59:
        mov a, l
        sta .cpu.fOverflow
;        cpu.a = result;
        lda .om_result
        sta .cpu.a
        jmp aset_nz_
;    }
;    else if ( 0 == math )
.math_0:
;        cpu.a |= rhs;
        cpi 0
        jnz .math_1
        lda .cpu.a
        ora b
        sta .cpu.a
        jmp aset_nz_
;    else if ( 1 == math )
.math_1:
;        cpu.a &= rhs;
        cpi 1
        jnz .math_2
        lda .cpu.a
        ana b
        sta .cpu.a
        jmp aset_nz_
;    else if ( 2 == math )
.math_2:
;        cpu.a ^= rhs;
        cpi 2
        rnz
        lda .cpu.a
        xra b
        sta .cpu.a
;    set_nz( cpu.a );
 .math_nz:
        jmp aset_nz_
;}

;void op_pop_pf()
;{
        PUBLIC op_pop_p_
op_pop_p_:
;    cpu.pf = pop();
        lda .cpu.sp
        inr a
        mov l, a
        sta .cpu.sp
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        mov a, m
        sta .cpu.pf
;    cpu.fNegative = !! ( cpu.pf & 0x80 );
        lda .cpu.pf
        ani 80h
        jz .68
        mvi a, 1
.68:
        sta .cpu.fNegative
;    cpu.fOverflow = !! ( cpu.pf & 0x40 );
        lda .cpu.pf
        ani 40h
        jz .70
        mvi a, 1
.70:
        sta .cpu.fOverflow
;    cpu.fDecimal = !! ( cpu.pf & 8 );
        lda .cpu.pf
        ani 8
        jz .72
        mvi a, 1
.72:
        sta .cpu.fDecimal
;    cpu.fInterruptDisable = !! ( cpu.pf & 4 );
        lda .cpu.pf
        ani 4
        jz .74
        mvi a, 1
.74:
        sta .cpu.fInterruptDisable
;    cpu.fZero = !! ( cpu.pf & 2 );
        lda .cpu.pf
        ani 2
        jz .76
        mvi a, 1
.76:
        sta .cpu.fZero
;    cpu.fCarry = ( cpu.pf & 1 ); 
        LDA .cpu.pf
        ani 1
        sta .cpu.fCarry
;}
        ret

;void op_php()
;{
        PUBLIC op_php_
op_php_:
;    cpu.pf = 0x30;
        mvi b, 30h
;    if ( cpu.fNegative ) cpu.pf |= 0x80;
        lda .cpu.fNegative
        ora a
        jz .78
        mov a, b
        ori 80h
        mov b, a
;    if ( cpu.fOverflow ) cpu.pf |= 0x40;
.78:
        lda .cpu.fOverflow
        ora a
        jz .79
        mov a, b
        ori 40h
        mov b, a
;    if ( cpu.fDecimal ) cpu.pf |= 8;
.79:
        lda .cpu.fDecimal
        ora a
        jz .80
        mov a, b
        ori 8
        mov b, a
;    if ( cpu.fInterruptDisable ) cpu.pf |= 4;
.80:
        lda .cpu.fInterruptDisable
        ora a
        jz .81
        mov a, b
        ori 4
        mov b, a
;    if ( cpu.fZero ) cpu.pf |= 2;
.81:
        lda .cpu.fZero
        ora a
        jz .82
        mov a, b
        ori 2
        mov b, a
;    if ( cpu.fCarry ) cpu.pf |= 1;
.82:
        lda .cpu.fCarry
        ora a
        jz .83
        mov a, b
        ori 1
        mov b, a
;    push( cpu.pf );
.83:
        mov a, b
        sta .cpu.pf
        lda .cpu.sp
        mov l, a
        dcr a
        sta .cpu.sp
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        mov m, b
;}
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; debugging
;            bss     ac_flags_,7
;            PUBLIC render_f_
;    render_f_:
;            push b
;            lxi h,0
;            dad sp
;            xchg
;            lxi h, 0
;            dad sp
;            sphl
;            push d
;    ;    ac_flags[ 0 ] = cpu.fNegative ? 'N' : 'n';
;            lda .cpu.fNegative
;            ora a
;            JZ .r85
;            mvi a, 78
;            JMP .r86
;    .r85:
;            mvi a, 110
;    .r86:
;            STA ac_flags_
;    ;    ac_flags[ 1 ] = cpu.fOverflow ? 'V' : 'v';
;            lda .cpu.fOverflow
;            ora a
;            JZ .r87
;            mvi a, 86
;            JMP .r88
;    .r87:
;            mvi a, 118
;    .r88:
;            STA ac_flags_+1
;    ;    ac_flags[ 2 ] = cpu.fDecimal ? 'D' : 'd';
;            lda .cpu.fDecimal
;            ora a
;            JZ .r89
;            mvi a, 68
;            JMP .r90
;    .r89:
;            mvi a, 100
;    .r90:
;            STA ac_flags_+2
;    ;    ac_flags[ 3 ] = cpu.fInterruptDisable ? 'I' : 'i';
;            lda .cpu.fInterruptDisable
;            ora a
;            JZ .r91
;            mvi a, 73
;            JMP .r92
;    .r91:
;            mvi a, 105
;    .r92:
;            STA ac_flags_+3
;    ;    ac_flags[ 4 ] = cpu.fZero ? 'Z' : 'z';
;            lda .cpu.fZero
;            ora a
;            JZ .r93
;            mvi a, 90
;            JMP .r94
;    .r93:
;            mvi a, 122
;    .r94:
;            STA ac_flags_+4
;    ;    ac_flags[ 5 ] = cpu.fCarry ? 'C' : 'c';
;            lda .cpu.fCarry
;            ora a
;            JZ .r95
;            mvi a, 67
;            JMP .r96
;    .r95:
;            mvi a, 99
;    .r96:
;            STA ac_flags_+5
;    ;    ac_flags[ 6 ] = 0;
;            xra a
;            STA ac_flags_+6
;    ;    return ac_flags;
;            LXI H, ac_flags_
;            jmp cret
;    ;}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end debugging

;void emulate()
;{
        PUBLIC emulate_
emulate_:
; enable instruction tracing in ntvcm. 
;     mvi c, 0b9h
;     mvi d, 1
;     call 5

;
;    for (;;)
;    {
;        op = get_byte( cpu.pc );
        lhld .cpu.pc
.gothl_loop          ; assumes hl has cpu.pc
        call get_hmem_
        mov c, m     ; ==> the current opcode is in register c

        ; It's very expensive to always load these even when they're unused,
        ; but it's slower overall to recalculate them for instructions that need them.
        ; ==> op1 is in register e (first byte after the opcode)
        ; ==> op2 is in register d (second byte after the opcode)
        inx h
        mov e, m
        inx h
        mov d, m

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; debugging
;            push b ; preserve register c 
;            push d ; preserve registers d and e
;            CALL render_f_
;            PUSH H
;            LDA .cpu.sp
;            MOV L,A
;            MVI     H,0
;            PUSH H
;            LDA .cpu.y
;            MOV L,A
;            PUSH H
;            LDA .cpu.x
;            MOV L,A
;            PUSH H
;            LDA .cpu.a
;            MOV L,A
;            PUSH H
;            MOV L,c
;            PUSH H
;            LHLD .cpu.pc
;            PUSH H
;            LXI H,.trc_str
;            PUSH H
;            CALL printf_
;            XCHG
;            LXI H,16
;            DAD SP
;            SPHL
;            pop d ; restore registers d and e
;            pop b ; restore register c (the opcode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end debugging

;        switch( op )
        mvi b, 0        ; opcode is in register c
        lxi h, .jump_table
        dad b
        dad b
        mov a, m
        inx h
        mov h, m
        mov l, a
        pchl
;        {
;            case 0x00:                                         
.93:
;                        /* brk */
;            {
;                push_word( cpu.pc + 2 );
        lhld .cpu.pc
        inx h
        inx h
        push h
        lda .cpu.sp
        mov l, a
        dcx h
        mov a, l
        sta .cpu.sp
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        pop d
        mov m, e
        inx h
        mov m, d
        lda .cpu.sp
        dcr a
        sta .cpu.sp
;                op_php(); 
        call op_php_
;                cpu.fInterruptDisable = true;
        mvi a, 1
        sta .cpu.fInterruptDisble
;                cpu.pc = get_word( 0xfffe );
        lxi h, -2
        call get_hmem_
        mov e, m
        inx h
        mov d, m
        xchg
        shld .cpu.pc
;                continue;
        jmp .gothl_loop
;            }
; case 0x01: case 0x21: case 0x41: case 0x61: case 0xc1: case 0xe1: /* ora/and/eor/adc/cmp/sbc (a8, x) */
.94:
.95:
.96:
.97:
.98:
.99:
;            {
;                val = get_byte( cpu.pc + 1 ) + cpu.x; /* reduce
        lda .cpu.x
        add e ; op1 is already in e
;                op_math( op, get_byte( get_word( val ) ) );
        mov l, a
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x05: case 0x25: case 0x45: case 0x65: case 0xc5: case 0xe5: /* ora/and/eor/adc/cmp/sbc a8 */
.100:
.101:
.102:
.103:
.104:
.105:
;            {
;                op_math( op, get_byte( get_byte( cpu.pc + 1 ) )
; );
        mov l, e
        mvi h, 0
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x09: case 0x29: case 0x49: case 0x69: case 0xc9: case 0xe9: /* ora/and/eor/adc/cmp/sbc #d8 */
.106:
.107:
.108:
.109:
.110:
.111:
;            {
;                op_math( op, get_byte( cpu.pc + 1 ) );
        mov b, e
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x0d: case 0x2d: case 0x4d: case 0x6d: case 0xcd: case 0xed: /* ora/and/eor/adc/cmp/sbc a16 */
.112:
.113:
.114:
.115:
.116:
.117:
;            {
;                op_math( op, get_byte( get_word( cpu.pc + 1 ) )
; );
        xchg
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x11: case 0x31: case 0x51: case 0x71: case 0xd1: case 0xf1: /* ora/and/eor/adc/cmp/sbc (a8), y */
.118:
.119:
.120:
.121:
.122:
.123:
;            {
; val = get_byte( cpu.pc + 1 ); /* reduce expression complexity for hisoft c by using local */
        mov l, e
;                op_math( op, get_byte( cpu.y + get_word( val ) ) );
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov d, m
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x15: case 0x35: case 0x55: case 0x75: case 0xd5: case 0xf5: /* ora/and/eor/adc/cmp/sbc a8, x */  
.124:
.125:
.126:
.127:
.128:
.129:
;            {
;                op_math( op, get_byte( (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ) ) );
        lda .cpu.x
        add e
        mov l, a
        mvi h, 0
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x19: case 0x39: case 0x59: case 0x79: case 0xd9: case 0xf9: /* ora/and/eor/adc/cmp/sbc a16, y */
.130:
.131:
.132:
.133:
.134:
.135:
;            {
;                op_math( op, get_byte( get_word( cpu.pc + 1 ) + cpu.y ) );
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x1d: case 0x3d: case 0x5d: case 0x7d: case 0xdd: case 0xfd:
;      /* ora/and/eor/adc/cmp/sbc a16, x */
.136:
.137:
.138:
.139:
.140:
.141:
;            {
;                op_math( op, get_byte( cpu.x + get_word( cpu.pc + 1 ) ) );
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
        call get_hmem_
        mov b, m
        call op_math_
;                break;
        jmp .next_pc
;            }
; case 0x06: case 0x26: case 0x46: case 0x66: { address = get_byte( cpu.pc + 1 ); goto _rot_complete; }
;      /* asl/rol/lsr/ror a8 */
.142:
.143:
.144:
.145:
        mov l, e
        mvi h, 0
        jmp .rot_complete
; case 0x0e: case 0x2e: case 0x4e: case 0x6e: { address = get_word( cpu.pc + 1 ); goto _rot_complete; }
;      /* asl/rol/lsr/ror a16 */
.147:
.148:
.149:
.150:
        xchg
        jmp .rot_complete
; case 0x16: case 0x36: case 0x56: case 0x76: { address = ( cpu.x + get_byte( cpu.pc + 1 ) ); goto _rot_complete; }
;      /* asl/rol/lsr/ror a8, x */
.151:
.152:
.153:
.154:
        mvi d, 0
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
        jmp .rot_complete
; case 0x1e: case 0x3e: case 0x5e: case 0x7e:        /* asl/rol/lsr/ror a16, x */
.155:
.156:
.157:
.158:
;            {
;                address = cpu.x + get_word( cpu.pc + 1 );
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
;_rot_complete:
.rot_complete:
;                pb = get_mem( address ); /* avoid two calls to get_mem */
        call get_hmem_
        push h ; save pb
;                *pb = op_rotate( op, *pb );
        mov b, m
        call op_brotate
        pop h
        mov m, a
;                break;
        jmp .next_pc
;            }
;            case 0x08: { op_php(); break; }                    
.159:
        call op_php_
        jmp .next_pc
;                        /* php */
;            case OP_HOOK:                                      
.160:
;                        /* hook */
;            {
;                op = m_hook();
        call m_hook_
;        mov a, l
;        sta .op
;                if ( 0 != g_State )
;                    goto _gstate_set;
        lda g_State_
        ora a
        jnz .161
;                goto _op_rts;
        jmp .162
;            }                             
; case 0x10: { if ( !cpu.fNegative ) goto _branch_complete; break; } /* bpl */
.163:
        lda .cpu.fNegative
        ora a
        jz .br_complete
        jmp .next_pc
; case 0x30: { if ( cpu.fNegative ) goto _branch_complete; break; }  /* bmi */
.165:
        lda .cpu.fNegative
        ora a
        jnz .br_complete
        jmp .next_pc
; case 0x50: { if ( !cpu.fOverflow ) goto _branch_complete; break; } /* bvc */
.166:
        lda .cpu.fOverflow
        ora a
        jz .br_complete
        jmp .next_pc
; case 0x70: { if ( cpu.fOverflow ) goto _branch_complete; break; }  /* bvs */
.167:
        lda .cpu.fOverflow
        ora a
        jnz .br_complete
        jmp .next_pc
; case 0x90: { if ( !cpu.fCarry ) goto _branch_complete; break; }    /* bcc */
.168:
        lda .cpu.fCarry
        ora a
        jz .br_complete
        jmp .next_pc
; case 0xb0: { if ( cpu.fCarry ) goto _branch_complete; break; }     /* bcs */
.169:
        lda .cpu.fCarry
        ora a
        jnz .br_complete
        jmp .next_pc
; case 0xd0: { if ( !cpu.fZero ) goto _branch_complete; break; }     /* bne */
.170:
        lda .cpu.fZero
        ora a
        jz .br_complete
        jmp .next_pc
; case 0xf0:                                                         /* beq */
.171:
;            {
;                if ( !cpu.fZero )
;                    break;                                     
        lda .cpu.fZero
        ora a
        jz .next_pc
;          
;_branch_complete:
.br_complete:
; /* casting to a larger signed type doesn't sign-extend on Aztec C, so do it manually */
; cpu.pc += ( 2 + sign_extend( get_byte( cpu.pc + 1 ), 7 ) );
        mvi d, 0
        lxi h, 128
        call .xr
        inx h
        inx h
        lxi d, -128
        dad d
        xchg
        lhld .cpu.pc
        dad d
        shld .cpu.pc
;                continue;
        jmp .gothl_loop
;            }
;            case 0x18: { cpu.fCarry = false; break; } /* clc */
.172:
        xra a
        sta .cpu.fCarry
        jmp .next_pc
;            case 0x20: /* jsr a16 */
.173:
;            {
;                push_word( cpu.pc + 2 );
        push d  ; save op1 and op2
        lhld .cpu.pc
        inx h
        inx h
        push h
        lda .cpu.sp
        dcr a
        sta .cpu.sp
        mov l, a
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        pop d
        mov m, e
        inx h
        mov m, d
        dcr a
        sta .cpu.sp
;                cpu.pc = get_word( cpu.pc + 1 );
        pop h ; restore op1 and op2
        shld .cpu.pc
;                continue;
        JMP .gothl_loop
;            }
; case 0x24: { op_bit( get_byte( get_byte( cpu.pc + 1 ) ) ); break; } /* bit a8 NVZ */
.174:
        mov l, e
        mvi h, 0
        call get_hmem_
        mov a, m
        call op_bit_
        jmp .next_pc
;            case 0x28: { op_pop_pf(); break; }                 
.175:
        call op_pop_p_
        jmp .next_pc
;                        /* plp NZCIDV */
; case 0x2c: { op_bit( get_byte( get_word( cpu.pc + 1 ) ) ); break; } /* bit a16 NVZ */
.176:
        xchg
        call get_hmem_
        mov a, m
        call op_bit_
        jmp .next_pc
; case 0x38: { cpu.fCarry = true; break; }                  /* sec */
.177:
        mvi a, 1
        sta .cpu.fCarry
        jmp .next_pc
; case 0x40:                                                /* rti */
.178:
;            {
;                op_pop_pf();
        call op_pop_pf
;                cpu.pc = pop();
;                cpu.pc |= ( ( (uint16_t) pop() ) << 8 );
        lda .cpu.sp
        inr a
        mov l, a
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        mov e, m
        inx h
        mov d, m
        inr a
        sta .cpu.sp
        mov h, d
        mov l, e
        shld .cpu.pc
;                continue;
        jmp .gothl_loop
;            }
; case 0x48: { push( cpu.a ); break; }                      /* pha */
.179:
         lda .cpu.sp
         lxi d, m_0000_+256
         mov l, a
         dcr a
         sta .cpu.sp
         mvi h, 0
         dad d
         lda .cpu.a
         mov m, a
         jmp .next_pc
; case 0x4c: { cpu.pc = get_word( cpu.pc + 1 ); continue; } /* jmp a16 */
.180:
        xchg
        shld .cpu.pc
        jmp .gothl_loop
;            case 0x58: { cpu.fInterruptDisable = false; break; }      /* cli */
.181:
        xra a
        sta .cpu.fInterruptDisable
        jmp .next_pc
;            case 0x60:                                                /* rts */
.182:
;            {
;_op_rts:
.162:
;                cpu.pc = pop();
;                cpu.pc = 1 + ( ( (uint16_t) pop() << 8 ) | cpu.pc );
        lda .cpu.sp
        inr a
        mov l, a
        inr a
        sta .cpu.sp
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        mov e, m
        inx h
        mov h, m
        mov l, e
        inx h
        shld .cpu.pc
;                continue;
        jmp .gothl_loop
;            }
;            case 0x68: { cpu.a = pop(); set_nz( cpu.a ); break; } /* pla NZ */
.183:
        lda .cpu.sp
        inr a
        sta .cpu.sp
        mov l, a
        mvi h, 0
        lxi d, m_0000_+256
        dad d
        mov a, m
        sta .cpu.a
        call aset_nz_
        jmp .next_pc
; case 0x6a: case 0x4a: case 0x2a: case 0x0a: { cpu.a = op_rotate( op, cpu.a ); break; }
;      /* asl, rol, lsr, ror */
.184:
.185:
.186:
.187:
        lda .cpu.a
        mov b, a
        call op_brotate
        sta .cpu.a
        jmp .next_pc
; case 0x6c: { cpu.pc = get_word( get_word( cpu.pc + 1 ) ); continue; } /* jmp (a16) */
.188:
        xchg
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        shld .cpu.pc
        jmp .gothl_loop
; case 0x78: { cpu.fInterruptDisable = true; break; } /* sei */
.189:
        mvi a, 1
        sta .cpu.fInterruptDisable
        jmp .next_pc
; case 0x81: { address = get_word( (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ) ); goto _st_complete; }
;      /* stx (a8, x) */
.190:
        mov l, e
        lda .cpu.x
        mov e, a
        dad d
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        jmp .st_complete
; case 0x84: case 0x85: case 0x86: { address = get_byte( cpu.pc + 1 ); goto _st_complete; }
;      /* sty/sta/stx a8 */
.192:
.193:
.194:
        mov l, e
        mvi h, 0
        jmp .st_complete
; case 0x8c: case 0x8d: case 0x8e: { address = get_word( cpu.pc + 1 ); goto _st_complete; }
;      /* sty/sta/stx a16 */
.195:
.196:
.197:
        xchg
        jmp .st_complete
; case 0x91: { address = cpu.y + get_word( get_byte( cpu.pc + 1 ) ); goto _st_complete; }
;      /* sta (a8), y */
.198:
        mov l, e
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov d, m
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        jmp .st_complete
; case 0x94: case 0x95: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ); goto _st_complete; }
;      /* sta/sty a8, x */
.199:
.200:
        mov l, e
        lda .cpu.x
        add l
        mov l, a
        mvi h, 0
        jmp .st_complete
; case 0x96: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.y ); goto _st_complete; }
;      /* stx a8, y */
.201:
        mov l, e
        lda .cpu.y
        add l
        mov l, a
        mvi h, 0
        jmp .st_complete
; case 0x99: { address = get_word( cpu.pc + 1 ) + cpu.y; goto _st_complete; }
; /* sta a16, y */
.202:
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        jmp .st_complete
; case 0x9d: /* sta a16, x */
.203:
;
;            {
;                address = get_word( cpu.pc + 1 ) + cpu.x;
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
;_st_complete:
.st_complete:
;                set_byte( address, ( op & 1 ) ? cpu.a : ( op & 2 ) ? cpu.x : cpu.y );
        mov a, c
        ani 1
        jz .204
        lda .cpu.a
        mov b, a
        jmp .205
.204:
        mov a, c
        ani 2
        jz .206
        lda .cpu.x
        mov b, a
        jmp .207
.206:
        lda .cpu.y
        mov b, a
.207:
.205:
        push h
        call get_hmem_
        mov m, b
;                if ( 0xd012 == address ) /* apple 1 memory-mapped I/O */
;                    m_store( address );
        pop h
        mov a, h
        cpi 0d0h
        jnz .next_pc
        mov a, l
        cpi 12h
        jnz .next_pc
        push h
        call m_store_
        pop d
;                break;
.208:
        jmp .next_pc
;            }
; case 0x88: { cpu.y--; set_nz( cpu.y ); break; }       /* dey */
.209:
        lda .cpu.y
        dcr a
        sta .cpu.y
        call aset_nz_
        jmp .next_pc
; case 0x8a: { cpu.a = cpu.x; set_nz( cpu.a ); break; } /* txa */
.210:
        lda .cpu.x
        sta .cpu.a
        call aset_nz_
        jmp .next_pc
; case 0x98: { cpu.a = cpu.y; set_nz( cpu.a ); break; } /* tya */
.211:
        lda .cpu.y
        sta .cpu.a
        call aset_nz_
        jmp .next_pc
; case 0x9a: { cpu.sp = cpu.x; break; }                 /* txs no flags set */
.212:
        lda .cpu.x
        sta .cpu.sp
        jmp .next_pc
; case 0xa0: case 0xa2: case 0xa9: { address = cpu.pc + 1; goto _ld_complete; }
;      /* ldy/ldx/lda #d8 */
.213:
.214:
.215:
        lhld .cpu.pc
        inx h
        jmp .ld_complete
; case 0xa1: { address = get_word( (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ) ); goto _ld_complete; }
;      /* lda (a8, x) */
.217:
        mov l, e
        lda .cpu.x
        mov e, a
        dad d
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        jmp .ld_complete
; case 0xa4 : case 0xa5: case  0xa6: { address = get_byte( cpu.pc + 1 ); goto _ld0_complete; }
;      /* ldy/lda/ldx a8 */
.218:
.219:
.220:
        mov l, e
        mvi h, 0
        jmp .ld0_complete
; case 0xac: case 0xad: case 0xae:{ address = get_word( cpu.pc + 1 ); goto _ld_complete; }
;      /* ldy/lda/ldx a16 */
.222:
.223:
.224:
        xchg
        jmp .ld_complete
; case 0xb1: { address = cpu.y + get_word( (uint16_t) get_byte( cpu.pc + 1 ) ); goto _ld_complete; }
;      /* lda (a8), y */
.225:
        mov l, e
        mvi h, 0
        call get_hmem_
        mov e, m
        inx h
        mov d, m
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        jmp .ld_complete
; case 0xb4: case 0xb5: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.x ); goto _ld0_complete; }
;      /* ldy/lda a8, x */
.226:
.227:
        lda .cpu.x
        add e
        mov l, a
        mvi h, 0
        jmp .ld0_complete
; case 0xb6: { address = (uint8_t) ( get_byte( cpu.pc + 1 ) + cpu.y ); goto _ld0_complete; }
;     /* ldx a8, y */
.228:
        lda .cpu.y
        mov l, a
        dad d
        mvi h, 0
        jmp .ld0_complete
; case 0xb9 : case 0xbe: { address = get_word( cpu.pc + 1 ) + cpu.y; goto _ld_complete; }
;      /* lda/ldx a16, y */
.229:
.230:
        lda .cpu.y
        mov l, a
        mvi h, 0
        dad d
        jmp .ld_complete
; case 0xbc: case 0xbd: /* ldy/lda a16, x */
.231:
.232:
;            {
;                address = get_word( cpu.pc + 1 ) + cpu.x;
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
;       
;_ld_complete:   /* load */
.ld_complete:
;                if ( address >= 0xd010 && address <= 0xd012 )
; note: really ony d010 and d011 are required for load
;                        /* apple 1 memory-mapped I/O */
;                {
        mov a, h
        cpi 0d0h
        jnz .ld0_complete

        mov a, l
        cpi 10h
        jz .ld_load
        cpi 11h
        jnz .ld0_complete
 .ld_load:
;                    set_byte( address, m_load( address ) );
        push h
        push h
        call m_load_
        pop d
        mov b, l
        pop h
        push h
        call get_hmem_
        mov m, b
        pop h
;_gstate_set:
.161:
;                    if ( g_State & stateEndEmulation )
;                        goto _all_done;
        lda g_State_
        ani 2
        jnz .all_done
;
;                    if ( g_State & stateSoftReset )
;                    {
        lda g_State_
        ani 4
        jz .ld0_complete
;                        g_State &= ~stateSoftReset;
        lda g_State_
        ani -5
        sta g_State_
;                        cpu.pc = get_word( 0xfffc );
        lxi h, -4
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        shld .cpu.pc
;                        continue;
        jmp .gothl_loop
;                    }
;                }
;
;_ld0_complete:  /* load from page 0 so no need for memory-mapped I/O check */
.ld0_complete:
;                val = get_byte( address );
        call get_hmem_
        mov a, m
        mov b, a
;                set_nz( val );
        call aset_nz_
;        
;                if ( op & 1 )
;                    cpu.a = val;
        mov a, c
        ani 1
        jz .236
        mov a, b
        sta .cpu.a
;                else if ( op & 2 )
        jmp .next_pc
.236:
;                    cpu.x = val;
        mov a, c
        ani 2
        jz .238
        mov a, b
        sta .cpu.x
;                else
        JMP .next_pc
.238:
;                    cpu.y = val;
        mov a, b
        sta .cpu.y
;                break;
        jmp .next_pc
;            }
; case 0xa8: { cpu.y = cpu.a; set_nz( cpu.y ); break; }                      /* tay */
.240:
        lda .cpu.a
        sta .cpu.y
        call aset_nz_
        jmp .next_pc
; case 0xaa: { cpu.x = cpu.a; set_nz( cpu.x ); break; }                      /* tax */
.241:
        lda .cpu.a
        sta .cpu.x
        call aset_nz_
        jmp .next_pc
; case 0xb8: { cpu.fOverflow = false; break; }                               /* clv */
.242:
        xra a
        sta .cpu.fOverflow
        jmp .next_pc
; case 0xba: { cpu.x = cpu.sp; set_nz( cpu.x ); break; }                     /* tsx */
.243:
        lda .cpu.sp
        sta .cpu.x
        call aset_nz_
        jmp .next_pc
; case 0xc0: { op_cmp( cpu.y, get_byte( cpu.pc + 1 ) ); break; }             /* cpy #d8 */
.244:
        mov b, e
        lda .cpu.y
        call op_bcmp_
        jmp .next_pc
; case 0xc4: { op_cmp( cpu.y, get_byte( get_byte( cpu.pc + 1 ) ) ); break; } /* cpy a8 */
.245:
        mov l, e
        mvi h, 0
        call get_hmem_
        mov b, m
        lda .cpu.y
        call op_bcmp_
        jmp .next_pc
; case 0xc6 : case 0xe6: { address = get_byte( cpu.pc + 1 ); goto _crement_complete; } /* inc/dec a8 */
.246:
.247:
        lhld .cpu.pc
        inx h
        call get_hmem_
        mov l, m
        mvi h, 0
        jmp .crement_complete
; case 0xce : case 0xee: { address = get_word( cpu.pc + 1 ); goto _crement_complete; } /* inc/dec a16 */
.249:
.250:
        lhld .cpu.pc
        inx h
        call get_hmem_
        mov e, m
        inx h
        mov h, m
        mov l, e
        jmp .crement_complete
; case 0xd6 : case 0xf6: { address = (uint8_t) ( cpu.x + get_byte( cpu.pc + 1 ) ); goto _crement_complete; }
;      /* inc/dec a8, x */
.251:
.252:
        lhld .cpu.pc
        inx h
        call get_hmem_
        lda .cpu.x
        add m
        mov l, a
        mvi h, 0
        jmp .crement_complete
;
;            case 0xde : case 0xfe: /* inc/dec a16, x */
.253:
.254:
;            {
;                address = cpu.x + get_word( cpu.pc + 1 );
        lda .cpu.x
        mov l, a
        mvi h, 0
        dad d
;_crement_complete:
.crement_complete:
;                pb = get_mem( address );
        call get_hmem_
;                if ( op >= 0xe6 )
;                    (*pb)++;
        mov a, c
        cpi 0e6h
        jm .255
        inr m
        jmp .256
.255:
;                    (*pb)--;
        dcr m
.256:
;                set_nz( *pb );
        mov a, m
        call aset_nz_
;                break;
        jmp .next_pc
;            }
; case 0xc8: { cpu.y++; set_nz( cpu.y ); break; } /* iny */
.257:
        lda .cpu.y
        inr a
        sta .cpu.y
        call aset_nz_
        jmp .next_pc
; case 0xca: { cpu.x--; set_nz( cpu.x ); break; } /* dex */
.258:
        lda .cpu.x
        dcr a
        sta .cpu.x
        call aset_nz_
        jmp .next_pc
; case 0xcc: { op_cmp( cpu.y, get_byte( get_word( cpu.pc + 1 ) ) ); break; } /* cpy a16 */
.259:
        xchg
        call get_hmem_
        mov b, m
        lda .cpu.y
        call op_bcmp_
        jmp .next_pc
; case 0xd8: { cpu.fDecimal = false; break; }                    /* cld */
.260:
        xra a
        sta .cpu.fDecimal
        JMP .next_pc
; case 0xe0: { op_cmp( cpu.x, get_byte( cpu.pc + 1 ) ); break; } /* cpx #d8 */
.261:
        lhld .cpu.pc
        inx h
        call get_hmem_
        mov b, m
        lda .cpu.x
        call op_bcmp_
        jmp .next_pc
; case 0xe4: { op_cmp( cpu.x, get_byte( get_byte( cpu.pc + 1 ) ) ); break; } /* cpx a8 */
.262:
        lhld .cpu.pc
        inx h
        call get_hmem_
        mov l, m
        mvi h, 0
        call get_hmem_
        mov b, m
        lda .cpu.x
        call op_bcmp_
        jmp .next_pc
; case 0xe8: { cpu.x++; set_nz( cpu.x ); break; } /* inx */
.263:
        lda .cpu.x
        inr a
        sta .cpu.x
        call aset_nz_
        jmp .next_pc
;            case 0xea: { break; } /* nop */
.264:
        jmp .next_pc
;
; case 0xec: { op_cmp( cpu.x, get_byte( get_word( cpu.pc + 1 ) ) ); break; } /* cpx a16 */
.265:
        xchg
        call get_hmem_
        mov b, m
        lda .cpu.x
        call op_bcmp_
        jmp .next_pc
; case 0xf8: { cpu.fDecimal = true; break; } /* sed */
.266:
        mvi a, 1
        sta .cpu.fDecimal
        jmp .next_pc
; case 0xff: { m_halt(); goto _all_done; } /* halt */
.267:
        call m_halt_
        jmp .all_done
;            default: m_hard_exit( "unknown mos6502 opcode %02x\n", op );
.268:
        mvi b, 0
        push b
        lxi h, .unk_op
        push h
        call m_hard_e_  ; no coming back from this
;        }
        jmp .next_pc
.next_pc:
;        cpu.pc += ins_len_6502[ op ];
        mvi b, 0
        lxi h, ins_len__
        dad b
        mov c, m
        lhld .cpu.pc
        dad b
        shld .cpu.pc
;    }
        jmp .gothl_loop
.90:
;_all_done:
.all_done:
;    return;
        ret
;}

        DSEG
.jump_table:
        DW  .93,  .94, .268, .268, .268, .100, .142, .268   ; 00
        DW .159, .106, .187, .268, .268, .112, .147, .160   ; 08
        DW .163, .118, .268, .268, .268, .124, .151, .268   ; 10
        DW .172, .130, .268, .268, .268, .136, .155, .268   ; 18
        DW .173,  .95, .268, .268, .174, .101, .143, .268   ; 20
        DW .175, .107, .186, .268, .176, .113, .148, .268   ; 28
        DW .165, .119, .268, .268, .268, .125, .152, .268   ; 30
        DW .177, .131, .268, .268, .268, .137, .156, .268   ; 38
        DW .178,  .96, .268, .268, .268, .102, .144, .268   ; 40
        DW .179, .108, .185, .268, .180, .114, .149, .268   ; 48
        DW .166, .120, .268, .268, .268, .126, .153, .268   ; 50
        DW .181, .132, .268, .268, .268, .138, .157, .268   ; 58
        DW .182,  .97, .268, .268, .268, .103, .145, .268   ; 60
        DW .183, .109, .184, .268, .188, .115, .150, .268   ; 68
        DW .167, .121, .268, .268, .268, .127, .154, .268   ; 70
        DW .189, .133, .268, .268, .268, .139, .158, .268   ; 78
        DW .268, .190, .268, .268, .192, .193, .194, .268   ; 80
        DW .209, .268, .210, .268, .195, .196, .197, .268   ; 88
        DW .168, .198, .268, .268, .199, .200, .201, .268   ; 90
        DW .211, .202, .212, .268, .268, .203, .268, .268   ; 98
        DW .213, .217, .214, .268, .218, .219, .220, .268   ; a0
        DW .240, .215, .241, .268, .222, .223, .224, .268   ; a8
        DW .169, .225, .268, .268, .226, .227, .228, .268   ; b0
        DW .242, .229, .243, .268, .231, .232, .230, .268   ; b8
        DW .244,  .98, .268, .268, .245, .104, .246, .268   ; c0
        DW .257, .110, .258, .268, .259, .116, .249, .268   ; c8
        DW .170, .122, .268, .268, .268, .128, .251, .268   ; d0
        DW .260, .134, .268, .268, .268, .140, .253, .268   ; d8
        DW .261,  .99, .268, .268, .262, .105, .247, .268   ; e0
        DW .263, .111, .264, .268, .265, .117, .250, .268   ; e8
        DW .171, .123, .268, .268, .268, .129, .252, .268   ; f0
        DW .266, .135, .268, .268, .268, .141, .254, .267   ; f8

.unk_op:
        DB 'u', 'n', 'k', 'n', 'o', 'w', 'n', ' ', 'm', 'o', 's', '6', '5', '0', '2'
        DB ' ', 'o', 'p', 'c', 'o', 'd', 'e', ' ', '%', '0', '2', 'x', 10, 0

.bad_addr_err:
        DB 't', 'h', 'e', ' ', 'a', 'p', 'p', 'l', 'e', ' ', '1', ' '
        DB 'a', 'p', 'p', ' ', 'r', 'e', 'f', 'e', 'r', 'e', 'n', 'c', 'e', 'd', ' '
        DB 't', 'h', 'e', ' ', 'i', 'n', 'v', 'a', 'l', 'i', 'd', ' '
        DB 'a', 'd', 'd', 'r', 'e', 's', 's', ' ', '%', '0', '4', 'x', 10, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; debugging
;.trc_str:
;        DB 'p', 'c', ' ', '%', '0', '4', 'x', ',', ' ', 'o', 'p', ' '
;        DB '%', '0', '2', 'x', ',', ' ', 'a', ' ', '%', '0', '2', 'x', ',', ' '
;        DB 'x', ' ', '%', '0', '2', 'x', ',', ' ', 'y', ' ', '%', '0', '2', 'x', ',', ' '
;        DB 's', 'p', ' ', '%', '0', '2', 'x', ',', ' ', '%', 's', 10, 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end debugging

        extrn   exit_
        extrn   printf_
        extrn   m_hard_e_
        extrn   m_store_
        extrn   m_load_
        extrn   m_hook_
        extrn   m_halt_
        extrn   get_mem_
        extrn   m_ff00_
        extrn   m_e000_
        extrn   m_d000_
        extrn   .xr
        extrn   .an
        extrn   .eq
        extrn   .ne
        extrn   .ug
        extrn   .uf
        extrn   .ur
        extrn   .sb
        extrn   .ml
        extrn   .ud
        extrn   .um
        END
