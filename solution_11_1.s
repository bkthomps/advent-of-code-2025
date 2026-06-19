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
    mov x20, #0          ; node count
    mov x21, #0          ; edge count
    mov x22, #0          ; current token code
    mov x23, #0          ; token length
    mov x24, #0          ; current source id
    mov x25, #0          ; parsing destinations
    mov x26, #-1         ; you id
    mov x27, #-1         ; out id

read_chunk:
    mov x0, x19
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.lt read_done
    b.eq read_done

    mov x28, x0
    adrp x15, buffer@PAGE
    add x15, x15, buffer@PAGEOFF

parse_byte:
    cbz x28, read_chunk
    ldrb w0, [x15], #1
    sub x28, x28, #1

    cmp w0, #'a'
    b.lt delimiter
    cmp w0, #'z'
    b.gt delimiter

    lsl x22, x22, #8
    orr x22, x22, x0
    add x23, x23, #1
    b parse_byte

delimiter:
    cbz x23, no_token
    stp x0, xzr, [sp, #-16]!
    stp x15, x28, [sp, #-16]!
    mov x0, x22
    bl get_id
    mov x1, x0
    ldp x15, x28, [sp], #16
    ldp x0, xzr, [sp], #16

    cbz x25, set_source

    adrp x2, edge_from@PAGE
    add x2, x2, edge_from@PAGEOFF
    str x24, [x2, x21, lsl #3]
    adrp x2, edge_to@PAGE
    add x2, x2, edge_to@PAGEOFF
    str x1, [x2, x21, lsl #3]
    add x21, x21, #1
    b reset_token

set_source:
    mov x24, x1

reset_token:
    mov x22, #0
    mov x23, #0

no_token:
    cmp w0, #':'
    b.eq got_colon
    cmp w0, #10
    b.eq got_newline
    b parse_byte

got_colon:
    mov x25, #1
    b parse_byte

got_newline:
    mov x25, #0
    b parse_byte

read_done:
    mov x0, x19
    bl _close

    adrp x0, edge_count_value@PAGE
    add x0, x0, edge_count_value@PAGEOFF
    str x21, [x0]

    mov x0, x26
    bl count_paths
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

get_id:
    adrp x9, node_codes@PAGE
    add x9, x9, node_codes@PAGEOFF
    mov x10, #0

find_node_loop:
    cmp x10, x20
    b.ge add_node
    ldr x11, [x9, x10, lsl #3]
    cmp x11, x0
    b.eq found_node
    add x10, x10, #1
    b find_node_loop

add_node:
    str x0, [x9, x20, lsl #3]
    mov x10, x20
    add x20, x20, #1

    adrp x11, code_you@PAGE
    add x11, x11, code_you@PAGEOFF
    ldr x11, [x11]
    cmp x0, x11
    b.ne check_out
    mov x26, x10
    b found_node

check_out:
    adrp x11, code_out@PAGE
    add x11, x11, code_out@PAGEOFF
    ldr x11, [x11]
    cmp x0, x11
    b.ne found_node
    mov x27, x10

found_node:
    mov x0, x10
    ret

count_paths:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    cmp x0, x27
    b.ne check_memo
    mov x0, #1
    b count_done

check_memo:
    mov x19, x0
    adrp x20, memo_valid@PAGE
    add x20, x20, memo_valid@PAGEOFF
    ldrb w1, [x20, x19]
    cbz w1, compute_paths
    adrp x21, memo_values@PAGE
    add x21, x21, memo_values@PAGEOFF
    ldr x0, [x21, x19, lsl #3]
    b count_done

compute_paths:
    mov x22, #0          ; sum
    mov x23, #0          ; edge index
    adrp x20, edge_from@PAGE
    add x20, x20, edge_from@PAGEOFF
    adrp x21, edge_to@PAGE
    add x21, x21, edge_to@PAGEOFF
    adrp x24, edge_count_value@PAGE
    add x24, x24, edge_count_value@PAGEOFF
    ldr x24, [x24]

edge_scan_loop:
    cmp x23, x24
    b.ge count_finish_compute
    ldr x1, [x20, x23, lsl #3]
    cmp x1, x19
    b.ne next_edge

    ldr x0, [x21, x23, lsl #3]
    bl count_paths
    add x22, x22, x0

next_edge:
    add x23, x23, #1
    b edge_scan_loop

count_finish_compute:
    adrp x1, memo_values@PAGE
    add x1, x1, memo_values@PAGEOFF
    str x22, [x1, x19, lsl #3]
    adrp x1, memo_valid@PAGE
    add x1, x1, memo_valid@PAGEOFF
    mov w2, #1
    strb w2, [x1, x19]
    mov x0, x22
    b count_done

count_done:
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
    .asciz "input_11.txt"
open_error:
    .asciz "failed to open input_11.txt\n"

.section __TEXT,__literal8,8byte_literals
code_you:
    .quad 0x796f75
code_out:
    .quad 0x6f7574

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
node_codes:
    .space 8192
edge_from:
    .space 32768
edge_to:
    .space 32768
memo_valid:
    .space 8192
memo_values:
    .space 8192
edge_count_value:
    .space 8
