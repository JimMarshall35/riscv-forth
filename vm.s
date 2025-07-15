.include "defines.s"

#define VM_STACK_BOUNDS_CHECK

.global vm_init

.equ CELL_SIZE, 4
.equ DATA_STACK_MAX_SIZE, 32
.equ RETURN_STACK_MAX_SIZE, 64

.equ HEADER_NAME_BUF_SIZE, 32
.equ HEADER_CODE_BUF_SIZE, 32

.equ DATA_STACK_MAX_SIZE_BYTES, (DATA_STACK_MAX_SIZE * CELL_SIZE)

.equ PC_REG, s0
.equ THREAD_REG, s1


.data

error_msg_stack_overflow:  .ascii "data stack overflow"
error_msg_stack_underflow: .ascii "data stack underflow"
error_msg_return_stack_overflow:  .ascii "return stack overflow"
error_msg_return_stack_underflow: .ascii "return stack underflow"


vm_data_stack: .fill DATA_STACK_MAX_SIZE, CELL_SIZE, 0      # 32 cell stack size
vm_return_stack: .fill RETURN_STACK_MAX_SIZE, CELL_SIZE, 0  # 64 cell return stack size

# data stack
vm_p_data_stack_base: .word 0
vm_data_stack_size: .word 0

# return stack
vm_p_return_stack_base: .word 0
vm_return_stack_size: .word 0

# dictionary
vm_p_dictionary_start: .word 0
vm_p_dictionary_end: .word 0


vm_str_error_message: .word 0

.macro StackSizeElements regSize, regTemp, regOut
li \regTemp, CELL_SIZE
div \regOut, \regSize, \regTemp 
.endm

.macro PushStack regBase, regSize, regVal
#ifdef VM_STACK_BOUNDS_CHECK
    li t0, DATA_STACK_MAX_SIZE_BYTES
    bge \regSize, t0, 1f
    j 2
1:
    l1 t0, vm_str_error_message
    la t1, error_msg_stack_underflow
    sw t1, 0(t0)
    call vm_error_handler
2:
#endif
    add \regBase, \regBase, \regSize
    sw \regVal, 0(\regBase)
    addi \regSize, \regSize, CELL_SIZE

.endm

.macro PopStack regBase, regSize, regOutVal
    addi \regSize, \regSize, -CELL_SIZE
#ifdef VM_STACK_BOUNDS_CHECK
    blt \regSize, \regBase, 1f
    j 2f
1:
    la t0, vm_str_error_message
    la t1, error_msg_stack_underflow
    sw t1, 0(t0)
    call vm_error_handler
2:
#endif
    add \regBase, \regBase, \regSize
    lw \regOutVal, 0(\regBase)
.endm



.macro padded_string string, max
1:
    .ascii "\string"
2:
    .iflt \max - (2b - 1b)
    .error "String too long"
    .endif

    .ifgt \max - (2b - 1b)
    .zero \max - (2b - 1b)
    .endif

.endm

# Imaginary C Struct - word header
#
# struct Header
# {
#     char name[HEADER_NAME_BUF_SIZE];       // the name that is used to generate assembler labels
#     char code[HEADER_CODE_BUF_SIZE];       // the code you write when you write forth 
#     struct Header* next;
#     struct Header* prev;
#     Cell bImmediate;
# }

.macro word_header_unitialised name, code, immediate
\name:
    padded_string \name, HEADER_NAME_BUF_SIZE
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word 0
    .word 0
    .word \immediate
\name\()_impl:
.endm

.macro word_header_last name, code, immediate, prev
\name:
    padded_string \name, HEADER_NAME_BUF_SIZE
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word 0
    .word \prev
    .word \immediate
\name\()_impl:
.endm


.macro word_header_first name, code, immediate, next
\name:
    padded_string \name, HEADER_NAME_BUF_SIZE
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word \next
    .word 0
    .word \immediate
\name\()_impl:
.endm

.macro word_header name, code, immediate, next, prev
\name:
    padded_string \name, HEADER_NAME_BUF_SIZE
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word \next
    .word \prev
    .word \immediate
\name\()_impl:
.endm

.equ OFFSET_NAME, 32
.equ OFFSET_CODE, 32
.equ OFFSET_NEXT, 64
.equ OFFSET_PREV, (64 + CELL_SIZE)
.equ OFFSET_IMM, (64 + 2*CELL_SIZE)

.macro word_next regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_NEXT
.endm

.macro word_prev regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_PREV
.endm

.macro word_imm regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_IMM
.endm

.macro word_name regPtrHeader, regPtrOut
    mv \regPtrOut, \regPtrHeader
.endm

.macro word_code regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_CODE
.endm

.text

vm_error_handler:
    li a1, UART_BASE
    la a0, vm_str_error_message
    lw a0, 0(a0)
    call puts
1:
    j 1b
    ret

find_dict_end:
    # Args:
    # a0 - ptr to first dict header
    # Returns:
    # a1 - ptr to last dict header
    SaveReturnAddress
1:
    word_next a0, t0
    lw t0, 0(t0)
    mv a1, a0
    mv a0, t0
    bne t0, zero, 1b
    RestoreReturnAddress
    ret

vm_init:
    SaveReturnAddress
    # init dictionary
    la t0, vm_p_dictionary_start
    la t1, emit
    sw t1, 0(t0)

    mv a0, t1
    call find_dict_end

    la t0, vm_p_dictionary_end
    sw a1, 0(t0)

    # init stacks
    la t0, vm_p_data_stack_base
    la t1, vm_data_stack
    sw t1, 0(t0)

    la t0, vm_p_return_stack_base
    la t1, vm_return_stack
    sw t1, 0(t0)
    
    RestoreReturnAddress
    ret

.macro end_word
    addi s0, s0, 1
    jal ra, vm_next
.endm

vm_next:
    li t1, CELL_SIZE
    mul t0, s0, t1
    add t0, s1, t0
    jalr ra, t0, 0
    ret

word_header_first emit,   emit,     0, key
    la t0, vm_data_stack
    la t1, vm_data_stack_size
    lw t1, 0(t1)
    PopStack t0, t1, a0
    li a1, UART_BASE
    call putc
    end_word

word_header       key,    key,      0, load, emit
    li a0, UART_BASE
    call getc_block
    
word_header_last  load,   "@",      0, key
