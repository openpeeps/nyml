# 
# A simple YAML-1.0 parser to JsonNode and from JSON back to YAML.
# https://github.com/openpeep/nyml
# 
# Copyright 2021 George Lemon from OpenPeep
# Released under MIT License
#

proc cutLast*(text: string, cuts=2): string =
    # Remove chars from the end of the string
    try: text[0 .. ^cuts]
    except RangeDefect: text

proc parseBoolValue*(v: string): bool =
    # Try parse given string value into a bool
    case v:
    of "TRUE", "True", "true", "YES", "Yes", "yes", "y": result = true
    of "FALSE", "False", "false", "NO", "No", "no", "n": result = false
    else: raise newException(ValueError, "cannot interpret as a bool: " & v)

proc parseBoolValueStr*(v: string): string =
    case v:
    of "TRUE", "True", "true", "YES", "Yes", "yes", "y": result = "true"
    of "FALSE", "False", "false", "NO", "No", "no", "n": result = "false"
    else: raise newException(ValueError, "cannot interpret as a bool: " & v)    