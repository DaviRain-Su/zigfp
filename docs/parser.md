# Parser Combinators

Parser Combinators 模块提供组合式解析器，用于构建复杂的解析逻辑。

## 概述

Parser Combinators 是一种函数式的解析方法，将解析器视为一等公民，通过组合小的解析器来构建复杂的解析逻辑。基于 Parsec 风格的设计，类似于 Haskell 的 Parsec 或 Scala 的 FastParse。

核心思想：
- **解析器是函数** - 解析器接受输入字符串，返回解析结果
- **组合性** - 小解析器可以组合成大解析器
- **声明式** - 描述"什么"而非"如何"

## 导入

```zig
const fp = @import("zigfp");
const Parser = fp.Parser;
const ParseResult = fp.ParseResult;

// 基础解析器
const digit = fp.digit;
const letter = fp.letter;
const alphaNum = fp.alphaNum;
const whitespace = fp.whitespace;
const anyChar = fp.anyChar;
const eof = fp.eof;
const integer = fp.integer;

// 组合子
const many = fp.many;
const many1 = fp.many1;
```

## 核心类型

### Parser(T)

解析器类型，`T` 是解析结果类型。

```zig
pub fn Parser(comptime T: type) type {
    return struct {
        parseFn: *const fn ([]const u8) ParseResult(T),
        
        pub fn parse(self: Self, input: []const u8) ParseResult(T);
        pub fn run(self: Self, input: []const u8) ?T;
    };
}
```

### ParseResult(T)

解析结果类型：

```zig
pub fn ParseResult(comptime T: type) type {
    return union(enum) {
        success: Success(T),  // 成功：值 + 剩余输入
        failure: Failure,     // 失败：错误信息
    };
}
```

### ParseError

解析错误：

```zig
pub const ParseError = struct {
    message: []const u8,    // 错误消息
    position: usize,        // 错误位置
    expected: ?[]const u8,  // 期望的内容
};
```

## 基础解析器

### anyChar - 任意字符

```zig
const p = anyChar();
const result = p.parse("hello");
// result.getValue() = 'h'
// result.getRemaining() = "ello"
```

### char - 特定字符

```zig
const p = char('a');
const result = p.parse("abc");
// result.getValue() = 'a'
// result.getRemaining() = "bc"
```

### digit - 数字字符

```zig
const p = digit();

// 成功
const r1 = p.parse("123");
// r1.getValue() = '1'

// 失败
const r2 = p.parse("abc");
// r2.isFailure() = true
// r2.getError().expected = "digit"
```

### letter - 字母字符

```zig
const p = letter();

// 成功（小写或大写）
const r1 = p.parse("abc");  // 'a'
const r2 = p.parse("ABC");  // 'A'

// 失败
const r3 = p.parse("123");
// r3.isFailure() = true
```

### alphaNum - 字母或数字

```zig
const p = alphaNum();

const r1 = p.parse("a1");  // 'a'
const r2 = p.parse("1a");  // '1'
const r3 = p.parse("!@");  // 失败
```

### whitespace - 空白字符

```zig
const p = whitespace();

// 匹配空格、制表符、换行符、回车符
const r1 = p.parse(" hello");   // ' '
const r2 = p.parse("\thello");  // '\t'
const r3 = p.parse("\nhello");  // '\n'
const r4 = p.parse("hello");    // 失败
```

### eof - 文件结束

```zig
const p = eof();

const r1 = p.parse("");       // 成功
const r2 = p.parse("hello");  // 失败
```

### integer - 整数

```zig
const p = integer();

// 正数
const r1 = p.parse("123abc");
// r1.getValue() = 123
// r1.getRemaining() = "abc"

// 负数
const r2 = p.parse("-456xyz");
// r2.getValue() = -456
// r2.getRemaining() = "xyz"
```

### skipWhitespace - 跳过空白

```zig
const p = skipWhitespace();

const r1 = p.parse("   hello");
// r1.getRemaining() = "hello"

const r2 = p.parse("hello");
// r2.getRemaining() = "hello"（空白是可选的）
```

## 组合子

### many - 零或多个

```zig
const allocator = std.testing.allocator;
const manyDigits = many(u8, digit(), allocator);

// 匹配多个数字
const result = try manyDigits.parse("123abc");
defer allocator.free(result.values);

// result.values = ['1', '2', '3']
// result.remaining = "abc"

// 零个也成功
const result2 = try manyDigits.parse("abc");
// result2.values.len = 0
// result2.remaining = "abc"
```

### many1 - 一或多个

```zig
const allocator = std.testing.allocator;
const many1Digits = many1(u8, digit(), allocator);

// 成功（至少一个）
const result = try many1Digits.parse("123abc");
defer allocator.free(result.?.values);
// result.?.values = ['1', '2', '3']

// 失败（零个不行）
const result2 = try many1Digits.parse("abc");
// result2 = null
```

### alt - 选择

```zig
const p = alt(u8, digit(), letter());
// 先尝试 digit，失败则尝试 letter
```

### optional - 可选

```zig
const p = optional(u8, digit());
// 成功返回 Some(值)，失败返回 None
```

### andThen - 序列（返回第二个）

```zig
const p = digit().andThen(u8, letter());
// 解析数字，然后解析字母，返回字母
```

### andSkip - 序列（返回第一个）

```zig
const p = digit().andSkip(u8, letter());
// 解析数字，然后解析字母，返回数字
```

## ParseResult 方法

```zig
const result = parser.parse(input);

// 检查成功/失败
if (result.isSuccess()) {
    const value = result.getValue().?;
    const remaining = result.getRemaining().?;
}

if (result.isFailure()) {
    const error = result.getError().?;
    std.debug.print("Error: {s} at {}\n", .{ error.message, error.position });
}
```

## Parser 方法

```zig
const p = digit();

// 完整解析（返回 ParseResult）
const result = p.parse("123");

// 简化解析（只返回值，忽略剩余）
const value = p.run("123");  // ?u8
```

## 完整示例

### 解析整数列表

```zig
const std = @import("std");
const fp = @import("zigfp");

pub fn parseIntegerList(allocator: std.mem.Allocator, input: []const u8) ![]i64 {
    var list = try std.ArrayList(i64).initCapacity(allocator, 16);
    errdefer list.deinit(allocator);
    
    const intParser = fp.integer();
    const ws = fp.skipWhitespace();
    
    var current = input;
    
    // 跳过前导空白
    const wsResult = ws.parse(current);
    current = wsResult.getRemaining().?;
    
    while (current.len > 0) {
        // 尝试解析整数
        const intResult = intParser.parse(current);
        if (intResult.isFailure()) break;
        
        try list.append(allocator, intResult.getValue().?);
        current = intResult.getRemaining().?;
        
        // 跳过空白和逗号
        const wsResult2 = ws.parse(current);
        current = wsResult2.getRemaining().?;
        
        if (current.len > 0 and current[0] == ',') {
            current = current[1..];
            const wsResult3 = ws.parse(current);
            current = wsResult3.getRemaining().?;
        }
    }
    
    return try list.toOwnedSlice(allocator);
}
```

### 解析标识符

```zig
const std = @import("std");
const fp = @import("zigfp");

pub fn parseIdentifier(allocator: std.mem.Allocator, input: []const u8) !?[]const u8 {
    // 标识符必须以字母开头
    const letterParser = fp.letter();
    const firstResult = letterParser.parse(input);
    if (firstResult.isFailure()) return null;
    
    var start: usize = 0;
    var end: usize = 1;
    
    // 后续可以是字母或数字
    const alphaNumParser = fp.alphaNum();
    var current = firstResult.getRemaining().?;
    
    while (current.len > 0) {
        const result = alphaNumParser.parse(current);
        if (result.isFailure()) break;
        end += 1;
        current = result.getRemaining().?;
    }
    
    return input[start..end];
}
```

### 解析简单表达式

```zig
const std = @import("std");
const fp = @import("zigfp");

pub const Expr = union(enum) {
    number: i64,
    add: struct { left: *Expr, right: *Expr },
};

pub fn parseNumber(input: []const u8) ?i64 {
    const p = fp.integer();
    return p.run(input);
}

pub fn parseExpr(allocator: std.mem.Allocator, input: []const u8) !?*Expr {
    // 跳过空白
    const ws = fp.skipWhitespace();
    var current = ws.parse(input).getRemaining().?;
    
    // 解析数字
    const intParser = fp.integer();
    const numResult = intParser.parse(current);
    if (numResult.isFailure()) return null;
    
    const expr = try allocator.create(Expr);
    expr.* = .{ .number = numResult.getValue().? };
    
    return expr;
}
```

## API 参考

### 基础解析器

| 函数 | 签名 | 说明 |
|------|------|------|
| `anyChar` | `fn() Parser(u8)` | 匹配任意字符 |
| `char` | `fn(comptime u8) Parser(u8)` | 匹配特定字符 |
| `digit` | `fn() Parser(u8)` | 匹配数字 0-9 |
| `letter` | `fn() Parser(u8)` | 匹配字母 a-z, A-Z |
| `alphaNum` | `fn() Parser(u8)` | 匹配字母或数字 |
| `whitespace` | `fn() Parser(u8)` | 匹配空白字符 |
| `eof` | `fn() Parser(void)` | 匹配输入结束 |
| `integer` | `fn() Parser(i64)` | 匹配整数（含负数） |
| `skipWhitespace` | `fn() Parser(void)` | 跳过空白（零或多个） |
| `string` | `fn([]const u8) Parser([]const u8)` | 匹配字符串 |

### 组合子

| 函数 | 签名 | 说明 |
|------|------|------|
| `many` | `fn(T, Parser(T), Allocator) ManyParser(T)` | 零或多个 |
| `many1` | `fn(T, Parser(T), Allocator) Many1Parser(T)` | 一或多个 |
| `alt` | `fn(T, Parser(T), Parser(T)) Parser(T)` | 选择 |
| `optional` | `fn(T, Parser(T)) Parser(?T)` | 可选 |
| `pure` | `fn(T, T) Parser(T)` | 始终成功 |
| `fail` | `fn(T, []const u8) Parser(T)` | 始终失败 |

### Parser(T) 方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `parse` | `fn(Self, []const u8) ParseResult(T)` | 运行解析器 |
| `run` | `fn(Self, []const u8) ?T` | 解析并返回值 |
| `map` | `fn(Self, U, fn(T) U) Parser(U)` | Functor map |
| `flatMap` | `fn(Self, U, fn(T) Parser(U)) Parser(U)` | Monad bind |
| `andThen` | `fn(Self, U, Parser(U)) Parser(U)` | 序列，返回第二个 |
| `andSkip` | `fn(Self, U, Parser(U)) Self` | 序列，返回第一个 |

### ParseResult(T) 方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `isSuccess` | `fn(Self) bool` | 是否成功 |
| `isFailure` | `fn(Self) bool` | 是否失败 |
| `getValue` | `fn(Self) ?T` | 获取成功的值 |
| `getRemaining` | `fn(Self) ?[]const u8` | 获取剩余输入 |
| `getError` | `fn(Self) ?Failure` | 获取错误信息 |

## 注意事项

1. **Zig 闭包限制**: 由于 Zig 不支持闭包，`map` 和 `flatMap` 采用简化实现
2. **内存管理**: `many` 和 `many1` 需要 allocator，记得释放返回的数组
3. **回溯**: 当前实现不支持完整的回溯，失败时不会自动尝试其他分支
4. **性能**: Parser Combinators 的性能不如手写解析器，但更易于编写和维护

## 与其他语言对比

| 特性 | Haskell Parsec | Scala FastParse | zigFP |
|------|---------------|-----------------|-------|
| 基础解析器 | `char`, `digit` | `P[_]` | `char`, `digit` |
| 组合子 | `<|>`, `many` | `|`, `rep` | `alt`, `many` |
| 回溯 | `try` | `backtrack` | 限制 |
| 错误处理 | 完整 | 完整 | 基础 |

## 相关模块

- [Option](option.md) - 可选值处理
- [Result](result.md) - 错误处理
- [Validation](validation.md) - 累积错误验证
