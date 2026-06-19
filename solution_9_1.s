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
    mov x20, #0          ; point count
    mov x21, #0          ; current number
    mov x22, #0          ; coordinate index on line
    mov x23, #0          ; have digits

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
    madd x21, x21, x1, x0
    mov x23, #1
    b parse_byte

not_digit:
    cmp w0, #','
    b.eq store_coord
    cmp w0, #10
    b.eq end_line
    b parse_byte

store_coord:
    bl save_coord
    add x22, x22, #1
    mov x21, #0
    mov x23, #0
    b parse_byte

end_line:
    cbz x23, parse_byte
    bl save_coord
    add x20, x20, #1
    mov x21, #0
    mov x22, #0
    mov x23, #0
    b parse_byte

read_done:
    cbz x23, close_file
    bl save_coord
    add x20, x20, #1

close_file:
    mov x0, x19
    bl _close

    bl find_max_area
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
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

save_coord:
    cbnz x22, save_y
    adrp x9, xs@PAGE
    add x9, x9, xs@PAGEOFF
    str x21, [x9, x20, lsl #3]
    ret

save_y:
    adrp x9, ys@PAGE
    add x9, x9, ys@PAGEOFF
    str x21, [x9, x20, lsl #3]
    ret

find_max_area:
    adrp x23, xs@PAGE
    add x23, x23, xs@PAGEOFF
    adrp x24, ys@PAGE
    add x24, x24, ys@PAGEOFF

    mov x0, #0           ; max area
    mov x21, #0          ; i

outer_loop:
    cmp x21, x20
    b.ge area_done
    add x22, x21, #1     ; j

inner_loop:
    cmp x22, x20
    b.ge next_i

    ldr x9, [x23, x21, lsl #3]
    ldr x10, [x23, x22, lsl #3]
    subs x11, x9, x10
    b.ge dx_positive
    neg x11, x11

dx_positive:
    add x11, x11, #1

    ldr x9, [x24, x21, lsl #3]
    ldr x10, [x24, x22, lsl #3]
    subs x12, x9, x10
    b.ge dy_positive
    neg x12, x12

dy_positive:
    add x12, x12, #1
    mul x13, x11, x12
    cmp x13, x0
    b.le next_j
    mov x0, x13

next_j:
    add x22, x22, #1
    b inner_loop

next_i:
    add x21, x21, #1
    b outer_loop

area_done:
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
    .asciz "input_9.txt"
open_error:
    .asciz "failed to open input_9.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
xs:
    .space 8192
ys:
    .space 8192
