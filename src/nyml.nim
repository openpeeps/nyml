# A stupid simple YAML-like parser. From YAML to JsonNode,
# stringified JSON or Nim objects via pkg/jsony.
#
# (c) 2023 nyml | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/nyml

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

template fromYaml*(str: string, obj: typedesc[object]): untyped =
  ## Add support for loose, direct to object parser using
  ## https://github.com/treeform/jsony
  var yml = YAML.init(str, false, nil)
  var p: Parser = yml.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  var jsonContent = p.getContents()
  jsony.fromJson(jsonContent, obj)

# when isMainModule:
  # echo yaml(readFile("test.yml"), data = %*{"hello": "yepsi"})
  # echo yaml(readFile("test.yml"), data = %*{"hello": "yepsi"}).toJsonStr()