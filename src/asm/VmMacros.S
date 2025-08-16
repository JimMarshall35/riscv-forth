

.equ CELL_SIZE, 4
.equ DATA_STACK_MAX_SIZE, 32
.equ RETURN_STACK_MAX_SIZE, 64

.equ HEADER_NAME_BUF_SIZE, 32
.equ HEADER_CODE_BUF_SIZE, 32

.equ DATA_STACK_MAX_SIZE_BYTES, (DATA_STACK_MAX_SIZE * CELL_SIZE)


.equ TOKEN_BUFFER_MAX_SIZE, 32
.equ LINE_BUFFER_MAX_SIZE, 128


.data

# flags

.equ COMPILE_BIT, 1
.equ COMMENT_BIT, 2
.equ FIND_TOKEN_ERROR_BIT, 4
.equ NUM_IO_HEX_BIT, 8   # if not set, num io is decimal


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
#     s5 - memory top

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
#     char code[HEADER_CODE_BUF_SIZE];       // the code you write when you write forth 
#     struct Header* next;
#     struct Header* prev;
#     Cell bImmediate;
# }

.macro word_header_unitialised name, code, immediate
\name:
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word 0
    .word 0
    .word \immediate
\name\()_impl:
.endm

.macro word_header_last name, code, immediate, prev
\name:
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word 0
    .word \prev
    .word \immediate
\name\()_impl:
.endm


.macro word_header_first name, code, immediate, next
\name:
    padded_string \code, HEADER_CODE_BUF_SIZE
    .word \next
    .word 0
    .word \immediate
\name\()_impl:
.endm

.macro word_header name, code, immediate, next, prev
\name:
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

.equ OFFSET_CODE, 0
.equ OFFSET_NEXT, (HEADER_CODE_BUF_SIZE)
.equ OFFSET_PREV, (OFFSET_NEXT + CELL_SIZE)
.equ OFFSET_IMM, (OFFSET_PREV + CELL_SIZE)
.equ HEADER_SIZE, OFFSET_IMM + CELL_SIZE

.macro word_next regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_NEXT
.endm

.macro word_prev regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_PREV
.endm

.macro word_imm regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_IMM
.endm

.macro word_code regPtrHeader, regPtrOut
    addi \regPtrOut, \regPtrHeader, OFFSET_CODE
.endm

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
