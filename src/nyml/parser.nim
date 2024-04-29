# A stupid simple YAML-like parser. From YAML to JsonNode,
# stringified JSON or Nim objects via pkg/jsony.
#
# (c) 2023 nyml | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/nyml

import toktok
import std/[json, jsonutils]
import std/strutils except NewLines
import ./meta

handlers:
  proc handleAltString*(lex: var Lexer, kind: TokenKind) =
    lex.startPos = lex.getColNumber(lex.bufpos)
    setLen(lex.token, 0)
    inc lex.bufpos
    while true:
      case lex.buf[lex.bufpos]
      of '\'':
        lex.kind = kind
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

  proc handleCustomIdent(lex: var Lexer): TokenKind {.discardable.} =
    let lineno = lex.lineNumber
    var isStopper: bool
    while lineno == lex.lineNumber:
      case lex.buf[lex.bufpos]:
      of NewLines, EndOfFile:
        lex.kind = tkString
        result = lex.kind
        break
      of ':':
        lex.kind = tkIdentifier
        result = lex.kind
        break
      else:
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos

  proc handleUnknown*(lex: var Lexer) =
    lex.startPos = lex.getColNumber(lex.bufpos)
    case lex.buf[lex.bufpos]:
    of '$', '/', '^', '(', ')', '<': # todo something to handle all chars except stoppers
      lex.handleCustomIdent()
    else:
      add lex.token, lex.buf[lex.bufpos]
      inc lex.bufpos
      lex.kind = tkUnknown

  proc handleComment*(lex: var Lexer, kind: TokenKind) =
    if lex.wsno == 0 and lex.getColNumber(lex.bufpos) != 0:
      lex.startPos = lex.getColNumber(lex.bufpos)
      setLen(lex.token, 0)
      inc lex.bufpos
      lex.token = "#"
      lex.kind = tkUnknown
      return
    lex.startPos = lex.getColNumber(lex.bufpos)
    setLen(lex.token, 0)
    inc lex.bufpos
    skip lex
    while true:
      case lex.buf[lex.bufpos]:
      of NewLines, EndOfFile:
        break
      else:
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
    lex.kind = kind

  proc handleVariable*(lex: var Lexer, kind: TokenKind) =
    try:
      if lex.buf[lex.bufpos + 1] == '{' and lex.buf[lex.bufpos + 2] == '{':
        lex.startPos = lex.getColNumber(lex.bufpos)
        setLen(lex.token, 0)
        inc lex.bufpos, 3 # ${{
        while true:
          case lex.buf[lex.bufpos]:
          of NewLines, EndOfFile:
            lex.setError("Invalid variable declaration")
            inc lex.bufpos
            break
          of '}':
            inc lex.bufpos
            if lex.buf[lex.bufpos] == '}':
              inc lex.bufpos
              break
            else:
              lex.setError("Invalid variable declaration missing curly bracket")
              return
          else:
            add lex.token, lex.buf[lex.bufpos]
            inc lex.bufpos
        lex.kind = kind
      else:
        # lex.kind = tkUnknown
        # add lex.token, lex.buf[lex.bufpos]
        # inc lex.bufpos
        lex.handleCustomIdent()
    except IndexDefect:
      lex.handleCustomIdent()

const settings =
  Settings(
    tkPrefix: "tk",
    tkModifier: defaultTokenModifier,
    lexerName: "Lexer",
    lexerTuple: "TokenTuple",
    lexerTokenKind: "TokenKind",
    keepUnknown: true,
    handleUnknown: true,
    keepChar: true,
    useDefaultIdent: false
  )

registerTokens settings:
  lb   = '['
  rb   = ']'
  colon = ':'
  comma = ','
  hyphen = '-'
  variable = tokenize(handleVariable, '$')
  header
  lc     = '{'
  rc     = '}'
  backSlash = '\\'

  gtChompClip = '>':     # keep the line feed, remove the trailing blank lines.
    gtChompStrip = '-'   # remove the line feed, remove the trailing blank lines.
    gtChompKeep  = '+'   # keep the line feed, keep trailing blank lines.

  pipeChompClip = '|':   # keep the line feed, remove the trailing blank lines.
    pipeChompStrip = '-' # remove the line feed, remove the trailing blank lines.
    pipeChompKeep = '+'  # keep the line feed, keep trailing blank lines.

  altString = tokenize(handleAltString, '\'')
  comment = tokenize(handleComment, '#')
  `nil` = ["NIL", "Nil", "nil"]
  null  = ["NULL", "Null", "null"]
  `true`  = ["TRUE", "True", "true", "YES", "Yes", "yes"]
  `false` = ["FALSE", "False", "false", "NO", "No", "no"]

type
  NType = enum
    Nil
    Array
    Object
    Field
    String
    Int
    Float
    Bool
    Comment
    Variable
    Header

  Parser* = object
    lex*: Lexer
    prev, curr, next: TokenTuple
    error: string
    code: string
    program: Program 
    rootType: NType
    yml: YAML

  Node = ref object
    # nodeName: string
    case nt: NType
    of Array:
      items: seq[Node]
    of Object:
      key: string
      value: seq[Node]
    of Field:
      fieldKey:string
      fieldValue: seq[Node]
    of String:
      vStr: string
    of Int:
      vInt: int
    of Float:
      vFloat: float
    of Bool:
      vBool: bool
    of Variable:
      varIdent: string
      varRight: seq[Node]
    else: discard
    meta: tuple[line, pos: int]

  Program = object
    nodes: seq[Node]

const
  assignables = {tkString, tkInteger, tkTrue, tkFalse, tkIdentifier}
  literals = {tkString, tkAltString, tkInteger, tkFloat, tkTrue, tkFalse, tkNil, tkNull}

proc setError[T: Parser](p: var T, msg: string) =
  p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $p.curr.pos]

proc hasError*[T: Parser](p: var T): bool =
  result = p.error.len != 0

proc getError*[T: Parser](p: var T): string =
  result = p.error

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()
    while p.next.kind == tkComment:
      p.next = p.lex.getToken()

proc getContents*(p: var Parser): string = p.code

proc strEscape(s: string, prefix, suffix = "\""): string =
  result = newStringOfCap(s.len + s.len shr 2)
  result.add(prefix)
  for c in items(s):
    case c
    of '\0'..'\31', '\127'..'\255':
      add(result, "\\x")
      add(result, toHex(ord(c), 2))
    of '\\': add(result, "\\\\")
    of '\"': add(result, "\\\"")
    else: add(result, c)
  add(result, suffix)

template `$$`(value: string) = add p.code, "\"" & value & "\":"
template `$=`(value: string) = add p.code, value
template `$=`(value: bool) = add p.code, $value
template `$=`(value: int|float) = add p.code, $value
# proc `$`(program: Program): string = pretty toJson(program), 2
proc `$`(node: Node): string = pretty toJson(node), 2

template `!`(nextBlock) =
  if p.curr.kind in literals:
    if p.curr.line != this.line:
      p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
      return
  nextBlock

template `!!`(nextBlock) =
  if p.curr.pos < this.pos:
    p.setError("Invalid indentation in array for \"$1\" item" % [p.next.value])
    break
  nextBlock

template `{`(subNode) =
  p.code &= "{"
  subNode

template `}`() =
  p.code &= "}"

template `[`(subNode) =
  p.code &= "["
  subNode
template `]`() = p.code &= "]"

proc writeNodes(p: var Parser, node: seq[Node]) =
  # Parse AST nodes and write JSON (strings)
  var skipComma: bool
  let nodeLen = node.len - 1
  for i in 0..node.high:
    if node[i] == nil: # dirty fix
      continue
    case node[i].nt:
    of Object:
      if node[i].key.len != 0:
        $$ node[i].key
      if node[i].value.len > 0:
        if node[i].value[0].nt == Array:
          p.writeNodes(node[i].value)
        else:
          `{`:
            p.writeNodes(node[i].value)
          `}`
      else:
        `{`:
          p.writeNodes(node[i].value)
        `}`
    of Field:
        $$ node[i].fieldKey
        p.writeNodes(node[i].fieldValue)
    of Array:
      `[`:
        p.writeNodes(node[i].items)
      `]`
    of Bool:
      $= node[i].vBool
    of Int:
      $= node[i].vInt
    of Float:
      $= node[i].vFloat
    of String:
      $= strEscape(node[i].vStr)
    of Nil:
      p.code &= "null"
    of Variable:
      var skipIter: bool
      if p.yml.hasData:
        let jsonValue = p.yml.data.get(node[i].varIdent)
        if node[i].varRight.len != 0:
          var strConcat = jsonValue.getStr
          for nodeConcat in node[i].varRight:
            strConcat &= nodeConcat.vStr
          $= strConcat
        else:
          $= jsonValue.getStr
      else:
        p.code &= "null"
      if skipIter: continue
    else:
      discard
    if i != node.high:
      if node[i].nt notin {Comment, Header}:
        add p.code, ","

proc newNode(p: var Parser, nt: NType): Node =
  result = Node(
    nt: nt,
    meta: (p.curr.line, p.curr.pos)
  )

proc newNode(p: var Parser, nt: NType,
    tk: TokenTuple): Node =
  result = Node(
    nt: nt,
    meta: (tk.line, tk.pos)
  )

proc parseUnquotedStrings(p: var Parser,
    this: TokenTuple, stoppers: set[TokenKind] = {}): Node =
  let strNode = p.newNode String
  var identToStr = p.curr
  walk p
  while p.curr.line == this.line or p.curr.pos > this.pos:
    if p.curr.kind in {tkEOF} + stoppers:
      break
    if p.curr.kind == tkComment:
      identToStr.value = identToStr.value.strip()
      break
    identToStr.value &= indent(p.curr.value, p.curr.wsno)
    walk p
  strNode.vStr = identToStr.value.strip()
  result = strNode

proc parse(p: var Parser, inArray = false): Node
proc parseObject(p: var Parser, this: TokenTuple, inArray = false): Node

proc parseString(p: var Parser): Node =
  result = p.newNode String
  result.vStr = p.curr.value
  walk p

template checkInlineString {.dirty.} =
  if p.next.line == p.curr.line:
    let this = p.curr
    return p.parseUnquotedStrings(this)

proc parseInt(p: var Parser): Node =
  checkInlineString()
  result = p.newNode Int
  result.vInt = parseInt(p.curr.value)
  walk p

proc parseFloat(p: var Parser): Node =
  checkInlineString()
  result = p.newNode Float
  result.vFloat = parseFloat(p.curr.value)
  walk p

proc parseBool(p: var Parser, lit: bool): Node =
  checkInlineString()
  result = p.newNode Bool
  result.vBool = lit
  walk p

proc parseVariable(p: var Parser, this: TokenTuple, inArray = false): Node =
  result = p.newNode Variable
  result.varIdent = p.curr.value
  walk p
  if inArray:
    if p.curr.line == this.line and p.curr.kind notin {tkComment, tkEOF, tkRB, tkComma}:
      result.varRight.add p.parseUnquotedStrings(this, {tkRB, tkComma})
  else:
    if p.curr.line == this.line and p.curr.kind notin {tkComment, tkEOF}:
      result.varRight.add p.parseUnquotedStrings(this)

proc parseArray(p: var Parser, node: Node, this: TokenTuple) =
  while p.curr.kind == tkHyphen and p.curr.pos == node.meta.pos:
    walk p # -
    if p.curr.kind in literals + {tkVariable, tkLC}:
      let lineno = p.curr.line
      while p.curr.line == lineno and p.curr.kind != tkEOF:
        node.items.add p.parse()
    elif p.curr.kind == tkIdentifier:
      if p.next.kind != tkColon:
        # handle unquoted strings.
        node.items.add p.parseUnquotedStrings(this, {tkHyphen})
      else:
        # handle objects 
        let
          objectNode = p.newNode Object
          this = p.curr
          subNode = p.parse(inArray = true)
        if subNode.nt == Field:
          objectNode.value.add(subNode)  
        else:
          objectNode.value.add(subNode)
        while p.curr.kind in {tkIdentifier, tkHyphen} and
          p.curr.pos >= this.pos:
          if p.curr.pos == subNode.meta[1]:
            let childNode = p.parse(inArray = true)
            add objectNode.value, childNode
          elif p.curr.pos > this.pos:
            let childNode = p.parse(inArray = true)
            case subNode.nt
            of Field:
              add objectNode.value, childNode
            of Object:
              add subNode.value, childNode
            else: discard
        node.items.add objectNode

proc parseInlineArray(p: var Parser, this: TokenTuple): Node =
  result = p.newNode Array
  walk p
  while p.curr.kind != tkRB:
    if p.curr.kind == tkEOF:
      p.setError("EOF reached before closing array")
      return
    if p.curr.kind in literals:
      result.items.add p.parse()
    elif p.curr.kind == tkVariable:
      result.items.add p.parseVariable(this, true)
    else:
      result.items.add p.parseUnquotedStrings(this, {tkRB, tkComma})
    if p.curr.kind == tkComma: walk p
  walk p # ]

template parseNestObjects =
  if p.curr.kind in literals and p.curr.line == this.line:
    ! result.value.add p.parse()
  elif p.curr.kind in {tkIdentifier, tkInteger, tkHyphen} and p.curr.pos >= this.pos:
    if p.curr.kind == tkIdentifier and p.curr.pos == this.pos and inArray == false:
      p.setError("Invalid indentation")
      return
    while p.curr.pos > this.pos and p.curr.kind in {tkIdentifier, tkInteger, tkHyphen}:
      if p.curr.kind in {tkIdentifier, tkInteger} and p.next.kind != tkColon:
        p.setError("Missing assignment token")
        return
      if p.curr.kind == tkInteger:
        p.curr.kind = tkIdentifier
      let sub = p.parse()
      result.value.add sub
      if p.curr.pos > sub.meta.pos and p.curr.kind notin {tkEOF, tkHyphen, tkComment}:
        p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
        break
  elif p.curr.kind == tkLB:
    result.value.add(p.parse())

proc parseObject(p: var Parser, this: TokenTuple, inArray = false): Node =
  walk p # tkIdentifier
  let colon = p.curr; walk p
  if p.curr.kind in literals and p.curr.line == this.line:
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    result.fieldValue.add(p.parse())
  elif p.curr.kind == tkPipeChompStrip: # |-
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    walk p
    var x = p.newNode String
    var str: seq[string]
    while p.curr.pos > this.pos and p.curr.kind != tkEOF:
      if p.curr.line > p.prev.line:
        add str, ("\\n" & p.curr.value)
      else:
        add str, indent(p.curr.value, p.curr.wsno)
      walk p
    x.vStr = str.join("")
    result.fieldValue.add(x)
  elif (p.curr.kind in literals or p.curr.kind == tkIdentifier) and ((p.curr.line > this.line and p.curr.pos > this.pos) and p.next.kind == tkColon):
    result = p.newNode(Object, this)
    result.key = this.value
    p.curr.kind = tkString
    let sub = p.curr
    result.value.add(p.parseObject(sub, inArray))
    while p.curr.pos > this.pos and p.curr.kind != tkEOF:
      result.value.add p.parse()
  elif p.curr.kind in literals and (p.curr.line > this.line and p.curr.pos > this.pos):
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    var x = p.newNode String
    var str: seq[string]
    while p.curr.pos > this.pos and p.curr.kind != tkEOF:
      add str, p.curr.value
      walk p
    x.vStr = str.join(" ")
    result.fieldValue.add(x)
  elif p.curr.kind != tkEOF and p.curr.line == this.line:
    if p.curr.kind == tkLB:
      result = p.newNode(Field, this)
      result.fieldKey = this.value
      result.fieldValue.add p.parse()
    elif p.curr.kind == tkVariable:
      result = p.newNode(Field, this)
      result.fieldKey = this.value
      let varNode = p.parseVariable(this)
      result.fieldValue.add varNode
    else:
      result = p.newNode(Field, this)
      result.fieldKey = this.value
      result.fieldValue.add p.parseUnquotedStrings(this)
  else:
    result = p.newNode(Object, this)
    result.key = this.value
    parseNestObjects()

proc parse(p: var Parser, inArray = false): Node =
  # Parse YAML to AST nodes
  let this = p.curr
  case p.curr.kind:
  of tkIdentifier:
    result = p.parseObject(this, inArray)
  of tkHyphen:
    if unlikely(p.next.kind == tkHyphen):
      while p.curr.kind == tkHyphen and p.curr.line == this.line:
        walk p
      return p.newNode(Header)
    var node: Node = p.newNode Array
    p.parseArray(node, this)
    result = node
  of tkString, tkAltString:
    if p.next.kind == tkColon:
      p.curr.kind = tkIdentifier
      return p.parseObject(this, inArray)
    result = p.parseString()
  of tkInteger:
    result = p.parseInt()
  of tkFloat:
    result = p.parseFloat()
  of tkTrue:
    result = p.parseBool true
  of tkFalse:
    result = p.parseBool false
  of tkLB:
    result = p.parseInlineArray(this)
  of tkLC:
    if p.next.kind == tkRC:
      walk p, 2
      return p.newNode(Object, this)
  of tkVariable:
    result = p.parseVariable(this)
  of tkComment: walk p
  of tkNull, tkNil:
    result = p.newNode Nil
    walk p
  else: discard

proc parseYAML*(yml: YAML, strContents: string): Parser =
  var p = Parser(lex: newLexer(strContents, allowMultilineStrings = true), yml: yml)
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  p.program = Program()
  while p.hasError == false and p.lex.hasError == false:
    if p.curr.kind == tkEOF: break
    if p.curr.kind == tkHyphen:
      p.rootType = Array
    else:
      p.rootType = Object
    let node = p.parse()
    if likely(node != nil):
      p.program.nodes.add node
  if p.rootType == Array:
    p.writeNodes(p.program.nodes)
  else:
    p.code &= "{"
    p.writeNodes(p.program.nodes)
    p.code &= "}"
  result = p
