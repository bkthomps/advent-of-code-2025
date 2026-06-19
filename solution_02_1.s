.section __TEXT,__text,regular,pure_instructions
.build_version macos, 11, 0
.globl _main
.p2align 2

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    adrp x0, input_path@PAGE
    add x0, x0, input_path@PAGEOFF
    mov x1, #0
    bl _open
    cmp x0, #0
    b.lt open_failed

    mov x19, x0          ; file descriptor
    mov x20, #0          ; sum of invalid product IDs
    mov x21, #0          ; current range start
    mov x22, #0          ; current parsed number
    mov x23, #0          ; parsing end value when nonzero
    mov x26, #0          ; have pending number

read_chunk:
    mov x0, x19
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.lt read_done
    b.eq read_done

    mov x24, x0
    adrp x25, buffer@PAGE
    add x25, x25, buffer@PAGEOFF

parse_byte:
    cbz x24, read_chunk
    ldrb w0, [x25], #1
    sub x24, x24, #1

    cmp w0, #'0'
    b.lt not_digit
    cmp w0, #'9'
    b.gt not_digit

    sub w0, w0, #'0'
    mov x1, #10
    madd x22, x22, x1, x0
    mov x26, #1
    b parse_byte

not_digit:
    cmp w0, #'-'
    b.eq got_dash
    cmp w0, #','
    b.eq got_range_end
    cmp w0, #10
    b.eq got_range_end
    b parse_byte

got_dash:
    mov x21, x22
    mov x22, #0
    mov x23, #1
    b parse_byte

got_range_end:
    cbz x26, parse_byte
    cbz x23, parse_byte
    bl process_range
    mov x22, #0
    mov x23, #0
    mov x26, #0
    b parse_byte

read_done:
    cbz x26, close_file
    cbz x23, close_file
    bl process_range

close_file:
    mov x0, x19
    bl _close

    mov x0, x20
    bl print_uint_newline

    mov w0, #0
    b finish

open_failed:
    mov x0, #2
    adrp x1, open_error@PAGE
    add x1, x1, open_error@PAGEOFF
    mov x2, #28
    bl _write
    mov w0, #1

finish:
    ldp x27, x28, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

process_range:
    mov x9, #1           ; half-length lower bound: 1, 10, 100, ...
    mov x10, #10         ; half-length upper bound
    mov x15, #5          ; check repeated IDs with 2, 4, 6, 8, and 10 digits

length_loop:
    add x11, x10, #1     ; multiplier: 11, 101, 1001, ...
    mov x12, x9          ; prefix

prefix_loop:
    mul x13, x12, x11    ; repeated-half candidate
    cmp x13, x21
    b.lt next_prefix
    cmp x13, x22
    b.gt next_length
    add x20, x20, x13

next_prefix:
    add x12, x12, #1
    cmp x12, x10
    b.lt prefix_loop

next_length:
    mov x9, x10
    mov x14, #10
    mul x10, x10, x14
    subs x15, x15, #1
    b.ne length_loop

    ret

print_uint_newline:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adrp x9, outbuf@PAGE
    add x9, x9, outbuf@PAGEOFF
    add x9, x9, #31
    mov w10, #10
    strb w10, [x9]
    mov x11, #1
    mov x12, x0
    mov x13, #10

    cbnz x12, convert_loop
    mov w10, #'0'
    sub x9, x9, #1
    strb w10, [x9]
    add x11, x11, #1
    b write_number

convert_loop:
    udiv x14, x12, x13
    msub x15, x14, x13, x12
    add w15, w15, #'0'
    sub x9, x9, #1
    strb w15, [x9]
    add x11, x11, #1
    mov x12, x14
    cbnz x12, convert_loop

write_number:
    mov x0, #1
    mov x1, x9
    mov x2, x11
    bl _write

    ldp x29, x30, [sp], #16
    ret

.section __TEXT,__cstring,cstring_literals
input_path:
    .asciz "input_02.txt"
open_error:
    .asciz "failed to open input_02.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
