import argparse
from AssemblySrcParser import parse_lines, WordHeader, HeaderType, WordType
from enum import Enum

# Compile a forth source code file into gnu assembler threaded code for Risc-V forth VM 
# Used to bootstrap the forth repl and outer interpreter without either A.) writing those in assembly or B.)
# Writing the threaded code unstructured "assembly style" by hand as I have done up until now.
# Implements the following control flow words that compile down to branch and branch0 tokens:
#   - if / then / else
#   - begin / until      ( pop value off the stack and loop back if the value )
#   - do / loop          ( ( endExclusive begin -- )  for loop-like, always increments by 1, compiled code stores beginning and end on return stack)
#   - var                ( a cell variable word, when called at runtime returns address )
#       - usage "10 var jim". Initialises a cell variable word 
#   - buf                ( a buffer of the length specified )

forth_dict = None
forth_dict_file_lines = None
bAsm_file_set = False
word_name_map = dict()




unset_label_phrase = "<<<LABEL_ACCEPTOR>>>"

branch_word_name = "branch_impl"
branch0_word_name = "branchIfZero_impl"
pop_return_stack_word_name = "pop_return_impl"
push_return_stack_word_name = "push_return_impl"
literal_word_name = "literal_impl"
add_word_name = "forth_add_impl"

return_token_name = "return_impl"
twodup_word_name = "2dup"
minus_word_name = "forth_minus_impl"
equals_word_name = minus_word_name
drop_word_name = "drop_impl"

class CompiledLine:
    def back_patch(self, label):
        if unset_label_phrase in self.txt:
            self.txt = self.txt.replace(unset_label_phrase, label[:-1])
            return True
        return False
    def get_string(self):
        return self.txt
    def __init__(self, txt):
        self.txt = txt
        
        
class ControlFlowType(Enum):
    If = 0
    Then = 1
    Else = 2
    Begin = 3
    Until = 4
    Do = 5
    Loop = 6

control_flow_type_names = {
    ControlFlowType.If : "if",
    ControlFlowType.Then : "then",
    ControlFlowType.Else : "else",
    ControlFlowType.Begin : "begin",
    ControlFlowType.Until : "until",
    ControlFlowType.Do : "do",
    ControlFlowType.Loop : "loop"
}

class CompiledWord:
    def get_lines(self):
        lines = []
        # add header macros
        lines.append(f"word_header {self.code}, {self.code}, {self.immediate if 1 else 0}, {self.nextWord}, {self.prevWord}")
        lines.append(f"    secondary_word {self.code}")
        # add word body
        lines += [x.txt for x in self.body]
        # add return
        lines.append("    .word return_impl")
        return lines
    def add_body_line(self, line):
        self.body.append(line)
    def get_control_flow_label(self, controlFlowType, extraText=""):
        typeString = control_flow_type_names[controlFlowType]
        s = f"{self.code}_{typeString}_{self.labelCounter}_{extraText}:"
        self.labelCounter += 1
        return s
    def set_next(self, nextWord):
        self.nextWord = nextWord.code
    def set_prev(self, prevWord):
        self.prevWord = prevWord.code
    def __init__(self, code):
        self.nextWord = ""
        self.prevWord = ""
        self.code = code
        self.immediate = False
        self.body = []
        self.labelCounter = 0
        self.bReturned = False


class ControlFlow:
    def __init__(self, compiledLine, type):
        self.compiledLine = compiledLine
        self.type = type
        pass

class Token:
    def __init__(self, string, srcLine):
        self.string = string
        self.srcLine = srcLine

class Program:
    def push_control_flow(self, compiledLine, type):
        self.control_flow_stack.append(ControlFlow(compiledLine, type))
    def pop_control_flow(self):
        assert len(self.control_flow_stack) > 0
        return self.control_flow_stack.pop()
    def append_line_to_current(self, compiledLine):
        assert len(self.compiledWords) > 0
        line = CompiledLine(compiledLine)
        self.compiledWords[-1].body.append(line)
        return line
    def get_control_flow_label_for_current(self, ctrltype, extraText=""):
        assert len(self.compiledWords) > 0
        return self.compiledWords[-1].get_control_flow_label(ctrltype, extraText)
    def set_current_word_returned(self):
        self.compiledWords[-1].bReturned = True
    def get_file_contents(self):
        lines = []
        for w in self.compiledWords:
            lines += w.get_lines()
            lines.append("\n")
        return "\n".join(lines)
    def save_to_file(self, filePath):
        content = self.get_file_contents()
        with open(filePath, "w") as f:
            f.write(content)
    def print_warnings_and_errors(self):
        print("Errors:\n")
        for error in self.errors:
            print(error)
            print()
        print("Warnings:\n")
        for w in self.warnings:
            print(w)
            print()
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.compiledWords = []
        self.control_flow_stack = []
        self.compiledWordNames = set()

class TokenIterator:
    def get_next(self):
        if self >= len(self.tokens):
            return None
        t = self.tokens[self.i]
        self.i += 1
        return t
    def __init__(self, tokens):
        self.tokens = tokens
        self.i = 0

def do_found_word(prg, token):
    lineTxt = f"    .word {word_name_map[token.string].name}_impl"
    prg.append_line_to_current(lineTxt)

def do_unfound_word(prg, token):
    lineTxt = f"    .word {token.string}_impl"
    prg.append_line_to_current(lineTxt)

def do_if(prg, tokenItr, currentToken):
    prg.append_line_to_current(f"    .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchForwardToLabel {unset_label_phrase}")
    prg.push_control_flow(branch_offset_line, ControlFlowType.If)

def do_then(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) == 0:
        prg.errors(f"Line {currentToken.srcLine}: then with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.If and ctrl_flow.type != ControlFlowType.Else:
        prg.errors(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'if' expected")
        return
    label = prg.get_control_flow_label_for_current(ControlFlowType.Then)
    ctrl_flow.compiledLine.back_patch(label)
    prg.append_line_to_current(label)

def do_else(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) == 0:
        prg.errors(f"Line {currentToken.srcLine}: else with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.If:
        prg.errors(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'if' expected")
        return
    prg.append_line_to_current(f"    .word {branch_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchForwardToLabel {unset_label_phrase}")
    prg.push_control_flow(branch_offset_line, ControlFlowType.Else)
    label = prg.get_control_flow_label_for_current(ControlFlowType.Else)
    ctrl_flow.compiledLine.back_patch(label)
    prg.append_line_to_current(label)

def do_begin(prg, tokenItr, currentToken):
    label = prg.get_control_flow_label_for_current(ControlFlowType.Begin)
    branch_offset_line = prg.append_line_to_current(label)
    prg.push_control_flow(branch_offset_line, ControlFlowType.Begin)

def do_until(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) == 0:
        prg.errors(f"Line {currentToken.srcLine}: then with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.Begin:
        prg.errors(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'begin' expected")
        return
    prg.append_line_to_current(f"    .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchBackToLabel {unset_label_phrase}")
    branch_offset_line.back_patch(ctrl_flow.compiledLine)

def do_do(prg, tokenItr, currentToken):
    # branch to test
    prg.append_line_to_current(f"    .word {branch_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchForwardToLabel {unset_label_phrase}")
    prg.push_control_flow(branch_offset_line, ControlFlowType.Do)
    # push a label - the start of the loop
    label = prg.get_control_flow_label_for_current(ControlFlowType.Do, "start")
    prg.push_control_flow(label, ControlFlowType.Do)
    prg.append_line_to_current(label)
    # compile code to push i onto return stack
    prg.append_line_to_current(f"    .word {push_return_stack_word_name}")
    # compile code to push limit onto return stack
    prg.append_line_to_current(f"    .word {push_return_stack_word_name}")

def do_loop(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) < 2:
        prg.errors(f"Line {currentToken.srcLine}: loop expects at least 2 control flow items on the stack")
        return
    loopStartLabel = prg.pop_control_flow()
    branchToTest = prg.pop_control_flow()
    if loopStartLabel.type != ControlFlowType.Do or branchToTest.type != ControlFlowType.Do:
        prg.errors(f"Line {currentToken.srcLine}: loop expects the 2 control flow items on the stack are of type 'Do' but got [{control_flow_type_names[label.type]}, {control_flow_type_names[branch.type]}]")
        return
    # compile code to pop limit
    prg.append_line_to_current(f"    .word {pop_return_stack_word_name}")
    # compile code to pop i
    prg.append_line_to_current(f"    .word {pop_return_stack_word_name}")
    # compile code to increment i
    prg.append_line_to_current(f"    .word {literal_word_name}")
    prg.append_line_to_current(f"    .word 1")
    prg.append_line_to_current(f"    .word {add_word_name}")
    # we're now at the test label
    testLabel = prg.get_control_flow_label_for_current(ControlFlowType.Loop, "test")
    branchToTest.compiledLine.back_patch(testLabel)
    prg.append_line_to_current(testLabel)
    # compile code to compare i and limit and branch if not equal
    prg.append_line_to_current(f"    .word {twodup_word_name}")
    prg.append_line_to_current(f"    .word {equals_word_name}")
    prg.append_line_to_current(f"    .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchBackToLabel {unset_label_phrase}")
    branch_offset_line.back_patch(loopStartLabel.compiledLine)
    # compile code to cleanup stack now loop has ended
    prg.append_line_to_current(f"    .word {drop_word_name}")
    prg.append_line_to_current(f"    .word {drop_word_name}")

def do_var(prg, tokenItr, currentToken):
    pass
def do_buf(prg, tokenItr, currentToken):
    pass

def do_semicolon(prg, tokenItr, currentToken):
    prg.set_current_word_returned()


def do_colon(prg, tokenItr, currentToken):
    wordName = next(tokenItr)
    w = CompiledWord(wordName.string)
    prg.compiledWords.append(w)
    prg.compiledWordNames.add(wordName)

pseudo_tokens = {
    "if" : do_if,
    "then" : do_then,
    "else" : do_else,
    "begin" : do_begin,
    "until" : do_until,
    "do" : do_do,
    "loop" : do_loop,
    "var" : do_var,
    "buf" : do_buf,
    ";" : do_semicolon,
    ":" : do_colon
}
def do_cmd_args():
    parser = argparse.ArgumentParser(
                    prog='Forth threaded code compiler',
                    description='Compile a forth source code file into gnu assembler threaded code for Risc-V forth VM',
                    epilog='Jim Marshall - Riscv assembly forth 2025')
    parser.add_argument("input_file", type=str, help="the input file to use")
    parser.add_argument("-a","--asm_file", type=str, help="the assembly file containing the prexisting precompiled forth dictionary. Needed to output word headers that are properly linked in with the others. If specified, will append output onto end of this file, and return a new copy as the output file. Also used to warn about words that can't be found")
    parser.add_argument("-o", "--output_file", type=str, help="output assembly file, defaults to out.asm")
    args = parser.parse_args()
    return args

def file_to_token_iterator(filePath):
    tokens = []
    with open(filePath, "r") as f:
        lines = f.readlines()
        onLine = 1
        for line in lines:
            line = line.replace("\n", "")
            line = line.replace("\t", "")
            tokens = tokens + ([Token(x, onLine) for x in line.split()])
            onLine += 1
    return iter(tokens)

def try_load_asm_file(args):
    global forth_dict
    global forth_dict_file_lines
    global bAsm_file_set
    if not args.asm_file:
        return
    with open(args.asm_file, "r") as f:
        forth_dict, forth_dict_file_lines = parse_lines(f)
    bAsm_file_set = True

def build_word_name_map(headers):
    for h in headers:
        if h not in word_name_map:
            word_name_map[h.code] = h

def compile_literal(prg, literalVal):
    prg.append_line_to_current(f"    .word {literal_word_name}")
    prg.append_line_to_current(f"    .word {literalVal}")

def main():
    args = do_cmd_args()
    try_load_asm_file(args)
    if bAsm_file_set:
        build_word_name_map(forth_dict)
    else:
        print("ASM file not set. You will not be warned about undefined words and you will have to manually link the outputted asm source code to a prexisting forth dictionary containing primitives")
    
    if not args.output_file:
        args.output_file = "out.S"

    tokenItr = file_to_token_iterator(args.input_file)
    prg = Program()
    for token in tokenItr:
        if token.string in pseudo_tokens:
            pseudo_tokens[token.string](prg, tokenItr, token)
        elif token.string in word_name_map:
            do_found_word(prg, token)
        elif token.string.isnumeric() or (token.string[0] == '-' and token.string[1:].isnumeric()):
            compile_literal(prg, token.string)
        else:
            do_unfound_word(prg, token)
            if bAsm_file_set and (not (token.string in prg.compiledWordNames)):
                prg.warnings.append(f"Line {token.srcLine}: unknown token '{token.string}'")
    prg.print_warnings_and_errors()
    prg.save_to_file(args.output_file)
    
main()