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
    mov x20, #50         ; current dial position
    mov x21, #0          ; count of clicks landing on 0
    mov x22, #0          ; current direction
    mov x23, #0          ; current distance
    mov x26, #0          ; pending rotation flag

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

    cmp w0, #'L'
    b.eq got_direction
    cmp w0, #'R'
    b.eq got_direction
    cmp w0, #'0'
    b.lt maybe_end_line
    cmp w0, #'9'
    b.gt maybe_end_line

    sub w0, w0, #'0'
    mov x1, #10
    madd x23, x23, x1, x0
    mov x26, #1
    b parse_byte

got_direction:
    mov x22, x0
    mov x23, #0
    mov x26, #1
    b parse_byte

maybe_end_line:
    cmp w0, #10
    b.ne parse_byte
    cbz x26, parse_byte
    bl apply_rotation
    mov x26, #0
    b parse_byte

read_done:
    cbz x26, close_file
    bl apply_rotation

close_file:
    mov x0, x19
    bl _close

    mov x0, x21
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

apply_rotation:
    cmp x22, #'R'
    b.eq count_right

    cbz x20, left_from_zero
    mov x0, x20
    b count_hits

left_from_zero:
    mov x0, #100
    b count_hits

count_right:
    cbz x20, right_from_zero
    mov x0, #100
    sub x0, x0, x20
    b count_hits

right_from_zero:
    mov x0, #100

count_hits:
    cmp x23, x0
    b.lt update_position
    sub x1, x23, x0
    mov x2, #100
    udiv x1, x1, x2
    add x1, x1, #1
    add x21, x21, x1

update_position:
    cmp x22, #'R'
    b.eq rotate_right

    sub x20, x20, x23
    b reduce_position

rotate_right:
    add x20, x20, x23

reduce_position:
    mov x0, #100
    sdiv x1, x20, x0
    msub x20, x1, x0, x20
    cmp x20, #0
    b.ge check_zero
    add x20, x20, #100

check_zero:
rotation_done:
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
    .asciz "input_1.txt"
open_error:
    .asciz "failed to open input_1.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
