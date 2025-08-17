import argparse
import sys

from AssemblySrcParser import parse_lines, WordHeader
from LinkNewWord import add_new_word
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
twodup_word_name = "dup2_impl"
minus_word_name = "forth_minus_impl"
equals_word_name = "equals_impl"
not_equals_word_name = "notEquals_impl"
drop_word_name = "drop_impl"
end_primitive_macro_name = "end_word"

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

def unescape_gas_macro_arg(s):
    ns = ""
    itr = iter(s)
    for c in itr:
        if c == '!':
            c = next(itr)
        ns += c
    print(f"UNESCAPED: {ns}")
    return ns

def escape_for_gas_macro_arg(s):
    ns = ""
    for c in s:
        if c == '!':
            ns += '!!'
        elif c == '<':
            ns += '!<'
        elif c == '>':
            ns += '!>'
        elif c == ':':
            ns += '!:'
        elif c == ',':
            ns += '!,'
        elif c == ';':
            ns += '!;'
        else:
            ns += c
    return ns

class CompiledLine:
    def back_patch(self, label):
        if unset_label_phrase in self.txt:
            self.txt = self.txt.replace(unset_label_phrase, label[:-1])
            return True
        return False
    def get_string(self):
        return self.txt
    def replace(self, oldphrase, newphrase):
        self.txt = self.txt.replace(oldphrase, newphrase)
    def __init__(self, txt):
        self.txt = txt

class CompiledWord:
    def set_assembler_label(self, label):
        self.assemblerLabelName = label
        global word_name_map
        if self.code not in word_name_map:
            header = WordHeader()
            header.name = self.assemblerLabelName
            word_name_map[self.code] = header
        for l in self.body:
            l.replace(self.code, self.assemblerLabelName) # fix any labels that will have used the code 
    def get_lines(self):
        lines = []
        def nextword_str(nextword):
            if self.nextWord:
                return self.nextWord
            else:
                return "0"
        if self.bAsmWord:
            # add header macros
            lines.append(f"word_header {self.get_label()}, \"{escape_for_gas_macro_arg(self.code)}\", {self.immediate_str()}, {nextword_str(self.nextWord)}, {self.prevWord}")
            # add word body
            lines += [x.txt for x in self.body]
        else:
            # add header macros
            lines.append(f"word_header {self.assemblerLabelName if self.assemblerLabelName != "" else self.code}, \"{escape_for_gas_macro_arg(self.code)}\", {self.immediate_str()}, {nextword_str(self.nextWord)}, {self.prevWord}")
            lines.append(f"    secondary_word {self.get_label()}")
            # add word body
            lines += [x.txt for x in self.body]
            # add return
            lines.append("    .word return_impl")
        
        return lines
    def add_body_line(self, line):
        self.body.append(line)
    def get_control_flow_label(self, controlFlowType, extraText=""):
        typeString = control_flow_type_names[controlFlowType]
        s = f"{self.get_label()}_{typeString}_{self.labelCounter}_{extraText}:"
        self.labelCounter += 1
        return s
    def set_next(self, nextWord):
        self.nextWord = escape_for_gas_macro_arg(nextWord.get_label())
    def set_prev(self, prevWord):
        self.prevWord = escape_for_gas_macro_arg(prevWord.get_label())
    def immediate_str(self):
        if self.immediate:
            return "1"
        else:
            return "0"
    def get_label(self):
        return self.assemblerLabelName if self.assemblerLabelName != "" else self.code
    def __init__(self, code):
        self.nextWord = ""
        self.prevWord = ""
        self.code = code

        # Some characters are just too "real" for the assembler to include in labels such as ':', ',', '=' and many more.
        # Some words street names contain such characters and so they need a government name
        # that conforms to the rules society places on them: self.assemblerLabelName.
        # But when the outer intepreter is fired up and the threads are threadin' we don't care about such "labels"
        self.assemblerLabelName = "" 
        
        self.immediate = False
        self.body = []
        self.labelCounter = 0
        self.bReturned = False
        self.bAsmWord = False


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
    def push_new_word(self, name, bAsmWord=False):
        if len(self.control_flow_stack) > 0:
            assert len(self.compiledWords) > 0
            self.errors.append(f"Word {self.compiledWords[-1].code} unclosed control flow. Type '{control_flow_type_names[self.control_flow_stack[-1].type]}'")
        newWord = CompiledWord(name)
        newWord.bAsmWord = bAsmWord
        if bAsmWord:
            newWord.bReturned = True
        self.compiledWords.append(newWord)
        pass
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
    def link_compiled_words(self):  # the dictionary is a linked list
        for i in range(0, len(self.compiledWords)):
            if i != 0:
                self.compiledWords[i].set_prev(self.compiledWords[i- 1])
            if i != len(self.compiledWords) - 1:
                self.compiledWords[i].set_next(self.compiledWords[i+ 1])
        if len(self.compiledWords) > 0:
            self.compiledWords[0].prevWord = "last_vm_word" # vm must export a label called "last_vm_word" that points to the last word in that file
    def get_globals_for_word(self):
        g = [f".global {w.assemblerLabelName if w.assemblerLabelName != "" else w.code}_impl" for w in self.compiledWords]
        g.append(".global first_system_word")
        return g
    def get_preamble_lines(self):
        return [
            ".include \"VmMacros.S\"",
            ".altmacro",
            ".text",
            "first_system_word:",
            "\n"
        ]
    def get_header_comment_lines(self):
        return [
            "# This file was generated by Compiler.py\n",
            "# command line args used:\n",
            f"# {' '.join(sys.argv)}\n"
        ]
    def get_file_contents(self):
        lines = []
        lines += self.get_header_comment_lines()
        lines += self.get_globals_for_word()      # global declarations so the words are useable by other translation units
        lines += self.get_preamble_lines()        # any includes for macros
        for w in self.compiledWords:
            lines += w.get_lines()
            lines.append("\n")
        return "\n".join(lines)
    def save_to_file(self, filePath):
        self.link_compiled_words()
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
    def set_current_word_assembler_label(self, label):
        assert len(self.compiledWords) > 0
        self.compiledWords[-1].set_assembler_label(label)
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.compiledWords = []
        self.control_flow_stack = []
        self.compiledWordNames = set()
        self.constantDefines = dict()

def do_found_word(prg, token):
    lineTxt = f"    .word {word_name_map[token.string].name}_impl"
    prg.append_line_to_current(lineTxt)

def do_unfound_word(prg, token):
    lineTxt = f"    .word {token.string}_impl"
    prg.append_line_to_current(lineTxt)

def do_if(prg, tokenItr, currentToken):
    prg.append_line_to_current(f"1:  .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchForwardToLabel {unset_label_phrase}")
    prg.push_control_flow(branch_offset_line, ControlFlowType.If)

def do_then(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) == 0:
        prg.errors.append(f"Line {currentToken.srcLine}: then with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.If and ctrl_flow.type != ControlFlowType.Else:
        prg.errors.append(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'if' expected")
        return
    label = prg.get_control_flow_label_for_current(ControlFlowType.Then)
    ctrl_flow.compiledLine.back_patch(label)
    prg.append_line_to_current(label)

def do_else(prg, tokenItr, currentToken):
    if len(prg.control_flow_stack) == 0:
        prg.errors.append(f"Line {currentToken.srcLine}: else with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.If:
        prg.errors.append(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'if' expected")
        return
    prg.append_line_to_current(f"1:  .word {branch_word_name}")
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
        prg.errors.append(f"Line {currentToken.srcLine}: then with no corresponding if")
        return
    ctrl_flow = prg.pop_control_flow()
    if ctrl_flow.type != ControlFlowType.Begin:
        prg.errors.append(f"Line {currentToken.srcLine}: {control_flow_type_names[ctrl_flow.type]} on control flow stack, 'begin' expected")
        return
    prg.append_line_to_current(f"1:  .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchBackToLabel {unset_label_phrase}")
    branch_offset_line.back_patch(ctrl_flow.compiledLine.get_string())

def do_do(prg, tokenItr, currentToken):
    # branch to test
    prg.append_line_to_current(f"1:  .word {branch_word_name}")
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
        prg.errors.append(f"Line {currentToken.srcLine}: loop expects at least 2 control flow items on the stack")
        return
    loopStartLabel = prg.pop_control_flow()
    branchToTest = prg.pop_control_flow()
    if loopStartLabel.type != ControlFlowType.Do or branchToTest.type != ControlFlowType.Do:
        prg.errors.append(f"Line {currentToken.srcLine}: loop expects the 2 control flow items on the stack are of type 'Do' but got [{control_flow_type_names[label.type]}, {control_flow_type_names[branch.type]}]")
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
    prg.append_line_to_current(f"1:  .word {branch0_word_name}")
    branch_offset_line = prg.append_line_to_current(f"    CalcBranchBackToLabel {unset_label_phrase}")
    branch_offset_line.back_patch(loopStartLabel.compiledLine)
    # compile code to cleanup stack now loop has ended
    prg.append_line_to_current(f"    .word {drop_word_name}")
    prg.append_line_to_current(f"    .word {drop_word_name}")

def string_is_valid_number(string):
    return string.isnumeric() or (string[0] == '-' and string[1:].isnumeric())

def do_var(prg, tokenItr, currentToken):
    #    la t1, flags_data
    #    PushDataStack t1
    #    end_word
    #flags_data:
    #    .word 0
    wordName = next(tokenItr)
    val = next(tokenItr)
    if(not string_is_valid_number(val.string)):
        prg.errors.append(f"Line {currentToken.srcLine}: buffer size was not a valid number")
        return
    prg.push_new_word(wordName.string, True)
    
    prg.compiledWordNames.add(wordName.string)
    prg.append_line_to_current(f"    la t1, {wordName.string}_data")
    prg.append_line_to_current(f"    PushDataStack t1")
    prg.append_line_to_current(f"    end_word")
    prg.append_line_to_current(f"{wordName.string}_data:")
    prg.append_line_to_current(f"    .word {val.string}")
    
def do_buf(prg, tokenItr, currentToken):
    # there's deviation from actual forth here, as
    # this script is a compiler only of compiled words designed to bootstrap
    # a traditional forth it lacks the ability to interpret so
    # unlike in the real forth the size of the buffer is specified AFTER the name.
    wordName = next(tokenItr)
    bufferSize = next(tokenItr)
    if(not string_is_valid_number(bufferSize.string)):
        prg.errors.append(f"Line {currentToken.srcLine}: buffer size was not a valid number")
        return
    prg.push_new_word(wordName.string, True)
    prg.compiledWordNames.add(wordName.string)
    prg.append_line_to_current(f"    la t1, {wordName.string}_data")
    prg.append_line_to_current(f"    PushDataStack t1")
    prg.append_line_to_current(f"    end_word")
    prg.append_line_to_current(f"{wordName.string}_data:")
    prg.append_line_to_current(f"    .fill {bufferSize.string}, 1, 0")

def do_semicolon(prg, tokenItr, currentToken):
    prg.set_current_word_returned()

def do_colon(prg, tokenItr, currentToken):
    wordName = next(tokenItr)
    prg.push_new_word(wordName.string)
    prg.compiledWordNames.add(wordName.string)

def do_define(prg, tokenItr, currentToken):
    defName = next(tokenItr).string
    defVal = next(tokenItr).string
    prg.constantDefines[defName] = defVal

def do_string(prg, tokenItr, currentToken):
    # TODO:  the tokenizer function needs to extract everything between " pairs as 1 token!!
    defName = next(tokenItr).string
    defVal = next(tokenItr).string 
    prg.push_new_word(defName, True)
    prg.compiledWordNames.add(defName)
    prg.append_line_to_current(f"    li t1, {str(len(defVal) - 2)}") # -2 for the ""
    prg.append_line_to_current(f"    PushDataStack t1")
    prg.append_line_to_current(f"    la t1, {defName}_data")
    prg.append_line_to_current(f"    PushDataStack t1")
    prg.append_line_to_current(f"    end_word")
    prg.append_line_to_current(f"{defName}_data:")
    prg.append_line_to_current(f"    .ascii {defVal}")
    prg.append_line_to_current( "    .align 4")

def do_immediate(prg, tokenItr, currentToken):
    prg.compiledWords[-1].immediate = True

def do_asm_name(prg, tokenItr, currentToken):
    name = next(tokenItr).string
    prg.set_current_word_assembler_label(name)

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
    ":" : do_colon,
    "#define" : do_define,
    "string" : do_string,
    "immediate" : do_immediate,
    "asm_name" : do_asm_name
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

def remove_comments_from_token_list(tokens):
    inComment = False
    newTokens = []
    for t in tokens:
        if t.string == "(":
            inComment = True
        elif not inComment:
            newTokens.append(t)
        elif t.string == ")":
            inComment = False
    return newTokens

def file_to_token_iterator(filePath):
    # TODO: should also strip comments
    tokens = []
    with open(filePath, "r") as f:
        lines = f.readlines()
        onLine = 1
        for line in lines:
            line = line.replace("\n", "")
            line = line.replace("\t", "")
            lineTokens = [Token(x, onLine) for x in line.split()]
            lineTokensCommentsRemoved = remove_comments_from_token_list(lineTokens)
            tokens = tokens + lineTokensCommentsRemoved
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
            if (h.code[0] == '<' and h.code[-1] == '>') or (h.code[0] == '(' and h.code[-1] == ')') or (h.code[0] == '[' and h.code[-1] == ']') or (h.code[0] == '\"' and h.code[-1] == '\"') or (h.code[0] == '\'' and h.code[-1] == '\''):
                h.code = unescape_gas_macro_arg(h.code[1:-1])
            word_name_map[h.code] = h

def compile_literal(prg, literalVal):
    prg.append_line_to_current(f"    .word {literal_word_name}")
    prg.append_line_to_current(f"    .word {literalVal}")

def is_valid_number(string):
    if string.isnumeric():
        return True
    if string[0] == '-' and string[1:].isnumeric():
        return True
    try:
        int(string, 16)
        return True
    except ValueError:
        return False


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
        if token.string in prg.constantDefines:
            token.string = prg.constantDefines[token.string]
        if token.string in pseudo_tokens:
            pseudo_tokens[token.string](prg, tokenItr, token)
        elif token.string in word_name_map:
            do_found_word(prg, token)
        elif is_valid_number(token.string):
            compile_literal(prg, token.string)
        else:
            do_unfound_word(prg, token)
            if bAsm_file_set and (not (token.string in prg.compiledWordNames)):
                prg.warnings.append(f"Line {token.srcLine}: unknown token '{token.string}'")
    prg.print_warnings_and_errors()
    
    prg.save_to_file(args.output_file)
    
main()