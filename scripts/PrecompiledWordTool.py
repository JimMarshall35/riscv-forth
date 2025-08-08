import argparse
from AssemblySrcParser import parse_lines, WordHeader, HeaderType, WordType
from LinkNewWord import add_new_word

# Precompiled Word Tool
# - Add new precompiled forth words to source file
#   - Automatically updates next and prev pointers
#   - Saves file to vmOut.S
# - Statically analyse word linkage, make sure its correct
# - Lists forth words present in source file
# FUTURE WORK:
# - flag to add in end_word macro (or make this the default and have the flag to disable)
# - If word is secondary are thread pointers pointing to valid word implementations (and NOT the header itself)
# - Is a word is primitive is it a variable
# - Are branch macros used correctly ('1:' in correct place)

def do_cmd_args():
    parser = argparse.ArgumentParser(
                    prog='PrecompiledWordTool',
                    description='Creates new word entries in an assembler file and does forth specific linting',
                    epilog='Jim Marshall - Riscv assembly forth 2025')
    parser.add_argument("assembly_file", help="the assembly file to use")
    parser.add_argument("--new_word_name", help="the name of a new word to add to the source file. If this is not passed, the script will list and verify the assembly file's contents as a list of forth words.", type=str)
    parser.add_argument("--new_word_code", help="the code of a new word to add to the source file. Only works if name is passed too. If not passed with name, set to the same value as name as default", type=str)
    parser.add_argument('--immediate', action='store_true', help="make the new word immediate")
    parser.add_argument('--list_words', action='store_true', help="print a list of word")
    parser.add_argument('--report_types', action='store_true', help="print a report of the frequency of different types of words")
    parser.add_argument('--globals_string', action='store_true', help="make a string of .global directives to add to a file and print in console")
    args = parser.parse_args()
    return args

def traverse_headers(headers, iteratorFn):
    byName = dict()
    for h in headers:
        if not h.name in byName:
            byName[h.name] = h
        else:
            print(f"WARNING: Duplicate name: {h.name}")
    onH = headers[0]
    count = 0
    while True and onH:
        iteratorFn(onH)
        if onH.next == "":
            return True
        onH = byName[onH.next]
        count += 1
        if count > len(headers):
            print("Loop detected!")
            return False
        
def traverse_backwards(headers, iteratorFn):
    byName = dict()
    for h in headers:
        if not h.name in byName:
            byName[h.name] = h
        else:
            print(f"WARNING: Duplicate name: {h.name}")
    onH = headers[len(headers) - 1]
    count = 0
    while True and onH:
        iteratorFn(onH)
        if onH.prev == "":
            return True
        onH = byName[onH.prev]
        count += 1
        if count == 0:
            print("Loop detected!")
            return False


def validate_links(headers):
    numHeaders = len(headers)
    count = 0
    def traverse_fn(header):
        nonlocal count
        count += 1
    if not traverse_headers(headers, traverse_fn):
        print("Loop detected in list of headers")
        return False
    if count != numHeaders:
        print("Some link between the headers must be broken, ")
        return False
    
    count = 0
    if not traverse_backwards(headers, traverse_fn):
        print("Loop detected in list of headers BACKWARDS")
        return False
    if count != numHeaders:
        print("Some link between the headers must be broken, BACKWARDS")
        return False
    else:
        return True

def validate_macro_types(headers):
    startAndEndValid = headers[0].type == HeaderType.Start and headers[len(headers)-1].type == HeaderType.End
    if not startAndEndValid:
        print("start and/or end type not valid")
    middleValid = True
    for i in range(1, len(headers) - 1, 1):
        if headers[i].type != HeaderType.Middle:
            print(f"header: {headers[i].name} is not type middle")
            middleValid = False
    return middleValid and startAndEndValid



def main():
    args = do_cmd_args()
    try:
        word_headers = []
        as_file = open(args.assembly_file, "r")
    except:
        print(f"Can't open file: {args.assembly_file}")

    word_headers, allLines = parse_lines(as_file)
    as_file.close()

    for header in word_headers:
        header.deduce_type_from_body()
        if len(header.errors) > 0:
            header.report_errors()

    
    if validate_macro_types(word_headers):
        print("valid macro types")
    else:
        print("header macro types not valid")

    if validate_links(word_headers):
        print("headers form a valid linked list")
    else:
        print("headers don't form a valid linked list")

    print()

    if args.list_words:
        print("List of word headers:")
        for header in word_headers:
            print(f"Name: {header.name}, Code: {header.code}, IsImmediate: {header.b_immediate}")
    
    if args.report_types:
        num_prim = sum(1 for x in word_headers if x.wordType == WordType.Primary)
        num_sec  = sum(1 for x in word_headers if x.wordType == WordType.Secondary)
        num_mal  = sum(1 for x in word_headers if x.wordType == WordType.Malformed)
        num_und  = sum(1 for x in word_headers if x.wordType == WordType.Undefined)
        print(f"Word Types:\nPrimative: {num_prim}\nSecondary: {num_sec}\nMalformed: {num_mal}\nUndefined: {num_und}\nTotal: {len(word_headers)}")
        pass

    if args.globals_string:
        for header in word_headers:
            print(f".global {header.name}_impl")

    if args.new_word_name:
        add_new_word(word_headers, allLines, args)
        with open('VMout.S', 'w') as f:
            f.writelines(allLines)
main()