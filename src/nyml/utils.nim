# 
# A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
# 

from ./meta import Document
from std/json import JsonNode

proc get*[T: Document](doc: T, key: string = ""): JsonNode =
    ## Retrieve a value from current Nyml Document as JsonNode.
    ## This procedure requires parsing the stringified JSON as JsonNode
    result = get(doc.nyjson, key)

proc get*[T: Document](doc: T, key: string = "", asObject = true): Document =
    ## Retrieve a value from current Nyml Document as NyObject
    ## This procedure is using an internal Object handler
    ## for returning structured data as Nim Objects
    result = get(doc.nyobject, key)

proc boolVariant*(): seq[string] = 
    ## Return a sequence containing available bool variants
    result = @["true", "True", "TRUE", "YES", "Y", "y", "false", "False", "FALSE", "NO", "N", "n"]

proc parseBoolValue*(v: string): bool =
    ## Try parse given string-based bool variant value to boolean
    case v:
    of "TRUE", "True", "true", "YES", "Yes", "yes", "y": result = true
    of "FALSE", "False", "false", "NO", "No", "no", "n": result = false
    else: raise newException(ValueError, "cannot interpret as a bool: " & v)

proc parseBoolValueStr*(v: string): string =
    ## Parse all string-based variants and return a stringified bool
    result = $(parseBoolValue(v))