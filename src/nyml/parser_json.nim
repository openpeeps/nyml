import json, ./meta
from ./lexer import TokenKind
from strutils import `%`, contains, split, parseInt, parseBool

type Document* = object
        json_contents: JsonNode         # Used by Y2J engine to store JSON contents
        yaml_contents: string           # Used by J2Y engine to store YAML contents

proc getTknValByType(tk: TokenKind, tk_val: string): JsonNode =
    # Internal procedure for mapping given
    # token value with a JsonNode of its kind
    var value: JsonNode
    value = case tk:
            # of TK_STRING: newJString(tk_val)
            of TK_INTEGER: newJInt(parseInt(tk_val))
            of TK_BOOLEAN: newJBool(parseBool(tk_val))
            of TK_ARRAY: parseJson(tk_val)
            else: newJString(tk_val)
    return value

proc get(jContents: JsonNode, key: string = ""): JsonNode = 
    if key.contains("."):
        var i = 0
        var k = key.split(".", maxsplit=1)
        var tree: JsonNode
        while true:
            try:
                tree = jContents[k[i]]
                inc i
                tree = get(tree, k[i])
            except KeyError:
                break
        return tree
    elif key.len == 0:
        return jContents
    else:
        return jContents[key]

proc get*[T: Document](doc: T, key: string = ""): JsonNode =
    ## Browse to current document content and retrieve
    ## values using dot annotation key.
    ## For example: get("user.email.business")
    return get(doc.json_contents, key)

proc putIt(contents: JsonNode, key: string, value: JsonNode, isLastCall=false): JsonNode =
    # Kinda nasty setter that creates json levels recursively
    if key.contains("."):
        var i = 0
        var last = false
        var k = key.split(".", maxsplit=1)
        var tree = newJObject()
        while true:
            try:
                tree[k[i]] = tree.putIt(k[i + 1], value)
                inc i
            except IndexDefect:
                last = true
                break
        return tree
    return %*{key: value}

proc setError[T: Nyml](handler: var T, tkn: tuple[kind: TokenKind, value: string, line, indent: int], msg: string) =
    handler.error = "(line: $1) Error - $2" % [$tkn.line, msg]
proc hasError[T: Nyml](handler: var T): bool = handler.error.len != 0
proc sameLine(v_tkl, k_tkl: int): bool = v_tkl == k_tkl
proc sameWith(prev, curr: TokenKind, these: set[TokenKind]): bool = prev in these and curr in these

proc parseToJson*[T: Nyml](yml: var T,
    tokens: seq[tuple[kind: TokenKind, value: string, line, indent: int]]): Document =
    var i = 0
    var ii = 0

    var contents = %* {}
    var tknsLen = tokens.len
    var allTokens = tokens
    var treekeys: string
    var curr, prev, currKey, origin, root: tuple[
        kind: TokenKind,
        value: string,
        line, indent: int
    ]

    root.kind = TK_SKIPPABLE

    while true:
        if i == tknsLen: break
        try: curr = allTokens[i]
        except IndexDefect: break

        if curr.kind == TK_COMMENT:
            delete(allTokens, i)
            continue

        if prev.kind == TK_NONE:
            if curr.kind == TK_KEY and curr.indent != 0:
                yml.setError(curr, "First key cannot be indented")
                break
            elif curr.kind != TK_KEY:
                yml.setError(curr, "Missing key declaration")
                break

            contents[curr.value] = newJObject()
            prev = curr         # current token as previously token declaration
            currKey = curr      # current token as previously key declaration
        else:
            # echo curr.indent > prev.indent
            if prev.kind == TK_KEY and curr.kind == TK_KEY:
                if prev.line == curr.line:
                    # Prevent multiple keys on the same line
                    yml.setError(curr, "Multiple keys on the same line")
                    break
                elif curr.indent == prev.indent:
                    yml.setError(curr, "Indentation required")
                    break

            if curr.kind == TK_KEY:
                if contents.hasKey(curr.value):
                    yml.setError(curr, "Duplicate keys")
                    break
                elif prev.kind in {TK_ARRAY, TK_OBJECT} and prev.line == curr.line:
                    yml.setError(curr, "Key declaration requires indentation")
                    break

                if prev.kind == TK_KEY and curr.indent > prev.indent:
                    if prev.indent == 0:
                        origin = prev
                        treekeys = ""
                        currKey = curr
                        prev = curr

                        # entering in grandparents, exclude itself from tokens list
                        # and retrieve the rest of the list so we can walk and
                        # determine the entire three of the origin
                        var originPosition = i
                        var subtkns = allTokens[originPosition + 1 .. ^1]
                        var cpsubtkns: seq[tuple[kind: TokenKind, value: string, line, indent: int]]
                        var tree = newJObject()
                        while true:
                            try:
                                if subtkns[ii].indent == prev.indent:
                                    echo "yeeeeee"
                                elif subtkns[ii].indent > prev.indent:
                                    cpsubtkns.add(subtkns[ii])
                                elif subtkns[ii].kind in {TK_STRING, TK_INTEGER, TK_BOOLEAN}:
                                    cpsubtkns.add(subtkns[ii])
                                else: break
                            except IndexDefect: break
                            prev = subtkns[ii]
                            inc ii
                            inc originPosition
                        ii = 0

                        # Remove the copied tree of tokens from main list
                        cpsubtkns.insert(currKey)   # insert second level key
                        for cpsubtkn in cpsubtkns:
                            if cpsubtkn.kind == TK_KEY:
                                treekeys.add(cpsubtkn.value & ".")
                            delete(allTokens, allTokens.find(cpsubtkn))
                        
                        # echo cpsubtkns
                        tree = putIt(tree, treekeys.cutLast(), getTknValByType(prev.kind, prev.value))
                        contents[origin.value] = tree
                        continue    # no need for parsing, skip it
                else: discard
                currKey = curr
                prev = curr
            elif currKey.kind == TK_KEY and curr.kind in {TK_ARRAY_BLOCK}:
                prev = curr
            
            elif currKey.kind == TK_KEY and curr.kind in {TK_STRING, TK_INTEGER, TK_BOOLEAN}:
                if not curr.line.sameLine(currKey.line) and prev.kind notin {TK_ARRAY_BLOCK}:
                    yml.setError(curr, "Bad indentation on string value assignment " & $prev.value)
                    break
                elif prev.kind.sameWith(curr.kind, {TK_STRING, TK_INTEGER, TK_BOOLEAN}) or prev.kind in {TK_ARRAY, TK_OBJECT}:
                    yml.setError(curr, "Unallowed mix of values assigned to the same key.")
                    break

                if prev.kind in {TK_ARRAY_BLOCK}:
                    if not contents.hasKey(currKey.value):
                        contents[currKey.value] = newJArray()

                case curr.kind:
                of TK_STRING:
                    var str_v = newJString(curr.value)
                    if prev.kind in {TK_ARRAY_BLOCK}:
                        contents[currKey.value].add(str_v)
                    else:
                        contents[currKey.value] = str_v
                        prev = curr
                of TK_INTEGER:
                    var int_v = newJInt(parseInt(curr.value))
                    if prev.kind in {TK_ARRAY_BLOCK}:
                        contents[currKey.value].add(int_v)
                    else:
                        contents[currKey.value] = int_v
                        prev = curr
                of TK_BOOLEAN:
                    var bool_v = newJBool(parseBool(curr.value))
                    if prev.kind in {TK_ARRAY_BLOCK}:
                        contents[currKey.value].add(bool_v)
                    else:
                        contents[currKey.value] = bool_v
                        prev = curr
                else: discard
            elif currKey.kind == TK_KEY and curr.kind in {TK_ARRAY, TK_OBJECT}:
                # Inline Arrays and Object assignments
                if prev.kind in {TK_ARRAY, TK_OBJECT}:
                    yml.setError(curr, "Unallowed mix of values assigned to the same key.")
                    break

                case curr.kind:
                of TK_ARRAY:
                    try:
                        contents[currKey.value] = parseJson(curr.value)
                    except JsonParsingError:
                        yml.setError(curr, "Invalid array format")
                    prev = curr
                else: discard
        inc i

    if yml.hasError():
        echo "\n" & yml.error & "\n"
        return Document(json_contents: newJObject())
    else: 
        return Document(json_contents: contents)