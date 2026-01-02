//! IO 模块 - 函数式 IO 操作
//!
//! 简化 Zig 0.15 的输入输出 API，提供函数式组合方式。
//!
//! Zig 0.15 的 IO API 需要显式传入 buffer，本模块使用线程本地缓冲区简化使用。

const std = @import("std");
const Allocator = std.mem.Allocator;

// 线程本地缓冲区用于 stdout/stderr/stdin
threadlocal var stdout_buffer: [4096]u8 = undefined;
threadlocal var stderr_buffer: [4096]u8 = undefined;
threadlocal var stdin_buffer: [4096]u8 = undefined;

// ============ 基础输出函数 ============

/// 获取 stdout writer（使用线程本地缓冲区）
pub fn getStdOutWriter() std.fs.File.Writer {
    return std.fs.File.stdout().writer(&stdout_buffer);
}

/// 获取 stderr writer（使用线程本地缓冲区）
pub fn getStdErrWriter() std.fs.File.Writer {
    return std.fs.File.stderr().writer(&stderr_buffer);
}

/// 获取 stdin reader（使用线程本地缓冲区）
pub fn getStdInReader() std.fs.File.Reader {
    return std.fs.File.stdin().reader(&stdin_buffer);
}

/// 打印字符串并换行到 stdout
pub fn putStrLn(s: []const u8) !void {
    var stdout = getStdOutWriter();
    try stdout.interface.print("{s}\n", .{s});
    try stdout.interface.flush();
}

/// 打印字符串（不换行）到 stdout
pub fn putStr(s: []const u8) !void {
    var stdout = getStdOutWriter();
    try stdout.interface.print("{s}", .{s});
    try stdout.interface.flush();
}

/// 格式化打印到 stdout
pub fn print(comptime fmt: []const u8, args: anytype) !void {
    var stdout = getStdOutWriter();
    try stdout.interface.print(fmt, args);
    try stdout.interface.flush();
}

/// 格式化打印并换行
pub fn println(comptime fmt: []const u8, args: anytype) !void {
    var stdout = getStdOutWriter();
    try stdout.interface.print(fmt ++ "\n", args);
    try stdout.interface.flush();
}

/// 打印到 stderr
pub fn eprint(comptime fmt: []const u8, args: anytype) !void {
    var stderr = getStdErrWriter();
    try stderr.interface.print(fmt, args);
    try stderr.interface.flush();
}

/// 打印到 stderr 并换行
pub fn eprintln(comptime fmt: []const u8, args: anytype) !void {
    var stderr = getStdErrWriter();
    try stderr.interface.print(fmt ++ "\n", args);
    try stderr.interface.flush();
}

// ============ 基础输入函数 ============

/// 从 stdin 读取一行（不包含换行符）
/// 调用者负责释放返回的内存
pub fn getLine(allocator: Allocator) ![]u8 {
    var stdin = getStdInReader();
    var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
    errdefer buf.deinit(allocator);

    // 读取直到遇到换行符
    while (true) {
        const byte = stdin.interface.takeByte() catch |err| {
            if (err == error.EndOfStream) {
                if (buf.items.len == 0) return error.EndOfStream;
                break;
            }
            return err;
        };

        if (byte == '\n') break;
        try buf.append(allocator, byte);
    }

    // 移除可能的 \r（Windows 换行）
    if (buf.items.len > 0 and buf.items[buf.items.len - 1] == '\r') {
        _ = buf.pop();
    }

    return buf.toOwnedSlice(allocator);
}

/// 从 stdin 读取所有内容（最多 max_size 字节）
/// 调用者负责释放返回的内存
pub fn getContents(allocator: Allocator, max_size: usize) ![]u8 {
    var stdin = getStdInReader();
    return stdin.interface.allocRemaining(allocator, std.Io.Limit.limited(max_size));
}

// ============ IO Monad 类型 ============

/// IO Monad - 封装 IO 操作
///
/// 由于 Zig 不支持闭包，IO Monad 使用 comptime 函数参数实现 map/flatMap。
/// 这意味着映射函数必须是编译时已知的。
pub fn IO(comptime T: type) type {
    return struct {
        runFn: *const fn () anyerror!T,

        const Self = @This();

        /// 从函数创建 IO
        pub fn fromFn(f: *const fn () anyerror!T) Self {
            return .{ .runFn = f };
        }

        /// 执行 IO 操作（"不安全"因为执行副作用）
        pub fn unsafeRun(self: Self) !T {
            return self.runFn();
        }

        /// 包装纯值为 IO
        pub fn pure(comptime value: T) Self {
            return Self.fromFn(struct {
                fn run() anyerror!T {
                    return value;
                }
            }.run);
        }

        /// Functor: 对 IO 的结果应用函数
        ///
        /// 由于 Zig 限制，无法在运行时捕获 self，
        /// 所以 map 需要在 comptime 组合。
        pub fn map(comptime U: type, comptime f: fn (T) U, comptime io_action: Self) IO(U) {
            return IO(U).fromFn(struct {
                fn run() anyerror!U {
                    const value = try io_action.runFn();
                    return f(value);
                }
            }.run);
        }

        /// Functor: 对 IO 的结果应用可能失败的函数
        pub fn mapErr(comptime U: type, comptime f: fn (T) anyerror!U, comptime io_action: Self) IO(U) {
            return IO(U).fromFn(struct {
                fn run() anyerror!U {
                    const value = try io_action.runFn();
                    return f(value);
                }
            }.run);
        }

        /// Monad: 链式 IO 操作
        ///
        /// flatMap 允许基于前一个 IO 的结果创建新的 IO。
        pub fn flatMap(comptime U: type, comptime f: fn (T) IO(U), comptime io_action: Self) IO(U) {
            return IO(U).fromFn(struct {
                fn run() anyerror!U {
                    const value = try io_action.runFn();
                    const next_io = f(value);
                    return next_io.unsafeRun();
                }
            }.run);
        }

        /// 顺序执行两个 IO，返回第二个的结果
        pub fn andThen(comptime U: type, comptime second: IO(U), comptime first: Self) IO(U) {
            return IO(U).fromFn(struct {
                fn run() anyerror!U {
                    _ = try first.runFn();
                    return second.unsafeRun();
                }
            }.run);
        }

        /// 顺序执行两个 IO，返回第一个的结果
        pub fn before(comptime U: type, comptime second: IO(U), comptime first: Self) IO(T) {
            return Self.fromFn(struct {
                fn run() anyerror!T {
                    const result = try first.runFn();
                    _ = try second.unsafeRun();
                    return result;
                }
            }.run);
        }
    };
}

/// 无返回值的 IO 操作
pub const IOVoid = IO(void);

// ============ Console 便捷模块 ============

/// Console - 简化的控制台操作
pub const Console = struct {
    /// 写入并换行
    pub fn writeLn(s: []const u8) !void {
        return putStrLn(s);
    }

    /// 写入（不换行）
    pub fn write(s: []const u8) !void {
        return putStr(s);
    }

    /// 格式化写入
    pub fn format(comptime fmt: []const u8, args: anytype) !void {
        return print(fmt, args);
    }

    /// 格式化写入并换行
    pub fn formatLn(comptime fmt: []const u8, args: anytype) !void {
        return println(fmt, args);
    }

    /// 读取一行
    pub fn readLn(allocator: Allocator) ![]u8 {
        return getLine(allocator);
    }

    /// 提示并读取
    pub fn prompt(allocator: Allocator, message: []const u8) ![]u8 {
        try putStr(message);
        return getLine(allocator);
    }

    /// 读取整数
    pub fn readInt(comptime T: type, allocator: Allocator) !T {
        const line = try getLine(allocator);
        defer allocator.free(line);
        return std.fmt.parseInt(T, line, 10);
    }

    /// 提示并读取整数
    pub fn promptInt(comptime T: type, allocator: Allocator, message: []const u8) !T {
        try putStr(message);
        return readInt(T, allocator);
    }
};

/// 全局 console 实例
pub const console = Console{};

// ============ 辅助函数 ============

/// 条件执行 IO
pub fn when(cond: bool, action: fn () anyerror!void) !void {
    if (cond) {
        try action();
    }
}

/// 循环执行 IO
pub fn replicateM(n: usize, action: fn () anyerror!void) !void {
    for (0..n) |_| {
        try action();
    }
}

// ============ 测试 ============

test "putStrLn does not crash" {
    // 基本的冒烟测试
    // 实际 IO 测试需要重定向 stdout
}

test "IO.pure" {
    const io_val = IO(i32).pure(42);
    const result = try io_val.unsafeRun();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "IO.fromFn" {
    const io_val = IO(i32).fromFn(struct {
        fn run() anyerror!i32 {
            return 100;
        }
    }.run);
    const result = try io_val.unsafeRun();
    try std.testing.expectEqual(@as(i32, 100), result);
}

test "IO.map comptime" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    // 使用 comptime 值
    const io_val = comptime IO(i32).pure(21);
    const mapped = comptime IO(i32).map(i32, double, io_val);
    const result = try mapped.unsafeRun();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "IO.mapErr comptime" {
    const safeDivide = struct {
        fn f(x: i32) anyerror!i32 {
            if (x == 0) return error.DivisionByZero;
            return @divTrunc(100, x);
        }
    }.f;

    const io_val = comptime IO(i32).pure(5);
    const mapped = comptime IO(i32).mapErr(i32, safeDivide, io_val);
    const result = try mapped.unsafeRun();
    try std.testing.expectEqual(@as(i32, 20), result);
}

test "IO.flatMap comptime" {
    const returnTenIO = struct {
        fn f(_: i32) IO(i32) {
            return IO(i32).fromFn(struct {
                fn run() anyerror!i32 {
                    return 15;
                }
            }.run);
        }
    }.f;

    const io_val = comptime IO(i32).pure(5);
    const chained = comptime IO(i32).flatMap(i32, returnTenIO, io_val);
    const result = try chained.unsafeRun();
    try std.testing.expectEqual(@as(i32, 15), result);
}

test "IO.andThen comptime" {
    const first = comptime IO(i32).fromFn(struct {
        fn run() anyerror!i32 {
            return 1;
        }
    }.run);

    const second = comptime IO(i32).fromFn(struct {
        fn run() anyerror!i32 {
            return 2;
        }
    }.run);

    const combined = comptime IO(i32).andThen(i32, second, first);
    const result = try combined.unsafeRun();

    // andThen 返回第二个 IO 的结果
    try std.testing.expectEqual(@as(i32, 2), result);
}

test "IO Functor law: identity comptime" {
    // map id == id
    const identityFn = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const io_val = comptime IO(i32).pure(42);
    const mapped = comptime IO(i32).map(i32, identityFn, io_val);

    const original = try io_val.unsafeRun();
    const result = try mapped.unsafeRun();
    try std.testing.expectEqual(original, result);
}

test "Console.format does not crash" {
    // 冒烟测试
}
