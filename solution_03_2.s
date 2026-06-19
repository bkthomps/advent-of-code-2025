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

    adrp x0, input_path@PAGE
    add x0, x0, input_path@PAGEOFF
    mov x1, #0
    bl _open
    cmp x0, #0
    b.lt open_failed

    mov x19, x0          ; file descriptor
    mov x20, #0          ; total joltage
    mov x21, #0          ; selected digit counts available, capped at 12
    mov x26, #0          ; line has digits

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
    b.lt maybe_newline
    cmp w0, #'9'
    b.gt maybe_newline

    sub w0, w0, #'0'
    mov x26, #1
    bl process_digit
    b parse_byte

maybe_newline:
    cmp w0, #10
    b.ne parse_byte
    cbz x26, parse_byte
    bl finish_line
    b parse_byte

read_done:
    cbz x26, close_file
    bl finish_line

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
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

finish_line:
    adrp x9, dp@PAGE
    add x9, x9, dp@PAGEOFF
    ldr x10, [x9, #96]
    add x20, x20, x10
    mov x10, #0
    mov x11, #1

clear_dp_loop:
    str x10, [x9, x11, lsl #3]
    add x11, x11, #1
    cmp x11, #13
    b.lt clear_dp_loop

    mov x21, #0
    mov x26, #0
    ret

process_digit:
    mov x8, x0
    add x10, x21, #1
    cmp x10, #12
    b.le have_limit
    mov x10, #12

have_limit:
    adrp x9, dp@PAGE
    add x9, x9, dp@PAGEOFF
    mov x11, #10

dp_loop:
    sub x12, x10, #1
    ldr x13, [x9, x12, lsl #3]
    madd x13, x13, x11, x8
    ldr x14, [x9, x10, lsl #3]
    cmp x13, x14
    b.le next_dp
    str x13, [x9, x10, lsl #3]

next_dp:
    subs x10, x10, #1
    b.ne dp_loop

    cmp x21, #12
    b.ge digit_done
    add x21, x21, #1

digit_done:
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
    .asciz "input_03.txt"
open_error:
    .asciz "failed to open input_03.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
dp:
    .space 104
