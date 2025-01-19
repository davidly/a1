; these two are defined in m6502.c
global _bad_address
global _mem_base
global _cpu

psect text

; in C:
;    uint8_t * get_mem( address ) uint16_t address;
;    {
;        uint8_t * base;
;        base = mem_base[ address >> 12 ];
;        if ( 0 == base )
;            bad_address( address );
;        return base + address;
;    }

global _get_mem
_get_mem:
    push     ix                 ; save ix for the caller
    ld       ix, 4
    add      ix, sp             ; the local variable is pointed to by ix
    ld       a, (ix + 1)        ; use the top nibble to index into _mem_base
    rrca
    rrca
    rrca                        ; shift just 3 times because array entries are 2 bytes long
    and      30
    ld       l, a
    ld       h, 0
    ld       de, _mem_base
    add      hl, de             ; hl now points to the array entry
    ld       e, (hl)
    inc      hl
    ld       d, (hl)            ; de now has the array entry value
    ld       l, (ix)            ; load the address argument
    ld       h, (ix + 1)
    ld       a, d               ; is the array entry 0?
    or       e
    jp       nz, _good_address  ; but only if it's valid
    push     hl
    call     _bad_address       ; never going back
  _good_address:
    add      hl, de             ; add array entry to address argument
    pop      ix
    ret

; in C:
;    void xset_nz( x ) uint8_t x;
;    {
;        cpu.fNegative = !! ( x & 0x80 );
;        cpu.fZero = !x;
;    }

; using the macro in m6502 is faster than calling this function for HI-SOFT C
; global _set_nz
; _set_nz:
;     push     ix                 ; save ix for the caller
;     ld       ix, 4
;     add      ix, sp             ; the local variable is pointed to by ix
;     ld       a, (ix)            ; get x into register a
;     cp       0
;     jp       nz, _nz_set_nz
;     ld       (_cpu + 7), a
;     inc      a
;     jp       _exit_set_nz
;   _nz_set_nz:
;     and      128
;     jp       z, _pos_set_nz
;     inc      a
;   _pos_set_nz:
;     ld       (_cpu + 7), a
;     xor      a
;   _exit_set_nz:
;     ld       (_cpu + 11), a
;     pop      ix
;     ret

