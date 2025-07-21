.include "defines.s"

#define VM_STACK_BOUNDS_CHECK


    # IMPORTANT! REGISTERS USED BY THE INTERPRETER:

    # Until I can get C Style defines to work you'll just have to read this, assembler.
    # The following registers must not be touched:

    # s0 - instruction pointer
    # s1 - data stack base pointer
    # s2 - data stack size
    # s3 - return stack base pointer
    # s4 - return stack size


.global vm_init

.equ CELL_SIZE, 4
.equ DATA_STACK_MAX_SIZE, 32
.equ RETURN_STACK_MAX_SIZE, 64

.equ HEADER_NAME_BUF_SIZE, 32
.equ HEADER_CODE_BUF_SIZE, 32

.equ DATA_STACK_MAX_SIZE_BYTES, (DATA_STACK_MAX_SIZE * CELL_SIZE)

.equ PC_REG, s0

.equ TOKEN_BUFFER_MAX_SIZE, 32
.equ LINE_BUFFER_MAX_SIZE, 128


.data

starting_interpreter_string: .ascii "starting outer interpreter...\n\0"
waiting_for_key_str: .ascii "waiting for key string...\n\0"

error_msg_stack_overflow:  .ascii "data stack overflow\n\0"
error_msg_stack_underflow: .ascii "data stack underflow\n\0"
error_msg_return_stack_overflow:  .ascii "return stack overflow\n\0"
error_msg_return_stack_underflow: .ascii "return stack underflow\n\0"


vm_data_stack: .fill DATA_STACK_MAX_SIZE, CELL_SIZE, 0      # 32 cell stack size
vm_return_stack: .fill RETURN_STACK_MAX_SIZE, CELL_SIZE, 0  # 64 cell return stack size

# dictionary
vm_p_dictionary_start: .word 0
vm_p_dictionary_end: .word 0


vm_str_error_message: .word 0

.macro StackSizeElements regSize, regTemp, regOut
li \regTemp, CELL_SIZE
div \regOut, \regSize, \regTemp 
.endm


.macro PushStack regBase, regSize, regVal

    add t0, \regBase, \regSize
    sw \regVal, 0(t0)
    addi \regSize, \regSize, CELL_SIZE
.endm

.macro PopStack regBase, regSize, regOutVal
    addi \regSize, \regSize, -CELL_SIZE
    add t0, \regBase, \regSize
    lw \regOutVal, 0(t0)
.endm
#     s0 - instruction pointer
#     s1 - data stack base pointer
#     s2 - data stack size
#     s3 - return stack base pointer
#     s4 - return stack size

.macro PushDataStack regVal
    PushStack s1, s2, \regVal
.endm

.macro PopDataStack regOutVal
    PopStack s1, s2, \regOutVal
.endm

.macro PushReturnStack regVal
    PushStack s3, s4, \regVal
.endm

.macro PopReturnStack regOutVal
    PopStack s3, s4, \regOutVal
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

.macro secondary_word name
    PushReturnStack s0
    la s0, \name\()_ThreadBegin
    lw t0, 0(s0)
    jalr ra, t0, 0
\name\()_ThreadBegin:
.endm

.equ OFFSET_NAME, 0
.equ OFFSET_CODE, HEADER_NAME_BUF_SIZE
.equ OFFSET_NEXT, (HEADER_NAME_BUF_SIZE + HEADER_CODE_BUF_SIZE)
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
    la s1, vm_data_stack
    li s2, 0
    la s3, vm_return_stack
    la s4, 0

    la t0, lineBufferSize_data
    sw zero, 0(t0)

    la t0, tokenBufferSize_data
    sw zero, 0(t0)

    la a0, lineBuffer_data
    li a1, 0
    li a2, LINE_BUFFER_MAX_SIZE
    call memset

    la a0, tokenBuffer_data
    li a1, 0
    li a2, TOKEN_BUFFER_MAX_SIZE
    call memset

    call outerInterpreter_impl

    RestoreReturnAddress
    ret

.macro end_word
    addi s0, s0, CELL_SIZE
    lw t0, 0(s0)
    jalr ra, t0, 0
.endm

# Following 2 macros used to calculate branch labels within pre-compiled secondary words
.macro CalcBranchBackToLabel label
    # ASSUMES THAT 1b IS A LABEL TO THE BRANCH OR BRANCHZERO IMPLEMENTATION POINTER
    .word - (( 1b - \label ) + 1 * CELL_SIZE)
.endm

.macro CalcBranchForwardToLabel label
    # ASSUMES THAT 1b IS A LABEL TO THE BRANCH OR BRANCHZERO IMPLEMENTATION POINTER
    .word (( \label - 1b) - 1 * CELL_SIZE)
.endm


word_header_first emit,   emit,     0, key
    PopDataStack a0
    li a1, UART_BASE
    call putc
    end_word

word_header       key,    key,      0, tokenBuffer, emit
    li a0, UART_BASE
    call getc_block         # char in a0
    PushDataStack a0
    end_word

word_header tokenBuffer, tokenbuffer, 0, lineBuffer, key
    la t1, tokenBuffer_data
    PushDataStack t1
    end_word
tokenBuffer_data:
    .fill TOKEN_BUFFER_MAX_SIZE, 1, 0
                                           
word_header lineBuffer, lineBuffer, 0, lineBufferSize, tokenBuffer
    la t1, lineBuffer_data
    PushDataStack t1
    end_word
lineBuffer_data:
    .fill LINE_BUFFER_MAX_SIZE, 1, 0

word_header lineBufferSize, lineBufferSize, 0, loadCell, lineBuffer
    la t1, lineBufferSize_data
    PushDataStack t1
    end_word
lineBufferSize_data:
    .word
    
word_header loadCell, @, 0, store, lineBufferSize
    PopDataStack t2
    lw t3, 0(t2)
    PushDataStack t3
    end_word

word_header store, !, 0, loadByte, loadCell
    PopDataStack t2
    PopDataStack t3
    sw t3, 0(t2)
    end_word
    
word_header loadByte, c@, 0, storeByte, store
    PopDataStack t2
    lb t3, 0(t2)
    PushDataStack t3
    end_word

word_header storeByte, c!, 0, branchIfZero, loadByte
    PopDataStack t2
    PopDataStack t3
    sb t3, 0(t2)
    end_word

word_header branchIfZero, b0, 0, branch, storeByte
    PopDataStack t2
    mv t1, s0 # s0 == PC
    beq t2, zero, 1f
    # no branch
    addi s0, s0, CELL_SIZE # skip over literal
    j 2f
1:
    addi t1, t1, CELL_SIZE # get literal
    lw t1, 0(t1)
    add s0, s0, t1         # add literal to PC
2:
    end_word

word_header branch, b, 0, forth_add, branchIfZero
    mv t1, s0
    addi t1, t1, CELL_SIZE # get literal
    lw t1, 0(t1)
    add s0, s0, t1         # add literal to PC
    end_word

word_header forth_add, +, 0, outerInterpreter, branch
    PopDataStack t2
    PopDataStack t3
    add t2, t2, t3
    PushDataStack t2
    end_word

word_header outerInterpreter, outerInterpreter, 0, literal, forth_add
    secondary_word outerInterpreter
 outer_start:
    .word key_impl                      # ( char )
    .word dup_impl                      # ( char char )
    .word lineBufferSize_impl           # ( char char &lineBufferSize )
    .word loadCell_impl                 # ( char char lineBufferSize )
    .word lineBuffer_impl               # ( char char lineBufferSize lineBuffer )
    .word forth_add_impl                # ( char char lineBufferSize+lineBuffer )
    .word storeByte_impl                # ( char )
    .word dup_impl                      # ( char char )
    .word emit_impl                     # ( char )
    .word dup_impl                      # ( char char )
    .word literal_impl 
    .word 0x7f                          # ( char char 0x7f )
    .word forth_minus_impl              # ( char areEqual )
1:  .word branchIfZero_impl                  
    CalcBranchForwardToLabel backspace_entered
    .word literal_impl 
    .word 0xD                           # ( char 0xd )
    .word forth_minus_impl              # ( areEqual )
1:  .word branchIfZero_impl                  
    CalcBranchForwardToLabel enter_entered

    # increment lineBufferSize - a non-enter non-backspace character has been entered
    .word literal_impl
    .word 1
    .word lineBufferSize_impl
    .word loadCell_impl
    .word forth_add_impl
    .word lineBufferSize_impl
    .word store_impl

1:  .word branch_impl 
    CalcBranchBackToLabel outer_start
backspace_entered:
    # emit
    .word literal_impl 
    .word 8                             # ( 8 )     
    .word dup_impl                      # ( 8 8 )
    .word emit_impl                     # ( 8 )
    .word emit_impl                     # ( )
    .word literal_impl
    .word 32                            # ( 32 )
    .word dup_impl                      # ( 8 8 )
    .word emit_impl                     # ( 8 )
    .word emit_impl                     # ( )
    .word literal_impl 
    .word 8                             # ( 8 )
    .word dup_impl                      # ( 8 8 )
    .word emit_impl                     # ( 8 )
    .word emit_impl                     # ( )

    # decrement lineBufferSize
    .word lineBufferSize_impl           # ( &lineBufferSize )
    .word dup_impl                      # ( &lineBufferSize &lineBufferSize )
    .word loadCell_impl                 # ( &lineBufferSize lineBufferSize )
    .word literal_impl
    .word 1                             # ( &lineBufferSize lineBufferSize 1 )
    .word forth_minus_impl              # ( &lineBufferSize newLineBufferSize )
    .word swap_impl                     # ( newLineBufferSize &lineBufferSize )
    .word store_impl                    # ( )
1:  .word branch_impl 
    CalcBranchBackToLabel outer_start
enter_entered:
    .word literal_impl 
    .word 10                            # ( 10 )
    .word emit_impl                     # ( )

    .word lineBuffer_impl               # ( lineBuffer )
    .word lineBufferSize_impl           # ( lineBuffer &lineBufferSize )
    .word loadCell_impl                 # ( lineBuffer lineBufferSize )
    .word eval_impl                     # ( )
    .word literal_impl
    .word 0                             # ( 0 )
    .word lineBufferSize_impl           # ( 0 &lineBufferSize )
    .word store_impl                    # ( )
1:  .word branch_impl 
    CalcBranchBackToLabel outer_start

word_header literal, literal, 0, dup, outerInterpreter
    addi s0, s0, CELL_SIZE
    lw t3, 0(s0)
    PushDataStack t3
    end_word

word_header dup, dup, 0, tokenBufferSize, literal
    PopDataStack t2
    PushDataStack t2
    PushDataStack t2
    end_word

word_header tokenBufferSize, tokenBufferSize, 0, return, dup
    la t1, tokenBufferSize_data
    PushDataStack t1
    end_word
tokenBufferSize_data:
    .word
    
word_header return, return, 0, forth_minus, tokenBufferSize
    PopReturnStack s0
    end_word

word_header forth_minus, -, 0, swap, return
    PopDataStack t2
    PopDataStack t3
    sub t3, t3, t2
    PushDataStack t3
    end_word
    
word_header swap, swap, 0, eval, forth_minus
    PopDataStack t2
    PopDataStack t3
    PushDataStack t2
    PushDataStack t3
    end_word


word_header eval, eval, 0, drop, swap
    secondary_word eval
    # mock eval implementation
    .word drop_impl
    .word drop_impl
    .word return_impl


word_header_last drop, drop, 0, eval
    PopDataStack t1
    end_word