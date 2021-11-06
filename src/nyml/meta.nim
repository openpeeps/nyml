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
