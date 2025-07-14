

.include "defines.s"
.global outer_interpreter
.section .data
.equ DataStackSize, 128

.equ OIState_WaitingForLine,   0
.equ OIState_InterpretingLine, 1
.equ OuterInterpreterErrorBufferSize, 256
.equ LineInputBufSize, 256
.equ TokenBufSize, 32 

dictionaryListHead: .word 0
dictionaryListTail: .word 0
vmflags: .word 0
dictTop: .word _dataEnd + DataStackSize
dataStackPtr: .word _dataEnd
outerInterpreterErrorBuf: .skip OuterInterpreterErrorBufferSize,0
lineInputBuf: .skip LineInputBufSize, 0
tokenBuffer:  .skip TokenBufSize, 0
lineInputParsePointer: .word 0 # points to the next token to be loaded
OIState: .word OIState_WaitingForLine # outer interpreter state. We wait for a line to be input with "\n" 
string_msg: .string "lololol\n"

.section .text

init_vm:
    li t0, OIState_WaitingForLine
    la t1, OIState
    sw t0, 0(t1)
    call init_dict
    ret

init_dict:
    
    ret

outer_interpreter_error_handler:
    la a0, outerInterpreterErrorBuf
    li a1, UART_BASE
    call puts
1:   
    j 1b
    ret

outer_interpreter_fatal_error:
    # Args:
    # a0 - error string
    la a1, outerInterpreterErrorBuf
    li a2, OuterInterpreterErrorBufferSize
    call strcpy_max
    call outer_interpreter_error_handler
    ret
    
outer_interpreter_waitingForLine:
    SaveReturnAddress
1:
    li a0, UART_BASE
    call getc_block
    li t0, '\r' 
    beq a0, t0, newline_entered

    la t0, lineInputParsePointer
    lw t1, 0(t0)
    mv t2, t1
    addi t2, t2, 1
    li t3, LineInputBufSize
    beq t3, t2, 2f # new char can't fit
    la t3, tokenBuffer # t3 = ptr to where new char goes
    add t3, t3, t1 # old line InputParsePtr value 
    sw a0, 0(t3) # store char
    sw t2, 0(t0) # store incremented size

    li a1, UART_BASE
    call putc
    j 2f
newline_entered:
    li a0, '\r'
    li a1, UART_BASE
    call putc
    li a0, '\n'
    li a1, UART_BASE
    call putc
    la t0, OIState
    li t1, OIState_InterpretingLine
    sw t1, 0(t0)
    la t0, lineInputParsePointer
    sw zero, 0(t0)
    j 3f
2:
    j 1b
3:
    RestoreReturnAddress
    ret



byte_at_parse_pointer:
    # Returns:
    # a0 - byte at parse ptr
    SaveReturnAddress
    PushReg t0
    PushReg t1
    la t1, lineInputBuf
    la t0, lineInputParsePointer
    lw t0, 0(t0)
    add t1, t1, t0
    lb a0, 0(t1)
    PopReg t1
    PopReg t0
    RestoreReturnAddress
    ret

incr_parsepointer:
    SaveReturnAddress
    PushReg t0
    PushReg t1
    la t0, lineInputParsePointer
    lw t0, 0(t0)
    addi t0, t0, 1
    la t1, lineInputParsePointer
    sw t0, 0(t1) 
    PushReg t0
    PushReg t1
    RestoreReturnAddress
    ret

is_whitespace:
    # Args:
    # a0 - char
    # a1 - 1 if whitespace 0 if not
    SaveReturnAddress
    PushReg t1
    li t1, ' '
    beq a0, t1, iswhitespace
    li t1, '\n'
    beq a0, t1, iswhitespace
    li t1, '\t'
    beq a0, t1, iswhitespace
    li t1, '\r'
    beq a0, t1, iswhitespace
    j isnotWhitespace
iswhitespace:
    li a1, 1
    j 1b
isnotWhitespace:
    li a1, 0
1:
    PopReg t1
    RestoreReturnAddress
    ret


load_next_token:
    # Returns:
    # a0 - 1 if token loaded, 0 if not
    SaveReturnAddress
    li t3, 0
    li t4, 0
    la t5, tokenBuffer
lt_loop_start:
    
    call byte_at_parse_pointer
    call is_whitespace
    beq a1, zero, 1f
    # is whitespace
    bne t3, zero, 2f
    call incr_parsepointer
    
    j lt_loop_start
1:
    # not whitespace
    li t3, 1
    beqz a0, 2f
    add t6, t5, t4
    sb a0, 0(t6)
    addi t4, t4, 1
    j lt_loop_start
2:
    add t6, t5, t4
    sb zero, 0(t6)

    RestoreReturnAddress
    ret

outer_interpreter_interpretingLine:
    SaveReturnAddress
    la a0, string_msg
    li a1, UART_BASE
    call puts 
1:
    call load_next_token
    beqz a0, 2f
    # new token loaded in buffer
    la a0, tokenBuffer
    li a1, UART_BASE
    call puts 
    j 1b
2:
    la t0, OIState
    li t1, OIState_WaitingForLine
    sw t1, 0(t0)
    la t0, lineInputParsePointer

    sw zero, 0(t0)
    RestoreReturnAddress
    ret

outer_interpreter:
    SaveReturnAddress
1:
    la t0, OIState
    lw t1, 0(t0)
    li t2, OIState_WaitingForLine
    beq t2, t1, OI_WaitingForLine
    li t2, OIState_InterpretingLine
    beq t2, t1, OI_DoingLine
OI_WaitingForLine:
    la a0, lineInputBuf
    li a1, 0
    li a2, LineInputBufSize
    call memset
    call outer_interpreter_waitingForLine
    j 2f
OI_DoingLine:
    call outer_interpreter_interpretingLine
2:
    j 1b

    RestoreReturnAddress
    ret 

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


.equ WordNameBufLen, 32

.macro WordHeader name, immediate
\name :

    1:
    .ascii "\name"
2:
    .iflt WordNameBufLen - (2b - 1b)
    .error "String too long"
    .endif

    .ifgt WordNameBufLen - (2b - 1b)
    .zero WordNameBufLen - (2b - 1b)
    .endif
    #bIsImmediate: 
    .word \immediate
    #next:
    .word 0
    #prev:
    .word 0

.endm

.equ SizeofWordHeader, (WordNameBufLen + (4*3))

.equ Header_Name_Offset,        0
.equ Header_IsImmediate_Offset, 32 
.equ Header_Next_Offset,        32 
.equ Header_Prev_Offset,        32 

.section .data

WordHeader "create", 0 
Word_impl:
    SaveReturnAddress
    la t0, dataStackPtr
    mv t1, t0
    lw t0, 0(t0)
    addi t0, t0, SizeofWordHeader
    sw t0, 0(t1)
    RestoreReturnAddress
    ret
