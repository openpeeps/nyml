# A stupid simple YAML parser. From YAML to Nim objects, JsonNode or stringified JSON
# 
# (c) 2023 Nyml | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/nyml

import toktok
import std/[ropes, tables, json, jsonutils]

from std/strutils import parseInt, parseBool, `%`, indent
from std/enumutils import symbolName

static:
  Program.settings(
    uppercase = true,
    prefix = "TK_",
    allowUnknown = true,
    keepUnknownChars = true
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

tokens:
  LBR   > '['
  RBR   > ']'
  COLON > ':'
  COMMA > ','
  HYPHEN > '-'
  ALT_STRING > tokenize(handleAltString, '\'')
  BACKSLASH > '\\'
  COMMENT > '#' .. EOL
  NIL   > {"NIL", "Nil", "nil"}
  NULL  > {"NULL", "Null", "null"}
  TRUE  > {"TRUE", "True", "true", "YES", "Yes", "yes"}
  FALSE > {"FALSE", "False", "false", "NO", "No", "no"}

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
    InlineComment

  Parser* = object
    lex*: Lexer
    prev, curr, next: TokenTuple
    lvl: Table[int, Node]
    error: string
    contents: Rope
    program: Program 
    rootType: NType

  Node = ref object
    nodeName: string
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
    of Comment:
      comments: seq[string]
    of InlineComment: discard
    of Nil: discard
    meta: tuple[line, col: int]

  Program = object
    nodes: seq[Node]

const
  assignables = {TK_STRING, TK_INTEGER, TK_TRUE, TK_FALSE, TK_IDENTIFIER}
  literals = {TK_STRING, TK_ALT_STRING, TK_INTEGER, TK_TRUE, TK_FALSE, TK_NIL, TK_NULL}

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
    # while p.next.kind == TK_COMMENT:
    #     p.next = p.lex.getToken()

proc getContents*(p: var Parser): string = $p.contents

template `$$`(value: string) = add p.contents, "\"" & value & "\":"
template `$=`(value: string) = add p.contents, "\"" & value & "\""
template `$=`(value: bool) = add p.contents, $value
template `$=`(value: int) = add p.contents, $value
proc `$`(program: Program): string = pretty toJson(program), 2
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

proc writeNodes(p: var Parser, node: seq[Node], withObjects = false) =
  # Parse AST nodes and write JSON (strings)
  let nodeLen = node.len - 1 
  for i in 0 .. nodeLen:
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
    else: discard
    if i != nodeLen:
      if node[i].ntype != Comment:
        p.contents &= ","

proc newNode(p: var Parser, ntype: NType): Node =
  result = Node(
    ntype: ntype,
    nodeName: ntype.symbolName,
    meta: (p.curr.line, p.curr.col)
  )

proc newNode(p: var Parser, ntype: NType, tk: TokenTuple): Node =
  result = Node(
    ntype: ntype,
    nodeName: ntype.symbolName,
    meta: (tk.line, tk.col)
  )

template handleUnquotedStrings() =
  walk p
  while p.curr.kind != TK_EOF and p.curr.line == parent.line:
    identToStr.value &= indent(p.curr.value, p.curr.wsno)
    walk p
  strNode.strv = identToStr.value
  # strNode.meta = (identToStr.line, identToStr.col)

proc parseUnquotedStrings(p: var Parser, this: TokenTuple): Node =
  let parent = this
  let strNode = p.newNode String
  var identToStr = p.curr
  handleUnquotedStrings()
  result = strNode

proc parse(p: var Parser): Node

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

proc parseArray(p: var Parser, node: Node, this: TokenTuple) =
  while p.curr.kind == TK_HYPHEN and p.curr.col == node.meta.col:
    walk p
    if p.curr.kind in literals:
      node.items.add p.parse()
    elif p.curr.kind == TK_IDENTIFIER:
      if p.next.kind != TK_COLON:
        # handle unquoted strings.
        # this should handle any kind of characters
        node.items.add p.parseUnquotedStrings(p.curr)
      else:
        # handle objects 
        let objectNode = p.newNode Object
        let subNode = p.parse()
        objectNode.value.add(subNode)
        node.items.add objectNode
        while p.curr.kind == TK_IDENTIFIER and p.curr.col == subNode.meta.col:
          objectNode.value.add p.parse()

proc parseInlineArray(p: var Parser, this: TokenTuple): Node =
  result = p.newNode Array
  walk p
  while p.curr.kind != TK_RBR and (p.curr.line == this.line):
    if p.curr.kind == TK_EOF:
      p.setError("EOF reached before closing array")
      break
    result.items.add p.parse()
    if p.curr.kind != TK_RBR:
      if p.curr.kind == TK_COMMA and p.next.kind in literals:
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
  elif p.next.kind != TK_EOF and p.next.line == this.line:
    walk p # :
    if p.curr.kind == TK_COLON:
      p.setError("Unexpected token")
    result = p.newNode(Field, this)
    result.fieldKey = this.value
    result.fieldValue.add p.parseUnquotedStrings(this)
  else:
    result = p.newNode(Object, this)
    result.key = this.value
    walk p
    if p.curr.kind in literals:
      ! result.value.add p.parse()
    elif p.curr.kind in {TK_IDENTIFIER, TK_HYPHEN} and p.curr.col > this.col:
      while p.curr.col > this.col and p.curr.kind in {TK_IDENTIFIER, TK_HYPHEN}:
        if p.curr.kind == TK_IDENTIFIER and p.next.kind != TK_COLON:
          p.setError("Missing assignment token")
          break
        let sub = p.parse()
        result.value.add sub
        if p.curr.col > sub.meta.col and p.curr.kind notin {TK_EOF, TK_HYPHEN}:
          p.setError("Invalid indentation for \"$1\"" % [p.curr.value])
          break
    elif p.curr.kind == TK_LBR:
      result.value.add(p.parse())

proc parse(p: var Parser): Node =
  # Parse YAML to AST nodes
  let this = p.curr
  case p.curr.kind:
  of TK_IDENTIFIER:
    result = p.parseObject(this)
  of TK_HYPHEN:
    var node: Node = p.newNode Array
    p.parseArray(node, this)
    result = node
  of TK_STRING, TK_ALT_STRING:
    result = p.parseString()
  of TK_INTEGER:
    result = p.parseInt()
  of TK_TRUE:
    result = p.parseBool true
  of TK_FALSE:
    result = p.parseBool false
  of TK_LBR:
    result = p.parseInlineArray(this)
  of TK_COMMENT:
    result = p.newNode Comment
    walk p
  of TK_NULL, TK_NIL:
    result = p.newNode Nil
    walk p
  else: discard

proc parseYAML*(strContents: string): Parser =
  var p = Parser(lex: Lexer.init(strContents, allowMultilineStrings = true))
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  p.program = Program()
  while p.hasError == false and p.lex.hasError == false:
    if p.curr.kind == TK_EOF: break
    if p.curr.kind == TK_HYPHEN:
      p.rootType = Array
    else:
      p.rootType = Object
    p.program.nodes.add p.parse()
  # echo p.program
  if p.rootType == Array:
    p.writeNodes(p.program.nodes)
  else:
    p.contents &= "{"
    p.writeNodes(p.program.nodes)
    p.contents &= "}"
  result = p