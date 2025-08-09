buf LineBuffer 128
var LineBufferSize 0

#define CARRIAGE_RETURN_CHAR 13
#define NEWLINE_CHAR 10
#define ENTER_CHAR 127
#define BACKSPACE_CHAR 8
#define SPACE_CHAR 32

: doBackspace
    LineBufferSize @ 0 > if
        BACKSPACE_CHAR emit
        SPACE_CHAR emit
        BACKSPACE_CHAR emit
        ( decrement line buffer size )
        LineBufferSize @ 1 - LineBufferSize !
    then
;

: outerInterpreter
    0 LineBufferSize !
    begin
        key    ( key )
        dup
        CARRIAGE_RETURN_CHAR = if
            ( enter entered )
            drop           ( )
            NEWLINE_CHAR emit        ( emit newline char )
            LineBuffer LineBufferSize @ eval ( call eval passing in lineBuffer and LineBuffer size - evaluate the line ) 
            0 LineBufferSize !
        else dup ENTER_CHAR = if
            ( backspace entered )
            drop
            doBackspace
        else
            ( some other key entered )
            ( key )
            
            LineBufferSize @
            ENTER_CHAR < if
                dup emit
                LineBuffer LineBufferSize @ + !         ( store inputed key at current buffer position )
                LineBufferSize @ 1 + LineBufferSize !   ( increment LineBufferSize )
            then
        then
        then
    0 until
;