.global strcpy_max
.global memset
.global memcpy
.global strcmp_fs_cs
.global strlen
.global strcmp
.global print_forth_string

.section .text
.include "defines.s"

print_forth_string:
    # Args:
    # a0 - string
    # a1 - stringlen
    SaveReturnAddress
    mv t3, a0
    mv t4, a1
1:
    beq t4, zero, 2f
    lb a0, 0(t3)
    li a1, UART_BASE
    call putc
    addi t4, t4, -1
    addi t3, t3, 1
    j 1b
2:
    RestoreReturnAddress
    ret


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

strlen:
    # Args:
    # a0 - string
    # Returns:
    # a1 - length
    SaveReturnAddress
    li a1, 0
1:
    lw t0, 0(a0)
    beq t0, zero, 2f
    addi a1, a1, 1
    addi a0, a0, 1
    j 1b
2:
    RestoreReturnAddress
    ret

strcmp:
    # Args:
    # a0 - C string 1
    # a1 - C string 2
    # Returns:
    # a2 - 1 if string 1 contents == string 2 contents else 0
    SaveReturnAddress
    li a2, 0
    mv t0, a0
    mv t1, a1
    call strlen 
    mv t2, a1      # t2 == str1 length
    mv a0, t1
    call strlen
    mv t3, a1      # t3 == str2 length
    bne t2, t3, 1f   
    # lengths are equal
2:
    lw a0, 0(t0)
    lw a1, 0(t1)
    bne a0, a1, 1f
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bne t2, zero, 2b
    li a2, 1
1:
    
    RestoreReturnAddress
    ret


# Compare a forth string to a C string
strcmp_fs_cs:
    # Args:
    # a0 - C string 
    # a1 - F string 
    # a2 - F string length
    # Returns:
    # a3 - 1 if string 1 contents == string 2 contents else 0
    SaveReturnAddress
    li a3, 0
    mv t0, a0      # t0 == cstring
    mv t1, a1      # t1 == fstring
    mv t2, a2      # t2 == fstring length

    call strlen 
    mv t3, a1      # t3 == cstring length

    bne t2, t3, 1f   

    # lengths are equal
2:
    lw a0, 0(t0)
    lw a1, 0(t1)
    bne a0, a1, 1f
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bne t2, zero, 2b
    li a3, 1
1:
    
    RestoreReturnAddress
    ret