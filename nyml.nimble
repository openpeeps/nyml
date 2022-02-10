# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A stupid simple YAML-like implementation in Nim language. From YML to JsonNode"
license       = "MIT"
srcDir        = "src"
bin           = @["nyml"]
binDir        = "bin"

# Dependencies

requires "nim >= 1.4.0"

include ./tasks/dev