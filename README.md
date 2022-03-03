<p align="center">
    😋 A stupid simple YAML Parser.<br>From <code>YAML</code> to stringified <code>JSON</code> or <code>JsonNode</code>. Written in Nim language 👑
</p>

_Nyml has no serialization, tags, indicators or any weird things. In fact, Nyml is somewhere between `toml` and `yaml`_
_If you need a YAML 1.2 compatible library go with [flyx's NimYAML](https://github.com/flyx/NimYAML)._

## 😍 Key Features
- [x] `integer`, `string`, `boolean`, `array`, `object`
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

assets:
  source: "./dist/assets/*"
  public: "/assets"

console:
  logger: true
  clear: true
```

</details>

From YAML to stringified JSON. Fastest. Best recommended for writing files
```nim
    var yml = Nyml.init(contents = readFile("sample.yml"))
    writeFile("sample.json", yml.toJsonStr())
```

Parse YAML to stringified JSON and JsonNode using `std/json`
```nim
    var yml = Nyml.init(contents = readFile("sample.yml"))
    let doc: Document = yml.toJson()
    doc.get("name").getStr
```

### Rules & Validators
_todo_

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