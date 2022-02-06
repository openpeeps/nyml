# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
#

import std/json
from std/strutils import `%`, contains, split, parseInt, parseBool, parseFloat, join
import ./lexer, ./meta

export json

type

    DocumentError = object
        msg: string

    Document* = object
        json_contents: JsonNode         # Used by Y2J engine to store JSON contents
        yaml_contents: string           # Used by J2Y engine to store YAML contents
        rules: seq[string]              # Used to validate the parsed JSON
        has_errors: bool
        getTotalErrors: int
        errors: seq[DocumentError]

    Parser* = object
        lexer: Lexer
        prev, current, next: TokenTuple
        error: string
        parents: seq[TokenTuple]        # TODO store all parents in a sequence so it can be removed one by one after resolved
        contents: string                # Holds stringified JSON contents

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
    return get(doc.json_contents, key)

proc getRuleTypeNode(nodetype: string): JsonNodeKind =
    return case nodetype:
        of "array": JArray
        of "bool": JBool
        of "float": JFloat
        of "int": JInt
        of "object": JObject
        of "string": JString
        else: JNull

proc getValueByNode(nodetype: JsonNodeKind, value: string): JsonNode = 
    return case nodetype:
        of JArray: newJArray()
        of JBool: newJBool(parseBool(value))
        of JFloat: newJFloat(parseFloat(value))
        of JInt: newJInt(parseInt(value))
        of JObject: newJObject()
        of JString: newJString(value)
        else: newJNull()

proc getTypeStr(nodetype: JsonNodeKind): string = 
    return case nodetype:
        of JArray: "array"
        of JBool: "bool"
        of JFloat: "float"
        of JInt: "int"
        of JObject: "object"
        of JString: "string"
        else: "null"    

proc parseRuleString(r: string): tuple[key: string, req: bool, expect: JsonNodeKind, default: JsonNode] =
    let
        rule = r.split("*")
        isRequired = if rule.len == 1: false else: true
    var
        fieldKey, fieldType, defaultVal: string
        ruleStruct: seq[string]
    if isRequired:
        fieldKey = rule[0]
        fieldType = rule[1].split(":")[1]
        if fieldType.contains("|"):
            raise newException(NymlException, "Required fields cannot hold a default value")
    else:
        ruleStruct = rule[0].split(":")
        fieldKey = ruleStruct[0]
        fieldType = ruleStruct[1]
        if fieldType.contains("|"):
            ruleStruct = fieldType.split("|")
            fieldType = ruleStruct[0]
            if fieldType in ["array", "object", "string"]:
                raise newException(NymlException, "\"$1\" fields cannot hold a default value" % [fieldType])
            defaultVal = ruleStruct[1]
    if fieldType notin ["array", "bool", "float", "int", "object", "string", "null"]:
        raise newException(NymlException, "\"$1\" is not valid typed value")

    let jsonNodeType = getRuleTypeNode(fieldType)
    let defaultJsonNodeValue = getValueByNode(jsonNodeType, defaultVal)
    return (key: fieldKey, req: isRequired, expect: jsonNodeType, default: defaultJsonNodeValue)

proc setRules*[T: Document](doc: var T, rules: seq[string]) =
    for r in rules:
        let rule = parseRuleString(r)
        var fieldVal: JsonNode = doc.get(rule.key)
        var fieldType: JsonNodeKind = rule.expect
        if fieldVal.kind == JNull:
            fieldVal = rule.default                 # get default value, if any
            doc.json_contents[rule.key] = fieldVal  # TODO create macro for set data with dot annotations
        if fieldVal.kind != fieldType:
            doc.errors.add(DocumentError(msg: "\"$1\" field is type of \"$2\", \"$3\" value given" % [rule.key, getTypeStr(fieldType), getTypeStr(fieldVal.kind)]))
            inc doc.getTotalErrors
    if doc.errors.len != 0: doc.has_errors = true

proc getErrorMessage*[T: DocumentError](docError: T): string = docError.msg
proc hasErrorRules*[T: Document](doc: T): bool = doc.has_errors
proc getErrorRules*[T: Document](doc: T): seq[DocumentError] = doc.errors
proc getErrorsCount*[T: Document](doc: T): int = doc.getTotalErrors

proc setError[T: Parser](p: var T, lineno: int, msg: string) = p.error = "Error ($2:$3): $1" % [msg, $lineno, "13"]
proc hasError[T: Parser](p: var T): bool = p.error.len != 0
proc isSame(a, b: int): bool = result = a == b
proc isSameWith(prev, curr: TokenKind, these: set[TokenKind]): bool = prev in these and curr in these
proc isKey(tk: TokenTuple): bool = tk.kind == TK_KEY
proc isArray(tk: TokenTuple): bool = tk.kind == TK_ARRAY_VALUE
proc isObject(tk: TokenTuple): bool = tk.kind == TK_KEY
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

proc walk(p: var Parser, isRecursive: bool = false, parentNode: TokenTuple) =
    var parent: TokenTuple
    while p.hasError() == false:
        if isRecursive and not p.current.isChildOf(parent):
            add p.contents, "},"
            return
        if p.current.kind in {TK_EOL, TK_INVALID}: break # end of line
        # if p.prev.kind == TK_NONE or p.prev.isLiteral():
        #     if p.current.wsno != 0:
        #         p.setError(p.next.line, "Bad indentation for first key declaration, \"$1\"." % [p.current.value])
        #         break
        if p.current.isKey() and p.next.isLiteral():
            if not p.next.isSameLine(p.current):
                p.setError(p.next.line, "Bad indentation for '$1' key declaration" % [p.current.value])
                break
            add p.contents, "\"$1\": $2," % [p.current.value, getValue(p.next)]
            jump p, 2

            if p.current.isLiteral():
                p.setError(p.current.line, "Unallowed mix of values assigned to the same key.")
                break
        elif p.current.isKey() and p.next.isKey():
            parent = p.current
            add p.contents, "\"$1\": {" % [p.current.value]
            jump p
            p.walk(isRecursive = true, parent)
    if isRecursive:
        add p.contents, "},"

proc parseToJson*[T: Nyml](yml: var T, nymlContents: string): Document =
    var p: Parser = Parser(lexer: Lexer.init(nymlContents))
    var contents: string
    var none    =  (kind: TK_NONE, value: "", wsno: 0, col: 0, line: 0)
    p.current = p.lexer.getToken()
    p.next    = p.lexer.getToken()
    
    add p.contents, "{"
    p.walk(parentNode = none)
    add p.contents, "}"
    
    p.lexer.close()

    if p.hasError():
        echo "\n" & p.error & "\n"
        result = Document(json_contents: %*{})
    else: 
        result = Document(json_contents: parseJson(p.contents))