# Package

version       = "0.1.6"
author        = "George Lemon"
description   = "A stupid simple YAML Parser. From YAML to stringified JSON (fastest) or JsonNode"
license       = "MIT"
srcDir        = "src"        
# Dependencies

requires "nim >= 1.4.0"
requires "toktok#head"
requires "jsony"

task tests, "Run test":
  exec "testament p 'tests/*.nim'"

task dev, "compile nyml":
  echo "\n✨ Compiling..." & "\n"
  exec "nim --gc:arc --out:bin/nyml --hints:off --threads:on c src/nyml.nim"

task bench, "benchmark":
  exec "nim c --gc:arc -d:danger -d:release benchmarks/test.nim"