; in C:
;    uint8_t * get_mem( address ) uint16_t address;
;    {
;        uint8_t * base;
;        base = mem_base[ address >> 12 ];
;        if ( 0 == ( (uint16_t) base & 0xff00 ) )
;            bad_address( address );
;        return base + address;
;    }

; these two are defined in m6502.c
global _bad_address
global _mem_base

psect text
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
    xor      a
    or       d
    jp       nz, _good_address  ; but only if it's valid
    push     hl
    call     _bad_address	; never going back
  _good_address:
    add      hl, de             ; add array entry to address argument
    pop      ix
    ret

