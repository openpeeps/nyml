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
