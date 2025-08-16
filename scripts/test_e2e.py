import pexpect
# This script is used to run end-to-end tests for the RISC-V Forth system.
# It is run as one long "soak test" where we have a dialog with the forth running in QEMU.
# The tests are designed to be run in GitHub Actions.
# It uses pexpect to interact with a QEMU instance running the Forth system.
# The pexepect library does NOT work properly on windows so don't expect this to work on windows.
# The tests work on the principle of matching strings. Each test should call show at the end to
# display the data stack. Each test case has to reset the stack after it is run, and needs
# to call show at the end to prove to the test framework that the stack is in the expected state.
# If you change the way the stack is displayed you'll need to change this.
# If one test fails the rest won't be run.

# renamed to stop pytest thinking this is a test class
class NotPyTestCase:
    def __init__(self, input_strs, expected_data_stack, cleanup):
        self.input_strs = input_strs
        self.expected_data_stack_string = expected_data_stack
        self.cleanup = cleanup

    def run(self, proc):
        for input_str in self.input_strs:
            proc.sendline(input_str)
        try:
            proc.expect_exact(self.expected_data_stack_string, timeout=10)
        except pexpect.TIMEOUT:
            print(f"Timeout waiting for expected output: {self.expected_data_stack_string}. Input strings: {'\n'.join(self.input_strs)}")
            assert False, "Test failed due to timeout"
        except pexpect.EOF:
            print(f"EOF for expected output: {self.expected_data_stack_string}. Input strings: {'\n'.join(self.input_strs)}")
            assert False, "EOF"
        if self.cleanup:
            proc.sendline(self.cleanup)
            try:
                proc.expect_exact("[  ]", timeout=10)
            except pexpect.TIMEOUT:
                print(f"Timeout waiting for empty stack after cleanup. Input strings: {'\n'.join(self.input_strs)} . Cleanup: {self.cleanup}")
                assert False, "Test failed due to timeout"
            except pexpect.EOF:
                print(f"EOF waiting for empty stack after cleanup. Input strings: {'\n'.join(self.input_strs)} . Cleanup: {self.cleanup}")
                assert False, "EOF"

tests = [
    # the forth code checks for a carriage return to process the input line.
    # Windows terminal outputs \r\n and this code was developed on Windows, 
    # but the CI runs on Linux, so we need to add \r
    NotPyTestCase(["1 2 show\r"], "[ 1, 2 ]", "drop drop show\r"),
    NotPyTestCase(["1 2 + show\r"], "[ 3 ]", "drop show\r"),
    NotPyTestCase(["4 6 - show\r"], "[ -2 ]", "drop show\r"),
    NotPyTestCase(["bw jim 1 2 3 4 5 ew\r", "jim show\r"], "[ 1, 2, 3, 4, 5 ]", "drop drop drop drop drop show\r"),
    NotPyTestCase(["bw jim2 jim 6 7 8 ew\r", "jim2 show\r"], "[ 1, 2, 3, 4, 5, 6, 7, 8 ]", "drop drop drop drop drop drop drop drop show\r"),
]

def test_run():
    proc = None
    with open('testlog.txt','wb') as logF:

        try:
            proc = pexpect.spawn("qemu-system-riscv32 -nographic -serial mon:stdio -machine virt -bios hello -qmp tcp:localhost:4444,server,wait=off", timeout=10)
        except pexpect.ExceptionPexpect as e:
            print(f"Error starting QEMU: {e}")
            assert False, "QEMU failed to start"

        proc.logfile = logF

        try:
            proc.expect_exact("Risc V Forth", timeout=10)
        except pexpect.TIMEOUT:
            print("Timeout waiting for 'Risc V Forth' prompt.")
            assert False, "QEMU did not output expected prompt"
        except pexpect.EOF:
            print("pexpect.EOF")
            assert False, "QEMU did not output expected prompt"

        for test in tests:
            test.run(proc)

    assert True