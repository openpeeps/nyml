Nyml is a simple YAML-1.0-like implementation for Nim language. Fast and Easy, **Nyml has no serialization, tags, indicators or any weird things.** In fact, Nyml is between `toml` and `yaml`, Providing support for dumping and parsing human-readable contents from `NYMl` to `JSON` and back.

_If you need a YAML 1.2 compatible library go with [flyx's NimYAML](https://github.com/flyx/NimYAML)._

Nyml is highly recommended for holding static configuration files, providing `get`, `add`, `update`, `delete` procs with or without `dot annotation access` for `JSON` nodes. Also included, a boolean formatter (supporting `no`, `yes`, `true`, `false`, lowercase and uppercase), `array` (inline or list), `string` (single/doubled quotes), `integer`, `object` trees and... `comments`. That's it!

# Usage
```python
import nyml

let grocery_list = """
user:
    id: 12345
    name: "jenna.jay"
cart:
    - apples
    - avocado
    - pineapple
    - cabbage
    - brocolli
    - carrots
    - spinach
"""

let collection = Nyml(engine: Y2J).parse(grocery_list)

```

Examples using `dot annotation access`.
_todo_