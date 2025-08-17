#define CARRIAGE_RETURN_CHAR 13
#define NEWLINE_CHAR 10
#define ENTER_CHAR 127
#define BACKSPACE_CHAR 8
#define SPACE_CHAR 32
#define MINUS_CHAR 45

#define HEADER_SIZE 44
#define OFFSET_IMM 40
#define OFFSET_NEXT 32
#define OFFSET_PREV 36

#define CELL_SIZE 4

#define ASCII_NUM_RANGE_START 48

#define ASCII_NUM_RANGE_END 57

#define COMPILE_BIT 1

buf LineBuffer_ 128
var LineBufferSize_ 0

buf Tokenbuffer_ 32
var TokenBufferSize_ 0

var LineBufferI_ 0

var EvalErrorFlag_ 0

var flags 0

string LiteralStr_ "literal"

string ReturnStr_ "r"

string UnknownTokenStartStr_ "unknowntoken:'" ( TODO: needs compiler change to allow spaces within strings but not high priority )

string UnknownTokenEndStr_ "'\n"

string branch0TokenStr_ "b0"

string branchTokenStr_ "b"

string pushReturnStr_ ">R"

string popReturnStr_ "<R"

string addStr_ "+"

string twodupStr_ "2dup"

string equalsStr_ "="

string dropStr_ "drop"

( flags )

: setCompile ( -- ) flags @ COMPILE_BIT | flags ! ;

: setInterpret ( -- ) flags @ COMPILE_BIT -1 ^ & flags ! ;

: get_compile_bit ( -- 1or0 ) flags @ COMPILE_BIT & 0 > if 1 r then 0 ;

( loop counter functions )

: i ( -- i ) -2 R[] @ ;

: j ( -- j ) -4 R[] @ ;

( printing functions )

: print ( pString nStringSize -- )
    0 do
        dup i + c@ emit
    loop
    drop
;

: && ( bool1 bool2 -- 1IfBoth1Else0 ) 
    if
        ( bool2 is true )
        if
            ( bool 1 is true )
            1 r
        else
            0 r
        then
    else
        drop 0 r
    then
;

asm_name logic_and

: || ( bool1 bool2 -- 1IfEitherElse0 ) 
    if drop 1 r then
    if 1 r then
    0 r
;

asm_name logic_or

: logic_not ( bool -- !bool )
    if
        0
    else
        1
    then
;

: >= ( int1 int2 -- 1IfInt1>=Int2 )
    2dup = rot rot > ||
;

asm_name gte

: <= ( int1 int2 -- 1IfInt1>=Int2 )
    2dup = rot rot < ||
;

asm_name lte

: isCharNumeric ( char -- 1IfNumericElse0 )
    dup ASCII_NUM_RANGE_START >= swap ASCII_NUM_RANGE_END <= &&
;

: isStringValidNumber ( pString nStringSize -- 0ifNotValid )
    0 do
        i 0 = if
            dup ( pString pString )
            c@ dup ( pString char char )
            MINUS_CHAR =  ( pString char isMinusChar )
            swap isCharNumeric
            || logic_not if
                ( character is not '-' or 0-9 )
                drop
                <R <R drop drop  
                0
                r
            then
        else
            dup i + c@ isCharNumeric logic_not if
                drop
                <R <R drop drop
                0
                r
            then
        then
    loop
    drop
    1
;

: getHeaderNext ( pHeader -- pHeader->pNext ) OFFSET_NEXT + @ ; 

: getHeaderPrev ( pHeader -- pHeader->pPrev ) OFFSET_PREV + @ ; 

: setHeaderPrev ( pPrev pHeader -- ) OFFSET_PREV + ! ; 

: setHeaderNext ( pNext pHeader -- ) OFFSET_NEXT + ! ; 

: setHeaderImmediate ( bImm pHeader -- ) OFFSET_IMM + ! ;

: getHeaderImmediate ( pHeader -- pHeader->bImmediate ) OFFSET_IMM + @ ; 

: getXTHeader ( xt -- xtHeader ) HEADER_SIZE - ; 

: getXTImmediate ( xt -- 0IfNotImmediate ) getXTHeader getHeaderImmediate ;

: tokenBufferToHeaderCode ( buffer -- ) TokenBufferSize_ @ swap Tokenbuffer_ swap toCString ;

: , ( word2compile -- ) here ! here CELL_SIZE + setHere ;

asm_name cw

: c, ( byte2compile -- ) here c! here 1 + setHere ;

asm_name cbyte

: doToken  
    TokenBufferSize_ @ Tokenbuffer_ '
    ( either 0 on stack or an excution token )
    dup 0 != if
        ( we've found a valid xt )
        get_compile_bit 0 != if
            dup getXTImmediate if 
                execute
            else
                ,
            then
        else
            execute
        then
    else
        drop ( empty stack )
        ( pString nStringSize -- 0ifNotValid )
        Tokenbuffer_ TokenBufferSize_ @ isStringValidNumber ( 0ifNotValid )
        0 != if
            ( valid number string in token buffer )
            Tokenbuffer_ TokenBufferSize_ @ $  ( converted number on stack )
            get_compile_bit 0 != if
                LiteralStr_ ' , ( TODO: NEED TO IMPLEMENT STRING LITERALS IN COMPILER - WILL HAND EDIT IN )
                ,
            then
        else 
            ( not valid )
            1 EvalErrorFlag_ !
        then
    then 
;

: seekTokenStart ( -- 0or1 )
    begin
        LineBuffer_ LineBufferI_ @ + c@         ( char@I )
        dup SPACE_CHAR != swap NEWLINE_CHAR != && if
            0 r                                ( I points to something other than a space - there's a token to load return 0 )
        then
        LineBufferI_ @ 1 + LineBufferI_ !      ( increment line buffer I )
        LineBufferI_ @ LineBufferSize_ @ = if
            1 r                                ( end of line buffer reached, no next token to load )
        then
    0 until 
;

: loadToken ( -- )
    0 TokenBufferSize_ !
    begin
        LineBuffer_ LineBufferI_ @ + c@         ( char@I )
        LineBufferI_ @ LineBufferSize_ @ = if
            drop 
            0 Tokenbuffer_ TokenBufferSize_ @ + c! ( store '0' terminator at end of token buffer )
            r
        then
        dup
        SPACE_CHAR = if
            drop 
            0 Tokenbuffer_ TokenBufferSize_ @ + c! ( store '0' terminator at end of token buffer )
            r
        then
        ( char@I )
        Tokenbuffer_ TokenBufferSize_ @ + c!
        LineBufferI_ @ 1 + LineBufferI_ !
        TokenBufferSize_ @ 1 + TokenBufferSize_ !
    0 until 
;

: loadNextToken ( -- 0or1 )
    LineBufferI_ @ LineBufferSize_ @ = if
        1 r
    then
    seekTokenStart 1 = if
        1 r
    then
    loadToken 
    0
;

: eval_ ( -- )
    0 LineBufferI_ !
    0 TokenBufferSize_ !
    0 EvalErrorFlag_ !
    begin
        EvalErrorFlag_ @ 0 != if
            UnknownTokenStartStr_ swap print
            Tokenbuffer_ TokenBufferSize_ @ print
            UnknownTokenEndStr_ swap 1 - print     ( TODO: the compilers handling of strings needs to improve - something wrong with how it escapes characters here )
            r
        then
        loadNextToken     ( 0or1 )
        1 != if
            doToken
        else
            r
        then
    0 until 
;

: doBackspace
    LineBufferSize_ @ 0 > if
        BACKSPACE_CHAR emit
        SPACE_CHAR emit
        BACKSPACE_CHAR emit
        ( decrement line buffer size )
        LineBufferSize_ @ 1 - LineBufferSize_ !
    then 
;

: outerInterpreter
    0 LineBufferSize_ !
    begin
        key    ( key )
        dup
        CARRIAGE_RETURN_CHAR = if
            ( enter entered )
            drop           ( )
            NEWLINE_CHAR emit        ( emit newline char )
            eval_  
            0 LineBufferSize_ !
        else dup ENTER_CHAR = if
            ( backspace entered )
            drop
            doBackspace
        else
            ( some other key entered )
            ( key )
            LineBufferSize_ @
            ENTER_CHAR < if
                dup emit
                LineBuffer_ LineBufferSize_ c@ + !        ( store inputed key at current buffer position )
                LineBufferSize_ @ 1 + LineBufferSize_ !   ( increment LineBufferSize_ )
            then
        then
        then
    0 until 
;

: compileHeader ( -- pHeader )
    loadNextToken drop
    here here HEADER_SIZE + setHere
    ( pHeader )
    dup tokenBufferToHeaderCode
    dup getDictionaryEnd swap setHeaderPrev
    dup getDictionaryEnd setHeaderNext
    dup 0 swap setHeaderNext
;

: alignHere ( alignment -- )
    ( I know, you don't need a loop you can do this just as a sum, but I couldn't get to work :o )
    begin 
        dup here swap mod 0 = if
            drop
            r
        then 
        here 1 + setHere
    0 until
;

: : ( pHeader )
    ( Implementation is for COMPRESSED INSTRUCTION FORMAT RISC-V )
    2 alignHere
    setCompile
    compileHeader
    ( Eventually I will write an assembler library and this raw machine code         )
    ( will be replaced with what will appear to be readable assembly code RPN style  )
    0xB3 c, 0x82 c, 0x49 c, 0x01 c, ( add	t0,s3,s4 )
    0x23 c, 0xA0 c, 0x82 c, 0x00 c, ( sw	s0,0[t0] )
    0x11 c, 0x0A c,                 ( addi	s4,s4,4  )
    0x17 c, 0x04 c, 0x00 c, 0x00 c, ( auipc	s0,0x0   )
    0x13 c, 0x04 c, 0x04 c, 0x01 c, ( mv	s0,s0    )
    0x83 c, 0x22 c, 0x04 c, 0x00 c, ( lw	t0,0[s0] )
    0xE7 c, 0x80 c, 0x02 c, 0x00 c, ( jalr	t0       )
;

asm_name bw

: ; ( pHeader -- )
    ReturnStr_ ' ,
    setInterpret
    ( only set the dictionary end ptr, from where token searches start, )
    ( after the word is compiled so that a word can be redfined and use )
    ( its old implementation in its NEW implementation. To call itself  )
    ( a new word needs to be rewritten, recurse.                        )
    setDictionaryEnd
; immediate 

asm_name ew

: if ( -- addressToBackpatch )
    branch0TokenStr_ ' ,
    here
    0 ,
; immediate 

: else ( ifBranchAddressToBackpatch -- elseBranchAddressToBackpatch )
    branchTokenStr_ ' ,
    here                 ( ifBranch here )
    0 ,
    swap dup             ( here ifBranch ifBranch )
    here swap -          ( here ifBranch here-ifBranch )
    swap !               ( here )
; immediate 

: then ( ifBranchAddressToBackpatch -- )
    dup
    here swap -
    swap !
; immediate 

: begin ( -- loopMarker )
    here
; immediate 

: until ( loopMarker -- )
    branch0TokenStr_ ' ,
    here swap - -1 * , 
; immediate 

: do ( -- startLabel initialJump )
    branchTokenStr_ ' ,    ( initial jump to test label )
    here 0 ,
    here                   ( initialJump startlabel )
    swap                   ( startLabel initialJump )
    pushReturnStr_ ' dup , ( compile code to push i onto return stack )
    ,                      ( compile code to push limit onto return stack ) 
; immediate 


: loop ( startLabel initialJump -- ) 
    ( compile code to pop i and limit from return stack )
    popReturnStr_ ' dup , ,

    ( compile code to increment i )
    LiteralStr_ ' ,
    1 ,
    addStr_ ' ,

    ( we are now at the test label )
    dup ( startLabel initialJump initialJump )
    here swap -
    swap !
    ( startLabel )

    ( compile code to compare i and limit and branch if not equal )
    twodupStr_ ' ,
    equalsStr_ ' ,
    branch0TokenStr_ ' ,
    here swap - -1 * ,

    ( compile code to clean up i and limit from int stack now that the loop has ended ) 
    dropStr_ ' dup , , 
; immediate 