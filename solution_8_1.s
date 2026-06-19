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
    mov x20, #0          ; parsed point count
    mov x21, #0          ; current number
    mov x22, #0          ; coordinate index on current line
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

    bl init_dsu
    bl build_pairs
    bl connect_shortest
    bl product_top_three
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

save_coord:
    cmp x22, #0
    b.eq save_x
    cmp x22, #1
    b.eq save_y

    adrp x9, zs@PAGE
    add x9, x9, zs@PAGEOFF
    str x21, [x9, x20, lsl #3]
    ret

save_x:
    adrp x9, xs@PAGE
    add x9, x9, xs@PAGEOFF
    str x21, [x9, x20, lsl #3]
    ret

save_y:
    adrp x9, ys@PAGE
    add x9, x9, ys@PAGEOFF
    str x21, [x9, x20, lsl #3]
    ret

init_dsu:
    adrp x9, parent@PAGE
    add x9, x9, parent@PAGEOFF
    adrp x10, comp_size@PAGE
    add x10, x10, comp_size@PAGEOFF
    mov x11, #0

init_loop:
    cmp x11, x20
    b.ge init_done
    str x11, [x9, x11, lsl #3]
    mov x12, #1
    str x12, [x10, x11, lsl #3]
    add x11, x11, #1
    b init_loop

init_done:
    ret

build_pairs:
    adrp x9, xs@PAGE
    add x9, x9, xs@PAGEOFF
    adrp x10, ys@PAGE
    add x10, x10, ys@PAGEOFF
    adrp x11, zs@PAGE
    add x11, x11, zs@PAGEOFF
    adrp x12, pair_dist@PAGE
    add x12, x12, pair_dist@PAGEOFF
    adrp x13, pair_a@PAGE
    add x13, x13, pair_a@PAGEOFF
    adrp x14, pair_b@PAGE
    add x14, x14, pair_b@PAGEOFF

    mov x19, #0          ; pair count
    mov x21, #0          ; i

outer_pair_loop:
    cmp x21, x20
    b.ge pairs_done
    add x22, x21, #1     ; j

inner_pair_loop:
    cmp x22, x20
    b.ge next_pair_i

    ldr x0, [x9, x21, lsl #3]
    ldr x1, [x9, x22, lsl #3]
    sub x0, x0, x1
    mul x2, x0, x0

    ldr x0, [x10, x21, lsl #3]
    ldr x1, [x10, x22, lsl #3]
    sub x0, x0, x1
    madd x2, x0, x0, x2

    ldr x0, [x11, x21, lsl #3]
    ldr x1, [x11, x22, lsl #3]
    sub x0, x0, x1
    madd x2, x0, x0, x2

    str x2, [x12, x19, lsl #3]
    str x21, [x13, x19, lsl #3]
    str x22, [x14, x19, lsl #3]

    add x19, x19, #1
    add x22, x22, #1
    b inner_pair_loop

next_pair_i:
    add x21, x21, #1
    b outer_pair_loop

pairs_done:
    ret

connect_shortest:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    adrp x25, pair_dist@PAGE
    add x25, x25, pair_dist@PAGEOFF
    adrp x26, pair_a@PAGE
    add x26, x26, pair_a@PAGEOFF
    adrp x27, pair_b@PAGE
    add x27, x27, pair_b@PAGEOFF

    mov x21, #0          ; selected edge count

select_loop:
    cmp x21, #1000
    b.ge connect_done

    mov x22, #-1         ; best distance
    mov x23, #0          ; best pair index
    mov x24, #0          ; scan index

scan_pair_loop:
    cmp x24, x19
    b.ge selected_pair
    ldr x0, [x25, x24, lsl #3]
    cmp x0, x22
    b.hs next_scan_pair
    mov x22, x0
    mov x23, x24

next_scan_pair:
    add x24, x24, #1
    b scan_pair_loop

selected_pair:
    str xzr, [x25, x23, lsl #3]
    mov x0, #-1
    str x0, [x25, x23, lsl #3]
    ldr x0, [x26, x23, lsl #3]
    ldr x1, [x27, x23, lsl #3]
    bl union_points
    add x21, x21, #1
    b select_loop

connect_done:
    ldp x29, x30, [sp], #16
    ret

union_points:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x1
    bl find_root
    mov x20, x0
    mov x0, x19
    bl find_root
    cmp x20, x0
    b.eq union_done

    adrp x9, comp_size@PAGE
    add x9, x9, comp_size@PAGEOFF
    ldr x10, [x9, x20, lsl #3]
    ldr x11, [x9, x0, lsl #3]
    cmp x10, x11
    b.ge attach_second_to_first

    adrp x12, parent@PAGE
    add x12, x12, parent@PAGEOFF
    str x0, [x12, x20, lsl #3]
    add x11, x11, x10
    str x11, [x9, x0, lsl #3]
    b union_done

attach_second_to_first:
    adrp x12, parent@PAGE
    add x12, x12, parent@PAGEOFF
    str x20, [x12, x0, lsl #3]
    add x10, x10, x11
    str x10, [x9, x20, lsl #3]

union_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

find_root:
    adrp x9, parent@PAGE
    add x9, x9, parent@PAGEOFF

find_loop:
    ldr x10, [x9, x0, lsl #3]
    cmp x10, x0
    b.eq find_done
    mov x0, x10
    b find_loop

find_done:
    ret

product_top_three:
    mov x21, #0          ; top1
    mov x22, #0          ; top2
    mov x23, #0          ; top3
    mov x24, #0          ; index
    adrp x25, parent@PAGE
    add x25, x25, parent@PAGEOFF
    adrp x26, comp_size@PAGE
    add x26, x26, comp_size@PAGEOFF

top_loop:
    cmp x24, x20
    b.ge top_done
    ldr x0, [x25, x24, lsl #3]
    cmp x0, x24
    b.ne next_top
    ldr x1, [x26, x24, lsl #3]

    cmp x1, x21
    b.le check_top2
    mov x23, x22
    mov x22, x21
    mov x21, x1
    b next_top

check_top2:
    cmp x1, x22
    b.le check_top3
    mov x23, x22
    mov x22, x1
    b next_top

check_top3:
    cmp x1, x23
    b.le next_top
    mov x23, x1

next_top:
    add x24, x24, #1
    b top_loop

top_done:
    mul x0, x21, x22
    mul x0, x0, x23
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
    .asciz "input_8.txt"
open_error:
    .asciz "failed to open input_8.txt\n"

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
zs:
    .space 8192
parent:
    .space 8192
comp_size:
    .space 8192
pair_dist:
    .space 4000000
pair_a:
    .space 4000000
pair_b:
    .space 4000000
