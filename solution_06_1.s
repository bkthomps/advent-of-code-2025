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
    mov x20, #0          ; current row
    mov x21, #0          ; max width
    mov x22, #0          ; current column

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

    adrp x1, worksheet@PAGE
    add x1, x1, worksheet@PAGEOFF
    mov x2, #4096
    madd x3, x20, x2, x22
    strb w0, [x1, x3]
    add x22, x22, #1
    b parse_byte

newline:
    cmp x22, x21
    b.le row_width_done
    mov x21, x22

row_width_done:
    add x20, x20, #1
    mov x22, #0
    b parse_byte

read_done:
    cbz x22, close_file
    cmp x22, x21
    b.le final_row_done
    mov x21, x22

final_row_done:
    add x20, x20, #1

close_file:
    mov x0, x19
    bl _close

    mov x19, x20         ; row count
    mov x20, x21         ; worksheet width
    bl solve_worksheet
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

solve_worksheet:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x21, #0          ; grand total
    mov x22, #0          ; current column

skip_separator_columns:
    cmp x22, x20
    b.ge worksheet_done
    mov x0, x22
    bl is_separator_column
    cbz x0, segment_start
    add x22, x22, #1
    b skip_separator_columns

segment_start:
    mov x23, x22         ; start column

find_segment_end:
    cmp x22, x20
    b.ge process_segment
    mov x0, x22
    bl is_separator_column
    cbnz x0, process_segment
    add x22, x22, #1
    b find_segment_end

process_segment:
    mov x24, x22         ; end column

    adrp x25, worksheet@PAGE
    add x25, x25, worksheet@PAGEOFF
    sub x9, x19, #1
    mov x10, #4096
    mul x9, x9, x10
    add x9, x9, x23
    mov x10, x23
    mov x11, #'*'

find_operator:
    cmp x10, x24
    b.ge operator_found
    ldrb w12, [x25, x9]
    cmp w12, #'+'
    b.ne next_operator_col
    mov x11, #'+'
    b operator_found

next_operator_col:
    add x9, x9, #1
    add x10, x10, #1
    b find_operator

operator_found:
    mov x26, #0          ; numeric row
    mov x27, #0          ; segment sum
    mov x28, #1          ; segment product

number_row_loop:
    sub x9, x19, #1
    cmp x26, x9
    b.ge finish_segment

    mov x9, #4096
    mul x10, x26, x9
    add x10, x10, x23
    mov x12, x23
    mov x13, #0          ; row value
    mov x14, #0          ; has digit

digit_col_loop:
    cmp x12, x24
    b.ge row_value_done

    ldrb w15, [x25, x10]
    cmp w15, #'0'
    b.lt next_digit_col
    cmp w15, #'9'
    b.gt next_digit_col

    sub w15, w15, #'0'
    mov x16, #10
    madd x13, x13, x16, x15
    mov x14, #1

next_digit_col:
    add x10, x10, #1
    add x12, x12, #1
    b digit_col_loop

row_value_done:
    cbz x14, next_number_row
    cmp x11, #'+'
    b.ne multiply_value
    add x27, x27, x13
    b next_number_row

multiply_value:
    mul x28, x28, x13

next_number_row:
    add x26, x26, #1
    b number_row_loop

finish_segment:
    cmp x11, #'+'
    b.ne add_product
    add x21, x21, x27
    b next_segment

add_product:
    add x21, x21, x28

next_segment:
    add x22, x24, #1
    b skip_separator_columns

worksheet_done:
    mov x0, x21
    ldp x29, x30, [sp], #16
    ret

is_separator_column:
    adrp x9, worksheet@PAGE
    add x9, x9, worksheet@PAGEOFF
    mov x10, #0
    mov x11, #4096

separator_row_loop:
    cmp x10, x19
    b.ge separator_true
    madd x12, x10, x11, x0
    ldrb w13, [x9, x12]
    cmp w13, #' '
    b.ne separator_false
    add x10, x10, #1
    b separator_row_loop

separator_true:
    mov x0, #1
    ret

separator_false:
    mov x0, #0
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
    .asciz "input_06.txt"
open_error:
    .asciz "failed to open input_06.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
worksheet:
    .space 24576
