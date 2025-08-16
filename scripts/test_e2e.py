import pexpect

class TestCase:
    def __init__(self, input_strs, expected_data_stack, cleanup):
        self.input_strs = input_strs
        self.expected_data_stack_string = expected_data_stack
        self.cleanup = cleanup

    def run(self, proc):
        # Placeholder for actual test logic
        for input_str in self.input_strs:
            proc.sendline(input_str)
        try:
            proc.expect(self.expected_data_stack_string, timeout=10)
        except pexpect.TIMEOUT:
            print(f"Timeout waiting for expected output: {self.expected_data_stack_string}. Input strings: {'\n'.join(self.input_strs)}")
            assert False, "Test failed due to timeout"
        except pexpect.EOF:
            print(f"EOF for expected output: {self.expected_data_stack_string}. Input strings: {'\n'.join(self.input_strs)}")
            assert False, "EOF"
        if self.cleanup:
            proc.sendline(self.cleanup)
            try:
                proc.expect("[  ]", timeout=10)
            except pexpect.TIMEOUT:
                print(f"Timeout waiting for empty stack after cleanup. Input strings: {'\n'.join(self.input_strs)} . Cleanup: {self.cleanup}")
                assert False, "Test failed due to timeout"
            except pexpect.EOF:
                print(f"EOF waiting for empty stack after cleanup. Input strings: {'\n'.join(self.input_strs)} . Cleanup: {self.cleanup}")
                assert False, "EOF"

tests = [
    TestCase(["1 2 show"], "[ 1, 2 ]", "drop drop")
]

def test_run():
    assert True
    proc = None
    try:
        proc = pexpect.spawn("qemu-system-riscv32 -nographic -serial mon:stdio -machine virt -bios hello -qmp tcp:localhost:4444,server,wait=off", timeout=10)
    except pexpect.ExceptionPexpect as e:
        print(f"Error starting QEMU: {e}")
        assert False, "QEMU failed to start"

    
    try:
        proc.expect("Risc V Forth", timeout=10)
    except pexpect.TIMEOUT:
        print("Timeout waiting for 'Risc V Forth' prompt.")
        assert False, "QEMU did not output expected prompt"
    except pexpect.EOF:
        print("pexpect.EOF")
        assert False, "QEMU did not output expected prompt"

    for test in tests:
        test.run(proc)

    assert True