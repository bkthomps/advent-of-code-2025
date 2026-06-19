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
    mov x21, #0          ; target light mask
    mov x22, #0          ; light index while parsing diagram
    mov x23, #0          ; current button mask
    mov x24, #0          ; current machine button count
    mov x26, #0          ; parser section: 0 outside, 1 diagram, 2 buttons, 3 ignore
    mov x27, #0          ; current parsed button index
    mov x28, #0          ; have parsed button index

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
    cmp x26, #3
    b.eq parse_byte

    cmp w0, #'['
    b.eq start_machine
    cmp x26, #1
    b.eq parse_diagram
    cmp x26, #2
    b.eq parse_buttons
    b parse_byte

start_machine:
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x24, #0
    mov x27, #0
    mov x28, #0
    mov x26, #1
    b parse_byte

parse_diagram:
    cmp w0, #'#'
    b.eq diagram_on
    cmp w0, #'.'
    b.eq diagram_off
    cmp w0, #']'
    b.eq end_diagram
    b parse_byte

diagram_on:
    mov x1, #1
    lsl x1, x1, x22
    orr x21, x21, x1

diagram_off:
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
    b.eq process_machine_start_ignore
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

process_machine_start_ignore:
    stp x14, x15, [sp, #-16]!
    bl solve_machine
    ldp x14, x15, [sp], #16
    add x20, x20, x0
    mov x26, #3
    b parse_byte

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
    adrp x9, button_masks@PAGE
    add x9, x9, button_masks@PAGEOFF
    mov x10, #1
    lsl x10, x10, x24    ; subset limit
    mov x11, #0          ; subset
    mov x12, #127        ; best

subset_loop:
    cmp x11, x10
    b.ge solve_done
    mov x13, #0          ; xor mask
    mov x14, #0          ; press count
    mov x15, #0          ; button index
    mov x16, x11

button_loop:
    cmp x15, x24
    b.ge check_subset
    tbz x16, #0, next_button
    ldr x17, [x9, x15, lsl #3]
    eor x13, x13, x17
    add x14, x14, #1

next_button:
    lsr x16, x16, #1
    add x15, x15, #1
    b button_loop

check_subset:
    cmp x13, x21
    b.ne next_subset
    cmp x14, x12
    b.ge next_subset
    mov x12, x14

next_subset:
    add x11, x11, #1
    b subset_loop

solve_done:
    mov x0, x12
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

.section __DATA,__bss
.p2align 4
buffer:
    .space 4096
outbuf:
    .space 32
button_masks:
    .space 128
