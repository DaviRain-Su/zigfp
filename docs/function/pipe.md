# Pipe 管道

> 链式操作，数据流式处理

## 概述

`Pipe(T)` 提供了一种流畅的 API 来链式处理数据，
类似于 Unix 管道或 Elixir 的 `|>` 操作符。

## 类型定义

```zig
pub fn Pipe(comptime T: type) type {
    return struct {
        value: T,

        pub fn init(v: T) Self { ... }
        pub fn then(self: Self, comptime U: type, f: *const fn (T) U) Pipe(U) { ... }
        pub fn tap(self: Self, f: *const fn (T) void) Self { ... }
        pub fn when(self: Self, cond: bool, f: *const fn (T) T) Self { ... }
        pub fn unwrap(self: Self) T { ... }
    };
}
```

## API

### init - 创建管道

```zig
const pipe = Pipe(i32).init(42);
```

### then - 转换

```zig
/// 应用函数并继续管道
pub fn then(self: Self, comptime U: type, f: *const fn (T) U) Pipe(U)
```

**使用示例**:

```zig
const result = Pipe(i32).init(5)
    .then(i32, double)      // 10
    .then(i32, addOne)      // 11
    .then([]const u8, toString)
    .unwrap();
```

### tap - 副作用

```zig
/// 执行副作用函数，不改变值
pub fn tap(self: Self, f: *const fn (T) void) Self
```

**使用示例**:

```zig
const result = Pipe(i32).init(42)
    .tap(struct {
        fn log(x: i32) void {
            std.debug.print("Value: {}\n", .{x});
        }
    }.log)
    .then(i32, double)
    .unwrap();
```

### when - 条件转换

```zig
/// 条件为真时应用函数
pub fn when(self: Self, cond: bool, f: *const fn (T) T) Self
```

**使用示例**:

```zig
const shouldDouble = true;
const result = Pipe(i32).init(5)
    .when(shouldDouble, double)  // 条件为真，执行 double
    .when(false, triple)          // 条件为假，跳过
    .unwrap();  // 10
```

### unwrap - 获取结果

```zig
/// 获取管道中的最终值
pub fn unwrap(self: Self) T
```

## 完整示例

```zig
const fp = @import("zigfp");

// 数据处理管道
const report = fp.Pipe(RawData).init(rawData)
    .tap(logInput)
    .then(ParsedData, parse)
    .then(ValidatedData, validate)
    .when(needsEnrichment, enrich)
    .then(Report, generateReport)
    .tap(logOutput)
    .unwrap();

// 数值计算管道
const result = fp.Pipe(i32).init(input)
    .then(i32, struct { fn f(x: i32) i32 { return x * 2; } }.f)
    .then(i32, struct { fn f(x: i32) i32 { return x + 10; } }.f)
    .then(f64, struct { fn f(x: i32) f64 { return @as(f64, @floatFromInt(x)) / 3.0; } }.f)
    .unwrap();
```

## 与其他语言对比

```zig
// zigFP
const result = Pipe(i32).init(5)
    .then(i32, double)
    .then(i32, addOne)
    .unwrap();

// Elixir
// 5 |> double() |> add_one()

// F#
// 5 |> double |> addOne

// Haskell
// addOne $ double 5
// 或 5 & double & addOne
```

## 性能

- **零成本**: 编译时展开为直接函数调用
- **无分配**: 栈上值传递

## 源码

`src/pipe.zig`
