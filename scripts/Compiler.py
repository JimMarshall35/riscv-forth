import argparse
from AssemblySrcParser import parse_lines, WordHeader, HeaderType, WordType

# Compile a forth source code file into gnu assembler threaded code for Risc-V forth VM 
# Used to bootstrap the forth repl and outer interpreter without either A.) writing those in assembly or B.)
# Writing the threaded code "assembly style" by hand as I have done up until now.
# Will implement the following control flow words that compile down to branch and branch0 tokens:
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

def do_cmd_args():
    parser = argparse.ArgumentParser(
                    prog='PrecompiledWordTool',
                    description='Creates new word entries in an assembler file and does forth specific linting',
                    epilog='Jim Marshall - Riscv assembly forth 2025')
    parser.add_argument("input_file", type=str, help="the input file to use")
    parser.add_argument("-a","--asm_file", type=str, help="the assembly file containing the prexisting precompiled forth dictionary. Needed to output word headers that are properly linked in with the others. If specified, will append output onto end of this file, and return a new copy as the output file. Also used to warn about words that can't be found")
    parser.add_argument("-o", "--output_file", type=str, help="output assembly file, defaults to out.asm")
    args = parser.parse_args()
    return args

def file_to_tokens(filePath):
    with open(filePath, "r") as f:
        contents = f.read()
        contents = contents.replace("\n", "")
        contents = contents.replace("\t", "")
        return contents.split()

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

def main():
    args = do_cmd_args()
    try_load_asm_file(args)
    if bAsm_file_set:
        build_word_name_map(forth_dict)
    tokens = file_to_tokens(args.input_file)
    

main()