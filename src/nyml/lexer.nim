# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2022 George Lemon from OpenPeep
# Released under MIT License
# 

import os, lexbase, streams, json, re
from strutils import Whitespace, `%`, replace, indent, startsWith

type
    TokenKind* = enum
        TK_NONE
        TK_KEY
        TK_NULL
        TK_INTEGER
        TK_STRING
        TK_BOOLEAN
        TK_ARRAY
        TK_ARRAY_ITEM
        TK_ARRAY_BLOCK
        TK_OBJECT
        TK_COMMENT
        TK_SLASH
        TK_MINUS
        TK_EOL,
        TK_INVALID

    Lexer* = object of BaseLexer
        kind*: TokenKind
        token*, error*: string
        startPos*: int
        whitespaces: int

    TokenTuple* = tuple[kind: TokenKind, value: string, wsno, col, line: int]

template setError(l: var Lexer; err: string): untyped =
    l.kind = TK_INVALID
    if l.error.len == 0:
        l.error = err

proc hasError*[T: Lexer](lex: T): bool = lex.error.len != 0

proc init*[T: typedesc[Lexer]](lex: T; fileContents: string): Lexer =
    ## Initialize a new BaseLexer instance with given Stream
    var lex = Lexer()
    lexbase.open(lex, newStringStream(fileContents))
    lex.startPos = 0
    lex.kind = TK_INVALID
    lex.token = ""
    lex.error = ""
    return lex

proc setToken*[T: Lexer](lex: var T, tokenKind: TokenKind, offset:int = 0) =
    ## Set meta data for current token
    lex.kind = tokenKind
    lex.startPos = lex.getColNumber(lex.bufpos)
    inc(lex.bufpos, offset)

proc getToken*[T: Lexer](lex: var T): TokenTuple

proc nextToEOL[T: Lexer](lex: var T): tuple[pos: int, token: string] =
    # Get entire buffer starting from given position to the end of line
    while true:
        case lex.buf[lex.bufpos]:
        of NewLines: return
        of EndOfFile: return
        else: 
            add lex.token, lex.buf[lex.bufpos]
            inc lex.bufpos
    return (pos: lex.bufpos, token: lex.token)

proc skipToEOL[T: Lexer](lex: var T): int =
    # Get entire buffer starting from given position to the end of line
    while true:
        if lex.buf[lex.bufpos] in NewLines:
            return
        inc lex.bufpos
    return lex.bufpos

proc handleNewLine[T: Lexer](lex: var T) =
    ## Handle new lines
    case lex.buf[lex.bufpos]
    of '\c': lex.bufpos = lex.handleCR(lex.bufpos)
    of '\n': lex.bufpos = lex.handleLF(lex.bufpos)
    else: discard
 
proc skip[T: Lexer](lex: var T) =
    ## Procedure for skipping/offset between columns/positions 
    var wsno: int
    while true:
        case lex.buf[lex.bufpos]
        of Whitespace:
            if lex.buf[lex.bufpos] notin NewLines:
                inc lex.bufpos
                inc wsno
            else:
                lex.handleNewLine()
        else:
            lex.whitespaces = wsno
            break
 
proc handleSpecial[T: Lexer](lex: var T): char =
    ## Procedure for for handling special escaping tokens
    assert lex.buf[lex.bufpos] == '\\'
    inc lex.bufpos
    case lex.buf[lex.bufpos]
    of 'n':
        lex.token.add "\\n"
        result = '\n'
        inc lex.bufpos
    of '\\':
        lex.token.add "\\\\"
        result = '\\'
        inc lex.bufpos
    else:
        lex.setError("Unknown escape sequence: '\\" & lex.buf[lex.bufpos] & "'")
        result = '\0'
 
proc handleString[T: Lexer](lex: var T) =
    ## Handle string values wrapped in single or double quotes
    lex.startPos = lex.getColNumber(lex.bufpos)
    lex.token = ""
    inc lex.bufpos
    while true:
        case lex.buf[lex.bufpos]
        of '\\':
            discard lex.handleSpecial()
            if lex.hasError(): return
        of '"', '\'':
            lex.kind = TK_STRING
            inc lex.bufpos
            break
        of NewLines:
            lex.setError("EOL reached before end of string")
            return
        of EndOfFile:
            lex.setError("EOF reached before end of string")
            return
        else:
            add lex.token, lex.buf[lex.bufpos]
            inc lex.bufpos

proc handleSequence[T: Lexer](lex: var T) =
    skip lex
    lex.startPos = lex.getColNumber(lex.bufpos)
    inc lex.bufpos
    
    var errorMessage = "$1 reached before closing the array"
    while true:
        case lex.buf[lex.bufpos]
        of '\\':
            discard lex.handleSpecial()
            if lex.hasError(): return
        of ']':
            inc lex.bufpos
            # lex.kind = TK_ARRAY_ITEM
            break
        of NewLines:
            lex.setError(errorMessage % ["EOL"])
            return
        of EndOfFile:
            lex.setError(errorMessage % ["EOF"])
            return
        of '[':
            lex.setError("Invalid multi-dimensional array using square brackets")
            return
        else:
            discard lex.getToken()
            # echo lex.buf[lex.bufpos]
            # add lex.token, lex.buf[lex.bufpos]
            # inc lex.bufpos

proc handleNumber[T: Lexer](lex: var T) =
    lex.startPos = lex.getColNumber(lex.bufpos)
    lex.token = "0"
    while lex.buf[lex.bufpos] == '0':
        inc lex.bufpos
    while true:
        case lex.buf[lex.bufpos]
        of '0'..'9':
            if lex.token == "0":
                setLen(lex.token, 0)
            add lex.token, lex.buf[lex.bufpos]
            inc lex.bufpos
        of 'a'..'z', 'A'..'Z', '_':
            lex.setError("Invalid number")
            return
        else:
            lex.setToken(TK_INTEGER)
            break

proc handleIdent[T: Lexer](lex: var T) =
    ## Procedure for handling identations
    # assert lex.buf[lex.bufpos] in {'a'..'z'}
    lex.startPos = lex.getColNumber(lex.bufpos)
    setLen(lex.token, 0)
    while true:
        if lex.buf[lex.bufpos] in {'a'..'z', 'A'..'Z', '0'..'9', '_', ':', '/', '\\', '-'}:
            add lex.token, lex.buf[lex.bufpos]
            inc lex.bufpos
        else: break

    # if lex.token =~ re"\w+\:":
    if lex.token =~ re"^[^\s!?.*#|]+\:":
        lex.token = lex.token.replace(":", "")      # Remove punctuation character
        lex.setToken(TK_KEY)
    else:
        lex.kind = case lex.token
            of "true", "false", "yes", "no", "y", "n", "True",
               "False", "Yes", "No", "TRUE", "FALSE", "YES", "NO": TK_BOOLEAN
            else: TK_INVALID

proc getToken*[T: Lexer](lex: var T): TokenTuple =
    ## Parsing through available tokens
    lex.kind = TK_INVALID
    setLen(lex.token, 0)
    skip lex
    case lex.buf[lex.bufpos]
    of EndOfFile:
        lex.startPos = lex.getColNumber(lex.bufpos)
        lex.kind = TK_EOL
    of '#': lex.setToken(TK_COMMENT, lex.nextToEOL().pos)
    of '0'..'9': lex.handleNumber()
    of 'a'..'z', 'A'..'Z', ':', '_': lex.handleIdent()
    of '-': lex.setToken(TK_ARRAY_ITEM, 1)
    of '[': lex.handleSequence()
    of '"', '\'': lex.handleString()
    else:
        echo lex.token
        lex.setError("Unexpected character \"$1\"" % [ $(lex.buf[lex.bufpos]) ])
    
    if lex.kind == TK_COMMENT: result = lex.getToken()
    result = (kind: lex.kind, value: lex.token, wsno: lex.whitespaces, col: lex.startPos, line: lex.lineNumber)

