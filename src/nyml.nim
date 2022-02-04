# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

import json
import nyml/[meta, lexer, utils, parser_json]
from strutils import contains, split

export Nyml, EngineParser, Document, TokenKind, parser_json.get
export json

proc parse*[T: Nyml](nymlObject: T, contents: string): Document =
    ## Parse YAML contents to JSON
    var nyml = nymlObject
    if nyml.engine == Y2J:
        return nyml.parseToJson(contents)
    
    raise newException(NymlException,
        "Stringified contents can be parsed only by Y2J engine (YAML to JSON)")

proc parse*[T: Nyml](nyml: T, contents: JsonNode): Document =
    ## Parse JsonNode contents to YAML
    if nyml.engine == J2Y: discard
    
    raise newException(NymlException,
        "JSON contents can be parsed only by J2Y engine *(JSON to YAML)")

when isMainModule:
    let doc = Nyml(engine: Y2J).parse(readFile("sample.yml"))
    echo pretty(doc.get(), 4)