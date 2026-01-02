//! Result 类型 - 错误处理
//!
//! `Result(T, E)` 表示一个操作要么成功（`ok`），要么失败（`err`）。
//! 类似 Haskell 的 `Either`、Rust 的 `Result`。

const std = @import("std");
const option = @import("option.zig");

/// Result 类型 - 表示成功或失败
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建成功值
        pub fn Ok(value: T) Self {
            return .{ .ok = value };
        }

        /// 创建错误值
        pub fn Err(e: E) Self {
            return .{ .err = e };
        }

        // ============ 检查方法 ============

        /// 检查是否成功
        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        /// 检查是否失败
        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        // ============ 解包方法 ============

        /// 获取成功值，如果是 err 则 panic
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => @panic("called `Result.unwrap()` on an `err` value"),
            };
        }

        /// 获取成功值，如果是 err 则返回默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                .err => default,
            };
        }

        /// 获取成功值，如果是 err 则调用函数获取默认值
        pub fn unwrapOrElse(self: Self, f: *const fn (E) T) T {
            return switch (self) {
                .ok => |v| v,
                .err => |e| f(e),
            };
        }

        /// 获取错误值，如果是 ok 则 panic
        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .ok => @panic("called `Result.unwrapErr()` on an `ok` value"),
                .err => |e| e,
            };
        }

        // ============ Functor 操作 ============

        /// 对成功值应用函数
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Result(U, E) {
            return switch (self) {
                .ok => |v| Result(U, E).Ok(f(v)),
                .err => |e| Result(U, E).Err(e),
            };
        }

        /// 对错误值应用函数
        pub fn mapErr(self: Self, comptime F: type, f: *const fn (E) F) Result(T, F) {
            return switch (self) {
                .ok => |v| Result(T, F).Ok(v),
                .err => |e| Result(T, F).Err(f(e)),
            };
        }

        // ============ Bifunctor 操作 ============

        /// 同时对成功值和错误值应用函数
        pub fn bimap(
            self: Self,
            comptime U: type,
            comptime F: type,
            okFn: *const fn (T) U,
            errFn: *const fn (E) F,
        ) Result(U, F) {
            return switch (self) {
                .ok => |v| Result(U, F).Ok(okFn(v)),
                .err => |e| Result(U, F).Err(errFn(e)),
            };
        }

        // ============ Monad 操作 ============

        /// 对成功值应用返回 Result 的函数
        pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) Result(U, E)) Result(U, E) {
            return switch (self) {
                .ok => |v| f(v),
                .err => |e| Result(U, E).Err(e),
            };
        }

        // ============ 错误恢复 ============

        /// 如果是 err，尝试恢复
        pub fn orElse(self: Self, f: *const fn (E) Self) Self {
            return switch (self) {
                .ok => self,
                .err => |e| f(e),
            };
        }

        // ============ 转换方法 ============

        /// 转换为 Option，丢弃错误信息
        pub fn toOption(self: Self) option.Option(T) {
            return switch (self) {
                .ok => |v| option.Option(T).Some(v),
                .err => option.Option(T).None(),
            };
        }

        /// 交换 ok 和 err
        pub fn swap(self: Self) Result(E, T) {
            return switch (self) {
                .ok => |v| Result(E, T).Err(v),
                .err => |e| Result(E, T).Ok(e),
            };
        }
    };
}

/// 便捷函数：创建 ok 值
pub fn ok(comptime T: type, comptime E: type, value: T) Result(T, E) {
    return Result(T, E).Ok(value);
}

/// 便捷函数：创建 err 值
pub fn err(comptime T: type, comptime E: type, error_value: E) Result(T, E) {
    return Result(T, E).Err(error_value);
}

// ============ 测试 ============

const TestError = enum {
    NotFound,
    InvalidInput,
    NetworkError,
};

test "Result.Ok and Result.Err" {
    const success = Result(i32, TestError).Ok(42);
    try std.testing.expect(success.isOk());
    try std.testing.expect(!success.isErr());

    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expect(!failure.isOk());
    try std.testing.expect(failure.isErr());
}

test "Result.unwrap" {
    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(@as(i32, 42), success.unwrap());
}

test "Result.unwrapOr" {
    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(@as(i32, 42), success.unwrapOr(0));

    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expectEqual(@as(i32, 0), failure.unwrapOr(0));
}

test "Result.unwrapOrElse" {
    const getDefault = struct {
        fn f(_: TestError) i32 {
            return 100;
        }
    }.f;

    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(@as(i32, 42), success.unwrapOrElse(getDefault));

    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expectEqual(@as(i32, 100), failure.unwrapOrElse(getDefault));
}

test "Result.unwrapErr" {
    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expectEqual(TestError.NotFound, failure.unwrapErr());
}

test "Result.map" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const success = Result(i32, TestError).Ok(21);
    const doubled = success.map(i32, double);
    try std.testing.expectEqual(@as(i32, 42), doubled.unwrap());

    const failure = Result(i32, TestError).Err(.NotFound);
    const failedMap = failure.map(i32, double);
    try std.testing.expect(failedMap.isErr());
    try std.testing.expectEqual(TestError.NotFound, failedMap.unwrapErr());
}

test "Result.mapErr" {
    const enhanceError = struct {
        fn f(e: TestError) []const u8 {
            return switch (e) {
                .NotFound => "Resource not found",
                .InvalidInput => "Invalid input provided",
                .NetworkError => "Network error occurred",
            };
        }
    }.f;

    const failure = Result(i32, TestError).Err(.NotFound);
    const mapped = failure.mapErr([]const u8, enhanceError);
    try std.testing.expect(mapped.isErr());
    try std.testing.expectEqualStrings("Resource not found", mapped.unwrapErr());

    const success = Result(i32, TestError).Ok(42);
    const successMapped = success.mapErr([]const u8, enhanceError);
    try std.testing.expect(successMapped.isOk());
}

test "Result.bimap" {
    const double = struct {
        fn f(x: i32) i64 {
            return @as(i64, x) * 2;
        }
    }.f;
    const errorToString = struct {
        fn f(_: TestError) []const u8 {
            return "error";
        }
    }.f;

    const success = Result(i32, TestError).Ok(21);
    const mapped = success.bimap(i64, []const u8, double, errorToString);
    try std.testing.expectEqual(@as(i64, 42), mapped.unwrap());

    const failure = Result(i32, TestError).Err(.NotFound);
    const mappedErr = failure.bimap(i64, []const u8, double, errorToString);
    try std.testing.expectEqualStrings("error", mappedErr.unwrapErr());
}

test "Result.flatMap" {
    const safeDiv = struct {
        fn f(x: i32) Result(i32, TestError) {
            if (x == 0) return Result(i32, TestError).Err(.InvalidInput);
            return Result(i32, TestError).Ok(@divTrunc(100, x));
        }
    }.f;

    const success = Result(i32, TestError).Ok(10);
    const result = success.flatMap(i32, safeDiv);
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());

    const zero = Result(i32, TestError).Ok(0);
    const zeroResult = zero.flatMap(i32, safeDiv);
    try std.testing.expect(zeroResult.isErr());

    const failure = Result(i32, TestError).Err(.NotFound);
    const failResult = failure.flatMap(i32, safeDiv);
    try std.testing.expect(failResult.isErr());
    try std.testing.expectEqual(TestError.NotFound, failResult.unwrapErr());
}

test "Result.orElse" {
    const recover = struct {
        fn f(_: TestError) Result(i32, TestError) {
            return Result(i32, TestError).Ok(0);
        }
    }.f;

    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(@as(i32, 42), success.orElse(recover).unwrap());

    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expectEqual(@as(i32, 0), failure.orElse(recover).unwrap());
}

test "Result.toOption" {
    const success = Result(i32, TestError).Ok(42);
    const opt = success.toOption();
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    const failure = Result(i32, TestError).Err(.NotFound);
    const optFail = failure.toOption();
    try std.testing.expect(optFail.isNone());
}

test "Result.swap" {
    const success = Result(i32, TestError).Ok(42);
    const swapped = success.swap();
    try std.testing.expect(swapped.isErr());

    const failure = Result(i32, TestError).Err(.NotFound);
    const swappedFail = failure.swap();
    try std.testing.expect(swappedFail.isOk());
}

test "convenience functions" {
    const success = ok(i32, TestError, 42);
    try std.testing.expect(success.isOk());
    try std.testing.expectEqual(@as(i32, 42), success.unwrap());

    const failure = err(i32, TestError, .NotFound);
    try std.testing.expect(failure.isErr());
    try std.testing.expectEqual(TestError.NotFound, failure.unwrapErr());
}

// ============ Functor 法则测试 ============

test "Functor identity law" {
    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(success.unwrap(), success.map(i32, id).unwrap());

    const failure = Result(i32, TestError).Err(.NotFound);
    try std.testing.expect(failure.map(i32, id).isErr());
}

test "Functor composition law" {
    const f = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;
    const g = struct {
        fn g(x: i32) i32 {
            return x + 1;
        }
    }.g;
    const fg = struct {
        fn fg(x: i32) i32 {
            return f(g(x));
        }
    }.fg;

    const success = Result(i32, TestError).Ok(5);
    try std.testing.expectEqual(
        success.map(i32, g).map(i32, f).unwrap(),
        success.map(i32, fg).unwrap(),
    );
}

// ============ Monad 法则测试 ============

test "Monad left identity law" {
    const f = struct {
        fn f(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x * 2);
        }
    }.f;

    const a: i32 = 21;
    const lhs = Result(i32, TestError).Ok(a).flatMap(i32, f);
    const rhs = f(a);
    try std.testing.expectEqual(lhs.unwrap(), rhs.unwrap());
}

test "Monad right identity law" {
    const pure = struct {
        fn f(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x);
        }
    }.f;

    const success = Result(i32, TestError).Ok(42);
    try std.testing.expectEqual(success.unwrap(), success.flatMap(i32, pure).unwrap());
}

test "Monad associativity law" {
    const f = struct {
        fn f(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x + 1);
        }
    }.f;
    const g = struct {
        fn g(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x * 2);
        }
    }.g;

    const success = Result(i32, TestError).Ok(5);

    const lhs = success.flatMap(i32, f).flatMap(i32, g);

    const fg = struct {
        fn fg(x: i32) Result(i32, TestError) {
            return f(x).flatMap(i32, g);
        }
    }.fg;
    const rhs = success.flatMap(i32, fg);

    try std.testing.expectEqual(lhs.unwrap(), rhs.unwrap());
}
