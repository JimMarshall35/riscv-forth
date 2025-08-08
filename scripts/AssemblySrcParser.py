from enum import Enum

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


def build_new_macro_line(wordHeader, name, code, b_immediate, next, prev):
    if next != "" and prev != "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {next}, {prev}"
    elif next == "" and prev != "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {prev}"
    elif next != "" and prev == "":
        return f"{wordHeader} {name}, {code}, {1 if b_immediate else 0}, {next}"
    else:
        assert False

def build_new_end_macro_line(name, code, b_immediate, prev):
    return build_new_macro_line(word_header_last_str, name, code, b_immediate, "", prev)

def build_new_mid_macro_line(name, code, b_immediate, next, prev):
    return build_new_macro_line(word_header_str, name, code, b_immediate, next, prev)

def build_new_start_macro_line(name, code, b_immediate, next):
    return build_new_macro_line(word_header_first_str, name, code, b_immediate, next, "")


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
            elif sem == HeaderSemantic.Code:
                self.code = val
            elif sem == HeaderSemantic.IsImmediate:
                self.b_is_valid = bool(val)
            elif sem == HeaderSemantic.Next:
                self.next = val
            elif sem == HeaderSemantic.Prev:
                self.prev = val

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