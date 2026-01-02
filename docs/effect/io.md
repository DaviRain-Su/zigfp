# IO Monad

> 函数式 IO 操作，简化 Zig 的输入输出

## 概述

`IO(T)` 封装了 IO 操作，提供函数式的组合方式。
它简化了 Zig 0.15 繁琐的 buffered writer API，同时保持类型安全。

## 动机

Zig 0.15 的标准输出很繁琐：

```zig
// Zig 0.15 原生方式
var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
try stdout.print("Hello {s}!\n", .{name});
try stdout.flush();
```

使用 zigFP IO：

```zig
// 函数式方式
const io = @import("zigfp").io;

try io.putStrLn("Hello World!");
try io.print("Value: {d}\n", .{42});

// 链式操作
try io.pure("Hello")
    .flatMap(greet)
    .flatMap(io.putStrLn)
    .run();
```

## API

### 基础输出

```zig
/// 打印字符串并换行
pub fn putStrLn(s: []const u8) !void

/// 打印字符串（不换行）
pub fn putStr(s: []const u8) !void

/// 格式化打印
pub fn print(comptime fmt: []const u8, args: anytype) !void

/// 打印并换行
pub fn println(comptime fmt: []const u8, args: anytype) !void
```

### 基础输入

```zig
/// 读取一行（不包含换行符）
pub fn getLine(allocator: Allocator) ![]u8

/// 读取所有输入
pub fn getContents(allocator: Allocator) ![]u8
```

### IO Monad 类型

```zig
pub fn IO(comptime T: type) type {
    return struct {
        run: *const fn () !T,

        /// 执行 IO 操作
        pub fn unsafeRun(self: Self) !T;

        /// Functor: 映射结果
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) IO(U);

        /// Monad: 链式 IO
        pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) IO(U)) IO(U);

        /// 包装纯值
        pub fn pure(value: T) IO(T);
    };
}
```

### 组合操作

```zig
/// 顺序执行，返回第二个结果
pub fn andThen(comptime A: type, comptime B: type, first: IO(A), second: IO(B)) IO(B);

/// 顺序执行，返回第一个结果
pub fn before(comptime A: type, comptime B: type, first: IO(A), second: IO(B)) IO(A);

/// 重复执行 n 次
pub fn replicateM(comptime T: type, n: usize, action: IO(T)) IO(void);

/// 条件执行
pub fn when(cond: bool, action: IO(void)) IO(void);

/// 遍历列表执行 IO
pub fn traverse(comptime T: type, comptime U: type, items: []const T, f: *const fn (T) IO(U)) IO(void);
```

## 使用示例

### 简单输出

```zig
const io = @import("zigfp").io;

pub fn main() !void {
    try io.putStrLn("Hello, World!");
    try io.println("The answer is {d}", .{42});
}
```

### 读取输入

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try io.putStr("Enter your name: ");
    const name = try io.getLine(allocator);
    defer allocator.free(name);

    try io.println("Hello, {s}!", .{name});
}
```

### IO Monad 组合

```zig
// 定义 IO 操作
fn askName() IO([]const u8) {
    return IO([]const u8).fromFn(struct {
        fn run() ![]const u8 {
            try io.putStr("Name: ");
            return io.getLine(allocator);
        }
    }.run);
}

fn greet(name: []const u8) IO(void) {
    return IO(void).fromFn(struct {
        fn run() !void {
            try io.println("Hello, {s}!", .{name});
        }
    }.run);
}

// 组合执行
pub fn main() !void {
    try askName()
        .flatMap(void, greet)
        .unsafeRun();
}
```

### 与 Result 结合

```zig
fn readInt() IO(Result(i32, ParseError)) {
    return IO(Result(i32, ParseError)).fromFn(struct {
        fn run() !Result(i32, ParseError) {
            const line = try io.getLine(allocator);
            defer allocator.free(line);
            
            const value = std.fmt.parseInt(i32, line, 10) catch {
                return Result(i32, ParseError).Err(.InvalidFormat);
            };
            return Result(i32, ParseError).Ok(value);
        }
    }.run);
}
```

## Console 便捷模块

```zig
const console = @import("zigfp").console;

// 直接使用，自动管理 buffer
try console.writeLn("Hello!");
try console.write("No newline");
try console.format("Value: {d}\n", .{42});

// 读取
const line = try console.readLn(allocator);
```

## 与 Haskell IO 对比

| Haskell | zigFP |
|---------|-------|
| `putStrLn "Hello"` | `io.putStrLn("Hello")` |
| `print 42` | `io.println("{d}", .{42})` |
| `getLine` | `io.getLine(allocator)` |
| `>>` | `andThen` |
| `>>=` | `flatMap` |
| `pure` / `return` | `IO.pure` |

## 设计考虑

### 为什么需要 allocator？

Zig 没有 GC，读取输入需要分配内存。与 Haskell 不同，我们必须显式管理：

```zig
const line = try io.getLine(allocator);
defer allocator.free(line);  // 必须释放
```

### 错误处理

Zig 使用 `!T` 表示可能失败的操作，而非 `IO (Either Error T)`：

```zig
// Zig 风格
pub fn getLine(allocator: Allocator) ![]u8

// 而非 Haskell 风格
// getLine :: IO (Either IOError String)
```

### 惰性 vs 及时

Haskell 的 IO 是惰性的，只在 `main` 中执行。
zigFP 的 IO 可以选择：

```zig
// 立即执行
try io.putStrLn("Hello");

// 延迟执行（Monad 风格）
const action = IO(void).fromFn(sayHello);
// ... 稍后
try action.unsafeRun();
```

## 源码

`src/io.zig`
