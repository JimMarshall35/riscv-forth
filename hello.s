.include "defines.s"
.equ RAM_END, 0x88000000
.global _start	      # Provide program starting address


.section .text
_start:
    call main

main:
     li sp, RAM_END
     li a0, UART_BASE
     call initUart
     li a1, UART_BASE
#     li a0, '\n'
#     call putc
#     li a0, 'J'
#     call putc
#     li a0, 'i'
#     call putc
#     li a0, 'm'
#     call putc
#     li a0, '\n'
#     call putc

     la a0, helloworld
     call puts
 loop: 
#     li a0, UART_BASE
#     call getc_block
#     li t1, '\n'
#     beq a0, t1, 1f
#     li t1, '\r'
#     beq a0, t1, 1f
#     li a1, UART_BASE
#     call putc
#     j 2f
# 1: 
#     li a0, '\r'
#     li a1, UART_BASE
#     call putc
#     li a0, '\n'
#     li a1, UART_BASE
#     call putc
# 2:
# 3:
    call outer_interpreter
    j loop
    
    ret
 

.section .data
helloworld: .string "Hello World!\n"

