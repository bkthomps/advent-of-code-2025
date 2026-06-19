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
    mov x2, #28
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
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    adrp x23, xs@PAGE
    add x23, x23, xs@PAGEOFF
    adrp x24, ys@PAGE
    add x24, x24, ys@PAGEOFF

    mov x26, #0          ; max area
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
    mul x25, x11, x12
    cmp x25, x26
    b.le next_j

    ldr x9, [x23, x21, lsl #3]
    ldr x10, [x23, x22, lsl #3]
    cmp x9, x10
    b.le store_x_order
    mov x11, x9
    mov x9, x10
    mov x10, x11

store_x_order:
    adrp x11, rect_xa@PAGE
    add x11, x11, rect_xa@PAGEOFF
    str x9, [x11]
    adrp x11, rect_xb@PAGE
    add x11, x11, rect_xb@PAGEOFF
    str x10, [x11]

    ldr x9, [x24, x21, lsl #3]
    ldr x10, [x24, x22, lsl #3]
    cmp x9, x10
    b.le store_y_order
    mov x11, x9
    mov x9, x10
    mov x10, x11

store_y_order:
    adrp x11, rect_ya@PAGE
    add x11, x11, rect_ya@PAGEOFF
    str x9, [x11]
    adrp x11, rect_yb@PAGE
    add x11, x11, rect_yb@PAGEOFF
    str x10, [x11]

    bl rectangle_valid
    cbz x0, next_j
    mov x26, x25

next_j:
    add x22, x22, #1
    b inner_loop

next_i:
    add x21, x21, #1
    b outer_loop

area_done:
    mov x0, x26
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

rectangle_valid:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adrp x9, rect_xa@PAGE
    add x9, x9, rect_xa@PAGEOFF
    ldr x0, [x9]
    adrp x9, rect_ya@PAGE
    add x9, x9, rect_ya@PAGEOFF
    ldr x1, [x9]
    bl point_inside
    cbz x0, rect_invalid

    adrp x9, rect_xa@PAGE
    add x9, x9, rect_xa@PAGEOFF
    ldr x0, [x9]
    adrp x9, rect_yb@PAGE
    add x9, x9, rect_yb@PAGEOFF
    ldr x1, [x9]
    bl point_inside
    cbz x0, rect_invalid

    adrp x9, rect_xb@PAGE
    add x9, x9, rect_xb@PAGEOFF
    ldr x0, [x9]
    adrp x9, rect_ya@PAGE
    add x9, x9, rect_ya@PAGEOFF
    ldr x1, [x9]
    bl point_inside
    cbz x0, rect_invalid

    adrp x9, rect_xb@PAGE
    add x9, x9, rect_xb@PAGEOFF
    ldr x0, [x9]
    adrp x9, rect_yb@PAGE
    add x9, x9, rect_yb@PAGEOFF
    ldr x1, [x9]
    bl point_inside
    cbz x0, rect_invalid

    bl edge_cuts_rect
    cbnz x0, rect_invalid
    mov x0, #1
    ldp x29, x30, [sp], #16
    ret

rect_invalid:
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

point_inside:
    adrp x9, query_x@PAGE
    add x9, x9, query_x@PAGEOFF
    str x0, [x9]
    adrp x9, query_y@PAGE
    add x9, x9, query_y@PAGEOFF
    str x1, [x9]

    adrp x23, xs@PAGE
    add x23, x23, xs@PAGEOFF
    adrp x24, ys@PAGE
    add x24, x24, ys@PAGEOFF
    mov x9, #0

boundary_loop:
    cmp x9, x20
    b.ge boundary_done
    add x10, x9, #1
    cmp x10, x20
    b.lt have_next_boundary
    mov x10, #0

have_next_boundary:
    ldr x11, [x23, x9, lsl #3]
    ldr x12, [x24, x9, lsl #3]
    ldr x13, [x23, x10, lsl #3]
    ldr x14, [x24, x10, lsl #3]

    cmp x11, x13
    b.ne check_horizontal_boundary
    cmp x0, x11
    b.ne next_boundary
    cmp x12, x14
    b.le vertical_min_ok
    mov x15, x12
    mov x12, x14
    mov x14, x15

vertical_min_ok:
    cmp x1, x12
    b.lt next_boundary
    cmp x1, x14
    b.le point_true
    b next_boundary

check_horizontal_boundary:
    cmp x12, x14
    b.ne next_boundary
    cmp x1, x12
    b.ne next_boundary
    cmp x11, x13
    b.le horizontal_min_ok
    mov x15, x11
    mov x11, x13
    mov x13, x15

horizontal_min_ok:
    cmp x0, x11
    b.lt next_boundary
    cmp x0, x13
    b.le point_true

next_boundary:
    add x9, x9, #1
    b boundary_loop

boundary_done:
    mov x16, #0
    mov x9, #0

ray_loop:
    cmp x9, x20
    b.ge ray_done
    add x10, x9, #1
    cmp x10, x20
    b.lt have_next_ray
    mov x10, #0

have_next_ray:
    ldr x11, [x23, x9, lsl #3]
    ldr x12, [x24, x9, lsl #3]
    ldr x13, [x23, x10, lsl #3]
    ldr x14, [x24, x10, lsl #3]
    cmp x11, x13
    b.ne next_ray
    cmp x11, x0
    b.le next_ray
    cmp x12, x14
    b.le ray_min_ok
    mov x15, x12
    mov x12, x14
    mov x14, x15

ray_min_ok:
    cmp x1, x12
    b.lt next_ray
    cmp x1, x14
    b.ge next_ray
    eor x16, x16, #1

next_ray:
    add x9, x9, #1
    b ray_loop

ray_done:
    mov x0, x16
    ret

point_true:
    mov x0, #1
    ret

edge_cuts_rect:
    adrp x9, rect_xa@PAGE
    add x9, x9, rect_xa@PAGEOFF
    ldr x0, [x9]
    adrp x9, rect_xb@PAGE
    add x9, x9, rect_xb@PAGEOFF
    ldr x1, [x9]
    adrp x9, rect_ya@PAGE
    add x9, x9, rect_ya@PAGEOFF
    ldr x2, [x9]
    adrp x9, rect_yb@PAGE
    add x9, x9, rect_yb@PAGEOFF
    ldr x3, [x9]

    cmp x0, x1
    b.eq no_edge_cut
    cmp x2, x3
    b.eq no_edge_cut

    adrp x23, xs@PAGE
    add x23, x23, xs@PAGEOFF
    adrp x24, ys@PAGE
    add x24, x24, ys@PAGEOFF
    mov x9, #0

edge_loop:
    cmp x9, x20
    b.ge no_edge_cut
    add x10, x9, #1
    cmp x10, x20
    b.lt have_next_edge
    mov x10, #0

have_next_edge:
    ldr x11, [x23, x9, lsl #3]
    ldr x12, [x24, x9, lsl #3]
    ldr x13, [x23, x10, lsl #3]
    ldr x14, [x24, x10, lsl #3]

    cmp x11, x13
    b.ne horizontal_cut
    cmp x11, x0
    b.le next_edge
    cmp x11, x1
    b.ge next_edge
    cmp x12, x14
    b.le vcut_min_ok
    mov x15, x12
    mov x12, x14
    mov x14, x15

vcut_min_ok:
    cmp x12, x3
    b.ge next_edge
    cmp x14, x2
    b.le next_edge
    b edge_cut_true

horizontal_cut:
    cmp x12, x14
    b.ne next_edge
    cmp x12, x2
    b.le next_edge
    cmp x12, x3
    b.ge next_edge
    cmp x11, x13
    b.le hcut_min_ok
    mov x15, x11
    mov x11, x13
    mov x13, x15

hcut_min_ok:
    cmp x11, x1
    b.ge next_edge
    cmp x13, x0
    b.le next_edge
    b edge_cut_true

next_edge:
    add x9, x9, #1
    b edge_loop

edge_cut_true:
    mov x0, #1
    ret

no_edge_cut:
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
    .asciz "input_09.txt"
open_error:
    .asciz "failed to open input_09.txt\n"

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
rect_xa:
    .space 8
rect_xb:
    .space 8
rect_ya:
    .space 8
rect_yb:
    .space 8
query_x:
    .space 8
query_y:
    .space 8
