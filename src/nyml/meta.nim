# 
# A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

import std/[json, tables]
from std/strutils import `%`, contains, split, parseInt, parseBool, parseFloat, join
export json

type
    NymlException* = object of CatchableError

    Nyml* = object
        yamlContents: string
        error: string

    DocumentError = object
        msg: string

    Document* = object
        contents*: JsonNode
        rules: seq[string]
        has_errors: bool
        errors: seq[DocumentError]
        getTotalErrors: int

    RuleTuple = tuple[key: string, req: bool, expect: JsonNodeKind, default: JsonNode]

proc init*[N: typedesc[Nyml]](newNyml: N, contents: string): Nyml =
    ## Initialize a new Nyml instance
    result = newNyml(yamlContents: contents)

proc getYamlContents*[N: Nyml](n: N): string {.inline.} =
    ## Retrieve YAMl contents fron Nyml object
    result = n.yamlContents

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

proc get(contents: JsonNode, key: string = ""): JsonNode = 
    ## Access data in current Json document using
    ## dot annotation, user.profile.name
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
    ## Access data in current Json document using
    ## dot annotation, user.profile.name
    result = get(doc.contents, key)

proc parseRuleString(r: string): RuleTuple =
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
        raise newException(NymlException, "\"$1\" is not valid type")

    let jsonNodeType = getRuleTypeNode(fieldType)
    let defaultJsonNodeValue = getValueByNode(jsonNodeType, defaultVal)
    result = (key: fieldKey, req: isRequired, expect: jsonNodeType, default: defaultJsonNodeValue)

proc setRules*[D: Document](doc: var D, rules: seq[string]) =
    ## Apply a set of rules to current Json Document
    for r in rules:
        let rule = parseRuleString(r)
        var fieldVal: JsonNode = doc.get(rule.key)
        var fieldType: JsonNodeKind = rule.expect
        if fieldVal.kind == JNull:
            fieldVal = rule.default                     # get default value, if any
            doc.contents[rule.key] = fieldVal      # TODO create macro set data with dot annotations
        if fieldVal.kind != fieldType:
            doc.errors.add(DocumentError(msg: "\"$1\" field is type of \"$2\", \"$3\" value given" % [rule.key, getTypeStr(fieldType), getTypeStr(fieldVal.kind)]))
            inc doc.getTotalErrors
    if doc.errors.len != 0:
        doc.has_errors = true
