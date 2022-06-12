# 
# A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

import toktok
import std/[ropes, tables]

from std/algorithm import reverse, SortOrder
from std/strutils import parseBool, parseInt, `%`, indent, join

import ./meta, ./utils

tokens:
    Lbr          > '['
    Rbr          > ']'
    Colon        > ':'
    Comma        > ','
    Hyphen       > '-'
    Slash        > '/'
    Comment      > '#' .. EOL
    Backslash    > '\\'
    Bool_True    > @["TRUE", "True", "true", "YES", "Yes", "yes", "y"]
    Bool_False   > @["FALSE", "False", "false", "NO", "No", "no", "n"]

type
    BracketType = enum
        None, Square, Curly

    Parser* = object
        lex*: Lexer
        error: string
        inArray, inObject: bool
        prev, curr, next, lastKey: TokenTuple
        # brackets: seq[BracketType]
        brackets: OrderedTable[int, BracketType]
        lastParent: seq[TokenTuple]
        lastArray: seq[int]
        contents: Rope

proc setError[T: Parser](p: var T, msg: string) =
    p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $p.curr.col]

proc hasError*[T: Parser](p: var T): bool =
    result = p.error.len != 0

proc getError*[T: Parser](p: var T): string =
    result = p.error

proc getLiteral(): set[TokenKind] =
    result = {TK_STRING, TK_INTEGER, TK_BOOL_TRUE, TK_BOOL_FALSE}

proc getAssignableTokens(): set[TokenKind] = 
    result = {TK_STRING, TK_INTEGER, TK_BOOL_TRUE, TK_BOOL_FALSE, TK_IDENTIFIER}

proc isKey[T: TokenTuple](token: T): bool =
    ## Determine if current TokenKind is TK_IDENTIFIER
    result = token.kind == TK_IDENTIFIER

proc isBool[T: TokenTuple](token: T): bool =
    result = token.kind in {TK_BOOL_TRUE, TK_BOOL_FALSE}

proc isString[T: TokenTuple](token: T): bool =
    result = token.kind == TK_STRING

proc isInt[T: TokenTuple](token: T): bool =
    result = token.kind == TK_INTEGER

proc isEOF[T: TokenTuple](token: T): bool =
    ## Determine if current TokenKind is TK_EOF
    result = token.kind == TK_EOF

proc isChildOf[T: TokenTuple](token: T, parentToken: T): bool =
    result = token.col > parentToken.col 

proc startBracket[P: Parser](p: var P, bracket: BracketType) =
    ## Open either a Curly or Square bracket
    p.brackets[p.prev.line] = bracket
    case p.brackets[p.prev.line]:
        of Curly: p.contents.add("{")
        of Square: p.contents.add("[")
        else: discard

proc endBracket[P: Parser](p: var P, lineno = -1) =
    ## Close a bracket based on given line number
    var lineNumber = if lineno == -1: p.curr.line else: lineno
    if p.brackets.len != 0:
        if p.brackets.hasKey(lineNumber):
            let bk = p.brackets[lineNumber]
            case bk:
            of Curly, Square:
                if bk == Curly: p.contents.add("}")
                else:           p.contents.add("]")
                p.brackets.del(lineNumber)
                if not p.next.isEOF():
                    p.contents.add(",")
            else: discard

proc endBrackets[P: Parser](p: var P, maxLevel = 0) =
    var bklen = p.brackets.len
    if bklen == 0: return
    p.brackets.sort(system.cmp, order = SortOrder.Descending)
    for lineNumber, bk in p.brackets.pairs():
        case bk:
        of Curly, Square:
            if bk == Curly: p.contents.add("}")
            else:           p.contents.add("]")
            if not p.next.isEOF():
                p.contents.add(",")
        else: discard
    p.brackets.clear()

template jump[P: Parser](p: var P, offset = 1): untyped =
    var i = 0
    while offset > i:
        inc i
        p.prev = p.curr
        p.curr = p.next
        p.next = p.lex.getToken()
        while p.next.kind == TK_COMMENT:
            p.next = p.lex.getToken()

proc expect(kind, expectKind: TokenKind): bool =
    ## Determine if token kind is as expected
    result = kind == expectKind

proc expect(kind: TokenKind, expectKind: set[TokenKind]): bool =
    ## Determine if token kind is in given given set
    result = kind in expectKind

proc j(value: string): string =
    result = "\"" & value & "\""

proc j(value: string, isKey: bool): string =
    result = "\"" & value & "\":"

template writeKey[T: Parser](p: var T) =
    let keyToken = p.curr
    p.contents.add j(keyToken.value, true)
    jump p

    if p.next.kind.expect(TK_HYPHEN):
        if p.curr.line == p.next.line:
            p.setError("Bad nest for array declaration")
            break
        jump p
        if not p.next.kind.expect(getAssignableTokens()):
            p.setError("Invalid value assignment for array declaration")
            break
        p.inArray = true
        p.lastArray.add(p.curr.line)
        p.startBracket(Square)
    elif not p.next.kind.expect(getAssignableTokens()):
        p.setError("Missing value assignment for \"$1\" identifier" % [keyToken.value])
        break

    if p.next.isKey() and p.next.col == keyToken.col:
        p.setError("Missing value assignment for \"$1\" identifier" % [keyToken.value])
        break
    jump p

    if p.curr.isKey() and p.curr.isChildOf(keyToken):
        p.startBracket(Curly)
        p.lastParent.add(keyToken)
    p.lastKey = keyToken

template writeBool[T: Parser](p: var T) =
    p.contents.add(parseBoolValueStr(p.curr.value))

template writeString[T: Parser](p: var T) =
    p.contents.add j(p.curr.value)

template writeInt[T: Parser](p: var T) =
    p.contents.add p.curr.value

template writeLiteralSnippet[P: Parser](p: var P) =
    if p.curr.isBool:       p.writeBool()
    elif p.curr.isString:   p.writeString()
    elif p.curr.isInt:      p.writeInt()

template writeLiteral[T: Parser](p: var T) =
    p.writeLiteralSnippet
    if p.next.isKey():
        if p.next.col > p.lastKey.col:
            p.setError("Invalid nesting after closing literal")
            break
    
    if p.next.isEOF():
        p.endBrackets()
    else:
    
        if p.lastParent.len != 0:
            let getLastParent = p.lastParent[^1]
            if p.next.isKey() and p.next.isChildOf(getLastParent) == false:
                if p.lastKey.col == getLastParent.col:
                    p.contents.add(",")
                else:
                    var i = 0
                    let parentPos = getLastParent.col
                    let currPos = p.next.col
                    if currPos == 0 and parentPos != 0:
                        let lastParentLen = p.lastParent.len
                        if not p.next.isEOF() and lastParentLen != 0:
                            while i < lastParentLen:
                                inc i
                                p.endBracket(p.lastParent[^1].line)
                                p.lastParent.delete(p.lastParent.high)
                            i = 0
                        else:
                            p.endBracket(p.lastParent[^1].line)
                            p.lastParent.delete(p.lastParent.high)
                    elif currPos == 0 and parentPos == 0:
                        p.endBracket(p.lastParent[^1].line)
                        p.lastParent.delete(p.lastParent.high)
                    else:
                        i = 0
                        let levels = int(parentPos / currPos)
                        while i < levels:
                            inc i
                            p.endBracket(p.lastParent[^1].line)
                            p.lastParent.delete(p.lastParent.high)
                        i = 0
        if p.next.isKey():
            if p.next.col == p.lastKey.col:
                if not p.inArray: p.contents.add(",")
        if p.next.kind != TK_HYPHEN and p.inArray == true:
            p.inArray = false
            p.endBracket(p.lastArray[^1] - 1)
            p.lastArray.delete(p.lastArray.high)
        elif p.inArray:
            p.contents.add(",")
    jump p

proc walk[P: Parser](p: var P) =
    while p.hasError == false and p.lex.hasError == false:
        if p.curr.isEOF(): break
        case p.curr.kind:
            of TK_IDENTIFIER:
                # if (p.next.kind == TK_IDENTIFIER and p.prev.kind == TK_COLON):
                #     if p.curr.line != p.next.line:
                #         p.setError("Wrong string assignment")
                #         break
                #     var str = p.curr.value
                #     let currln = p.curr.line
                #     p.writeKey()
                #     jump p
                #     while currln == p.next.line and p.next.kind != TK_EOF:
                #         str &= indent(p.curr.value, 1)
                #         jump p
                #     p.curr.kind = TK_STRING
                #     p.curr.value = str & indent(p.curr.value, 1)
                #     continue
                if p.next.kind.expect TK_SLASH:
                    var initCol = p.curr.col
                    var key: seq[string]
                    while true:
                        if p.curr.kind.expect TK_IDENTIFIER:
                            key.add p.curr.value
                        elif p.curr.kind.expect TK_SLASH:
                            jump p
                            continue
                        if p.next.kind.expect TK_COLON:
                            p.curr.value = join(key, "/")
                            p.curr.col = initCol
                            break
                        jump p
                elif not p.next.kind.expect TK_COLON:
                    p.setError("Missing assignment token \":\"")
                    break
                p.writeKey()
            of TK_HYPHEN:
                p.inArray = true
                jump p
            of getLiteral():
                if p.next.kind.expect(TK_COLON):
                    p.curr.kind = TK_IDENTIFIER
                    continue
                p.writeLiteral()
            of TK_COMMENT:
                jump p
            else: discard           ## TODO raise exception

proc getContents*[P: Parser](p: var P): string = 
    ## Retrieve parsed YAML as JSON string
    result = $p.contents

proc parseYAML*(yamlContents: string): Parser =
    var p: Parser = Parser(lex: Lexer.init(yamlContents))
    p.curr  = p.lex.getToken()
    p.next  = p.lex.getToken()
    p.contents.add("{")
    p.walk()
    p.contents.add("}")
    result = p
    p.lex.close()
