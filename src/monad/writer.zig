//! Writer Monad - 日志累积
//!
//! `Writer(W, T)` 表示一个产生值 T 并同时累积日志 W 的计算。
//! 常用于日志记录、审计追踪等场景。

const std = @import("std");
const monoid = @import("../algebra/monoid.zig");

/// Writer Monad - 日志累积
pub fn Writer(comptime W: type, comptime T: type) type {
    return struct {
        /// 计算结果值
        value: T,
        /// 累积的日志
        log: W,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建 Writer
        pub fn init(value: T, log: W) Self {
            return .{ .value = value, .log = log };
        }

        /// 包装值，使用空日志
        pub fn pure(value: T, emptyLog: W) Self {
            return .{ .value = value, .log = emptyLog };
        }

        // ============ 获取结果 ============

        /// 获取值和日志
        pub fn run(self: Self) struct { T, W } {
            return .{ self.value, self.log };
        }

        /// 只获取值
        pub fn execValue(self: Self) T {
            return self.value;
        }

        /// 只获取日志
        pub fn execLog(self: Self) W {
            return self.log;
        }

        // ============ Functor 操作 ============

        /// 对值应用函数，保留日志
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Writer(W, U) {
            return Writer(W, U).init(f(self.value), self.log);
        }

        // ============ Writer 特有操作 ============

        /// 追加日志
        pub fn tell(self: Self, additionalLog: W, combine: *const fn (W, W) W) Self {
            return Self.init(self.value, combine(self.log, additionalLog));
        }

        /// 修改日志
        pub fn censor(self: Self, f: *const fn (W) W) Self {
            return Self.init(self.value, f(self.log));
        }

        /// 同时获取值和修改结果
        pub fn listen(self: Self) Writer(W, struct { T, W }) {
            return Writer(W, struct { T, W }).init(
                .{ self.value, self.log },
                self.log,
            );
        }
    };
}

/// 只记录日志，无返回值
pub fn tell(comptime W: type, log: W) Writer(W, void) {
    return Writer(W, void).init({}, log);
}

// ============ 测试 ============

test "Writer.init and run" {
    const writer = Writer(i32, []const u8).init("hello", 42);
    const result = writer.run();

    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqual(@as(i32, 42), result[1]);
}

test "Writer.pure" {
    const writer = Writer(i32, []const u8).pure("value", 0);

    try std.testing.expectEqualStrings("value", writer.value);
    try std.testing.expectEqual(@as(i32, 0), writer.log);
}

test "Writer.map" {
    const writer = Writer(i32, i32).init(21, 100);

    const doubled = writer.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), doubled.value);
    try std.testing.expectEqual(@as(i32, 100), doubled.log); // 日志保持不变
}

test "Writer.tell" {
    const writer = Writer(i32, i32).init(42, 10);

    const combine = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const withMore = writer.tell(5, combine);

    try std.testing.expectEqual(@as(i32, 42), withMore.value); // 值不变
    try std.testing.expectEqual(@as(i32, 15), withMore.log); // 日志累加
}

test "Writer.censor" {
    const writer = Writer(i32, i32).init(42, 100);

    const halved = writer.censor(struct {
        fn f(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), halved.value);
    try std.testing.expectEqual(@as(i32, 50), halved.log);
}

test "Writer.listen" {
    const writer = Writer(i32, []const u8).init("hello", 42);
    const listened = writer.listen();

    const innerResult = listened.value;
    try std.testing.expectEqualStrings("hello", innerResult[0]);
    try std.testing.expectEqual(@as(i32, 42), innerResult[1]);
}

test "Writer.execValue and execLog" {
    const writer = Writer(i32, []const u8).init("hello", 42);

    try std.testing.expectEqualStrings("hello", writer.execValue());
    try std.testing.expectEqual(@as(i32, 42), writer.execLog());
}

test "tell helper" {
    const writer = tell(i32, 42);

    try std.testing.expectEqual(@as(i32, 42), writer.log);
}

test "Writer chain with Monoid" {
    // 使用 Monoid 进行链式操作
    const combine = monoid.sumMonoidI32.combine;

    var writer = Writer(i32, i32).init(1, 0);
    writer = writer.tell(10, combine);
    writer = writer.tell(20, combine);
    writer = writer.tell(30, combine);

    try std.testing.expectEqual(@as(i32, 1), writer.value);
    try std.testing.expectEqual(@as(i32, 60), writer.log);
}

test "Writer map chain" {
    const writer = Writer(i32, i32).init(5, 0)
        .map(i32, struct {
            fn f(x: i32) i32 {
                return x * 2;
            }
        }.f)
        .map(i32, struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 11), writer.value);
    try std.testing.expectEqual(@as(i32, 0), writer.log);
}
