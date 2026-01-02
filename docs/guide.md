# zigFP 用户指南

> 将函数式编程的核心特性带入 Zig，用函数式风格写高性能代码

## 目录

1. [快速开始](#快速开始)
2. [核心概念](#核心概念)
3. [Option 类型](#option-类型)
4. [Result 类型](#result-类型)
5. [函数组合](#函数组合)
6. [Monad 使用](#monad-使用)
7. [高级抽象](#高级抽象)
8. [效果系统](#效果系统)
9. [最佳实践](#最佳实践)

## 快速开始

### 安装

将 zigFP 添加到你的 `build.zig.zon`：

```zig
.dependencies = .{
    .zigfp = .{
        .url = "https://github.com/your-repo/zigfp/archive/v1.0.0.tar.gz",
        .hash = "...",
    },
},
```

### 基本使用

```zig
const std = @import("std");
const fp = @import("zigfp");

pub fn main() !void {
    // 使用 Option 处理可空值
    const opt = fp.some(i32, 42);
    const doubled = opt.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    
    std.debug.print("Result: {}\n", .{doubled.unwrapOr(0)});
}
```

## 核心概念

### 什么是函数式编程？

函数式编程是一种编程范式，强调：

- **纯函数**: 相同输入总是产生相同输出
- **不可变性**: 数据创建后不被修改
- **组合性**: 小函数组合成大函数
- **类型安全**: 使用类型系统防止错误

### zigFP 的设计目标

1. **零成本抽象**: 所有抽象在编译时展开
2. **类型安全**: 充分利用 Zig 的类型系统
3. **实用性**: 解决真实问题，不只是学术探索
4. **Zig 惯用法**: 遵循 Zig 的设计哲学

## Option 类型

`Option(T)` 表示一个可能存在也可能不存在的值。

### 创建 Option

```zig
const fp = @import("zigfp");

// 创建包含值的 Option
const some_value = fp.some(i32, 42);

// 创建空的 Option
const no_value = fp.none(i32);
```

### 基本操作

```zig
// 检查是否有值
if (opt.isSome()) {
    const value = opt.unwrap();
    // 使用 value...
}

// 提供默认值
const value = opt.unwrapOr(0);

// 映射操作
const doubled = opt.map(i32, double);

// 链式操作
const result = opt.flatMap(i32, safeOperation);
```

### 实际示例

```zig
fn findUser(id: u64) fp.Option(*User) {
    if (users.get(id)) |user| {
        return fp.some(*User, user);
    }
    return fp.none(*User);
}

fn getUserEmail(id: u64) []const u8 {
    return findUser(id)
        .map([]const u8, struct {
            fn getEmail(user: *User) []const u8 {
                return user.email;
            }
        }.getEmail)
        .unwrapOr("unknown@example.com");
}
```

## Result 类型

`Result(T, E)` 表示一个可能成功也可能失败的操作结果。

### 创建 Result

```zig
const fp = @import("zigfp");

const Error = enum { NotFound, InvalidInput };

// 成功结果
const success = fp.ok(i32, Error, 42);

// 失败结果
const failure = fp.err(i32, Error, .NotFound);
```

### 基本操作

```zig
// 检查结果
if (result.isOk()) {
    const value = result.unwrap();
} else {
    const error = result.unwrapErr();
}

// 映射成功值
const doubled = result.map(i32, double);

// 映射错误
const translated = result.mapErr(OtherError, translateError);

// 链式操作
const final = result.flatMap(i32, processValue);
```

### 实际示例

```zig
const ParseError = enum { InvalidFormat, Overflow };

fn parseNumber(input: []const u8) fp.Result(i32, ParseError) {
    const num = std.fmt.parseInt(i32, input, 10) catch |e| {
        return switch (e) {
            error.InvalidCharacter => fp.err(i32, ParseError, .InvalidFormat),
            error.Overflow => fp.err(i32, ParseError, .Overflow),
            else => fp.err(i32, ParseError, .InvalidFormat),
        };
    };
    return fp.ok(i32, ParseError, num);
}
```

## 函数组合

### compose

从右向左组合函数：

```zig
const fp = @import("zigfp");

const double = struct {
    fn f(x: i32) i32 { return x * 2; }
}.f;

const addOne = struct {
    fn f(x: i32) i32 { return x + 1; }
}.f;

// compose(f, g)(x) = f(g(x))
const composed = fp.compose(i32, i32, i32, double, addOne);
// composed(5) = double(addOne(5)) = double(6) = 12
```

### Pipe

从左向右的数据流：

```zig
const result = fp.Pipe(i32).init(5)
    .then(i32, addOne)    // 6
    .then(i32, double)    // 12
    .then(i32, toString)  // "12"
    .unwrap();
```

## Monad 使用

### Reader Monad

用于依赖注入：

```zig
const fp = @import("zigfp");

const Config = struct {
    db_url: []const u8,
    api_key: []const u8,
};

fn getDbUrl() fp.Reader(Config, []const u8) {
    return fp.asks(Config, []const u8, struct {
        fn f(cfg: Config) []const u8 {
            return cfg.db_url;
        }
    }.f);
}

// 运行 Reader
const config = Config{ .db_url = "postgres://...", .api_key = "secret" };
const url = getDbUrl().run(config);
```

### Writer Monad

用于日志累积：

```zig
const fp = @import("zigfp");

fn compute(x: i32) fp.Writer([]const u8, i32) {
    return fp.tell([]const u8, i32, "Computing...", x * 2);
}

const result = compute(5);
// result.value = 10
// result.log = "Computing..."
```

### State Monad

用于状态管理：

```zig
const fp = @import("zigfp");

fn increment() fp.State(i32, i32) {
    return fp.modify(i32, i32, struct {
        fn f(s: i32) fp.StateValue(i32, i32) {
            return .{ .state = s + 1, .value = s };
        }
    }.f);
}

const initial_state = 0;
const result = increment().run(initial_state);
// result.value = 0 (旧状态)
// result.state = 1 (新状态)
```

## 高级抽象

### Lens

不可变数据的更新：

```zig
const fp = @import("zigfp");

const Person = struct {
    name: []const u8,
    age: u32,
};

const ageLens = fp.makeLens(Person, u32, 
    struct { fn f(p: Person) u32 { return p.age; } }.f,
    struct { fn f(p: Person, a: u32) Person { return .{ .name = p.name, .age = a }; } }.f
);

const person = Person{ .name = "Alice", .age = 30 };
const updated = ageLens.set(person, 31);
// updated = Person{ .name = "Alice", .age = 31 }
```

### Validation

累积错误验证：

```zig
const fp = @import("zigfp");

const validator = fp.ValidationPipeline([]const u8, []const u8).init()
    .add(fp.StringValidators.notEmpty("Name is required"))
    .add(fp.StringValidators.minLength(2, "Name too short"));

const result = validator.validate("A");
if (result.isInvalid()) {
    for (result.getErrors()) |err| {
        std.debug.print("Error: {s}\n", .{err});
    }
}
```

## 效果系统

### Effect

代数效果系统：

```zig
const fp = @import("zigfp");

// 定义效果
const MyEffect = struct {
    log: fn ([]const u8) void,
    getConfig: fn ([]const u8) ?[]const u8,
};

// 使用效果
fn program(effects: MyEffect) !void {
    effects.log("Starting...");
    if (effects.getConfig("API_KEY")) |key| {
        effects.log("Found API key");
    }
}
```

## 最佳实践

### 1. 优先使用 Option 而不是 null

```zig
// 不推荐
fn find(id: u64) ?*Item { ... }

// 推荐
fn find(id: u64) fp.Option(*Item) { ... }
```

### 2. 使用 Result 而不是抛出错误

```zig
// 两种方式都可以，根据情况选择
fn parse(input: []const u8) fp.Result(i32, ParseError) { ... }
fn parse(input: []const u8) !i32 { ... }
```

### 3. 组合小函数

```zig
// 不推荐 - 一个大函数
fn processData(data: Data) Result {
    // 100 行代码...
}

// 推荐 - 组合小函数
const processData = fp.Pipe(Data)
    .then(Data, validate)
    .then(Data, transform)
    .then(Result, save);
```

### 4. 利用类型系统

```zig
// 使用新类型防止错误
const UserId = struct { value: u64 };
const OrderId = struct { value: u64 };

fn getUser(id: UserId) fp.Option(*User) { ... }
fn getOrder(id: OrderId) fp.Option(*Order) { ... }
```

## 下一步

- 查看 [API 文档](./api-stability.md)
- 浏览 [示例代码](../examples/)
- 阅读各模块详细文档

## 获取帮助

- [GitHub Issues](https://github.com/your-repo/zigfp/issues)
- [讨论区](https://github.com/your-repo/zigfp/discussions)
