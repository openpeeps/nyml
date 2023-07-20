# A stupid simple YAML-like parser.
#
# Can parse YAML to JsonNode, stringified JSON or Nim objects via JSONY
#
# (c) 2023 yamlike | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeeps/yamlike

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

  proc handleCustomIdent*(lex: var Lexer): TokenKind =
    let identLineno = lex.lineNumber
    while identLineno == lex.lineNumber:
      case lex.buf[lex.bufpos]:
      of ':', ',', ']', NewLines, EndOfFile:
        break
      of '#':
        if lex.wsno == 0:
          add lex.token, lex.buf[lex.bufpos]
          inc lex.bufpos          
        else: break
      else:
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
    result = tkIdentifier

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
        lex.kind = tkUnknown
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
    except IndexDefect:
      discard lex.handleCustomIdent()

const settings =
  Settings(tkPrefix: "tk", tkModifier: defaultTokenModifier,
          keepUnknown: true, enableCustomIdent: true)
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
    case ntype: NType
    of Array:
      items: seq[Node]
    of Object:
      key: string
      value: seq[Node]
    of Field:
      fieldKey:string
      fieldValue: seq[Node]
    of String:
      strv: string
    of Int:
      intv: int
    of Bool:
      boolv: bool
    of Variable:
      varIdent: string
      varRight: seq[Node]
    else: discard
    meta: tuple[line, pos: int]

  Program = object
    nodes: seq[Node]

const
  assignables = {tkString, tkInteger, tkTrue, tkFalse, tkIdentifier}
  literals = {tkString, tkAltString, tkInteger, tkTrue, tkFalse, tkNil, tkNull}

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

template `$$`(value: string) = add p.code, "\"" & value & "\":"
template `$=`(value: string) = add p.code, "\"" & value & "\""
template `$=`(value: bool) = add p.code, $value
template `$=`(value: int) = add p.code, $value
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
    case node[i].ntype:
    of Object:
      if node[i].key.len != 0:
        $$ node[i].key
      if node[i].value[0].ntype == Array:
        p.writeNodes(node[i].value)
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
      $= node[i].boolv
    of Int:
      $= node[i].intv
    of String:
      $= node[i].strv
    of Nil:
      p.code &= "null"
    of Variable:
      var skipIter: bool
      if p.yml.hasData:
        let jsonValue = p.yml.data.get(node[i].varIdent)
        if node[i].varRight.len != 0:
          var strConcat = jsonValue.getStr
          for nodeConcat in node[i].varRight:
            strConcat &= nodeConcat.strv
          $= strConcat
        else:
          $= jsonValue.getStr
      else:
        p.code &= "null"
      if skipIter: continue
    else:
      discard
    if i != node.high:
      if node[i].ntype notin {Comment, Header}:
        add p.code, ","
    # inc i

proc newNode(p: var Parser, ntype: NType): Node =
  result = Node(
    ntype: ntype,
    meta: (p.curr.line, p.curr.pos)
  )

proc newNode(p: var Parser, ntype: NType, tk: TokenTuple): Node =
  result = Node(
    ntype: ntype,
    meta: (tk.line, tk.pos)
  )

proc parseUnquotedStrings(p: var Parser, this: TokenTuple, stoppers: set[TokenKind] = {}): Node =
  let strNode = p.newNode String
  var identToStr = p.curr
  walk p
  while p.curr.line == this.line:
    if p.curr.kind in {tkEOF} + stoppers:
      break
    if p.curr.kind == tkComment:
      identToStr.value = identToStr.value.strip()
      break
    identToStr.value &= indent(p.curr.value, p.curr.wsno)
    walk p
  strNode.strv = identToStr.value.strip()
  result = strNode

proc parse(p: var Parser): Node
proc parseObject(p: var Parser, this: TokenTuple): Node

proc parseString(p: var Parser): Node =
  result = p.newNode String
  result.strv = p.curr.value
  walk p

proc parseInt(p: var Parser): Node =
  result = p.newNode Int
  result.intv = parseInt(p.curr.value)
  walk p

proc parseBool(p: var Parser, lit: bool): Node =
  result = p.newNode Bool
  result.boolv = lit
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
    if p.curr.kind in literals + {tkVariable}:
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
          subNode = p.parse()
        objectNode.value.add(subNode)
        if p.curr.kind == tkIdentifier and p.curr.pos == this.pos:
          while p.curr.kind == tkIdentifier and p.curr.pos == this.pos:
            objectNode.value.add p.parse()
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

proc parseObject(p: var Parser, this: TokenTuple): Node =
  walk p # :
  if p.next.kind in literals:
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    walk p
    result.fieldValue.add(p.parse())
  elif p.next.kind != tkEOF and p.next.line == this.line:
    walk p # :
    if p.curr.kind == tkColon:
      p.setError("Unexpected token")
    elif p.curr.kind == tkLB:
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
    walk p
    if p.curr.kind in literals:
      ! result.value.add p.parse()
    elif p.curr.kind in {tkIdentifier, tkHyphen} and p.curr.pos >= this.pos:
      if p.curr.kind == tkIdentifier and p.curr.pos == this.pos:
        p.setError("Invalid indentation")
        return
      while p.curr.pos >= this.pos and p.curr.kind in {tkIdentifier, tkHyphen}:
        if p.curr.kind == tkIdentifier and p.next.kind != tkColon:
          p.setError("Missing assignment token")
          return
        let sub = p.parse()
        result.value.add sub
        if p.curr.pos > sub.meta.pos and p.curr.kind notin {tkEOF, tkHyphen, tkComment}:
          p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
          break
    elif p.curr.kind == tkLB:
      result.value.add(p.parse())

proc parse(p: var Parser): Node =
  # Parse YAML to AST nodes
  let this = p.curr
  case p.curr.kind:
  of tkIdentifier:
    result = p.parseObject(this)
  of tkHyphen:
    if unlikely(p.next.kind == tkHyphen):
      while p.curr.kind == tkHyphen and p.curr.line == this.line:
        walk p
      return p.newNode(Header)
    var node: Node = p.newNode Array
    p.parseArray(node, this)
    result = node
  of tkString, tkAltString:
    result = p.parseString()
  of tkInteger:
    result = p.parseInt()
  of tkTrue:
    result = p.parseBool true
  of tkFalse:
    result = p.parseBool false
  of tkLB:
    result = p.parseInlineArray(this)
  of tkVariable:
    result = p.parseVariable(this)
  of tkComment: walk p
  of tkNull, tkNil:
    result = p.newNode Nil
    walk p
  else: discard

proc parseYAML*(yml: YAML, strContents: string): Parser =
  var p = Parser(lex: Lexer.init(strContents, allowMultilineStrings = true), yml: yml)
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  p.program = Program()
  while p.hasError == false and p.lex.hasError == false:
    if p.curr.kind == tkEOF: break
    if p.curr.kind == tkHyphen:
      p.rootType = Array
    else:
      p.rootType = Object
    p.program.nodes.add p.parse()
  if p.rootType == Array:
    p.writeNodes(p.program.nodes)
  else:
    p.code &= "{"
    p.writeNodes(p.program.nodes)
    p.code &= "}"
  result = p