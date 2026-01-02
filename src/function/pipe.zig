//! Pipe 管道 - 链式操作
//!
//! `Pipe(T)` 提供流畅的 API 进行链式数据处理。

const std = @import("std");

/// Pipe 类型 - 管道操作
pub fn Pipe(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建管道
        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        // ============ 转换操作 ============

        /// 应用函数并继续管道
        pub fn then(self: Self, comptime U: type, f: *const fn (T) U) Pipe(U) {
            return Pipe(U).init(f(self.value));
        }

        /// 执行副作用函数，不改变值
        pub fn tap(self: Self, f: *const fn (T) void) Self {
            f(self.value);
            return self;
        }

        /// 条件为真时应用函数
        pub fn when(self: Self, cond: bool, f: *const fn (T) T) Self {
            return if (cond) Self.init(f(self.value)) else self;
        }

        /// 条件为假时应用函数
        pub fn unless(self: Self, cond: bool, f: *const fn (T) T) Self {
            return if (!cond) Self.init(f(self.value)) else self;
        }

        // ============ 获取结果 ============

        /// 获取管道中的最终值
        pub fn unwrap(self: Self) T {
            return self.value;
        }

        /// 别名：获取值
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// 便捷函数：创建管道
pub fn pipe(comptime T: type, value: T) Pipe(T) {
    return Pipe(T).init(value);
}

// ============ 测试 ============

test "Pipe.init and unwrap" {
    const p = Pipe(i32).init(42);
    try std.testing.expectEqual(@as(i32, 42), p.unwrap());
}

test "Pipe.then" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .then(i32, double) // 10
        .then(i32, addOne) // 11
        .unwrap();

    try std.testing.expectEqual(@as(i32, 11), result);
}

test "Pipe.then with type conversion" {
    const intToFloat = struct {
        fn f(x: i32) f64 {
            return @floatFromInt(x);
        }
    }.f;

    const doubleFloat = struct {
        fn f(x: f64) f64 {
            return x * 2.0;
        }
    }.f;

    const result = Pipe(i32).init(21)
        .then(f64, intToFloat)
        .then(f64, doubleFloat)
        .unwrap();

    try std.testing.expectEqual(@as(f64, 42.0), result);
}

test "Pipe.tap" {
    const logValue = struct {
        fn f(x: i32) void {
            _ = x;
            // 模拟副作用
        }
    }.f;

    const result = Pipe(i32).init(42)
        .tap(logValue)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "Pipe.when true" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(true, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 10), result);
}

test "Pipe.when false" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(false, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 5), result);
}

test "Pipe.unless" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result1 = Pipe(i32).init(5)
        .unless(false, double)
        .unwrap();
    try std.testing.expectEqual(@as(i32, 10), result1);

    const result2 = Pipe(i32).init(5)
        .unless(true, double)
        .unwrap();
    try std.testing.expectEqual(@as(i32, 5), result2);
}

test "Pipe complex chain" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const shouldDouble = true;
    const shouldTriple = false;

    const triple = struct {
        fn f(x: i32) i32 {
            return x * 3;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(shouldDouble, double) // 10
        .when(shouldTriple, triple) // 仍是 10
        .then(i32, addOne) // 11
        .unwrap();

    try std.testing.expectEqual(@as(i32, 11), result);
}

test "pipe convenience function" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = pipe(i32, 21)
        .then(i32, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 42), result);
}
