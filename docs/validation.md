# Validation - 累积错误验证

> 收集所有错误而非快速失败的验证类型

## 概述

`Validation` 与 `Result` 类似，但关键区别在于错误处理：

- **Result**: 遇到第一个错误就停止（fail-fast）
- **Validation**: 收集所有错误（accumulating）

这使得 `Validation` 非常适合表单验证、配置验证等需要一次性返回所有错误的场景。

## 核心类型

```zig
const fp = @import("zigfp");

// Validation(T, E) 有两种状态
// - valid: 包含成功值 T
// - invalid: 包含错误列表 []const E
```

## 基本用法

### 创建 Validation

```zig
// 有效值
const v1 = fp.valid(i32, []const u8, 42);

// 无效值（单个错误）
const v2 = fp.invalid(i32, []const u8, "error message");

// 无效值（多个错误）
const errors = [_][]const u8{ "error1", "error2" };
const v3 = fp.invalidMany(i32, []const u8, &errors);
```

### 查询状态

```zig
const v = fp.valid(i32, []const u8, 42);

if (v.isValid()) {
    const value = v.getValue().?;  // 42
}

if (v.isInvalid()) {
    const errors = v.getErrors().?;
}

// 获取值或默认值
const value = v.getOrElse(0);
```

## 函数式操作

### map

对有效值应用函数。

```zig
const v = fp.valid(i32, []const u8, 21);

const double = struct {
    fn f(x: i32) i32 { return x * 2; }
}.f;

const mapped = v.map(i32, double);
// mapped.getValue() = 42
```

### combine

组合两个 Validation，累积所有错误。

```zig
const v1 = fp.valid(i32, []const u8, 10);
const v2 = fp.valid(i32, []const u8, 20);

const add = struct {
    fn f(a: i32, b: i32) i32 { return a + b; }
}.f;

const result = try v1.combine(v2, add, allocator);
// result.getValue() = 30

// 如果两边都有错误，错误会累积
const e1 = fp.invalid(i32, []const u8, "error1");
const e2 = fp.invalid(i32, []const u8, "error2");
const combined = try e1.combine(e2, add, allocator);
// combined.getErrors() = ["error1", "error2"]
```

### fold

处理两种情况。

```zig
const result = v.fold(
    []const u8,
    struct { fn f(_: i32) []const u8 { return "valid"; } }.f,
    struct { fn f(_: []const []const u8) []const u8 { return "invalid"; } }.f
);
```

## 批量验证

### validateAll

验证多个值，累积所有错误。

```zig
const validations = [_]fp.Validation(i32, []const u8){
    fp.valid(i32, []const u8, 1),
    fp.invalid(i32, []const u8, "error1"),
    fp.invalid(i32, []const u8, "error2"),
};

const result = try fp.validateAll(i32, []const u8, &validations, allocator);

if (result.isInvalid()) {
    const errors = result.getErrors().?;
    // errors = ["error1", "error2"]
}
```

## 内置验证器

### 字符串验证

```zig
// 非空验证
const v1 = fp.notEmpty("hello");  // valid
const v2 = fp.notEmpty("");       // invalid(.Empty)

// 最小长度验证
const minLen3 = fp.minLengthValidator(3);
const v3 = minLen3("hi");    // invalid(.TooShort)
const v4 = minLen3("hello"); // valid
```

### 数字验证

```zig
// 正数验证
const positiveI32 = fp.validation.positive(i32);
const v1 = positiveI32(5);   // valid
const v2 = positiveI32(-5);  // invalid(.NotPositive)
const v3 = positiveI32(0);   // invalid(.NotPositive)

// 非零验证
const nonZeroI32 = fp.validation.nonZero(i32);
const v4 = nonZeroI32(5);    // valid
const v5 = nonZeroI32(0);    // invalid(.Zero)
```

## 实际示例

### 表单验证

```zig
const FormError = enum {
    NameEmpty,
    NameTooShort,
    AgeTooYoung,
    EmailInvalid,
};

fn validateForm(
    name: []const u8,
    age: i32,
    email: []const u8,
    allocator: Allocator,
) !fp.Validation(FormData, FormError) {
    const nameValidation = if (name.len == 0)
        fp.invalid([]const u8, FormError, .NameEmpty)
    else if (name.len < 2)
        fp.invalid([]const u8, FormError, .NameTooShort)
    else
        fp.valid([]const u8, FormError, name);

    const ageValidation = if (age < 18)
        fp.invalid(i32, FormError, .AgeTooYoung)
    else
        fp.valid(i32, FormError, age);

    const emailValidation = if (!isValidEmail(email))
        fp.invalid([]const u8, FormError, .EmailInvalid)
    else
        fp.valid([]const u8, FormError, email);

    // 收集所有验证结果
    const validations = [_]fp.Validation(anytype, FormError){
        nameValidation,
        ageValidation,
        emailValidation,
    };

    // ... 组合验证结果
}
```

### 配置验证

```zig
fn validateConfig(config: Config) fp.Validation(Config, ConfigError) {
    var errors = std.ArrayList(ConfigError).init(allocator);

    if (config.port < 1024) {
        try errors.append(.PortTooLow);
    }
    if (config.timeout == 0) {
        try errors.append(.TimeoutZero);
    }
    if (config.maxConnections < 1) {
        try errors.append(.InvalidMaxConnections);
    }

    if (errors.items.len > 0) {
        return fp.invalidMany(Config, ConfigError, errors.items);
    }
    return fp.valid(Config, ConfigError, config);
}
```

## 与 Result 对比

| 特性 | Result | Validation |
|------|--------|------------|
| 错误处理 | 快速失败 | 累积错误 |
| 错误类型 | 单个 E | []const E |
| 适用场景 | 串行操作 | 并行验证 |
| flatMap | 有 | 无（使用 combine） |
| Monad | 是 | 否（Applicative） |

## 数学法则

Validation 是 Applicative Functor，满足：

```
// Identity
pure id <*> v = v

// Composition
pure (.) <*> u <*> v <*> w = u <*> (v <*> w)

// Homomorphism
pure f <*> pure x = pure (f x)

// Interchange
u <*> pure y = pure ($ y) <*> u
```

## 源码

`src/validation.zig`
