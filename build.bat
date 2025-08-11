rem Generate assembly files from forth code
python scripts/Compiler.py src/forth/system.forth -a src/asm/vm.s -o src/asm/system.s
rem Compile that + the hand written assembly
make -C src/asm
pause