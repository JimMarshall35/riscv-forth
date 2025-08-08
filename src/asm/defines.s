.equ UART_BASE, 0x10000000

.macro SaveReturnAddress 
    addi sp, sp, -16  # allocate 16 bytes on stack
    sw   ra, 12(sp)   # store return address on stack
.endm

.macro RestoreReturnAddress
    lw   ra, 12(sp)  # load return address from stack
    addi sp, sp, 16  # restore stack pointer
.endm

.macro PushReg reg
    addi sp, sp, -4
    sw \reg, 0(sp)
.endm

.macro PopReg reg
    lw \reg, 0(sp)
    addi sp, sp, 4
.endm
