buf LineBuffer 128
var LineBufferSize 0

: doBackspace
    LineBufferSize @ 0 > if
        8 8 emit emit
        32 32 emit emit
        8 8 emit emit
        ( decrement line buffer size )
        LineBufferSize @ 1 - LineBufferSize !
    then
;

: outerInterpreter
    begin
        key    ( key )
        dup
        14 = if
            ( enter entered )
            drop           ( )
            eval 
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
                LineBuffer LineBufferSize @ + !         ( store inputed key at current buffer position )
                LineBufferSize @ 1 + LineBufferSize !   ( increment LineBufferSize )
            then
        then
        then
    1 until
;