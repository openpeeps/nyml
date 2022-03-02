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
    logger: true
    clear: true
"""
  var yml = Nyml.init(contents = input)
  let doc = yml.toJson()
    # rules = @[
    #   "name*:string",
    #   "path*:string",
    #   "port:int|1234",

    #   "templates*:object",
    #   "templates.layouts*:string",
    #   "templates.views*:string",
    #   "templates.partials*:string",

    #   "console:object",
    #   "console.logger:bool|true",
    #   "console.clear:bool|true",
    # ]
  check doc.get("name").getStr == "Madam"
  check doc.get("path").getStr == "./example"
  check doc.get("port").getInt == 1230
  check doc.get("templates.views").getStr == "views"
  check doc.get("console.logger").getBool == true

# block:
#   checkpoint "Error case"

#   const input = """
# name: 123
# path: "./example"
# """
#   var yml = Nyml.init(contents = input)
#   let doc = yml.toJson()
#   check doc.hasErrorRules
#   check doc.getErrorsCount == 1
