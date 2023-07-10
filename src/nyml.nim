# A stupid simple YAML-like parser.
#
# Can parse YAML to JsonNode, stringified JSON or Nim objects via JSONY
#
# (c) 2023 yamlike | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeeps/yamlike

import jsony
import std/macros
import std/json except `%*`
import nyml/[meta, parser, dump]

export meta, dump, jsony
export getInt, getStr, getBool, getFloat

proc parse*(n: YAML): Parser =
  ## Parse a new YAML-like document
  result = parseYAML(n, n.str)

proc yaml*(contents: string, prettyPrint = false, data: JsonNode = nil): YAML =
  ## Parse a new YAML-like document
  result = YAML.init(contents, prettyPrint, data)

proc toJson*(n: YAML): Document =
  ## Parse YAML contents to JsonNode
  var p: Parser = n.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  result = Document(contents: parseJson(p.getContents()))

proc toJsonStr*(n: YAML, prettyPrint = false, indent = 2): string =
  ## Parse YAML contents to stringified JSON
  var p: Parser = n.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  else:
    if prettyPrint:
      return pretty(parseJson(p.getContents()), indent)
    result = p.getContents()

proc toJsonStr*(n: YAML, ruler:seq[string], prettyPrint = false, indent = 2): string =
  ## YAML parser to JSON string representation, with rules checker
  var doc = n.toJson()
  # if ruler.len != 0:
  #     doc.rules(ruler)
  result = $doc.get()

proc `$`*(n: YAML): string =
  ## Return a stringified JSON
  result = n.toJsonStr(prettyPrint = n.isPretty)

proc toYAML*(json: JsonNode): string = dump(json)
proc toYAML*(json: string): string = dump(parseJson(json))

## Add support for loose, direct to object parser
## https://github.com/treeform/jsony
template ymlParser*(strContents: string, toObject: typedesc[object]): untyped =
  var yml = YAML.init(strContents)
  var p: Parser = yml.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  var str = p.getContents()
  str.fromJson(toObject)

# macro yaml*()

when isMainModule:
  # echo yaml(readFile("test.yml"), data = %*{"hello": "yepsi"})
  echo yaml(readFile("test.yml"), data = %*{"hello": "yepsi"}).toJsonStr()