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

    bl count_accessible
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

count_accessible:
    adrp x28, grid@PAGE
    add x28, x28, grid@PAGEOFF
    mov x0, #0           ; accessible count
    mov x23, #0          ; row

row_loop:
    cmp x23, x20
    b.ge count_done
    mov x24, #0          ; column

col_loop:
    cmp x24, x21
    b.ge next_row

    mul x25, x23, x21
    add x25, x25, x24
    ldrb w1, [x28, x25]
    cmp w1, #'@'
    b.ne next_col

    mov x26, #0          ; neighbor count
    mov x9, #-1          ; row delta

neighbor_row_loop:
    cmp x9, #2
    b.ge check_accessible
    add x10, x23, x9
    cmp x10, #0
    b.lt next_neighbor_row
    cmp x10, x20
    b.ge next_neighbor_row

    mov x11, #-1         ; column delta

neighbor_col_loop:
    cmp x11, #2
    b.ge next_neighbor_row
    orr x12, x9, x11
    cbz x12, next_neighbor_col

    add x12, x24, x11
    cmp x12, #0
    b.lt next_neighbor_col
    cmp x12, x21
    b.ge next_neighbor_col

    mul x13, x10, x21
    add x13, x13, x12
    ldrb w14, [x28, x13]
    cmp w14, #'@'
    b.ne next_neighbor_col
    add x26, x26, #1

next_neighbor_col:
    add x11, x11, #1
    b neighbor_col_loop

next_neighbor_row:
    add x9, x9, #1
    b neighbor_row_loop

check_accessible:
    cmp x26, #4
    b.ge next_col
    add x0, x0, #1

next_col:
    add x24, x24, #1
    b col_loop

next_row:
    add x23, x23, #1
    b row_loop

count_done:
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
    .asciz "input_4.txt"
open_error:
    .asciz "failed to open input_4.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
grid:
    .space 32768
