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
    mov x20, #0          ; row count
    mov x21, #0          ; column count
    mov x22, #0          ; current column while parsing
    mov x23, #0          ; flat grid index
    mov x26, #0          ; start column

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

    cmp w0, #10
    b.eq newline

    cmp w0, #'S'
    b.ne store_cell
    mov x26, x22

store_cell:
    adrp x1, grid@PAGE
    add x1, x1, grid@PAGEOFF
    strb w0, [x1, x23]
    add x23, x23, #1
    add x22, x22, #1
    b parse_byte

newline:
    cbz x22, parse_byte
    cbnz x21, counted_row
    mov x21, x22

counted_row:
    add x20, x20, #1
    mov x22, #0
    b parse_byte

read_done:
    cbz x22, close_file
    cbnz x21, final_row_counted
    mov x21, x22

final_row_counted:
    add x20, x20, #1

close_file:
    mov x0, x19
    bl _close

    bl simulate_beams
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

simulate_beams:
    adrp x27, grid@PAGE
    add x27, x27, grid@PAGEOFF
    adrp x28, active@PAGE
    add x28, x28, active@PAGEOFF
    adrp x25, next_active@PAGE
    add x25, x25, next_active@PAGEOFF

    mov w0, #1
    str x0, [x28, x26, lsl #3]

    mov x22, #0          ; row

row_loop:
    cmp x22, x20
    b.ge sum_timelines

    mov x23, #0

clear_next_loop:
    cmp x23, x21
    b.ge process_row
    str xzr, [x25, x23, lsl #3]
    add x23, x23, #1
    b clear_next_loop

process_row:
    mov x23, #0          ; column

col_loop:
    cmp x23, x21
    b.ge swap_rows
    ldr x1, [x28, x23, lsl #3]
    cbz x1, next_col

    mul x24, x22, x21
    add x24, x24, x23
    ldrb w4, [x27, x24]
    cmp w4, #'^'
    b.eq split_beam

    ldr x2, [x25, x23, lsl #3]
    add x2, x2, x1
    str x2, [x25, x23, lsl #3]
    b next_col

split_beam:
    cbz x23, maybe_right
    sub x1, x23, #1
    ldr x2, [x28, x23, lsl #3]
    ldr x3, [x25, x1, lsl #3]
    add x3, x3, x2
    str x3, [x25, x1, lsl #3]

maybe_right:
    add x1, x23, #1
    cmp x1, x21
    b.ge next_col
    ldr x2, [x28, x23, lsl #3]
    ldr x3, [x25, x1, lsl #3]
    add x3, x3, x2
    str x3, [x25, x1, lsl #3]

next_col:
    add x23, x23, #1
    b col_loop

swap_rows:
    mov x23, #0

copy_next_loop:
    cmp x23, x21
    b.ge next_row
    ldr x1, [x25, x23, lsl #3]
    str x1, [x28, x23, lsl #3]
    add x23, x23, #1
    b copy_next_loop

next_row:
    add x22, x22, #1
    b row_loop

sum_timelines:
    mov x0, #0
    mov x23, #0

sum_loop:
    cmp x23, x21
    b.ge simulation_done
    ldr x1, [x28, x23, lsl #3]
    add x0, x0, x1
    add x23, x23, #1
    b sum_loop

simulation_done:
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
    .asciz "input_07.txt"
open_error:
    .asciz "failed to open input_07.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
grid:
    .space 32768
active:
    .space 2048
next_active:
    .space 2048
