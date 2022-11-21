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
        hasErrors: bool
        errors: seq[string]
        getTotalErrors: int

    # RuleTuple = tuple[key: string, req: bool, expect: JsonNodeKind, default: JsonNode]

proc init*[N: typedesc[Nyml]](newNyml: N, contents: string): Nyml =
    ## Initialize a new Nyml instance
    result = newNyml(yamlContents: contents)

proc getYamlContents*[N: Nyml](n: N): string {.inline.} =
    ## Retrieve YAMl contents fron Nyml object
    result = n.yamlContents

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

proc get*(doc: Document, key: string = ""): JsonNode =
    ## Access data in current Json document using dot annotation,
    ## like for example: `user.profile.name`
    result = get(doc.contents, key)

proc exists*(field: JsonNode): bool =
    result = field != nil

proc rules*(doc: var Document, docRules: openarray[tuple[key: string, kind: JsonNodeKind]]) =
    for rule in docRules:
        var val = doc.get(rule.key)
        if val.kind == JNull and val.kind != rule.kind:
            doc.errors.add("\"$1\" field is missing" % [rule.key])
        elif val.kind != rule.kind:
            doc.errors.add("\"$1\" field is type of `$2`, `$3` given." % [rule.key, $rule.kind, $val.kind])

proc hasErrors*(doc: Document): bool =
    result = doc.errors.len != 0

proc getErrors*(doc: Document): string =
    result = join(doc.errors, "\n")

proc newDocument*(contents: JsonNode): Document =
    result = Document(contents: contents)
