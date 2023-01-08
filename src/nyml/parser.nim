import toktok
import std/[ropes, tables, json, jsonutils]

from strutils import parseInt, parseBool, `%`

static:
    Program.settings(true, "TK_")

tokens:
    LBR   > '['
    RBR   > ']'
    COLON > ':'
    COMMA > ','
    HYPHEN > '-'
    SLASH  > '/'
    BACKSLASH > '\\'
    COMMENT > '#' .. EOL
    NIL   > {"NIL", "Nil", "nil"}
    NULL  > {"NULL", "Null", "null"}
    TRUE  > {"TRUE", "True", "true", "YES", "Yes", "yes", "y"}
    FALSE > {"FALSE", "False", "false", "NO", "No", "no", "n"}

type
    NType = enum
        Nil
        Array
        Object
        String
        Int
        Bool
        Comment
        InlineComment

    Parser* = object
        lex*: Lexer
        prev, curr, next: TokenTuple
        lvl: Table[int, Node]
        error: string
        contents: Rope
        program: Program 
        rootType: NType

    Node = ref object
        case ntype: NType
        of Array:
            items: seq[Node]
            arrayInlineComment: string
        of Object:
            key: string
            value: seq[Node]
            objectInlineComment: string
        of String:
            strv: string
            strInlineComment: string
        of Int:
            intv: int
            intInlineComment: string
        of Bool:
            boolv: bool
            boolInlineComment: string
        of Comment:
            comments: seq[string]
        of InlineComment: discard
        of Nil: discard
        meta: tuple[line, col: int]

    Program = object
        nodes: seq[Node]

const
    assignables = {TK_STRING, TK_INTEGER, TK_TRUE, TK_FALSE, TK_IDENTIFIER}
    literals = {TK_STRING, TK_INTEGER, TK_TRUE, TK_FALSE, TK_NIL, TK_NULL}

proc setError[T: Parser](p: var T, msg: string) =
    p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $p.curr.pos]

proc hasError*[T: Parser](p: var T): bool =
    result = p.error.len != 0

proc getError*[T: Parser](p: var T): string =
    result = p.error

proc walk(p: var Parser, offset = 1) =
    var i = 0
    while offset > i:
        inc i
        p.prev = p.curr
        p.curr = p.next
        p.next = p.lex.getToken()
        # while p.next.kind == TK_COMMENT:
        #     p.next = p.lex.getToken()

proc getContents*(p: var Parser): string = $p.contents

template `$$`(value: string) = add p.contents, "\"" & value & "\":"
template `$=`(value: string) = add p.contents, "\"" & value & "\""
template `$=`(value: bool) = add p.contents, $value
template `$=`(value: int) = add p.contents, $value
proc `$`(program: Program): string = pretty toJson(program), 2

template `!`(nextBlock) =
    if p.curr.kind in literals:
        if p.curr.line != this.line:
            p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
            return
    nextBlock

template `!!`(nextBlock) =
    if p.curr.col < this.col:
        p.setError("Invalid indentation in array for \"$1\" item" % [p.next.value])
        break
    nextBlock

template `{`(subNode) =
    p.contents &= "{"
    subNode

template `}`() =
    p.contents &= "}"

template `[`(subNode) =
    p.contents &= "["
    subNode
template `]`() = p.contents &= "]"

proc writeNodes(p: var Parser, node: seq[Node]) =
    # Parse AST nodes and write JSON (strings)
    let nodeLen = node.len - 1 
    for i in 0 .. nodeLen:
        case node[i].ntype:
        of Object:
            if node[i].value.len != 1:
                $$ node[i].key
                `{`:
                    p.writeNodes(node[i].value)
                `}`
            elif node[i].value[0].ntype == Object:
                $$ node[i].key
                `{`:
                    p.writeNodes(node[i].value)
                `}`
            else:
                $$ node[i].key
                p.writeNodes(node[i].value)
        of Array:
            `[`:
                p.writeNodes(node[i].items)
            `]`
        of Bool:
            $= node[i].boolv
        of Int:
            $= node[i].intv
        of String:
            $= node[i].strv
        of Nil:
            p.contents &= "null"
        else: discard
        if i != nodeLen:
            if node[i].ntype != Comment:
                p.contents &= ","

proc newNode(p: var Parser, ntype: NType): Node =
    Node(ntype: ntype, meta: (line: p.curr.line, col: p.curr.col))

proc parse(p: var Parser): Node =
    # Parse YAML to AST nodes
    let this = p.curr
    case p.curr.kind:
    of TK_IDENTIFIER:
        result = p.newNode Object
        result.key = p.curr.value
        walk p, 2 # :
        p.lvl[this.col] = result
        if p.curr.kind in literals:
            ! result.value.add p.parse()
        elif p.curr.kind in {TK_IDENTIFIER, TK_HYPHEN} and p.curr.col > this.col:
            while p.curr.col > this.col and p.curr.kind in {TK_IDENTIFIER, TK_HYPHEN}:
                if p.curr.kind == TK_IDENTIFIER and p.next.kind != TK_COLON:
                    p.setError("Missing assignment token")
                    break
                let sub = p.parse()
                result.value.add sub
                if p.curr.col > sub.meta.col and p.curr.kind notin {TK_EOF, TK_HYPHEN}:
                    p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
                    break
        elif p.curr.kind == TK_LBR:
            result.value.add(p.parse())
    of TK_STRING:
        result = p.newNode String
        result.strv = p.curr.value
        walk p
    of TK_INTEGER:
        result = p.newNode Int
        result.intv = parseInt(p.curr.value)
        walk p
    of TK_TRUE:
        result = p.newNode Bool
        result.boolv = true
        walk p
    of TK_FALSE:
        result = p.newNode Bool
        result.boolv = false
        walk p
    of TK_LBR:
        result = p.newNode Array
        walk p
        while p.curr.kind != TK_RBR and (p.curr.line == this.line):
            if p.curr.kind == TK_EOF:
                p.setError("EOF reached before closing array")
                break
            result.items.add p.parse()
            if p.curr.kind != TK_RBR:
                if p.curr.kind == TK_COMMA and p.next.kind in literals:
                    walk p
                else:
                    p.setError("Invalid array item $1" % [p.curr.value])
        walk p
    of TK_HYPHEN:
        result = p.newNode Array
        while p.curr.kind == TK_HYPHEN:
            `!!`:
                walk p
                result.items.add(p.parse())
    of TK_COMMENT:
        result = p.newNode Comment
        walk p
    of TK_NULL, TK_NIL:
        result = p.newNode Nil
        walk p
    else: discard

proc parseYAML*(strContents: string): Parser =
    var p = Parser(lex: Lexer.init(strContents))
    p.curr = p.lex.getToken()
    p.next = p.lex.getToken()
    p.program = Program()
    while p.hasError == false and p.lex.hasError == false:
        if p.curr.kind == TK_EOF: break
        if p.curr.kind == TK_HYPHEN:
            p.rootType = Array
        else:
            p.rootType = Object
        p.program.nodes.add p.parse()
    if p.rootType == Array:
        p.writeNodes(p.program.nodes)
    else:
        p.contents &= "{"
        p.writeNodes(p.program.nodes)
        p.contents &= "}"
    result = p