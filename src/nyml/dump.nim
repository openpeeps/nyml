# A stupid simple YAML-like parser.
#
# Can parse YAML to JsonNode, stringified JSON or Nim objects via JSONY
#
# (c) 2023 yamlike | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeeps/yamlike

import jsony
import std/[json, strutils]

type
  JD* = object
    yaml*: string
    node: JsonNode

# forward declaration
proc parse(j: var JD, n: JsonNode, i: var int)

proc inc(j: var JD, i: var int) =
  if i > 0: inc i, 2 else: i = 2

proc dec(j: var JD, i: var int) =
  if i > 1: dec i, 2 else: i = 0

proc ynull(j: var JD, n: JsonNode) = j.yaml.add indent("null", 1) & "\n"
proc ybool(j: var JD, n: JsonNode) = j.yaml.add indent($n.bval, 1) & "\n"
proc yfloat(j: var JD, n: JsonNode) = j.yaml.add indent($n.fnum, 1) & "\n"
proc yint(j: var JD, n: JsonNode) = j.yaml.add indent($n.num, 1) & "\n"
proc ystr(j: var JD, n: JsonNode) =
  if n.str.len > 0: add j.yaml, indent("\"" & n.str & "\"", 1) & "\n"
  else:             add j.yaml, indent("\"\"", 1) & "\n"

proc tab(j: var JD, s: string, i: int) =
  if i >= 2: j.yaml.add(spaces(i))
  j.yaml.add(s)

proc yobj(j: var JD, n: JsonNode, i: var int) =
  for k, v in pairs(n):
    j.tab(k & ":", i)
    case v.kind
    of JObject, JArray:
      j.inc i
      j.yaml.add("\n")
    else: discard
    j.parse(v, i)
  j.dec i

proc yarr(j: var JD, n: JsonNode, i: var int) =
  for v in n:
    j.tab("-", i)
    case v.kind:
    of JObject:
      j.inc i
      j.yaml.add("\n")
    else: discard
    j.parse(v, i)
  j.dec i

proc parse(j: var JD, n: JsonNode, i: var int) =
  case n.kind
  of JBool:   j.ybool(n)
  of JFloat:  j.yfloat(n)
  of JInt:    j.yint(n)
  of JString: j.ystr(n)
  of JNull:   j.ynull(n)
  of JObject: j.yobj(n, i)
  of JArray:  j.yarr(n, i)

proc dump*(n: JsonNode): string =
  var j = JD(node: n)
  var i = 0
  j.parse(j.node, i)
  j.node = nil
  result = $j.yaml