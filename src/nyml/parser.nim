# A stupid simple YAML parser. From YAML to Nim objects, JsonNode or stringified JSON
# 
# (c) 2023 Nyml | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/nyml

import pkg/toktok
import std/ropes
import ./meta

from std/strutils import parseInt, parseBool, `%`, indent
from std/enumutils import symbolName

import std/[jsonutils, json]

static:
  Program.settings(
    uppercase = true,
    prefix = "TK_",
    allowUnknown = true,
    keepUnknownChars = true,
    handleCustomIdent = true
  )

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
      of ':', NewLines, EndOfFile:
        break
      of '#':
        if lex.wsno == 0:
          add lex.token, lex.buf[lex.bufpos]
          inc lex.bufpos          
        else: break
      else:
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
    result = TKIdentifier

  proc handleComment*(lex: var Lexer, kind: TokenKind) =
    if lex.wsno == 0 and lex.getColNumber(lex.bufpos) != 0:
      lex.startPos = lex.getColNumber(lex.bufpos)
      setLen(lex.token, 0)
      inc lex.bufpos
      lex.token = "#"
      lex.kind = TKUnknown
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
        lex.kind = TKUnknown
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
    except IndexDefect:
      discard lex.handleCustomIdent()

tokens:
  LBR   > '['
  RBR   > ']'
  Colon > ':'
  Comma > ','
  Hyphen > '-'
  Header
  Variable > tokenize(handleVariable, '$')
  LC     > '{'
  RC     > '}'
  AltString > tokenize(handleAltString, '\'')
  Backslash > '\\'
  Comment > tokenize(handleComment, '#')
  Nil   > {"NIL", "Nil", "nil"}
  Null  > {"NULL", "Null", "null"}
  True  > {"TRUE", "True", "true", "YES", "Yes", "yes"}
  False > {"FALSE", "False", "false", "NO", "No", "no"}

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
    contents: string
    program: Program 
    rootType: NType
    yml: Nyml

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
    meta: tuple[line, col: int]

  Program = object
    nodes: seq[Node]

const
  assignables = {TKString, TKInteger, TKTrue, TKFalse, TKIdentifier}
  literals = {TKString, TKAltString, TKInteger, TKTrue, TKFalse, TKNil, TKNull}

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
    while p.next.kind == TKComment:
      p.next = p.lex.getToken()

proc getContents*(p: var Parser): string = $p.contents

template `$$`(value: string) = add p.contents, "\"" & value & "\":"
template `$=`(value: string) = add p.contents, "\"" & value & "\""
template `$=`(value: bool) = add p.contents, $value
template `$=`(value: int) = add p.contents, $value
# proc `$`(program: Program): string = pretty toJson(program), 2
proc `$`(node: Node): string = pretty toJson(node), 2

template `!`(nextBlock) =
  if p.curr.kind in literals:
    if p.curr.line != this.line:
      p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
      return
  nextBlock

template `!!`(nextBlock) =
  if p.curr.col < this.col:
    p.setError("Invalid indentation in array for \"$1\" item" % [p.next.value])
    break
  nextBlock

template `{`(subNode) =
  p.contents &= "{"
  subNode

template `}`() =
  p.contents &= "}"

template `[`(subNode) =
  p.contents &= "["
  subNode
template `]`() = p.contents &= "]"

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
      p.contents &= "null"
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
        p.contents &= "null"
      if skipIter: continue
    else:
      discard
    if i != node.high:
      if node[i].ntype notin {Comment, Header}:
        add p.contents, ","
    # inc i

proc newNode(p: var Parser, ntype: NType): Node =
  result = Node(
    ntype: ntype,
    meta: (p.curr.line, p.curr.col)
  )

proc newNode(p: var Parser, ntype: NType, tk: TokenTuple): Node =
  result = Node(
    ntype: ntype,
    meta: (tk.line, tk.col)
  )

proc parseUnquotedStrings(p: var Parser, this: TokenTuple, stoppers: set[TokenKind] = {}): Node =
  let strNode = p.newNode String
  var identToStr = p.curr
  walk p
  while p.curr.line == this.line:
    if p.curr.kind in {TKEOF} + stoppers:
      break
    if p.curr.kind == TKComment:
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
    if p.curr.line == this.line and p.curr.kind notin {TKComment, TKEOF, TKRBR, TKComma}:
      result.varRight.add p.parseUnquotedStrings(this, {TKRBR, TKComma})
  else:
    if p.curr.line == this.line and p.curr.kind notin {TKComment, TKEOF}:
      result.varRight.add p.parseUnquotedStrings(this)

proc parseArray(p: var Parser, node: Node, this: TokenTuple) =
  while p.curr.kind == TKHyphen and p.curr.col == node.meta.col:
    walk p
    if p.curr.kind in literals + {TKVariable}:
      node.items.add p.parse()
    elif p.curr.kind == TKIdentifier:
      if p.next.kind != TKColon:
        # handle unquoted strings.
        node.items.add p.parseUnquotedStrings(p.curr)
      else:
        # handle objects 
        let
          objectNode = p.newNode Object
          this = p.curr
          subNode = p.parse()
        objectNode.value.add(subNode)
        if p.curr.kind == TKIdentifier and p.curr.col == this.col:
          while p.curr.kind == TKIdentifier and p.curr.col == this.col:
            objectNode.value.add p.parse()
        node.items.add objectNode

proc parseInlineArray(p: var Parser, this: TokenTuple): Node =
  result = p.newNode Array
  walk p
  while p.curr.kind != TKRBR and (p.curr.line == this.line):
    if p.curr.kind == TKEOF:
      p.setError("EOF reached before closing array")
      break
    if p.curr.kind in literals:
      result.items.add p.parse()
    elif p.curr.kind == TKVariable:
      result.items.add p.parseVariable(this, true)
    else:
      discard # TODO
      # result.items.add p.parseUnquotedStrings(p.curr)
    if p.curr.kind != TKRBR:
      if p.curr.kind == TKCOMMA and p.next.kind in literals + {TKVariable}:
        walk p
      else:
        p.setError("Invalid array item $1" % [p.curr.value])
        break
  walk p

proc parseObject(p: var Parser, this: TokenTuple): Node =
  walk p # :
  if p.next.kind in literals:
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    walk p
    result.fieldValue.add(p.parse())
  elif p.next.kind != TKEOF and p.next.line == this.line:
    walk p # :
    if p.curr.kind == TKColon:
      p.setError("Unexpected token")
    elif p.curr.kind == TKLBR:
      result = p.newNode(Field, this)
      result.fieldKey = this.value
      result.fieldValue.add p.parse()
    elif p.curr.kind == TKVariable:
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
    elif p.curr.kind in {TKIdentifier, TKHyphen} and p.curr.col > this.col:
      while p.curr.col > this.col and p.curr.kind in {TKIdentifier, TKHyphen}:
        if p.curr.kind == TKIdentifier and p.next.kind != TKColon:
          p.setError("Missing assignment token")
          break
        let sub = p.parse()
        result.value.add sub
        if p.curr.col > sub.meta.col and p.curr.kind notin {TKEOF, TKHyphen, TKComment}:
          p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
          break
    elif p.curr.kind == TKLBR:
      result.value.add(p.parse())

proc parse(p: var Parser): Node =
  # Parse YAML to AST nodes
  let this = p.curr
  case p.curr.kind:
  of TKIdentifier:
    result = p.parseObject(this)
  of TKHyphen:
    if unlikely(p.next.kind == TKHyphen):
      while p.curr.kind == TKHyphen and p.curr.line == this.line:
        walk p
      return p.newNode(Header)
    var node: Node = p.newNode Array
    p.parseArray(node, this)
    result = node
  of TKString, TKAltString:
    result = p.parseString()
  of TKInteger:
    result = p.parseInt()
  of TKTrue:
    result = p.parseBool true
  of TKFalse:
    result = p.parseBool false
  of TKLBR:
    result = p.parseInlineArray(this)
  of TKVariable:
    result = p.parseVariable(this)
  of TKComment: walk p
  of TKNull, TKNil:
    result = p.newNode Nil
    walk p
  else: discard

proc parseYAML*(yml: Nyml, strContents: string): Parser =
  var p = Parser(lex: Lexer.init(strContents, allowMultilineStrings = true), yml: yml)
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  p.program = Program()
  while p.hasError == false and p.lex.hasError == false:
    if p.curr.kind == TKEOF: break
    if p.curr.kind == TKHyphen:
      p.rootType = Array
    else:
      p.rootType = Object
    p.program.nodes.add p.parse()
  if p.rootType == Array:
    p.writeNodes(p.program.nodes)
  else:
    p.contents &= "{"
    p.writeNodes(p.program.nodes)
    p.contents &= "}"
  result = p