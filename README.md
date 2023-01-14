<p align="center">
    😋 A stupid simple YAML Parser.<br>From <code>YAML</code> to stringified <code>JSON</code> or <code>JsonNode</code>. Written in Nim language 👑
</p>

_Nyml has no serialization, tags, indicators or any weird things. In fact, Nyml is somewhere between `toml` and `yaml`_
_If you need a YAML 1.2 compatible library go with [flyx's NimYAML](https://github.com/flyx/NimYAML)._

## 😍 Key Features
- [x] `integer`, `string`, `boolean`, `array`, `object`
- [x] `GET` access using `dot` annotations
- [x] Direct to object parser using [JSONY](https://github.com/treeform/jsony)
- [x] Rules and Validator
- [x] Open Source | `MIT` License

## Installing

```
nimble install nyml
```

## Example

<details>
  <summary>A simple YAML file</summary>

```yaml
name: test
on:
  push:
    paths-ignore:
      - LICENSE
      - README.*
  pull_request:
    paths-ignore:
      - LICENSE
      - README.*
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        nim-version:
          - 'stable'
    steps:
      - uses: actions/checkout@v2
      - uses: jiro4989/setup-nim-action@v1
        with:
          nim-version: ${{ matrix.nim-version }}
          repo-token: ${{ secrets.GITHUB_TOKEN }}
      - run: nimble install -Y
      - run: nim --threads:on c -r src/tim.nim
      - run: nimble test

```

</details>

### Get JSON document
```nim
let contents = readFile("sample.yaml")
let jsonContents: JsonNode = yaml(contents).toJson.get
```

### Get a specific value using `.` notation
```nim
let port: JsonNode = yaml(contents).toJson.get("app.port")
echo port.getInt
```

### Dump YAML to JSON string
```nim
echo yaml(contents)

# dump to json with indentation
echo yaml(contents, true)

```

## Roadmap
- [ ] Add tests
- [ ] Add more examples

### ❤ Contributions
You can help with code, bugfixing, or any ideas. 

### 🎩 License
Nyml is an Open Source Software released under `MIT` license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.