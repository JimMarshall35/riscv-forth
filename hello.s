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

    call vm_init

    li a1, UART_BASE
    la a0, helloworld
    call puts

 loop:
    j loop
    
    ret
 

.section .data
helloworld: .string "Hello World!\n"

