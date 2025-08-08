.global strcpy_max
.global memset
.global memcpy
.global strcmp_fs_cs
.global strlen
.global strcmp
.global print_forth_string
.global fatoi
.global itofa
.global forth_string_to_c

.section .data

itofa_hex_LUT: .ascii "0123456789abcdef"

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
    #SaveReturnAddress
    #j c_fs_notequal
    mv t6, ra
    mv t4, a1
    mv t5, a0


    call strlen


    mv a0, t5
    bne a1, a2, c_fs_notequal
    mv a1, t4
    li t0, 0
1:
    mv t1, a0
    mv t2, a1
    add t1, t1, t0
    add t2, t2, t0
    lb t1, 0(t1)
    lb t2, 0(t2)
    bne t1, t2, c_fs_notequal
    addi t0, t0, 1
    bne t0, a2, 1b
c_fs_equal:
    li a3, 1
    mv ra, t6
    #RestoreReturnAddress
    ret
c_fs_notequal:
    li a3, 0
    mv ra, t6
    #RestoreReturnAddress
    ret

fatoi_error_msg: .ascii "fatoi error\n\0"
fatoi_error_msg_malformed: .ascii "fatoi error malformed string. '-' must be at end\n\0"
fatoi_error_msg_invalid: .ascii "fatoi error invalid chars\n\0"

fatoi:
    # Args:
    # a0 - forth string
    # a1 - string length
    # Returns:
    # a2 - converted num
    SaveReturnAddress
    li a2, 0
    blt a1, zero, fatoi_end
    beq a1, zero, fatoi_end
    # length > 0
    li t0, 1  # t0 = order of magnitude
    addi a1, a1, -1
1:
    add t1, a1, a0 # t1 points to end of string
    lb t1, 0(t1)   # deref byte at end of string
    
    li t2, '-'
    beq t1, t2, fatoi_minus

    la t3, fatoi_error_msg_invalid
    li t2, '0'
    blt t1, t2, fatoi_error_end
    li t2, '9'
    bgt t1, t2, fatoi_error_end
    
    li t2, '0'       
    sub t1, t1, t2 # convert from ascii to a number from 0-9
    mul t1, t1, t0 # multiply by order of magnitude
    add a2, a2, t1 # add to total
    li t2, 10
    mul t0, t0, t2 # increase order of magnitude
    j fatoi_minus_end
fatoi_minus:
    li t2, -1
    mul a2, a2, t2
    la t3, fatoi_error_msg_malformed
    bne a1, zero, fatoi_error_end
fatoi_minus_end:
    beq a1, zero, 2f
    addi a1, a1, -1
    j 1b
2:
fatoi_end:
    RestoreReturnAddress
    ret
fatoi_error_end:
    # report error
    mv a0, t3
    li a1, UART_BASE
    call puts
    RestoreReturnAddress
    ret

abs:
    # Args:
    # a0 - integer
    # Returns:
    # a0 - integer
    SaveReturnAddress
    li t0, 0
    blt a0, t0, 1f
    RestoreReturnAddress
    ret
1:
    li t0, -1
    mul a0, a0, t0
    RestoreReturnAddress
    ret

num_chars_required:
    # Args:
    # a0 - integer
    # Return:
    # a1 - outNumChars
    # Note:
    # Expects that a0 > 0
    SaveReturnAddress

    li a1, 1
1:
    li t0, 10
    blt a0, t0, num_between_0_and_9
    addi a1, a1, 1
    div a0, a0, t0
    j 1b
num_between_0_and_9:

    RestoreReturnAddress
    ret

itofa:
    # Args:
    # a0 - integer
    # a1 - outBuf
    # a2 - outBufMaxSize
    SaveReturnAddress
    la t0, vm_flags
    lw t0, 0(t0)
    andi t0, t0, 8 # NUM_IO_HEX_BIT
    beq t0, zero, decimal_io
hex_io:
    call itofa_hex
    j num_io_end
decimal_io:
    call itofa_dec
num_io_end:
    RestoreReturnAddress
    ret

itofa_hex:
    # Args:
    # a0 - integer
    # a1 - outBuf
    # a2 - outBufMaxSize
    SaveReturnAddress
    li t0, '0'
    sb t0, 0(a1)
    li t0, 'x'
    sb t0, 1(a1)

    la t2, itofa_hex_LUT

    srli t1, a0, 28
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 2(a1)

    srli t1, a0, 24
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 3(a1)

    srli t1, a0, 20
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 4(a1)

    srli t1, a0, 16
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 5(a1)

    srli t1, a0, 12
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 6(a1)

    srli t1, a0, 8
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 7(a1)

    srli t1, a0, 4
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 8(a1)

    mv t1, a0
    andi t0, t1, 0xf
    add t0, t0, t2
    lb t0, 0(t0)
    sb t0, 9(a1)

    sb zero, 10(a1)

    RestoreReturnAddress
    ret


itofa_dec:
    # Args:
    # a0 - integer
    # a1 - outBuf
    # a2 - outBufMaxSize
    SaveReturnAddress
    
    li t0, 0
    blt a0, t0, itofa_neg
itofa_pos:
    li t6, 0   # t6 == do we add the '-' sign at start of string
    j 1f
itofa_neg:
    li t6, 1
    call abs
1:
    # by here a0 is > 0
    mv t1, a0
    mv t2, a1
    call num_chars_required
    mv t3, a1        # t3 = number of chars required
    add t3, t3, t6   # possibly add 1 for the - sign
    mv a0, t1        # restore a0
    mv a1, t2        # restore a1
    add t1, t3, a1   # t1 - ptr for zero terminator
    sb zero, 0(t1)   # store zero at end
    addi t3, t3, -1  # -1 to get index of last char  
1:
    li t0, 10
    rem t1, a0, t0   # t1 = a0 % 10  
    addi t1, t1, '0' # t1 = char
    add t0, a1, t3   # t0 = ptr to write char to
    sb t1, 0(t0)     # store byte at char
    li t0, 10        # 
    blt a0, t0, 2f   # terminate loop if a0 < 10
    div a0, a0, t0   # a0 /= 10
    addi t3, t3, -1  # t3-- . move write index 1 to the left
    j 1b             # 
2:
    bgt t6, zero, add_neg_sign
    j add_neg_sign_end
add_neg_sign:
    li t0, '-'
    sb t0, 0(a1)
add_neg_sign_end:

    RestoreReturnAddress
    ret

forth_string_to_c:
    # Args:
    # a0 - outCStringBuf
    # a1 - inString
    # a2 - inStringLen
    #SaveReturnAddress
    mv t2, a0
    mv t3, a1
    mv t4, a2
    
    li t1, 0
1:
    beq t1, a2, 2f
    lb t0, 0(a1)
    sb t0, 0(a0)
    addi a0, a0, 1
    addi a1, a1, 1
    addi t1, t1, 1
    j 1b
2:
    add t0, t2, t4
    sb zero, 0(t0)
    #RestoreReturnAddress
    ret