# A stupid simple YAML Parser.
# From YAML to stringified JSON (fastest) or JsonNode
#
# https://github.com/openpeep/nyml | MIT License

import std/json
from std/strutils import `%`, contains, count, split, strip,
                        parseInt, parseBool, parseFloat, join
export json

type
    NymlException* = object of CatchableError

    Nyml* = object
        yamlContents: string
        error: string

    Document* = object
        contents*: JsonNode
        rules: seq[string]
        has_errors: bool
        errors: seq[string]
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

method get*(doc: Document, key: string = ""): JsonNode {.base.} =
    ## Access data in current Json document using dot annotation,
    ## like for example: `user.profile.name`
    result = get(doc.contents, key)

proc exists*(field: JsonNode): bool =
    result = field != nil

method rules*(doc: var Document, docRules: openarray[tuple[key: string, kind: JsonNodeKind]]) {.base.} =
    for rule in docRules:
        var val = doc.get(rule.key)
        if val.kind == JNull and val.kind != rule.kind:
            doc.errors.add("\"$1\" field is missing" % [rule.key])
        elif val.kind != rule.kind:
            doc.errors.add("\"$1\" field is type of `$2`, `$3` given." % [rule.key, $rule.kind, $val.kind])

method hasErrors*(doc: Document): bool {.base.} =
    result = doc.errors.len != 0

method getErrors*(doc: Document): string {.base.} =
    result = join(doc.errors, "\n")
