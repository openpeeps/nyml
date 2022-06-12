# 
# A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License

import std/json
import nyml/parser
import nyml/meta

export meta
export getInt, getStr, getBool

proc parse[N: Nyml](n: var N): Parser =
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
