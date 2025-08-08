buf LineBuffer 128
var LineBufferSize 0

: doBackspace
    LineBufferSize @ 0 > if
        8 emit
        32 emit
        8 emit
        ( decrement line buffer size )
        LineBufferSize @ 1 - LineBufferSize !
    then
;

: outerInterpreter
    0 LineBufferSize !
    begin
        key    ( key )
        dup
        13 = if
            ( enter entered )
            drop           ( )
            10 emit        ( emit newline char )
            LineBuffer LineBufferSize @ eval ( call eval passing in lineBuffer and LineBuffer size - evaluate the line ) 
            0 LineBufferSize !
        else dup 127 = if
            ( backspace entered )
            drop
            doBackspace
        else
            ( some other key entered )
            ( key )
            
            LineBufferSize @
            127 < if
                dup emit
                LineBuffer LineBufferSize @ + !         ( store inputed key at current buffer position )
                LineBufferSize @ 1 + LineBufferSize !   ( increment LineBufferSize )
            then
        then
        then
    0 until
;