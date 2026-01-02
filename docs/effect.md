# Effect System

Effect System 模块提供代数效果系统，分离效果描述与处理。

## 概述

代数效果是一种强大的抽象，允许以纯函数式的方式描述副作用，然后用不同的处理器解释执行。类似于 Haskell 的 polysemy 或 Scala 的 ZIO。

核心思想：
- **效果是描述，不是实现** - 效果只描述"做什么"，不关心"怎么做"
- **处理器提供语义** - Handler 定义如何解释和执行效果
- **组合性** - 多个效果可以组合使用

## 导入

```zig
const fp = @import("zigfp");
const Effect = fp.Effect;
const EffectTag = fp.EffectTag;
const Handler = fp.Handler;
const ErrorEffect = fp.ErrorEffect;
const LogEffect = fp.LogEffect;
const ReaderEffect = fp.ReaderEffect;
const StateEffect = fp.StateEffect;
```

## 核心类型

### Effect(E, A)

效果类型，`E` 是效果数据类型，`A` 是结果类型。

```zig
pub fn Effect(comptime E: type, comptime A: type) type {
    return union(enum) {
        pure_val: A,      // 纯值
        effect_op: EffectOp,  // 效果操作
    };
}
```

### EffectTag

效果标记，标识不同类型的效果：

```zig
pub const EffectTag = enum {
    Pure,    // 纯计算
    Reader,  // 读取环境
    State,   // 状态操作
    Error,   // 错误处理
    IO,      // IO 操作
    Async,   // 异步操作
    Log,     // 日志
};
```

## 基本用法

### 创建纯值

```zig
const eff = Effect(void, i32).pure(42);

// 检查是否是纯值
if (eff.isPure()) {
    const value = eff.getValue().?;  // 42
}
```

### 创建效果操作

```zig
const eff = Effect([]const u8, i32).perform(.Log, "hello");

// 这是一个效果，不是纯值
if (!eff.isPure()) {
    // 处理效果...
}
```

### Functor 操作

```zig
const eff = Effect(void, i32).pure(21);
const mapped = eff.map(i32, struct {
    fn f(x: i32) i32 {
        return x * 2;
    }
}.f);
// mapped.getValue() = 42
```

### Monad 操作

```zig
const eff = Effect(void, i32).pure(10);
const chained = eff.flatMap(i32, struct {
    fn f(x: i32) Effect(void, i32) {
        return Effect(void, i32).pure(x + 5);
    }
}.f);
// chained.getValue() = 15
```

### 序列操作

```zig
const first = Effect(void, i32).pure(10);
const second = Effect(void, i32).pure(20);
const result = first.andThen(i32, second);
// result.getValue() = 20
```

## 内置效果

### ErrorEffect

错误处理效果：

```zig
const ErrEff = ErrorEffect([]const u8, i32);

// 抛出错误
const eff1 = ErrEff.throw("something went wrong");

// 纯值
const eff2 = ErrEff.Eff.pure(42);

// 运行并处理错误
const result = ErrEff.runError(eff1);
switch (result) {
    .ok => |v| std.debug.print("success: {}\n", .{v}),
    .err => |e| std.debug.print("error: {s}\n", .{e}),
}

// 捕获错误
const caught = ErrEff.catch_(eff1, struct {
    fn handler(e: []const u8) ErrEff.Eff {
        _ = e;
        return ErrEff.Eff.pure(0);  // 返回默认值
    }
}.handler);
```

### LogEffect

日志效果：

```zig
const LogEff = LogEffect(void);

// 记录不同级别的日志
const debug = LogEff.debug("debug message");
const info = LogEff.info("info message");
const warn = LogEff.warn("warning message");
const err = LogEff.err("error message");

// 或使用通用方法
const log = LogEff.log(.Info, "custom message");
```

### ReaderEffect

读取环境效果：

```zig
const Config = struct { dbUrl: []const u8 };
const ReaderEff = ReaderEffect(Config, []const u8);

// 读取环境
const eff = ReaderEff.ask();

// 运行（提供环境）
const config = Config{ .dbUrl = "postgres://localhost" };
const result = ReaderEff.runReader(eff, config);
```

### StateEffect

状态操作效果：

```zig
const StateEff = StateEffect(i32, i32);

// 获取状态
const getEff = StateEff.get();

// 设置状态
const putEff = StateEff.put(100);

// 修改状态
const modifyEff = StateEff.modify(struct {
    fn f(s: i32) i32 {
        return s + 1;
    }
}.f);
```

## 效果处理器

### Handler

处理器接口，定义如何处理效果：

```zig
const handler = Handler(void, i32, i32).init(
    struct {
        fn handle(tag: EffectTag, data: void) i32 {
            _ = tag;
            _ = data;
            return 0;  // 默认值
        }
    }.handle,
    struct {
        fn pure(v: i32) i32 {
            return v * 2;  // 转换纯值
        }
    }.pure,
);

const eff = Effect(void, i32).pure(21);
const result = handler.handle(eff);  // 42
```

### runPure

运行纯效果（无副作用）：

```zig
const eff = Effect(void, i32).pure(42);
const result = runPure(i32, eff);  // 42
```

## 效果组合

### Combined

组合两种效果：

```zig
const Combined12 = Combined(ErrorType, LogType);
```

### EffectList

组合多个效果：

```zig
const Effects = EffectList(&[_]type{ ErrorType, LogType, StateType });
```

## Monad 法则

Effect 满足 Monad 法则：

### 左单位元

```zig
// pure(a).flatMap(f) == f(a)
const a: i32 = 5;
const f = struct {
    fn func(x: i32) Effect(void, i32) {
        return Effect(void, i32).pure(x * 2);
    }
}.func;

const left = Effect(void, i32).pure(a).flatMap(i32, f);
const right = f(a);
// left.getValue() == right.getValue()
```

### 右单位元

```zig
// m.flatMap(pure) == m
const m = Effect(void, i32).pure(42);
const left = m.flatMap(i32, struct {
    fn f(x: i32) Effect(void, i32) {
        return Effect(void, i32).pure(x);
    }
}.f);
// left.getValue() == m.getValue()
```

### 结合律

```zig
// (m.flatMap(f)).flatMap(g) == m.flatMap(x -> f(x).flatMap(g))
```

## 完整示例

### 错误处理示例

```zig
const std = @import("std");
const fp = @import("zigfp");
const ErrorEffect = fp.ErrorEffect;

pub fn main() void {
    const ErrEff = ErrorEffect([]const u8, i32);
    
    // 模拟可能失败的计算
    fn divide(a: i32, b: i32) ErrEff.Eff {
        if (b == 0) {
            return ErrEff.throw("division by zero");
        }
        return ErrEff.Eff.pure(@divTrunc(a, b));
    }
    
    const result = divide(10, 0);
    const output = ErrEff.runError(result);
    
    switch (output) {
        .ok => |v| std.debug.print("Result: {}\n", .{v}),
        .err => |e| std.debug.print("Error: {s}\n", .{e}),
    }
}
```

### 日志效果示例

```zig
const LogEff = LogEffect(void);

// 创建一系列日志操作
const eff1 = LogEff.info("starting process");
const eff2 = LogEff.debug("processing data");
const eff3 = LogEff.info("process complete");

// 这些效果可以被不同的处理器解释：
// - 控制台输出
// - 文件写入
// - 忽略（测试时）
```

## API 参考

### Effect(E, A)

| 方法 | 签名 | 说明 |
|------|------|------|
| `pure` | `fn(A) Effect(E, A)` | 创建纯值 |
| `perform` | `fn(EffectTag, E) Effect(E, A)` | 创建效果操作 |
| `isPure` | `fn(Self) bool` | 是否是纯值 |
| `getValue` | `fn(Self) ?A` | 获取纯值 |
| `map` | `fn(Self, B, fn(A) B) Effect(E, B)` | Functor map |
| `flatMap` | `fn(Self, B, fn(A) Effect(E, B)) Effect(E, B)` | Monad bind |
| `andThen` | `fn(Self, B, Effect(E, B)) Effect(E, B)` | 序列操作 |

### ErrorEffect(E, A)

| 方法 | 签名 | 说明 |
|------|------|------|
| `throw` | `fn(E) Eff` | 抛出错误 |
| `catch_` | `fn(Eff, fn(E) Eff) Eff` | 捕获错误 |
| `runError` | `fn(Eff) union { ok: A, err: E }` | 运行并返回结果 |

### LogEffect(A)

| 方法 | 签名 | 说明 |
|------|------|------|
| `log` | `fn(LogLevel, []const u8) Eff` | 记录日志 |
| `debug` | `fn([]const u8) Eff` | 调试日志 |
| `info` | `fn([]const u8) Eff` | 信息日志 |
| `warn` | `fn([]const u8) Eff` | 警告日志 |
| `err` | `fn([]const u8) Eff` | 错误日志 |

### Handler(E, A, R)

| 方法 | 签名 | 说明 |
|------|------|------|
| `init` | `fn(handleFn, pureFn) Handler` | 创建处理器 |
| `handle` | `fn(Self, Effect(E, A)) R` | 处理效果 |

## 注意事项

1. **Zig 限制**: 由于 Zig 不支持闭包，部分高级特性（如完整的 Free Monad 解释器）需要简化实现
2. **效果组合**: 组合效果时注意类型兼容性
3. **纯值优先**: 尽可能使用纯值，只在必要时使用效果
4. **处理器测试**: 可以用不同的处理器来测试效果代码

## 相关模块

- [Free Monad](free.md) - 另一种效果建模方式
- [Result](result.md) - 简单的错误处理
- [Reader](reader.md) - 依赖注入
- [State](state.md) - 状态管理
