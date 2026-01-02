# Writer Monad

> 日志累积，附加输出

## 概述

`Writer(W, T)` 表示一个产生值 `T` 并同时累积日志/输出 `W` 的计算。
常用于日志记录、审计追踪等需要收集附加信息的场景。

## 类型定义

```zig
pub fn Writer(comptime W: type, comptime T: type) type {
    return struct {
        value: T,
        log: W,

        pub fn run(self: Self) struct { T, W } { ... }
    };
}
```

## 要求

`W` 类型需要是 Monoid（有 `empty` 和 `combine` 操作）。
常见选择：
- `[]const u8` - 字符串日志
- `ArrayList(LogEntry)` - 结构化日志
- `i64` - 数值累积

## API

### init - 创建 Writer

```zig
/// 创建带初始日志的 Writer
pub fn init(value: T, log: W) Writer(W, T)
```

### pure - 包装值

```zig
/// 包装值，使用空日志
pub fn pure(value: T, monoid: Monoid(W)) Writer(W, T)
```

### tell - 记录日志

```zig
/// 只记录日志，值为 void
pub fn tell(log: W) Writer(W, void)
```

### map - Functor

```zig
/// 对值应用函数，保留日志
pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Writer(W, U)
```

### flatMap - Monad

```zig
/// 链式操作，合并日志
pub fn flatMap(
    self: Self,
    comptime U: type,
    f: *const fn (T) Writer(W, U),
    monoid: Monoid(W),
) Writer(W, U)
```

### run - 获取结果

```zig
/// 获取值和累积的日志
pub fn run(self: Self) struct { T, W }
```

## 使用示例

```zig
const fp = @import("zigfp");

// 使用字符串累积日志
const StringWriter = fp.Writer([]const u8, i32);
const stringMonoid = fp.Monoid([]const u8){
    .empty = "",
    .combine = struct {
        fn f(a: []const u8, b: []const u8) []const u8 {
            // 实际实现需要分配内存
            return concat(a, b);
        }
    }.f,
};

fn process(x: i32) StringWriter {
    return StringWriter.init(
        x * 2,
        "Processed value\n",
    );
}

fn validate(x: i32) StringWriter {
    const log = if (x > 0) "Validation passed\n" else "Validation failed\n";
    return StringWriter.init(x, log);
}

// 链式操作，日志自动累积
const computation = StringWriter.pure(42, stringMonoid)
    .flatMap(i32, process, stringMonoid)
    .flatMap(i32, validate, stringMonoid);

const result = computation.run();
// result[0] = 84
// result[1] = "Processed value\nValidation passed\n"
```

## 结构化日志示例

```zig
const LogEntry = struct {
    timestamp: i64,
    level: Level,
    message: []const u8,
};

const Log = ArrayList(LogEntry);

fn logInfo(msg: []const u8) fp.Writer(Log, void) {
    var log = Log.init(allocator);
    log.append(.{
        .timestamp = std.time.timestamp(),
        .level = .Info,
        .message = msg,
    });
    return fp.Writer(Log, void).tell(log);
}

// 使用
const computation = logInfo("Starting process")
    .flatMap(void, struct {
        fn f(_: void) fp.Writer(Log, i32) {
            return fp.Writer(Log, i32).init(42, logInfo("Computed value").log);
        }
    }.f, logMonoid);
```

## Monad 法则

Writer 满足 Monad 法则（需要 W 是 Monoid）：

1. **Left Identity**: `pure(a).flatMap(f) == f(a)`
2. **Right Identity**: `w.flatMap(pure) == w`
3. **Associativity**: `w.flatMap(f).flatMap(g) == w.flatMap(x => f(x).flatMap(g))`

## 与显式日志传递对比

传统方式:
```zig
fn process(x: i32, log: *Log) i32 {
    log.append("Processing...");
    return x * 2;
}
// 每个函数都需要传递 log 指针
```

Writer Monad:
```zig
fn process(x: i32) Writer(Log, i32) {
    return Writer(Log, i32).init(x * 2, makeLog("Processing..."));
}
// 日志通过 flatMap 自动累积
```

## 源码

`src/writer.zig`
