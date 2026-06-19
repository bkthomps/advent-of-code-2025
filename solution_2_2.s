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
    mov x27, #0          ; parsed range count

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
    bl store_range
    mov x22, #0
    mov x23, #0
    mov x26, #0
    b parse_byte

read_done:
    cbz x26, close_file
    cbz x23, close_file
    bl store_range

close_file:
    mov x0, x19
    bl _close

    mov x19, x27
    bl process_all_ranges

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
    str x21, [x9, x27, lsl #3]

    adrp x9, range_ends@PAGE
    add x9, x9, range_ends@PAGEOFF
    str x22, [x9, x27, lsl #3]

    add x27, x27, #1
    ret

process_all_ranges:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x24, #1          ; base length
    mov x25, #1          ; smallest base with this length
    mov x26, #10         ; first base with next length, also 10^base_length

base_length_loop:
    mov x27, #2          ; repeat count

repeat_loop:
    mul x2, x24, x27     ; total digit length
    cmp x2, #11
    b.gt next_base_length

    mov x28, x25         ; base value

base_loop:
    mov x13, x28
    mov x14, #1

build_candidate_loop:
    cmp x14, x27
    b.ge candidate_built
    mul x13, x13, x26
    add x13, x13, x28
    add x14, x14, #1
    b build_candidate_loop

candidate_built:
    mov x23, x13
    mov x0, x13
    mov x1, x24
    bl is_shortest_period
    cbz x0, next_base
    bl candidate_in_any_range
    cbz x0, next_base
    add x20, x20, x23

next_base:
    add x28, x28, #1
    cmp x28, x26
    b.lt base_loop

next_repeat:
    add x27, x27, #1
    b repeat_loop

next_base_length:
    mov x25, x26
    mov x9, #10
    mul x26, x26, x9
    add x24, x24, #1
    cmp x24, #6
    b.lt base_length_loop

    ldp x29, x30, [sp], #16
    ret

candidate_in_any_range:
    adrp x9, range_starts@PAGE
    add x9, x9, range_starts@PAGEOFF
    adrp x10, range_ends@PAGE
    add x10, x10, range_ends@PAGEOFF
    mov x11, #0

range_check_loop:
    cmp x11, x19
    b.ge candidate_not_found
    ldr x12, [x9, x11, lsl #3]
    cmp x23, x12
    b.lt next_range_check
    ldr x12, [x10, x11, lsl #3]
    cmp x23, x12
    b.le candidate_found

next_range_check:
    add x11, x11, #1
    b range_check_loop

candidate_found:
    mov x0, #1
    ret

candidate_not_found:
    mov x0, #0
    ret

is_shortest_period:
    adrp x9, digitbuf@PAGE
    add x9, x9, digitbuf@PAGEOFF
    mov x10, #0          ; digit index
    mov x11, #10

digit_loop:
    udiv x12, x0, x11
    msub x13, x12, x11, x0
    strb w13, [x9, x10]
    add x10, x10, #1
    mov x0, x12
    cmp x10, x2
    b.lt digit_loop

    mov x14, #1          ; shorter period to test

period_loop:
    cmp x14, x1
    b.ge shortest_true

    udiv x16, x2, x14
    msub x17, x16, x14, x2
    cbnz x17, next_period

    mov x15, #0
    sub x16, x2, x14

compare_loop:
    ldrb w17, [x9, x15]
    add x12, x15, x14
    ldrb w13, [x9, x12]
    cmp w17, w13
    b.ne next_period
    add x15, x15, #1
    cmp x15, x16
    b.lt compare_loop

    mov x0, #0
    ret

next_period:
    add x14, x14, #1
    b period_loop

shortest_true:
    mov x0, #1
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
    .asciz "input_2.txt"
open_error:
    .asciz "failed to open input_2.txt\n"

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
digitbuf:
    .space 32
range_starts:
    .space 512
range_ends:
    .space 512
