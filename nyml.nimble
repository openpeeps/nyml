# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A stupid simple YAML-like implementation in Nim language. From YML to JsonNode"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.4.0"

task dev, "Compile Nyml":
    echo "\n✨ Compiling Nyml" & "\n"
    exec "nim c --gc:arc -d:useMalloc -r src/nyml.nim"

task tests, "Run test":
    exec "testament p 'tests/*.nim'"
