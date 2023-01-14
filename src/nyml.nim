# A stupid simple YAML parser. From YAML to Nim objects, JsonNode or stringified JSON
# 
# (c) 2023 Nyml | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/nyml
import pkginfo, std/json
import nyml/[meta, parser]

export json, parser

when requires "jsony":
  # By default, Nyml has no built-in serialization.
  # But, thanks to `pkginfo` we can enable the serialization feature
  # using `jsony` package library (when current project requires it)
  # https://github.com/treeform/jsony
  import jsony
  export jsony

export meta
export getInt, getStr, getBool

proc parse*(n: Nyml): Parser =
  result = parseYAML(n.getYamlContents)

proc yaml*(contents: string, prettyPrint = false): Nyml =
  ## Parse a new YAML document
  result = Nyml.init(contents, prettyPrint)

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
  result = n.toJsonStr(prettyPrint = n.isPretty)

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