#define CARRIAGE_RETURN_CHAR 13
#define NEWLINE_CHAR 10
#define ENTER_CHAR 127
#define BACKSPACE_CHAR 8
#define SPACE_CHAR 32
#define HEADER_SIZE 44
#define OFFSET_IMM 36
#define CELL_SIZE 4


buf LineBuffer_ 128
var LineBufferSize_ 0

buf Tokenbuffer_ 32
var TokenBufferSize_ 0

var LineBufferI_ 0

var EvalErrorFlag_ 0

string LiteralStr_ "literal"

string UnknownTokenStartStr_ "unknowntoken:'" ( TODO: needs compiler change to allow spaces within strings but not high priority )

string UnknownTokenEndStr_ "'\n"


: setHeaderImmediate ( bImm pHeader -- ) OFFSET_IMM + ! ;

: getHeaderImmediate ( pHeader -- pHeader->bImmediate ) OFFSET_IMM + @ ; 

: getXTHeader ( xt -- xtHeader ) HEADER_SIZE - ; 

: getXTImmediate ( xt -- 0IfNotImmediate ) getXTHeader getHeaderImmediate ;


: doToken  
    TokenBufferSize_ @ Tokenbuffer_ findXT
    ( either 0 on stack or an excution token )
    dup 0 != if
        ( we've found a valid xt )
        get_compile_bit 0 != if
            cw
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
            ( TODO: implement EvalErrorFlag_ )
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