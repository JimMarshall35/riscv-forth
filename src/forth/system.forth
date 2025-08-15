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

string ReturnStr_ "return"

string UnknownTokenStartStr_ "unknowntoken:'" ( TODO: needs compiler change to allow spaces within strings but not high priority )

string UnknownTokenEndStr_ "'\n"

( flags )

: setCompile ( -- ) flags @ COMPILE_BIT or flags ! ;

: setInterpret ( -- ) flags @ COMPILE_BIT -1 xor and flags ! ;

: get_compile_bit ( -- 1or0 ) flags @ COMPILE_BIT and 0 > if 1 r then 0 ;

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

( TODO: replace logic_and and logic_or with && and || when possible )

: logic_and ( bool1 bool2 -- 1IfBoth1Else0 ) 
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

: logic_or ( bool1 bool2 -- 1IfEitherElse0 ) 
    if drop 1 r then
    if 1 r then
    0 r
;

: logic_not ( bool -- !bool )
    if
        0
    else
        1
    then
;

( todo: replace gte and lte with >= and <= when possible )

: gte ( int1 int2 -- 1IfInt1>=Int2 )
    2dup = rot rot > logic_or
;

: lte ( int1 int2 -- 1IfInt1>=Int2 )
    2dup = rot rot < logic_or
;

: isCharNumeric ( char -- 1IfNumericElse0 )
    dup ASCII_NUM_RANGE_START gte swap ASCII_NUM_RANGE_END lte logic_and
;

: isStringValidNumber ( pString nStringSize -- 0ifNotValid )
    0 do
        i 0 = if
            dup ( pString pString )
            c@ dup ( pString char char )
            MINUS_CHAR =  ( pString char isMinusChar )
            swap isCharNumeric
            logic_or logic_not if
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

: cw ( word2compile -- ) here ! here CELL_SIZE + setHere ;

: doToken  
    TokenBufferSize_ @ Tokenbuffer_ findXT
    ( either 0 on stack or an excution token )
    dup 0 != if
        ( we've found a valid xt )
        get_compile_bit 0 != if
            dup getXTImmediate if 
                execute
            else
                cw
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
                LiteralStr_ findXT cw ( TODO: NEED TO IMPLEMENT STRING LITERALS IN COMPILER - WILL HAND EDIT IN )
                cw
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
        SPACE_CHAR != if
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

: bw ( pHeader )
    setCompile
    compileHeader
    0x014982b3 cw
    0x0082a023 cw 
    0x004a0a13 cw   
    0x00000417 cw     
    0x00040413 cw
    0x00042283 cw 
    0x000280e7 cw 
;

: ew ( pHeader -- )
    ReturnStr_ findXT cw
    setInterpret
    setDictionaryEnd
; immediate 

