# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode"
license       = "MIT"
srcDir        = "src"        
# Dependencies

requires "nim >= 1.4.0"
requires "toktok"
requires "pkginfo"

task tests, "Run test":
    exec "testament p 'tests/*.nim'"

task dev, "compile nyml":
    echo "\n✨ Compiling..." & "\n"
    exec "nim --gc:arc --out:bin/nyml --hints:off -d:toktokdebug --threads:on c src/nyml.nim"