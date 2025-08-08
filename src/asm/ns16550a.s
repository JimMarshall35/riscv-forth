.include "defines.s"

.equ UART_REG_TRANSMIT, 0
.equ UART_REG_RECEIVE, 0
.equ UART_REG_FCR, 2
.equ UART_REG_LCR, 3 
.equ UART_REG_LSR, 5
.equ UART_REG_IER, 0x1

.equ UART_REG_FCF_FIFOENABLE, 1
.equ UART_REG_LCR_THRE, (1 << 5)
.equ UART_REG_LSR_DR, 1

.global puts
.global putc
.global getc
.global getc_block
.global initUart

.text

# "ns16550a compatible" UART DRIVER

initUart:
    # taken from https://github.com/safinsingh/ns16550a/tree/master
    # Args:
    # a0 - UART base address
    mv  t0, a0

    # 0x3 -> 8 bit word length
    li  t1, 0x3
    sb  t1, UART_REG_LCR(t0)

    # 0x1 -> enable FIFOs
    li  t1, 0x1
    sb  t1, UART_REG_LCR(t0)

    # 0x1 -> enable reciever interrupts
    sb  t1, UART_REG_IER(t0)
    ret

putc:
    # Args:
    # a0 - character to output
    # a1 - UART base address
    addi sp, sp, -16  # allocate 16 bytes on stack
    sw   ra, 12(sp)   # store return address on stack

.loopstart:
    lb t0, UART_REG_LCR(a1)
    andi t1, t0, UART_REG_LCR_THRE
    beqz t1, .ready
    j .loopstart
.ready:
    sb a0, UART_REG_TRANSMIT(a1)

    lw   ra, 12(sp)  # load return address from stack
    addi sp, sp, 16  # restore stack pointer
    ret

puts:
    # Args:
    # a0 - string address
    # a1 - UART base address
    # while string byte not null
    SaveReturnAddress
    mv t3, a0
1:
    lb t0, 0(t3)
    beq t0, zero, 2f
    mv a0, t0
    call putc
    addi t3, t3, 1
    j 1b
2:
    RestoreReturnAddress
    ret

getc_block:
    # Args:
    # a0 - UART base address
    # Returns:
    # a0 - char from uart
    SaveReturnAddress
    mv t0, a0
getc_block_loop_start:
    call getc
    beq a0, zero, notgotchar
    RestoreReturnAddress
    ret
notgotchar:
    mv a0, t0
    j getc_block_loop_start
    # should never get here
    RestoreReturnAddress
    ret

getc:
    # Args:
    # a0 - UART base address
    # Returns:
    # a0 - char from uart
    SaveReturnAddress
    add sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    lbu t0, UART_REG_LSR(a0)
    andi t1, t0, UART_REG_LSR_DR
    beq t1, zero, bytenotread
    j byteread
bytenotread:
    li a0, 0
    j end
byteread:
    lb a0, UART_REG_RECEIVE(a0)
end:
    lw t0, 0(sp)
    lw t1, 4(sp)
    add sp, sp, 8
    RestoreReturnAddress
    ret