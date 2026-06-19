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
    mov x20, #0          ; fresh available ID count
    mov x21, #0          ; parsed range count
    mov x22, #0          ; current parsed number
    mov x23, #0          ; range start
    mov x24, #0          ; parser section: 0 ranges, 1 IDs
    mov x26, #0          ; have digits on current line
    mov x27, #0          ; parsing range end when nonzero
    mov x28, #0          ; current line length

read_chunk:
    mov x0, x19
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.lt read_done
    b.eq read_done

    mov x14, x0
    adrp x15, buffer@PAGE
    add x15, x15, buffer@PAGEOFF

parse_byte:
    cbz x14, read_chunk
    ldrb w0, [x15], #1
    sub x14, x14, #1

    cmp w0, #'0'
    b.lt not_digit
    cmp w0, #'9'
    b.gt not_digit

    sub w0, w0, #'0'
    mov x1, #10
    madd x22, x22, x1, x0
    mov x26, #1
    add x28, x28, #1
    b parse_byte

not_digit:
    cmp w0, #'-'
    b.eq got_dash
    cmp w0, #10
    b.eq got_newline
    b parse_byte

got_dash:
    mov x23, x22
    mov x22, #0
    mov x27, #1
    add x28, x28, #1
    b parse_byte

got_newline:
    cbz x28, blank_line
    cbz x24, finish_range_line
    cbz x26, reset_line
    bl process_id
    b reset_line

blank_line:
    mov x24, #1
    b reset_line

finish_range_line:
    cbz x26, reset_line
    cbz x27, reset_line
    bl store_range

reset_line:
    mov x22, #0
    mov x23, #0
    mov x26, #0
    mov x27, #0
    mov x28, #0
    b parse_byte

read_done:
    cbz x28, close_file
    cbz x24, finish_final_range
    cbz x26, close_file
    bl process_id
    b close_file

finish_final_range:
    cbz x26, close_file
    cbz x27, close_file
    bl store_range

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
    mov x2, #27
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

store_range:
    adrp x9, range_starts@PAGE
    add x9, x9, range_starts@PAGEOFF
    str x23, [x9, x21, lsl #3]

    adrp x9, range_ends@PAGE
    add x9, x9, range_ends@PAGEOFF
    str x22, [x9, x21, lsl #3]

    add x21, x21, #1
    ret

process_id:
    adrp x9, range_starts@PAGE
    add x9, x9, range_starts@PAGEOFF
    adrp x10, range_ends@PAGE
    add x10, x10, range_ends@PAGEOFF
    mov x11, #0

range_loop:
    cmp x11, x21
    b.ge id_done

    ldr x12, [x9, x11, lsl #3]
    cmp x22, x12
    b.lt next_range

    ldr x12, [x10, x11, lsl #3]
    cmp x22, x12
    b.le id_fresh

next_range:
    add x11, x11, #1
    b range_loop

id_fresh:
    add x20, x20, #1

id_done:
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
    .asciz "input_5.txt"
open_error:
    .asciz "failed to open input_5.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
range_starts:
    .space 2048
range_ends:
    .space 2048
