# A stupid simple YAML-like parser.
#
# Can parse YAML to JsonNode, stringified JSON or Nim objects via JSONY
#
# (c) 2023 yamlike | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeeps/yamlike

import std/json
from std/strutils import `%`, contains, split, join
export json

type
  YAMLException* = object of CatchableError

  YAML* = object
    str*: string
    error: string
    prettyPrint: bool
    data*: Document
    hasData*: bool

  Document* = ref object
    contents*: JsonNode
    rules: seq[string]
    hasErrors: bool
    errors: seq[string]

  # RuleTuple = tuple[key: string, req: bool, expect: JsonNodeKind, default: JsonNode]

proc newDocument*(contents: JsonNode): Document

proc init*[N: YAML](newNyml: typedesc[N], str: string, pretty = false, data: JsonNode): N =
  ## Initialize a new Nyml instance
  result = newNyml(str: str, prettyPrint: pretty, data: newDocument(data), hasData: data != nil)

proc isPretty*(n: YAML): bool =
  result = n.prettyPrint

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

proc get*(doc: Document, key: string = "", default: JsonNode = nil): JsonNode =
  ## Access data in current JSON document using dot annotation,
  ## like for example: `user.profile.name`
  result = get(doc.contents, key)
  if result.kind == JNull:
    return default

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
