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
    mov x20, #0          ; total minimum presses
    mov x21, #0          ; current parsed number
    mov x22, #0          ; diagram light index
    mov x23, #0          ; current button mask
    mov x24, #0          ; button count
    mov x25, #0          ; requirement count
    mov x26, #0          ; parser section: 0 outside, 1 diagram, 2 buttons, 3 reqs, 4 ignore
    mov x27, #0          ; current button index
    mov x28, #0          ; have parsed number

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

    cmp w0, #10
    b.eq newline
    cmp x26, #4
    b.eq parse_byte

    cmp w0, #'['
    b.eq start_machine
    cmp x26, #1
    b.eq parse_diagram
    cmp x26, #2
    b.eq parse_buttons
    cmp x26, #3
    b.eq parse_requirements
    b parse_byte

start_machine:
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x24, #0
    mov x25, #0
    mov x27, #0
    mov x28, #0
    mov x26, #1
    b parse_byte

parse_diagram:
    cmp w0, #'.'
    b.eq count_light
    cmp w0, #'#'
    b.eq count_light
    cmp w0, #']'
    b.eq end_diagram
    b parse_byte

count_light:
    add x22, x22, #1
    b parse_byte

end_diagram:
    mov x26, #2
    b parse_byte

parse_buttons:
    cmp w0, #'('
    b.eq start_button
    cmp w0, #')'
    b.eq end_button
    cmp w0, #','
    b.eq finish_button_index
    cmp w0, #'{'
    b.eq start_requirements
    cmp w0, #'0'
    b.lt parse_byte
    cmp w0, #'9'
    b.gt parse_byte

    sub w0, w0, #'0'
    mov x1, #10
    madd x27, x27, x1, x0
    mov x28, #1
    b parse_byte

start_button:
    mov x23, #0
    mov x27, #0
    mov x28, #0
    b parse_byte

finish_button_index:
    cbz x28, parse_byte
    mov x1, #1
    lsl x1, x1, x27
    orr x23, x23, x1
    mov x27, #0
    mov x28, #0
    b parse_byte

end_button:
    cbz x28, store_button
    mov x1, #1
    lsl x1, x1, x27
    orr x23, x23, x1

store_button:
    adrp x1, button_masks@PAGE
    add x1, x1, button_masks@PAGEOFF
    str x23, [x1, x24, lsl #3]
    add x24, x24, #1
    mov x23, #0
    mov x27, #0
    mov x28, #0
    b parse_byte

start_requirements:
    mov x26, #3
    mov x21, #0
    mov x28, #0
    b parse_byte

parse_requirements:
    cmp w0, #','
    b.eq finish_requirement
    cmp w0, #'}'
    b.eq finish_machine
    cmp w0, #'0'
    b.lt parse_byte
    cmp w0, #'9'
    b.gt parse_byte

    sub w0, w0, #'0'
    mov x1, #10
    madd x21, x21, x1, x0
    mov x28, #1
    b parse_byte

finish_requirement:
    cbz x28, parse_byte
    bl store_requirement
    mov x21, #0
    mov x28, #0
    b parse_byte

finish_machine:
    cbz x28, solve_current_machine
    bl store_requirement

solve_current_machine:
    stp x14, x15, [sp, #-16]!
    bl solve_machine
    ldp x14, x15, [sp], #16
    add x20, x20, x0
    mov x26, #4
    mov x21, #0
    mov x28, #0
    b parse_byte

store_requirement:
    adrp x1, requirements@PAGE
    add x1, x1, requirements@PAGEOFF
    str x21, [x1, x25, lsl #3]
    add x25, x25, #1
    ret

newline:
    mov x26, #0
    b parse_byte

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

solve_machine:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    mov x19, x24         ; button count
    mov x20, x25         ; requirement count
    bl build_matrix
    bl rref_matrix
    bl enumerate_solutions

    ldp x27, x28, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

build_matrix:
    adrp x9, matrix@PAGE
    add x9, x9, matrix@PAGEOFF
    mov x10, #0
    mov x11, #160

clear_matrix_loop:
    cmp x10, x11
    b.ge fill_matrix
    str xzr, [x9, x10, lsl #3]
    add x10, x10, #1
    b clear_matrix_loop

fill_matrix:
    adrp x21, button_masks@PAGE
    add x21, x21, button_masks@PAGEOFF
    adrp x22, requirements@PAGE
    add x22, x22, requirements@PAGEOFF
    adrp x23, max_req@PAGE
    add x23, x23, max_req@PAGEOFF
    str xzr, [x23]
    adrp x23, sum_req@PAGE
    add x23, x23, sum_req@PAGEOFF
    str xzr, [x23]
    mov x10, #0          ; row / counter

fill_row_loop:
    cmp x10, x20
    b.ge build_done
    mov x11, #0          ; button col

fill_col_loop:
    cmp x11, x19
    b.ge fill_rhs
    ldr x12, [x21, x11, lsl #3]
    lsr x13, x12, x10
    tbz x13, #0, next_fill_col
    mov x14, #16
    madd x15, x10, x14, x11
    mov x16, #1
    scvtf d0, x16
    str d0, [x9, x15, lsl #3]

next_fill_col:
    add x11, x11, #1
    b fill_col_loop

fill_rhs:
    ldr x12, [x22, x10, lsl #3]
    adrp x13, sum_req@PAGE
    add x13, x13, sum_req@PAGEOFF
    ldr x14, [x13]
    add x14, x14, x12
    str x14, [x13]
    mov x14, #16
    madd x15, x10, x14, x19
    scvtf d0, x12
    str d0, [x9, x15, lsl #3]
    adrp x23, max_req@PAGE
    add x23, x23, max_req@PAGEOFF
    ldr x13, [x23]
    cmp x12, x13
    b.le next_fill_row
    str x12, [x23]

next_fill_row:
    add x10, x10, #1
    b fill_row_loop

build_done:
    ret

rref_matrix:
    adrp x27, matrix@PAGE
    add x27, x27, matrix@PAGEOFF
    adrp x28, pivot_cols@PAGE
    add x28, x28, pivot_cols@PAGEOFF
    adrp x26, eps@PAGE
    add x26, x26, eps@PAGEOFF
    ldr d31, [x26]
    mov x21, #0          ; rank
    mov x22, #0          ; column

rref_col_loop:
    cmp x22, x19
    b.ge rref_done
    mov x23, x21         ; candidate pivot row
    mov x24, #-1

find_pivot_loop:
    cmp x23, x20
    b.ge pivot_search_done
    mov x9, #16
    madd x10, x23, x9, x22
    ldr d0, [x27, x10, lsl #3]
    fabs d0, d0
    fcmp d0, d31
    b.le next_pivot_row
    mov x24, x23
    b pivot_search_done

next_pivot_row:
    add x23, x23, #1
    b find_pivot_loop

pivot_search_done:
    cmp x24, #-1
    b.eq next_rref_col
    cmp x24, x21
    b.eq normalize_pivot
    mov x23, #0

swap_loop:
    cmp x23, #16
    b.ge normalize_pivot
    mov x9, #16
    madd x10, x21, x9, x23
    madd x11, x24, x9, x23
    ldr d0, [x27, x10, lsl #3]
    ldr d1, [x27, x11, lsl #3]
    str d1, [x27, x10, lsl #3]
    str d0, [x27, x11, lsl #3]
    add x23, x23, #1
    b swap_loop

normalize_pivot:
    str x22, [x28, x21, lsl #3]
    mov x9, #16
    madd x10, x21, x9, x22
    ldr d2, [x27, x10, lsl #3]
    mov x23, x22

normalize_loop:
    cmp x23, #16
    b.ge eliminate_rows
    mov x9, #16
    madd x10, x21, x9, x23
    ldr d0, [x27, x10, lsl #3]
    fdiv d0, d0, d2
    str d0, [x27, x10, lsl #3]
    add x23, x23, #1
    b normalize_loop

eliminate_rows:
    mov x23, #0

elim_row_loop:
    cmp x23, x20
    b.ge pivot_complete
    cmp x23, x21
    b.eq next_elim_row
    mov x9, #16
    madd x10, x23, x9, x22
    ldr d3, [x27, x10, lsl #3]
    fabs d0, d3
    fcmp d0, d31
    b.le next_elim_row
    mov x24, x22

elim_col_loop:
    cmp x24, #16
    b.ge next_elim_row
    mov x9, #16
    madd x10, x23, x9, x24
    madd x11, x21, x9, x24
    ldr d0, [x27, x10, lsl #3]
    ldr d1, [x27, x11, lsl #3]
    fmul d1, d1, d3
    fsub d0, d0, d1
    str d0, [x27, x10, lsl #3]
    add x24, x24, #1
    b elim_col_loop

next_elim_row:
    add x23, x23, #1
    b elim_row_loop

pivot_complete:
    add x21, x21, #1

next_rref_col:
    add x22, x22, #1
    b rref_col_loop

rref_done:
    adrp x9, rank_value@PAGE
    add x9, x9, rank_value@PAGEOFF
    str x21, [x9]
    b build_free_cols

build_free_cols:
    adrp x9, pivot_cols@PAGE
    add x9, x9, pivot_cols@PAGEOFF
    adrp x10, free_cols@PAGE
    add x10, x10, free_cols@PAGEOFF
    mov x11, #0          ; col
    mov x12, #0          ; free count

free_col_loop:
    cmp x11, x19
    b.ge free_cols_done
    mov x13, #0

pivot_check_loop:
    cmp x13, x21
    b.ge is_free_col
    ldr x14, [x9, x13, lsl #3]
    cmp x14, x11
    b.eq next_free_col
    add x13, x13, #1
    b pivot_check_loop

is_free_col:
    str x11, [x10, x12, lsl #3]
    add x12, x12, #1

next_free_col:
    add x11, x11, #1
    b free_col_loop

free_cols_done:
    adrp x9, free_count@PAGE
    add x9, x9, free_count@PAGEOFF
    str x12, [x9]
    ret

enumerate_solutions:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x9, free_count@PAGE
    add x9, x9, free_count@PAGEOFF
    ldr x21, [x9]
    adrp x9, max_req@PAGE
    add x9, x9, max_req@PAGEOFF
    ldr x22, [x9]
    adrp x9, best_value@PAGE
    add x9, x9, best_value@PAGEOFF
    adrp x10, sum_req@PAGE
    add x10, x10, sum_req@PAGEOFF
    ldr x10, [x10]
    str x10, [x9]
    mov x23, #0

enum_a_loop:
    cmp x23, x22
    b.gt enum_done
    mov x24, #0

enum_b_loop:
    cmp x21, #1
    b.le enum_try
    cmp x24, x22
    b.gt next_enum_a
    mov x25, #0

enum_c_loop:
    cmp x21, #2
    b.le enum_try
    cmp x25, x22
    b.gt next_enum_b

enum_try:
    adrp x9, best_value@PAGE
    add x9, x9, best_value@PAGEOFF
    ldr x9, [x9]
    mov x10, x23
    cmp x21, #1
    b.le have_partial_sum
    add x10, x10, x24
    cmp x21, #2
    b.le have_partial_sum
    add x10, x10, x25

have_partial_sum:
    cmp x10, x9
    b.ge skip_enum_try
    bl try_assignment

skip_enum_try:
    cmp x21, #2
    b.gt next_enum_c
    cmp x21, #1
    b.gt next_enum_b
    b next_enum_a

next_enum_c:
    add x25, x25, #1
    b enum_c_loop

next_enum_b:
    add x24, x24, #1
    b enum_b_loop

next_enum_a:
    add x23, x23, #1
    b enum_a_loop

enum_done:
    adrp x9, best_value@PAGE
    add x9, x9, best_value@PAGEOFF
    ldr x0, [x9]
    ldp x29, x30, [sp], #16
    ret

try_assignment:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x9, values@PAGE
    add x9, x9, values@PAGEOFF
    mov x10, #0

clear_values_loop:
    cmp x10, #16
    b.ge store_free_values
    str xzr, [x9, x10, lsl #3]
    add x10, x10, #1
    b clear_values_loop

store_free_values:
    adrp x10, free_cols@PAGE
    add x10, x10, free_cols@PAGEOFF
    cmp x21, #0
    b.eq solve_pivots
    ldr x11, [x10]
    str x23, [x9, x11, lsl #3]
    cmp x21, #1
    b.eq solve_pivots
    ldr x11, [x10, #8]
    str x24, [x9, x11, lsl #3]
    cmp x21, #2
    b.eq solve_pivots
    ldr x11, [x10, #16]
    str x25, [x9, x11, lsl #3]

solve_pivots:
    adrp x26, matrix@PAGE
    add x26, x26, matrix@PAGEOFF
    adrp x27, pivot_cols@PAGE
    add x27, x27, pivot_cols@PAGEOFF
    adrp x28, rank_value@PAGE
    add x28, x28, rank_value@PAGEOFF
    ldr x28, [x28]
    mov x10, #0          ; pivot row

pivot_value_loop:
    cmp x10, x28
    b.ge verify_candidate
    mov x11, #16
    madd x12, x10, x11, x19
    ldr d0, [x26, x12, lsl #3]
    mov x11, #0

subtract_free_loop:
    cmp x11, x21
    b.ge round_pivot
    adrp x12, free_cols@PAGE
    add x12, x12, free_cols@PAGEOFF
    ldr x13, [x12, x11, lsl #3]
    mov x12, #16
    madd x14, x10, x12, x13
    ldr d1, [x26, x14, lsl #3]
    ldr x15, [x9, x13, lsl #3]
    scvtf d2, x15
    fmul d1, d1, d2
    fsub d0, d0, d1
    add x11, x11, #1
    b subtract_free_loop

round_pivot:
    fcvtas x11, d0
    cmp x11, #0
    b.lt candidate_done
    ldr x12, [x27, x10, lsl #3]
    str x11, [x9, x12, lsl #3]
    add x10, x10, #1
    b pivot_value_loop

verify_candidate:
    bl verify_values

candidate_done:
    ldp x29, x30, [sp], #16
    ret

verify_values:
    adrp x9, values@PAGE
    add x9, x9, values@PAGEOFF
    adrp x10, button_masks@PAGE
    add x10, x10, button_masks@PAGEOFF
    adrp x11, requirements@PAGE
    add x11, x11, requirements@PAGEOFF
    mov x12, #0          ; counter

verify_counter_loop:
    cmp x12, x20
    b.ge candidate_valid
    mov x13, #0
    mov x14, #0

verify_button_loop:
    cmp x14, x19
    b.ge check_counter
    ldr x15, [x10, x14, lsl #3]
    lsr x16, x15, x12
    tbz x16, #0, next_verify_button
    ldr x17, [x9, x14, lsl #3]
    add x13, x13, x17

next_verify_button:
    add x14, x14, #1
    b verify_button_loop

check_counter:
    ldr x15, [x11, x12, lsl #3]
    cmp x13, x15
    b.ne candidate_invalid
    add x12, x12, #1
    b verify_counter_loop

candidate_valid:
    mov x12, #0
    mov x13, #0

sum_values_loop:
    cmp x12, x19
    b.ge check_best
    ldr x14, [x9, x12, lsl #3]
    add x13, x13, x14
    add x12, x12, #1
    b sum_values_loop

check_best:
    adrp x14, best_value@PAGE
    add x14, x14, best_value@PAGEOFF
    ldr x15, [x14]
    cmp x13, x15
    b.ge candidate_invalid
    str x13, [x14]

candidate_invalid:
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
    .asciz "input_10.txt"
open_error:
    .asciz "failed to open input_10.txt\n"

.section __TEXT,__literal8,8byte_literals
eps:
    .double 0.000000001

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
button_masks:
    .space 128
requirements:
    .space 128
matrix:
    .space 1280
pivot_cols:
    .space 128
free_cols:
    .space 128
values:
    .space 128
rank_value:
    .space 8
free_count:
    .space 8
max_req:
    .space 8
sum_req:
    .space 8
best_value:
    .space 8
