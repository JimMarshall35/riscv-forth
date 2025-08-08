.include "VmMacros.S"
.global LineBuffer_impl
.global LineBufferSize_impl
.global doBackspace_impl
.global outerInterpreter_impl
.text
word_header LineBuffer, LineBuffer, 0, LineBufferSize, 
    la t1, LineBuffer_data
    PushDataStack t1
    end_word
LineBuffer_data:
    .fill 128, 1, 0
    end_word


word_header LineBufferSize, LineBufferSize, 0, doBackspace, LineBuffer
    la t1, LineBufferSize_data
    PushDataStack t1
    end_word
LineBufferSize_data:
    .word 0
    end_word


word_header doBackspace, doBackspace, 0, outerInterpreter, LineBufferSize
    secondary_word doBackspace
    .word LineBufferSize_impl
    .word loadCell_impl
    .word literal_impl
    .word 0
    .word >_impl
    .word branchIfZero_impl
    CalcBranchForwardToLabel doBackspace_then_0_
    .word literal_impl
    .word 8
    .word literal_impl
    .word 8
    .word emit_impl
    .word emit_impl
    .word literal_impl
    .word 32
    .word literal_impl
    .word 32
    .word emit_impl
    .word emit_impl
    .word literal_impl
    .word 8
    .word literal_impl
    .word 8
    .word emit_impl
    .word emit_impl
    .word LineBufferSize_impl
    .word loadCell_impl
    .word literal_impl
    .word 1
    .word forth_minus_impl
    .word LineBufferSize_impl
    .word store_impl
doBackspace_then_0_:
    .word return_impl


word_header outerInterpreter, outerInterpreter, 0, , doBackspace
    secondary_word outerInterpreter
outerInterpreter_begin_0_:
    .word key_impl
    .word dup_impl
    .word literal_impl
    .word 14
    .word =_impl
    .word branchIfZero_impl
    CalcBranchForwardToLabel outerInterpreter_else_1_
    .word drop_impl
    .word eval_impl
    .word literal_impl
    .word 0
    .word LineBufferSize_impl
    .word store_impl
    .word branch_impl
    CalcBranchForwardToLabel outerInterpreter_then_5_
outerInterpreter_else_1_:
    .word dup_impl
    .word literal_impl
    .word 127
    .word =_impl
    .word branchIfZero_impl
    CalcBranchForwardToLabel outerInterpreter_else_2_
    .word drop_impl
    .word doBackspace_impl
    .word branch_impl
    CalcBranchForwardToLabel outerInterpreter_then_4_
outerInterpreter_else_2_:
    .word LineBufferSize_impl
    .word loadCell_impl
    .word literal_impl
    .word 127
    .word lessThan_impl
    .word branchIfZero_impl
    CalcBranchForwardToLabel outerInterpreter_then_3_
    .word LineBuffer_impl
    .word LineBufferSize_impl
    .word loadCell_impl
    .word forth_add_impl
    .word store_impl
    .word LineBufferSize_impl
    .word loadCell_impl
    .word literal_impl
    .word 1
    .word forth_add_impl
    .word LineBufferSize_impl
    .word store_impl
outerInterpreter_then_3_:
outerInterpreter_then_4_:
outerInterpreter_then_5_:
    .word literal_impl
    .word 1
    .word branchIfZero_impl
    CalcBranchBackToLabel outerInterpreter_begin_0_
    .word return_impl

