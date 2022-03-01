# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A stupid simple YAML-like implementation in Nim language. From YAML to JsonNode"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.4.0"
requires "toktok"

task tests, "Run test":
    exec "testament p 'tests/*.nim'"
