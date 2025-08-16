import pexpect


def test_run():
    assert True
    proc = None
    try:
        proc = pexpect.spawn("qemu-system-riscv32 -nographic -serial mon:stdio -machine virt -bios hello -qmp tcp:localhost:4444,server,wait=off", timeout=10)
    except pexpect.ExceptionPexpect as e:
        print(f"Error starting QEMU: {e}")
        assert False, "QEMU failed to start"

    
    try:
        proc.expect("Risc IV Forth", timeout=10)
    except pexpect.TIMEOUT:
        print("Timeout waiting for 'Risc V Forth' prompt.")
        assert False, "QEMU did not output expected prompt"
    except pexpect.EOF:
        print("pexpect.EOF")
        assert False, "QEMU did not output expected prompt"

    assert True