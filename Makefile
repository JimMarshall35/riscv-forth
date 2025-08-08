default: hello

hello: hello.o ns16550a.o utils.o vm.o system.o baremetal.ld
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-gcc -fno-use-linker-plugin -T baremetal.ld -march=rv32imafdc -mabi=ilp32 -nostdlib -static -o hello hello.o ns16550a.o vm.o utils.o system.o

hello.o: hello.s
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-as -g -march=rv32imafdc -mabi=ilp32 hello.s -o hello.o

ns16550a.o: ns16550a.s
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-as -g -march=rv32imafdc -mabi=ilp32 ns16550a.s -o ns16550a.o

vm.o: vm.s
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-as -g -march=rv32imafdc -mabi=ilp32 vm.s -o vm.o

system.o: system.s
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-as -g -march=rv32imafdc -mabi=ilp32 system.s -o system.o

utils.o: utils.s
	C:\SysGCC\risc-v\bin\riscv64-unknown-elf-as -g -march=rv32imafdc -mabi=ilp32 utils.s -o utils.o

run : hello 
	qemu-system-riscv32 -nographic -serial mon:stdio -machine virt -bios hello	