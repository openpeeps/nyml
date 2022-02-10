# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

from ./lexer import TokenKind

type
    NymlException* = object of CatchableError

    EngineParser* = enum
        J2Y, Y2J

    Nyml* = object
        engine*: EngineParser
        left*: tuple[kind: TokenKind, value: string, line, indent: int]
        right*: tuple[kind: TokenKind, value: string, line, indent: int]
        error*: string