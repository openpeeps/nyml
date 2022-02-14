discard """
  output: ""
  exitCode: 0
"""

import nyml

import std/unittest

block:
  checkpoint "Basic usage"

  const input = """
name: "Madam"
path: "./example"
port: 1230

templates:
    views: "views"
    layouts: "layouts"
    partials: "partials"

assets:
    source: "./dist/assets/*"
    public: "/assets"

console:
    logger: true                    # Enable http request logger
    clear: true                     # Clear previous console output on request
"""
  let got = Nyml(engine: Y2J).parse(input,
    rules = @[
      "name*:string",
      "path*:string",
      "port:int|1234",
      "port2:int|1234",

      "templates*:object",
      "templates.layouts*:string",
      "templates.views*:string",
      "templates.partials*:string",

      "console:object",
      "console.logger:bool|true",
      "console.clear:bool|true",
    ])
  check got.get("name").getStr == "Madam"
  check got.get("path").getStr == "./example"
  check got.get("port").getInt == 1230
  check got.get("port2").getInt == 1234 # Default value
  check got.get("templates.views").getStr == "views"
  check got.get("console.logger").getBool == true

block:
  checkpoint "Error case"

  const input = """
name: 123
path: "./example"
"""
  let got = Nyml(engine: Y2J).parse(input,
    rules = @[
      "name*:string",
    ])
  check got.hasErrorRules
  check got.getErrorsCount == 1
