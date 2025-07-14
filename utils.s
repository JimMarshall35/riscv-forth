.global strcpy_max
.global memset
.global memcpy

.section .text
.include "defines.s"
strcpy_max:
    # Args:
    # a0 - string src
    # a1 - string dst
    # a2 - max len
    SaveReturnAddress

    addi sp, sp, -16  # allocate 16 bytes on stack
    sw   ra, 12(sp)   # store return address on stack


    li t1, 0 # counter
    mv t2, a2
    addi t2, t2, -1
1:  
    
    lb t0, 0(a0)
    sb t0, 0(a1)
    addi a0, a0, 1
    addi a1, a1, 1
    
    addi t1, t1, 1
    beq t1, t2, 2f
    j 1b
2:
    li t0, '\0'
    sb t0, 0(a1)

    lw   ra, 12(sp)  # load return address from stack
    addi sp, sp, 16  # restore stack pointer

    RestoreReturnAddress
    ret

memcpy:
    # Args:
    # a0 - destination
    # a1 - src
    # a2 - length
    SaveReturnAddress
    li t0, 0
1:
    beq t0, a2, 2f

    add t1, a0, t0 # t1 = destination ptr
    add t2, a1, t0 # t2 = src ptr
    lb t3, 0(t2)
    sb t3, 0(t1)

    addi t0, t0, 1
    j 1b
2:

    RestoreReturnAddress
    ret

memset:
    # Args:
    # a0 - destination
    # a1 - val (byte)
    # a2 - length
    SaveReturnAddress
    li t0, 0
1:
    beq t0, a2, 2f
    add t1, a0, t0 # t1 = destination ptr
    sb a1, 0(t1)
    addi t0, t0, 1
    j 1b
2:

    RestoreReturnAddress
    ret