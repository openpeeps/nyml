# Package

version       = "0.1.9"
author        = "George Lemon"
description   = "A stupid simple YAML Parser. YAML to stringified JSON, JsonNode or Nim objects via pkg/jsony"
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
  exec "nimble --mm:arc --out:bin/nyml --hints:off c src/nyml.nim"

task bench, "benchmark":
  exec "nimble --mm:arc -d:danger c src/nyml.nim"