<p align="center">
    😋 A stupid simple YAML-like implementation in Nim language. From <code>YML</code> to <code>JsonNode</code><br>
    <strong>Fast</strong> • <strong>Dependency free</strong>
</p>

_Work in progress_

_Nyml has no serialization, tags, indicators or any weird things. In fact, Nyml is somewhere between `toml` and `yaml`_
_If you need a YAML 1.2 compatible library go with [flyx's NimYAML](https://github.com/flyx/NimYAML)._

## 😍 Key Features
- [x] `integer`, `string`, `boolean`, `array`, `objects`
- [x] `GET` access using `dot` annotations
- [x] Rules and Validator
- [x] Open Source | `MIT` License

## Installing

```
nimble install nyml
```

## Examples

The following example is taken from [Madam's Configurator](https://github.com/openpeep/madam)

<details>
    <summary>Contents example</summary>

```yaml
name: "Madam"
path: "./example"
port: 1230
templates:
    views: "views"
    layouts: "layouts"
    partials: "partials"
routes:
    get:
        about: "about.html"
assets:
    source: "./dist/assets/*"
    public: "/assets"
console:
    logger: true                    # Enable http request logger
    clear: true                     # Clear previous console output on request
```

</details>

```nim
let doc = Nyml(engine: Y2J).parse(readFile("sample.yml"),
            rules = @["name*:string", "path*:string", "port:int|1234",
                    "logs:bool|false","templates*:object", "templates.layouts*:string",
                    "templates.views*:string", "templates.partials*:string"
            ]),

if doc.hasErrorRules():
    let count = doc.getErrorsCount()
    let errorWord = if count == 1: "error" else: "errors"
    echo "👉 Found $1 $2 in your Madam configuration:" % [$count, errorWord]
    for key, err in doc.getErrorRules().pairs():
        echo "  • " & err.getErrorMessage()

echo doc.get("name").getStr             # Madam
echo doc.get("assets.source")           # ./dist/assets/*
```

### Rules & Validators
_documentation_

## Roadmap
- [ ] Add tests
- [ ] Add more examples

### ❤ Contributions
If you like this project you can contribute to Nyml project by opening new issues, fixing bugs, contribute with code, ideas and you can even [donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C) 🥰

### 👑 Discover Nim language
<strong>What's Nim?</strong> Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim language](https://nim-lang.org/)

<strong>Why Nim?</strong> Performance, fast compilation and C-like freedom. We want to keep code clean, readable, concise, and close to our intention. Also a very good language to learn in 2022.

### 🎩 License
Nyml is an Open Source Software released under `MIT` license. [Developed by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2022 OpenPeep & Contributors &mdash; All rights reserved.