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
    mov x20, #0          ; fitting region count
    mov x21, #0          ; current parsed number
    mov x22, #0          ; have parsed number
    mov x23, #0          ; line type: 0 unknown, 1 shape header, 2 region, 3 shape grid
    mov x24, #-1         ; current shape index
    mov x25, #0          ; region width
    mov x26, #0          ; region height
    mov x27, #0          ; region count index
    mov x28, #0          ; required area total

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
    madd x21, x21, x1, x0
    mov x22, #1
    b parse_byte

not_digit:
    cmp w0, #'#'
    b.eq got_hash
    cmp w0, #'.'
    b.eq got_dot
    cmp w0, #'x'
    b.eq got_x
    cmp w0, #':'
    b.eq got_colon
    cmp w0, #' '
    b.eq got_space
    cmp w0, #10
    b.eq got_newline
    b parse_byte

got_hash:
    mov x23, #3
    cmp x24, #0
    b.lt parse_byte
    adrp x1, shape_areas@PAGE
    add x1, x1, shape_areas@PAGEOFF
    ldr x2, [x1, x24, lsl #3]
    add x2, x2, #1
    str x2, [x1, x24, lsl #3]
    b parse_byte

got_dot:
    mov x23, #3
    b parse_byte

got_x:
    mov x23, #2
    mov x25, x21
    mov x21, #0
    mov x22, #0
    b parse_byte

got_colon:
    cmp x23, #2
    b.eq finish_region_header
    mov x24, x21
    mov x23, #1
    mov x21, #0
    mov x22, #0
    b parse_byte

finish_region_header:
    mov x26, x21
    mov x21, #0
    mov x22, #0
    mov x27, #0
    mov x28, #0
    b parse_byte

got_space:
    cmp x23, #2
    b.ne reset_pending_number
    cbz x22, parse_byte
    bl add_region_count
    b parse_byte

reset_pending_number:
    mov x21, #0
    mov x22, #0
    b parse_byte

got_newline:
    cmp x23, #2
    b.ne reset_line
    cbz x22, finish_region
    bl add_region_count

finish_region:
    mul x1, x25, x26
    cmp x28, x1
    b.gt reset_line
    add x20, x20, #1

reset_line:
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x25, #0
    mov x26, #0
    mov x27, #0
    mov x28, #0
    b parse_byte

add_region_count:
    adrp x1, shape_areas@PAGE
    add x1, x1, shape_areas@PAGEOFF
    ldr x2, [x1, x27, lsl #3]
    madd x28, x21, x2, x28
    add x27, x27, #1
    mov x21, #0
    mov x22, #0
    ret

read_done:
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
    .asciz "input_12.txt"
open_error:
    .asciz "failed to open input_12.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
shape_areas:
    .space 128
