# A stupid simple YAML parser.
# From YAML to Nim objects, JsonNode or stringified JSON
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/nyml
import pkg/pkginfo
import std/json except `%*`
import nyml/[meta, parser, dump]

export parser

when requires "jsony":
  # By default, Nyml has no built-in serialization.
  # But, thanks to `pkginfo` we can enable this feature
  # using `jsony` library (when current project requires it),
  # So if you want to enable this feature,
  # be sure you add `requires jsony` in your .nimble file
  # See https://github.com/treeform/jsony.
  import jsony
  export jsony

export meta
export getInt, getStr, getBool, getFloat

proc parse*(n: Nyml): Parser =
  ## Parse a new YAML-like document
  result = parseYAML(n, n.getYamlContents)

proc hasErrors*(n: Nyml): bool =
  ## Determine if there are any errors to handle

proc yaml*(contents: string, prettyPrint = false, data: JsonNode = nil): Nyml =
  ## Parse a new YAML-like document
  result = Nyml.init(contents, prettyPrint, data)

proc toJson*(n: Nyml): Document =
  ## Parse YAML contents to JsonNode without content rules
  var p: Parser = n.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  else:
    result = Document(contents: parseJson(p.getContents()))

proc toJsonStr*(n: Nyml, prettyPrint = false, indent = 2): string =
  ## YAML parser to JSON string representation without rules checker
  var p: Parser = n.parse()
  if p.hasError():
    raise newException(YAMLException, p.getError)
  elif p.lex.hasError():
    raise newException(YAMLException, p.lex.getError)
  else:
    if prettyPrint:
      result = pretty(parseJson(p.getContents()), indent)
    else:
      result = p.getContents()

proc toJsonStr*(n: Nyml, ruler:seq[string], prettyPrint = false, indent = 2): string =
  ## YAML parser to JSON string representation, with rules checker
  var doc = n.toJson()
  # if ruler.len != 0:
  #     doc.rules(ruler)
  result = $doc.get()

proc `$`*(n: Nyml): string =
  ## Return a stringified JSON
  result = n.toJsonStr(prettyPrint = n.isPretty)

proc toYAML*(json: JsonNode): string =
  ## Transform given JSON to YAML
  result = dumpYAML(json)

proc toYAML*(jsonString: string): string =
  ## Transform given stringified JSON to YAML
  result = dumpYAML(parseJson(jsonString))

when requires "jsony":
  ## Add support for loose, direct to object parser
  ## https://github.com/treeform/jsony
  template ymlParser*(strContents: string, toObject: typedesc[object]): untyped =
    var yml = Nyml.init(strContents)
    var p: Parser = yml.parse()
    if p.hasError():
      raise newException(YAMLException, p.getError)
    elif p.lex.hasError():
      raise newException(YAMLException, p.lex.getError)
    else:
      var parsedContents = p.getContents()
      parsedContents.fromJson(toObject)

# when isMainModule:
#   echo yaml(readFile("test.yml"), data = %*{"hello": "yepsi"})
#   echo yaml(readFile("test.yml")).toJsonStr(true)