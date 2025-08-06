from AssemblySrcParser import WordHeader, HeaderType, build_new_end_macro_line

def add_new_word(word_headers, allLines, args):
    """
        word_headers: as returned from parse_lines
        allLines: as returned from parse_lines
        args: {
            new_word_name : str,
            new_word_code : str,
            immediate : bool
        }
    """
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