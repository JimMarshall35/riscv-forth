import argparse
from enum import Enum

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
    args = parser.parse_args()
    return args

class HeaderType(Enum):
    Undefined = 0
    Start = 1
    Middle = 2
    End = 3

class HeaderSemantic(Enum):
    Irrelevant = 0
    Name = 1
    Code = 2
    IsImmediate = 3
    Next = 4
    Prev = 5

# how many arguments is each type of header macro supposed to have and what are they?
header_info = {
    HeaderType.Start  : [
        HeaderSemantic.Name, HeaderSemantic.Code, HeaderSemantic.IsImmediate, HeaderSemantic.Next
    ],
    HeaderType.Middle : [
        HeaderSemantic.Name, HeaderSemantic.Code, HeaderSemantic.IsImmediate, HeaderSemantic.Next, HeaderSemantic.Prev
    ],
    HeaderType.End    : [
        HeaderSemantic.Name, HeaderSemantic.Code, HeaderSemantic.IsImmediate, HeaderSemantic.Prev
    ]
}    
word_header_str = "word_header"
word_header_first_str = "word_header_first"
word_header_last_str = "word_header_last"

class WordType(Enum):
    Undefined = 0
    Primary = 1
    Secondary = 2
    Malformed = 3

class WordHeader:
    def deduce_type_from_body(self):
        def secondary_word_macro_present(self):
            matches = [x for x in self.body if "secondary_word" in x]
            if len(matches) > 1:
                self.errors.append(f"more than one possible secondary header line present ({len(matches)})")
            for m in matches:
                split_res = m.split()
                if len(split_res) != 2 or split_res[1] != self.name:
                    self.errors.append(f"malformed secondary word header line '{m}'")
            return len(matches) == 1 and len(self.errors) == 0
        
        def validate_as_primary_word(self):
            matches = [x for x in self.body if "end_word" in x]
            if len(matches):
                self.wordType = WordType.Primary
            else:
                self.wordType = WordType.Malformed
                self.errors.append("no 'end_word' macro present")
        
        if secondary_word_macro_present(self):
            self.wordType = WordType.Secondary
        else:
            validate_as_primary_word(self)
        

    def add_line_to_body(self, line):
        self.body.append(line)

    def get_line_string(self):
        if self.type == HeaderType.Start:
            return build_new_start_macro_line(self.name, self.code, self.b_immediate, self.next)
        elif self.type == HeaderType.Middle:
            return build_new_mid_macro_line(self.name, self.code, self.b_immediate, self.next, self.prev)
        elif self.type == HeaderType.End:
            return build_new_end_macro_line(self.name, self.code, self.b_immediate, self.prev)
        else:
            assert False

    def populate_fields(self, args):
        assert len(args) == len(header_info[self.type])
        for i in range(len(header_info[self.type])):
            sem =  header_info[self.type][i]
            val = args[i]
            if sem == HeaderSemantic.Name:
                self.name = val
                pass
            elif sem == HeaderSemantic.Code:
                self.code = val
                pass
            elif sem == HeaderSemantic.IsImmediate:
                self.b_is_valid = bool(val)
                pass
            elif sem == HeaderSemantic.Next:
                self.next = val
                pass
            elif sem == HeaderSemantic.Prev:
                self.prev = val
                pass

    def validate(self):
        self.b_is_valid = False
        s = self.line_str.split(' ')
        if ".macro" in s:
            self.b_is_valid = False
            return
        elif word_header_str in s:
            index = s.index(word_header_str)
            if index == 0:
                self.b_is_valid = True
                self.type = HeaderType.Middle
        elif word_header_first_str in s:
            index = s.index(word_header_first_str)
            if index == 0:
                self.b_is_valid = True
                self.type = HeaderType.Start
        elif word_header_last_str in s:
            index = s.index(word_header_last_str)
            if index == 0:
                self.b_is_valid = True
                self.type = HeaderType.End
        if not self.b_is_valid:
            return
        
        numargs = 0
        args = []

        for i in range(1, len(s), 1): # iterate macro args
            token = s[i]
            if token == "":
                continue
            if token != ",":
                numargs += 1
                # all tokens besides last one must end in ','
                if i < len(s) - 1:
                    if token[-1] == ',':
                        args.append(token[:-1])
                    elif s[i+1] == ",":
                        args.append(token)
                    else:
                        self.b_is_valid = False
                        self.errors.append(f"Expected a ',' after token {token}")
                elif token[-1] != ',':
                    args.append(token.rstrip())
                else:
                    self.b_is_valid = False
                    self.errors.append(f"last token: {token}, can't end in a comma")
                    
        if not self.b_is_valid:
            return
        
        assert numargs == len(args)

        if numargs != len(header_info[self.type]):
            self.errors.append(f"{numargs} recieved {len(header_info[self.type])} expected")
            return
        
        self.populate_fields(args)
    
    def report_errors(self):
        assert len(self.errors) > 0
        print(f"Word name: '{self.name}' errors: \n{'\n'.join(self.errors) + '\n'}")

    def __init__(self, line_str, line_num):
        self.line_str = line_str
        self.b_is_valid = False
        self.type = HeaderType.Undefined

        # Every line is fed into this class to be validated
        # as a possible word header. We'll emit errors and warnings
        # only if it's close enough to being a valid word header but 
        # there's something slightly wrong.
        # Nothing will be emitted for ones that are not a wordheader at all 
        self.errors = []

        self.name = ""
        self.code = ""
        self.b_immediate = False
        self.next = ""
        self.prev = ""
        self.line_num = line_num
        self.b_dirty = False
        self.body = []
        self.wordType = WordType.Undefined
        self.validate()
    
    def valid(self):
        return self.b_is_valid

def parse_lines(file): 
    allLines = []
    headers = [] 
    lineCtr = 0
    currentHeader = None
    for line in file.readlines():
        h = WordHeader(line,lineCtr)
        allLines.append(line)
        if len(h.errors) != 0:
            print(f"Line {line} errors:")
            for e in h.errors:
                print(e)
        if h.valid():
            headers.append(h)
            currentHeader = h
        elif currentHeader != None:
            currentHeader.add_line_to_body(line)
        lineCtr += 1
    return headers, allLines

def build_new_macro_line(wordHeader, name, code, b_immediate, next, prev):
    if next != "" and prev != "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {next}, {prev}"
    elif next == "" and prev != "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {prev}"
    elif next != "" and prev == "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {next}"
    

def build_new_end_macro_line(name, code, b_immediate, prev):
    return build_new_macro_line(word_header_last_str, name, code, b_immediate, "", prev)

def build_new_mid_macro_line(name, code, b_immediate, next, prev):
    return build_new_macro_line(word_header_str, name, code, b_immediate, next, prev)

def build_new_start_macro_line(name, code, b_immediate, next):
    return build_new_macro_line(word_header_first_str, name, code, b_immediate, next, "")

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

    if args.new_word_name:
        print(f"Adding new word, '{args.new_word_name}'")
        oldTail = word_headers[len(word_headers)-1]
        oldTail.type = HeaderType.Middle
        word_headers.append(
            WordHeader(
                build_new_end_macro_line(
                    args.new_word_name,
                    args.new_word_code if args.new_word_code else args.new_word_name,
                    1 if args.immediate else 0,
                    oldTail.name
                ),
                len(allLines)
            )
        )
        newTail = word_headers[len(word_headers)-1]
        oldTail.next = newTail.name
        newTail.prev = oldTail.name
        allLines[oldTail.line_num] = oldTail.get_line_string() + "\n"
        allLines.append(newTail.get_line_string())
        with open('VMout.S', 'w') as f:
            f.writelines(allLines)
main()