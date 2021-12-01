# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
#

import json, ./meta
from ./lexer import TokenKind
from strutils import `%`, contains, split, parseInt, parseBool
import ./utils

type Document* = object
        json_contents: JsonNode         # Used by Y2J engine to store JSON contents
        yaml_contents: string           # Used by J2Y engine to store YAML contents

proc getTknValByType(tk: TokenKind, tk_val: string): JsonNode =
    # Internal procedure for mapping given
    # token value with a JsonNode of its kind
    var value: JsonNode 
    value = case tk:
            # of TK_STRING: newJString(tk_val)
            of TK_INTEGER: newJInt(parseInt(tk_val))
            of TK_BOOLEAN: newJBool(parseBool(tk_val))
            of TK_ARRAY: parseJson(tk_val)
            else: newJString(tk_val)
    return value


proc get(jContents: JsonNode, key: string = ""): JsonNode = 
    # TODO try implement dot annotation access using macros:
    # doc.get("field.level.second.third")
    # 
    # produce:
    # field["level"]["second"]["third"]
    # 
    # from:
    # nnkStmtList.newTree(
    #   nnkBracketExpr.newTree(
    #     nnkBracketExpr.newTree(
    #       nnkBracketExpr.newTree(
    #         newIdentNode("field"),
    #         newLit("level")
    #       ),
    #       newLit("second")
    #     ),
    #     newLit("third")
    #   )
    # )
    if key.contains("."):
        var i = 0
        var k = key.split(".", maxsplit=1)
        var tree: JsonNode
        while true:
            try:
                tree = jContents[k[i]]
                inc i
                tree = get(tree, k[i])
            except KeyError:
                break
        return tree
    elif key.len == 0:
        return jContents
    else:
        return jContents[key]

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

proc setError[T: Nyml](handler: var T, lineno: int, msg: string) =
    # Set an error during parsing
    handler.error = "NymlError: $1 (line: $2)" % [msg, $lineno]

proc hasError[T: Nyml](handler: var T): bool =
    # Determine if current parse process has errors
    result = handler.error.len != 0

proc isSame(a, b: int): bool =
    result = a == b
proc isSameWith(prev, curr: TokenKind, these: set[TokenKind]): bool = prev in these and curr in these

proc assignValue(curr: tuple[kind: TokenKind, value, annot: string, line, indent: int]): JsonNode =
    # Assign a value to its key. It can be either TK_STRING, TK_INTEGER or TK_BOOLEAN.
    var value: JsonNode
    case curr.kind:
    of TK_STRING:
        value = newJString(curr.value)
    of TK_INTEGER:
        value = newJInt(parseInt(curr.value))
    of TK_BOOLEAN:
        value = newJBool(parseBool(curr.value))
    else: discard
    return value

proc assignArrayValue(curr: tuple[kind: TokenKind, value, annot: string, line, indent: int]): JsonNode =
    var value: JsonNode
    var parsed = false
    try:
        # Try parse as a boolean value. For more details related
        # string to bool values check parseBoolValue procedure from ./utils
        value = newJBool(parseBoolValue(curr.value))
        parsed = true
    except ValueError:
        parsed = false

    if not parsed:
        # If could not parse as a boolean, let's try parsing as an integer
        try:
            value = newJInt(parseInt(curr.value))
        except ValueError:
            parsed = false
    if not parsed:
        value = newJString(curr.value)

    return value

macro createJsonArray(): untyped =
    # Macro for creating dynamic JSON Arrays
    discard

macro createJsonObject(): untyped =
    # Macro for creating dynamic JSON Objects
    discard

proc isKey(tk: TokenKind): bool =
    # Determine if current token is kind of TK_KEY 
    return tk == TK_KEY

proc isArray(tk: TokenKind): bool =
    # Determine if current token is type of TK_ARRAY_BLOCK
    return tk == TK_ARRAY_VALUE

proc isInlineArray(tk: TokenKind): bool =
    # Determine if current token is type of TK_ARRAY
    return tk == TK_ARRAY_BLOCK

proc isValue(): bool =
    # Determine if current token is kind of
    # TK_STRING, TK_INTEGER, TK_BOOLEAN or TK_ARRAY
    discard

proc isLiteral(tokenKind: TokenKind): bool =
    # Determine if current token kind is in given literal set.
    return tokenKind in {TK_STRING, TK_INTEGER, TK_BOOLEAN}

proc isChildOf(currIndent, prevIndent: int): bool =
    # Determine if current token is child of given previous key
    return currIndent > prevIndent

proc parseToJson*[T: Nyml](yml: var T,
    tokens: seq[tuple[kind: TokenKind, value, annot: string,  line, indent: int]]): Document =
    var
        i = 0
        ii = 0
        contents = %* {}
        tokensLength = tokens.len
        allTokens = tokens
        treekeys: string
        curr, prev, currKey, prevKey, origin, root: tuple[
            kind: TokenKind,    # the token type
            value: string,      # the token value
            annot: string,      # holds dot annotations of creating/accessing deeper levels
            line, indent: int   # line nunber and indentations (whitespaces)
        ]

    root.kind = TK_SKIPPABLE

    while true:
        if i == tokensLength:
            break # nothing to parse
        try:
            curr = allTokens[i]
        except IndexDefect:
            break

        if curr.kind == TK_KEY:
            currKey = curr

        if curr.kind == TK_COMMENT:
            delete(allTokens, i)
            continue

        if prev.kind == TK_NONE:
            if curr.kind == TK_KEY and curr.indent != 0:
                yml.setError(curr.line, "First key cannot be indented")
                break
            elif curr.kind != TK_KEY:
                yml.setError(curr.line, "Missing key declaration")
                break
            contents[curr.value] = newJObject()
            prev = curr         # current token as previously token declaration
            prevKey = curr      # current token as previously key declaration
        else:
            # Start create the key-value assignment
            if curr.kind.isKey():
                # Before parsing tokens we must ensure we have
                # some clean contents following the NYML standards
                if currKey.line.isSame(prevKey.line):
                    # Prevent multiple key declarations on the same line
                    yml.setError(currKey.line, "Key '$1' has conflict with '$2'" % [currKey.value, prevKey.value])
                    break
                elif currKey.indent.isSame(prevKey.indent) and prev.kind.isLiteral() == false:
                    # Prevent multiple key declarations on different lines without indentation
                    yml.setError(currKey.line, "Bad indentation for '$1' key declaration" % [currKey.value])
                    break
                if currKey.indent.isChildOf(prevKey.indent):
                    # Handle key declarations for deeper levels
                    echo curr
                else:
                    # Otherwise define keys with a predefined object type value
                    # This is the first case for key declaratiosn
                    contents[curr.value] = newJObject()
                    currKey = curr      # set current token key
                prev = curr
            else:
                if currKey.indent.isChildOf(prevKey.indent):
                    # Handle value assignments for deeper levels
                    echo curr
                else:
                    # Otherwise is just a simple key-value assignment
                    if curr.kind.isArray():
                        if contents[currKey.value].len == 0:
                            contents[currKey.value] = newJArray()
                        contents[currKey.value].add(assignArrayValue(curr))
                    else:

                        if prev.kind.isLiteral() or prev.kind in {TK_ARRAY_VALUE}:
                            yml.setError(curr.line, "Unallowed mix of values assigned to the same key.")
                            break

                        contents[currKey.value] = assignValue(curr)
                
                prev = curr             # set current token as previous
                prevKey = currKey       # set current key as previous
        inc i

    if yml.hasError():
        echo "\n" & yml.error & "\n"
        result = Document(json_contents: newJObject())
    else: 
        result = Document(json_contents: contents)