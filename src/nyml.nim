# A stupid simple YAML Parser.
# From YAML to stringified JSON (fastest) or JsonNode
#
# https://github.com/openpeep/nyml | MIT License
import pkginfo
import std/json
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

proc parse*[N: Nyml](n: var N): Parser =
    ## Internal procedure for parsing current YAML Contents
    result = parseYAML(n.getYamlContents)

proc toJson*[N: Nyml](n: var N): Document =
    ## Parse YAML contents to JsonNode without content rules
    var p: Parser = n.parse()
    if p.hasError():
        raise newException(NymlException, p.getError)
    elif p.lex.hasError():
        raise newException(NymlException, p.lex.getError)
    else:
        # echo p.getContents()
        result = Document(contents: parseJson(p.getContents()))

proc toJson*[N: Nyml](n: var N, rules:seq[string]): Document =
    ## Parse YAML contents to JsonNode followed by content rules
    var doc: Document = n.toJson()
    if rules.len != 0:
        doc.setRules(rules)
    result = doc

proc toJsonStr*[N: Nyml](n: var N, prettyPrint = false, indent = 2): string =
    ## YAML parser to JSON string representation without rules checker
    var p: Parser = n.parse()
    if p.hasError():
        raise newException(NymlException, p.getError)
    elif p.lex.hasError():
        raise newException(NymlException, p.lex.getError)
    else:
        if prettyPrint: # TODO native support for indentation, to avoid parsing the string JSON to JsonNode
            result = pretty(parseJson(p.getContents()), indent)
        else:
            result = p.getContents()

proc toJsonStr*[N: Nyml](n: var N, rules:seq[string], prettyPrint = false, indent = 2): string =
    ## YAML parser to JSON string representation, with rules checker
    var doc: Document = Document(contents: n.toJson())
    if rules.len != 0:
        doc.setRules(rules)
    result = $doc.get()

when requires "jsony":
    template ymlParser*(strContents: string, toObject: typedesc[object]): untyped =
        var yml = Nyml.init(strContents)
        var p: Parser = yml.parse()
        if p.hasError():
            raise newException(NymlException, p.getError)
        elif p.lex.hasError():
            raise newException(NymlException, p.lex.getError)
        else:
            var parsedContents = p.getContents()
            parsedContents.fromJson(toObject)

when isMainModule:
    from os import getCurrentDir
    var yml = Nyml.init(readFile(getCurrentDir() & "/bin/test.yml"))
    echo yml.toJson()