.include "defines.s"
.include "VmMacros.S"

.global emit_impl
.global key_impl
.global tokenBuffer_impl
.global loadCell_impl
.global store_impl
.global loadByte_impl
.global storeByte_impl
.global branchIfZero_impl
.global branch_impl
.global forth_add_impl
.global literal_impl
.global dup_impl
.global tokenBufferSize_impl
.global return_impl
.global forth_minus_impl
.global swap_impl
.global drop_impl
.global dup2_impl
.global findXT_impl
.global doWordFound_impl
.global flags_impl
.global setCompile_impl
.global setInterpret_impl
.global forth_and_impl
.global forth_or_impl
.global get_compile_bit_impl
.global forth_xor_impl
.global get_comment_bit_impl
.global comment_on_impl
.global comment_off_impl
.global here_impl
.global rot_impl
.global push_return_impl
.global pop_return_impl
.global setTokenLookupErrorFlag_impl
.global getTokenLookupErrorFlag_impl
.global unsetTokenLookupErrorFlag_impl
.global isCharValidNumber_impl
.global isStringValidNumber_impl
.global forth_fatoi_impl
.global show_impl
.global execute_impl
.global showR_impl
.global setHere_impl
.global return_stack_index_impl
.global getHeaderNext_impl
.global getHeaderPrev_impl
.global setHeaderPrev_impl
.global setHeaderNext_impl
.global getDictionaryEnd_impl
.global setDictionaryEnd_impl
.global tokenBufferToHeaderCode_impl
.global toCString_impl
.global compileWord_impl
.global endWord_impl
.global getHeaderImmediate_impl
.global setHeaderImmediate_impl
.global getXTHeader_impl
.global isXTImmediate_impl
.global setNumInputHex_impl
.global setNumInputDec_impl
.global equals_impl
.global notEquals_impl
.global lessThan_impl
.global greaterThan_impl

.global last_vm_word

#define VM_STACK_BOUNDS_CHECK
.global title_string
.global vm_flags
    # IMPORTANT! REGISTERS USED BY THE INTERPRETER:

    # Until I can get C Style defines to work you'll just have to read this, assembler.
    # The following registers must not be touched:

    # s0 - instruction pointer
    # s1 - data stack base pointer
    # s2 - data stack size
    # s3 - return stack base pointer
    # s4 - return stack size
    # s5 - memory top


.global vm_run


vm_flags: .word 0

vm_data_stack: .fill DATA_STACK_MAX_SIZE, CELL_SIZE, 0      # 32 cell stack size
vm_return_stack: .fill RETURN_STACK_MAX_SIZE, CELL_SIZE, 0  # 64 cell return stack size

vm_scratch_pad: .fill 64, 1, 0

# dictionary
vm_p_dictionary_start: .word 0
vm_p_dictionary_end: .word 0
vm_str_error_message: .word 0


starting_interpreter_string: .ascii "starting outer interpreter...\n\0"
waiting_for_key_str: .ascii "waiting for key string...\n\0"

error_msg_stack_overflow:  .ascii "data stack overflow\n\0"
error_msg_stack_underflow: .ascii "data stack underflow\n\0"
error_msg_return_stack_overflow:  .ascii "return stack overflow\n\0"
error_msg_return_stack_underflow: .ascii "return stack underflow\n\0"

.equ ERROR_MSG_TOKEN_LEN, 8
.equ ERROR_MSG_NOTFOUND_LEN, 12
error_msg_token: .ascii "token: '\0"
error_msg_not_found: .ascii "' not found\n\0"

show_data_stack_begin_str:   .ascii "data   [ \0"
show_return_stack_begin_str: .ascii "return [ \0"
show_comma_sep_str:          .ascii ", \0"
show_stack_end_str:          .ascii " ]\n\0"

title_string: .string "Risc V Forth\n"



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

vm_run:
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
    li s4, 0

    la t0, tokenBufferSize_data
    sw zero, 0(t0)

    la a0, tokenBuffer_data
    li a1, 0
    li a2, TOKEN_BUFFER_MAX_SIZE
    call memset

    la s5, _dataEnd

    la s0, outerInterpreter_impl
    call outerInterpreter_impl

    RestoreReturnAddress
    ret

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

word_header tokenBuffer, tokenbuffer, 0, loadCell, key
    la t1, tokenBuffer_data
    PushDataStack t1
    end_word
tokenBuffer_data:
    .fill TOKEN_BUFFER_MAX_SIZE, 1, 0
                                           
word_header loadCell, @, 0, store, tokenBuffer
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

word_header forth_add, +, 0, literal, branch
    PopDataStack t2
    PopDataStack t3
    add t2, t2, t3
    PushDataStack t2
    end_word
    
word_header literal, literal, 0, dup, forth_add
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
    .word 0
    
word_header return, "r", 0, forth_minus, tokenBufferSize
    PopReturnStack s0
    end_word

word_header forth_minus, -, 0, swap, return
    PopDataStack t2
    PopDataStack t3
    sub t3, t3, t2
    PushDataStack t3
    end_word
    
word_header swap, swap, 0, drop, forth_minus
    PopDataStack t2
    PopDataStack t3
    PushDataStack t2
    PushDataStack t3
    end_word

word_header drop, drop, 0, dup2, swap
    PopDataStack t1
    end_word
    
word_header dup2, 2dup, 0, findXT, drop
    PopDataStack t1
    PopDataStack t2
    PushDataStack t2
    PushDataStack t1
    PushDataStack t2
    PushDataStack t1
    end_word
    
word_header findXT, findXT, 0, forth_and, dup2
    PopDataStack t5   # t5 == string ptr
    PopDataStack t6   # t6 == string length
    
    la t4, vm_p_dictionary_end
    lw t4, 0(t4)
1:
    word_code t4, t2

    mv a0, t2
    mv a1, t5
    mv a2, t6
    
    PushReg t4
    PushReg t5
    PushReg t6

    call strcmp_fs_cs

    PopReg t6
    PopReg t5
    PopReg t4
    
    bne a3, zero, 3f # its a match! 
    lw t1, OFFSET_PREV(t4)
    beq t1, zero, 2f
    mv t4, t1
    j 1b
2: 
    PushDataStack zero
    end_word
3:
    addi t4, t4, HEADER_SIZE
    PushDataStack t4
    end_word          
    
word_header forth_and, "and", 0, forth_or, findXT
    PopDataStack t2
    PopDataStack t3
    and t2, t2, t3
    PushDataStack t2
    end_word

word_header forth_or, "or", 0, forth_xor, forth_and
    PopDataStack t2
    PopDataStack t3
    or t2, t2, t3
    PushDataStack t2
    end_word

word_header forth_xor, "xor", 0, here, forth_or
    PopDataStack t2
    PopDataStack t3
    xor t2, t2, t3
    PushDataStack t2
    end_word
    
word_header here, here, 0, rot, forth_xor
    PushDataStack s5
    end_word

word_header rot, rot, 0, push_return, here
    PopDataStack t1
    PopDataStack t2
    PopDataStack t3
    PushDataStack t2
    PushDataStack t1
    PushDataStack t3
    end_word
    
word_header push_return, ">R", 0, pop_return, rot
    PopDataStack t1
    PushReturnStack t1
    end_word

word_header pop_return, "<R", 0, forth_fatoi, push_return
    PopReturnStack t1
    PushDataStack t1
    end_word

word_header forth_fatoi, "$", 0, show, pop_return
    # ( buffer size -- num )
    PopDataStack a1
    PopDataStack a0
    call fatoi
    PushDataStack a2
    end_word

word_header show, show, 0, execute, forth_fatoi
    # DATA STACK
    la a0, show_data_stack_begin_str
    li a1, UART_BASE
    call puts

    mv t1, s1               # t1 = data stack ptr
    mv t2, s2               # t2 = data stack size
    beq t2, zero, data_stack_empty
    add t3, t1, t2          # t3 = pointer end point
    li t0, CELL_SIZE
    sub t4, t3, t0 # penultimate pointer value
1:
    lw t0, 0(t1)

    PushReg t1
    PushReg t3
    PushReg t4

    mv a0, t0
    la a1, vm_scratch_pad
    li a2, 64
    call itofa
    
    la a0, vm_scratch_pad
    li a1, UART_BASE
    call puts
    PopReg t4
    PopReg t3
    PopReg t1

    PushReg t3
    PushReg t1
    beq t1, t4, 2f  # skip comma if on last stack entry
    la a0, show_comma_sep_str
    li a1, UART_BASE
    call puts
2:
    PopReg t1
    PopReg t3
    
    
    addi t1, t1, CELL_SIZE
    bne t1, t3, 1b

    la a0, show_stack_end_str
    li a1, UART_BASE
    call puts
    end_word
data_stack_empty:
    la a0, show_stack_end_str
    li a1, UART_BASE
    call puts
    end_word

word_header execute, execute, 0, showR, show
    PopDataStack t2
    jalr ra, t2, 0
    end_word         # should never be hit


word_header showR, showR, 0, setHere, execute
    # RETURN STACK
    la a0, show_return_stack_begin_str
    li a1, UART_BASE
    call puts

    mv t1, s3               # t1 = data stack ptr
    mv t2, s4               # t2 = data stack size
    beq t2, zero, return_stack_empty
    add t3, t1, t2          # t3 = pointer end point
    li t0, CELL_SIZE
    sub t4, t3, t0 # penultimate pointer value
1:
    lw t0, 0(t1)

    PushReg t1
    PushReg t3
    PushReg t4

    mv a0, t0
    la a1, vm_scratch_pad
    li a2, 64
    call itofa
    
    la a0, vm_scratch_pad
    li a1, UART_BASE
    call puts
    PopReg t4
    PopReg t3
    PopReg t1

    PushReg t3
    PushReg t1
    beq t1, t4, 2f  # skip comma if on last stack entry
    la a0, show_comma_sep_str
    li a1, UART_BASE
    call puts
2:
    PopReg t1
    PopReg t3
    
    
    addi t1, t1, CELL_SIZE
    bne t1, t3, 1b

    la a0, show_stack_end_str
    li a1, UART_BASE
    call puts
    end_word
return_stack_empty:
    la a0, show_stack_end_str
    li a1, UART_BASE
    call puts
    end_word

word_header setHere, setHere, 0, return_stack_index, showR
    PopDataStack s5
    end_word

word_header return_stack_index, R[], 0, getDictionaryEnd, setHere
    PopDataStack t3
    bgt t3, zero, invalid_rstack_index
    mv t0, s3 # s3 - return stack base pointer
    mv t1, s4 # s4 - return stack size
    addi t1, t1, -CELL_SIZE
    add t0, t0, t1 # t0 points to end of stack
    
    lw t4, 0(t0)

    li t2, CELL_SIZE
    mul t3, t3, t2
    add t3, t0, t3
    blt t3, s3, invalid_rstack_index
    PushDataStack t3
    end_word
invalid_rstack_index:
    li t3, 0
    PushDataStack t3
    end_word


word_header getDictionaryEnd, getDictionaryEnd, 0, setDictionaryEnd, return_stack_index
    # ( -- pDictEnd )
    la t1, vm_p_dictionary_end
    lw t1, 0(t1)
    PushDataStack t1
    end_word

word_header setDictionaryEnd, setDictionaryEnd, 0, toCString, getDictionaryEnd
    # ( pDictEndNew -- )
    PopDataStack t1
    la t0, vm_p_dictionary_end
    sw t1, 0(t0)
    end_word

word_header toCString, toCString, 0, setNumInputHex, setDictionaryEnd
    # ( inStringLen inString outCString -- )
    PopDataStack a0
    PopDataStack a1
    PopDataStack a2
    call forth_string_to_c
    end_word

word_header setNumInputHex, ioHex, 0, setNumInputDec, toCString
    la t1, vm_flags
    lw t0, 0(t1)
    ori t0, t0, NUM_IO_HEX_BIT
    sw t0, 0(t1)
    end_word


word_header setNumInputDec, ioDec, 0, equals, setNumInputHex
    la t1, vm_flags
    lw t0, 0(t1)
    li t2, NUM_IO_HEX_BIT
    xori t2, t2, -1
    and t0, t0, t2 # t0 &= ~NUM_IO_HEX_BIT
    sw t0, 0(t1)
    end_word

word_header equals, (=), 0, notEquals, setNumInputDec
    PopDataStack t1
    PopDataStack t2
    beq t1, t2, equals_equals
    PushDataStack zero
    j equals_end
equals_equals:
    li t1, 1
    PushDataStack t1
equals_end:
    end_word
    
word_header notEquals, (!=), 0, lessThan, equals
    PopDataStack t1
    PopDataStack t2
    bne t1, t2, nq_equals
    PushDataStack zero
    j nq_end
nq_equals:
    li t2, 1
    PushDataStack t2 
nq_end:
    end_word
    
word_header lessThan, <, 0, greaterThan, notEquals
    PopDataStack t1
    PopDataStack t2
    blt t2, t1, lt
    PushDataStack zero
    j lt_end
lt:
    li t2, 1
    PushDataStack t2
lt_end:
    end_word

last_vm_word: # IMPORTANT: KEEP THIS LABEL POINTING TO THE LAST VM WORD.
word_header greaterThan, >, 0, first_system_word, lessThan
    PopDataStack t1
    PopDataStack t2
    bgt t2, t1, gt
    PushDataStack zero
    j gt_end
gt:
    li t1, 1
    PushDataStack t1
gt_end:
    end_word

