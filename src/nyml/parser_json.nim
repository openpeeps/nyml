# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
#

import std/json
from std/strutils import `%`, contains, split, parseInt, parseBool, join
import ./lexer, ./meta

type
    Document* = object
        json_contents: JsonNode         # Used by Y2J engine to store JSON contents
        yaml_contents: string           # Used by J2Y engine to store YAML contents

    Parser* = object
        lexer: Lexer
        prev, current, next: TokenTuple
        error: string

    TokenTuple = tuple[kind: TokenKind, value: string, wsno, col, line: int]

proc getValue[T: TokenTuple](tk: T): string =
    return case tk.kind:
        of TK_INTEGER, TK_BOOLEAN: tk.value
        of TK_STRING: "\"" & tk.value & "\""
        else: ""

proc get(contents: JsonNode, key: string = ""): JsonNode = 
    ## Access data from current document using dot annotations.
    ## When not found, returns `null` (JsonNode)
    if key.contains("."):
        var i = 0
        var k = key.split(".", maxsplit=1)
        var tree: JsonNode
        while true:
            try:
                tree = contents[k[i]]
                inc i
                tree = get(tree, k[i])
            except KeyError:
                break
        result = tree
    elif key.len == 0:
        result = contents
    else:
        if contents.hasKey(key):
            result = contents[key]
        else:
            result = newJNull()

proc get*[T: Document](doc: T, key: string = ""): JsonNode =
    ## Browse to current document content and retrieve
    ## values using dot annotation key.
    ## For example: get("user.email.business")
    return get(doc.json_contents, key)

proc putIt(contents: JsonNode, key: string, value: JsonNode, isLastCall=false): JsonNode =
    # Kinda nasty setter that creates json levels recursively
    if key.contains("."):
        var i = 0
        var last = false
        var k = key.split(".", maxsplit=1)
        var tree = newJObject()
        while true:
            try:
                tree[k[i]] = tree.putIt(k[i + 1], value)
                inc i
            except IndexDefect:
                last = true
                break
        return tree
    return %*{key: value}

proc setError[T: Parser](p: var T, lineno: int, msg: string) = p.error = "Error ($2:$3): $1" % [msg, $lineno, "13"]
proc hasError[T: Parser](p: var T): bool = p.error.len != 0
proc isSame(a, b: int): bool = result = a == b
proc isSameWith(prev, curr: TokenKind, these: set[TokenKind]): bool = prev in these and curr in these
proc isKey(tk: TokenTuple): bool = tk.kind == TK_KEY
proc isArray(tk: TokenTuple): bool = tk.kind == TK_ARRAY_VALUE
proc isSameLine(next, curr: TokenTuple): bool = curr.line == next.line
proc isLiteral(tk: TokenTuple): bool = tk.kind in {TK_STRING, TK_INTEGER, TK_BOOLEAN}
proc isChildOf(next, curr: TokenTuple): bool = next.wsno > curr.wsno

proc isInlineArray(tk: TokenKind): bool =
    # Determine if current token is type of TK_ARRAY
    return tk == TK_ARRAY_BLOCK

proc isValue(): bool =
    # Determine if current token is kind of
    # TK_STRING, TK_INTEGER, TK_BOOLEAN or TK_ARRAY
    discard

proc jump[T: Parser](p: var T, offset = 1) =
    var i = 0
    while offset > i: 
        p.prev = p.current
        p.current = p.next
        p.next = p.lexer.getToken()
        inc i

proc parseToJson*[T: Nyml](yml: var T, nymlContents: string): Document =
    var p: Parser = Parser(lexer: Lexer.init(nymlContents))
    var contents: string
    p.current = p.lexer.getToken()
    p.next    = p.lexer.getToken()
    while p.hasError() == false:
        if p.current.kind == TK_EOL: break # end of line
        if p.prev.kind == TK_NONE or p.prev.isLiteral():
            if p.current.wsno != 0:
                p.setError(p.next.line, "Bad indentation for first key declaration, \"$1\"." % [p.current.value])
                break
        if p.current.isKey() and p.next.isLiteral():
            if not p.next.isSameLine(p.current):
                p.setError(p.next.line, "Bad indentation for '$1' key declaration" % [p.current.value])
                break
            add contents, "\"$1\": \"$2\"," % [p.current.value, p.next.value]
            jump p, 2
            # echo p.next
            # if p.next.isLiteral():
            #     p.setError(p.current.line, "Unallowed mix of values assigned to the same key.")
            #     break
        elif p.current.isKey():
            if not p.next.isKey():
                p.setError(p.current.line, "Missing key declaration")
                break
            let parent = p.current
            jump p
            add contents, "\"$1\": {" % [parent.value]
            var arrays: seq[string]
            var arrayKey: string
            var i = 0
            while true:
                if not p.current.isChildOf(parent):
                    add contents, "},"
                    break
                else:
                    while true:
                        if not p.next.isArray(): break
                        if p.current.isKey():
                            add contents, "\"$1\":" % [p.current.value]
                        arrays.add("$1" % [getValue(p.next)])
                        inc i
                        jump p
                    if arrays.len != 0 and arrays.len == i:
                        add contents, "[$1], " % [join(arrays, ", ")]
                        i = 0
                        arrays = @[]
                    else:
                        add contents, "\"$1\": $2," % [p.current.value, getValue(p.next)]
                        jump p
                jump p

            #     let root = p.current
            #     let second = p.next
            #     contents[root.value] = newJObject()
            #     contents[root.value][second.value] = newJObject()
            #     jump p, 1
            #     var tree = newJObject()
            #     echo p.current
            # else:
            #     echo "elsee"
    p.lexer.close()

    contents = "{$1}" % [contents]
    echo contents

    if p.hasError():
        echo "\n" & p.error & "\n"
        result = Document(json_contents: %*{})
    else: 
        result = Document(json_contents: parseJson(contents))