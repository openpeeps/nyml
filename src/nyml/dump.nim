# A stupid simple YAML parser.
# From YAML to Nim objects, JsonNode or stringified JSON
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/nyml
import std/[json, ropes, strutils]

type
  JsonDocument* = ref object
    i: int
    yaml: Rope
    jsonNode: JsonNode

proc str(j: JsonDocument, node: JsonNode) =
  let s = node.str
  if s.count(' ') > 1:
    add j.yaml, indent("\"" & s & "\"", 1)
  else:
    if s.len != 0:
      add j.yaml, indent(s, 1)
    else:
      add j.yaml, indent("\"\"", 1)

proc integer(j: JsonDocument, node: JsonNode) = add j.yaml, indent($node.num, 1)
proc floatNumber(j: JsonDocument, node: JsonNode) = add j.yaml, indent($node.fnum, 1)
proc boolean(j: JsonDocument, node: JsonNode) = add j.yaml, indent($node.bval, 1)
proc obj(j: JsonDocument, node: JsonNode, pKind: JsonNodeKind) # defer
proc arr(j: JsonDocument, node: JsonNode, nl = true) # defer

proc handleValue(j: JsonDocument, n: JsonNode, pKind: JsonNodeKind) =
  case n.kind:
  of JString: j.str n
  of JInt:    j.integer n
  of JFloat:    j.floatNumber n
  of JBool:   j.boolean n
  of JObject:
    inc j.i
    j.obj n, pKind
    dec j.i
  of JArray: j.arr n, false
  else: discard

proc obj(j: JsonDocument, node: JsonNode, pKind: JsonNodeKind) =
  var i = 0
  for k, v in node.pairs:
    if i == 0 and pKind == JArray:
      add j.yaml, indent(k, j.i) & ":"
    else:
      add j.yaml, indent(k, j.i * 2) & ":"
    if v.kind == JObject:
      inc j.i
      if v.len != 0:
        add j.yaml, "\n"
        add j.yaml, spaces(j.i)
        j.obj(v, pKind)
      else: add j.yaml, indent("{}", 1)
      dec j.i
    elif v.kind == JArray:
      inc j.i
      j.handleValue(v, pKind)
      dec j.i
    else:
      j.handleValue(v, pKind)
    inc i
    if i != node.len:
      add j.yaml, "\n"

proc arr(j: JsonDocument, node: JsonNode, nl = true) =
  if nl:
    add j.yaml, "\n"
  if node.len == 0:
    add j.yaml, indent("[]", 1)
  else:
    add j.yaml, "\n"
  var i = 0
  for n in node.items:
    add j.yaml, spaces(j.i * 2)
    add j.yaml, "-"
    j.handleValue(n, JArray)
    inc i
    if i != node.len:
      add j.yaml, "\n"

proc dumpYAML*(json: JsonNode): string =
  let j = JsonDocument(jsonNode: json)
  case json.kind:
  of JInt:      j.integer json
  of JFloat:    j.floatNumber json 
  of JString:   j.str json
  of JBool:     j.boolean json
  of JArray:    j.arr json, false
  of JObject:   j.obj json, JObject
  else: discard
  result = $j.yaml