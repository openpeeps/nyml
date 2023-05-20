import std/unittest
import nyml

let basicExample = """
info:
  short: "United States"
  long: "United States of America"
  alpha2: US
  alpha3: USA
  iso: 840
  ioc: USA
  capital: "Washington"
  tld: ".us"
"""

let basicExampleJSON = """{"info":{"short":"United States","long":"United States of America","alpha2":"US","alpha3":"USA","iso":840,"ioc":"USA","capital":"Washington","tld":".us"}}"""

test "can parse basicExample":
  check $yaml(basicExample) == basicExampleJSON

test "can access fields via dot annotation":
  let yml = yaml(basicExample)
  check yml.toJson.get("info.short").getStr == "United States"
  check yml.toJson.get("info.tld") == %*(".us")

test "can parse with ---":
  let basicExampleHeader = """
---
title: "Table of Contents"
subtitle: "Lorem ipsum whenever seaside yes please no more city"
  """
  check yaml(basicExampleHeader).toJson.get("title").getStr == "Table of Contents"

test "can parse unquoted strings":
  let unquotedExample = """
postal:
  description: "US : NNNNN[-NNNN]"
  redenundant_chars: '-'
  regex: ^[0-9]{5}([0-9]{4})?$
  charset: number
  length: 
    - "5"
    - "10"
  """
  let unquotedExampleJSON = """{"postal":{"description":"US : NNNNN[-NNNN]","redenundant_chars":"-","regex":"^0-95(0-94)?$","charset":"number","length":["5","10"]}}"""
  check $yaml(unquotedExample) == unquotedExampleJSON
