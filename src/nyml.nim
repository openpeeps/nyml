# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

import json
import nyml/[meta, lexer, parser_json]
from strutils import contains, split

export Nyml, EngineParser, Document, TokenKind
export parser_json.get, parser_json.hasErrorRules, parser_json.getErrorRules, parser_json.getErrorMessage, parser_json.getErrorsCount
export json

proc parse*[T: Nyml](nymlObject: T, contents: string, rules: seq[string] = @[]): Document =
    ## Parse YAML contents to JSON
    var nyml = nymlObject
    if nyml.engine == Y2J:
        var doc = nyml.parseToJson(contents)
        if rules.len != 0:
            doc.setRules(rules)
        return doc
    raise newException(NymlException, "Stringified contents can be parsed only by Y2J engine (YAML to JSON)")

proc parse*[T: Nyml](nyml: T, contents: JsonNode): Document =
    ## Parse JsonNode contents to YAML
    if nyml.engine == J2Y: discard
    
    raise newException(NymlException,
        "JSON contents can be parsed only by J2Y engine *(JSON to YAML)")