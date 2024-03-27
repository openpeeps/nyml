<p align="center">
  😋 A stupid simple YAML Parser.<br>From <code>YAML</code> to stringified <code>JSON</code>, <code>JsonNode</code> or <code>Nim</code> objects via <code>pkg/jsony</code><br>
</p>

<p align="center">
  <code>nimble install nyml</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/nyml/">API reference</a><br><br>
  <img src="https://github.com/openpeeps/nyml/workflows/test/badge.svg" alt="Github Actions"> <img src="https://github.com/openpeeps/nyml/workflows/docs/badge.svg" alt="Github Actions">
</p>


## 😍 Key Features
- [x] `integer`, `string`, `boolean`, `array`, `object`
- [x] `GET` access using `dot` annotations
- [x] Direct to object parser using [JSONY](https://github.com/treeform/jsony)
- [x] Rules and Validator
- [x] Open Source | `MIT` License

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
let osName: JsonNode = yaml(contents).toJson.get("jobs.test.runs-on")
echo osName.getStr
```

### Handle variables

```nim
let example = """
name: ${{username}}
"""
let yml = yaml(example, data = %*{"username": "John Do The Do"})
echo yml # {"name": "John Do The Do"}
```

### Dump YAML to stringified JSON
```nim
echo yaml(contents)

# dump to json with indentation
echo yaml(contents, true)

```

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/nyml/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/nyml/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to OpenPeeps via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
`MIT` license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.
