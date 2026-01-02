# Parser 模块

解析器组合子，提供组合式解析能力。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [parser.md](parser.md) | `Parser(T)` | 组合式解析器 |
| json.md | `JsonValue` | JSON 解析和序列化 |
| codec.md | `Codec` | 通用编解码器 |

## 导入方式

```zig
const parser = @import("zigfp").parser;

const Parser = parser.Parser;
const JsonValue = parser.JsonValue;
```

## 快速示例

### Parser Combinators

```zig
// 基础解析器
const digit = parser.digit;           // 解析单个数字
const letter = parser.letter;         // 解析单个字母
const whitespace = parser.whitespace; // 解析空白

// 组合解析器
const integer = parser.integer;       // 解析整数
const identifier = letter.then(parser.many(parser.alphaNum));

// 解析
const result = integer.parse("123abc");
// result.success = { value: 123, remaining: "abc" }
```

### JSON 处理

```zig
// 解析 JSON
const json_str = "{\"name\": \"zigfp\", \"version\": 1}";
var value = try parser.parseJson(allocator, json_str);
defer value.deinit(allocator);

// 访问字段
const name = value.object.get("name").?.string;  // "zigfp"

// 序列化
const output = try parser.stringifyJson(allocator, value);
defer allocator.free(output);
```

### Codec - 编解码

```zig
var registry = CodecRegistry.init(allocator);
defer registry.deinit();

// 编码
const encoded = try registry.encode(allocator, "json", myStruct);
defer allocator.free(encoded);

// 解码
const decoded = try registry.decode(allocator, "json", encoded, MyStruct);
```

## 设计说明

Parser Combinators 基于 Parsec 风格设计，支持：

- **顺序组合**: `p1.then(p2)` - 先解析 p1，再解析 p2
- **选择**: `p1.or(p2)` - 尝试 p1，失败则尝试 p2
- **重复**: `many(p)`, `many1(p)` - 零或多个，一或多个
- **映射**: `p.map(f)` - 转换解析结果
