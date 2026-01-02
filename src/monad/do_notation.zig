//! Do-Notation 构建器
//!
//! 由于 Zig 不支持 Haskell 风格的 do-notation，
//! 本模块提供构建器模式来模拟 monadic 组合。
//!
//! ## 示例
//!
//! ```zig
//! // Haskell:
//! // do
//! //   x <- Just 1
//! //   y <- Just 2
//! //   pure (x + y)
//!
//! // zigFP:
//! const result = DoOption(i32)
//!     .start(Option(i32).Some(1))
//!     .andThen(struct {
//!         fn f(x: i32) Option(i32) {
//!             return Option(i32).Some(x + 2);
//!         }
//!     }.f)
//!     .run();
//! ```

const std = @import("std");
const Option = @import("../core/option.zig").Option;
const Result = @import("../core/result.zig").Result;

// ============ Option Do-Notation ============

/// Option Monad 的 Do-notation 构建器
pub fn DoOption(comptime T: type) type {
    return struct {
        value: Option(T),

        const Self = @This();

        /// 开始一个 Do 块
        pub fn start(opt: Option(T)) Self {
            return .{ .value = opt };
        }

        /// 从值开始
        pub fn pure(val: T) Self {
            return .{ .value = Option(T).Some(val) };
        }

        /// bind (>>=) - 绑定并转换
        pub fn andThen(self: Self, comptime U: type, f: *const fn (T) Option(U)) DoOption(U) {
            return .{
                .value = switch (self.value) {
                    .some => |v| f(v),
                    .none => Option(U).None(),
                },
            };
        }

        /// map (<$>) - 映射值
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) DoOption(U) {
            return .{
                .value = switch (self.value) {
                    .some => |v| Option(U).Some(f(v)),
                    .none => Option(U).None(),
                },
            };
        }

        /// then (>>) - 执行但忽略前一个值
        pub fn then(self: Self, comptime U: type, next: Option(U)) DoOption(U) {
            return .{
                .value = switch (self.value) {
                    .some => next,
                    .none => Option(U).None(),
                },
            };
        }

        /// guard - 条件检查，失败返回 None
        pub fn guard(self: Self, predicate: *const fn (T) bool) Self {
            return .{
                .value = switch (self.value) {
                    .some => |v| if (predicate(v)) self.value else Option(T).None(),
                    .none => Option(T).None(),
                },
            };
        }

        /// filter - guard 的别名
        pub fn filter(self: Self, predicate: *const fn (T) bool) Self {
            return self.guard(predicate);
        }

        /// 获取最终结果
        pub fn run(self: Self) Option(T) {
            return self.value;
        }

        /// 解包或返回默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self.value) {
                .some => |v| v,
                .none => default,
            };
        }

        /// 检查是否有值
        pub fn isSome(self: Self) bool {
            return self.value == .some;
        }

        /// 检查是否为空
        pub fn isNone(self: Self) bool {
            return self.value == .none;
        }
    };
}

// ============ Result Do-Notation ============

/// Result Monad 的 Do-notation 构建器
pub fn DoResult(comptime T: type, comptime E: type) type {
    return struct {
        value: Result(T, E),

        const Self = @This();

        /// 开始一个 Do 块
        pub fn start(res: Result(T, E)) Self {
            return .{ .value = res };
        }

        /// 从值开始
        pub fn pure(val: T) Self {
            return .{ .value = Result(T, E).Ok(val) };
        }

        /// 从错误开始
        pub fn fail(err: E) Self {
            return .{ .value = Result(T, E).Err(err) };
        }

        /// bind (>>=) - 绑定并转换
        pub fn andThen(self: Self, comptime U: type, f: *const fn (T) Result(U, E)) DoResult(U, E) {
            return .{
                .value = switch (self.value) {
                    .ok => |v| f(v),
                    .err => |e| Result(U, E).Err(e),
                },
            };
        }

        /// map (<$>) - 映射值
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) DoResult(U, E) {
            return .{
                .value = switch (self.value) {
                    .ok => |v| Result(U, E).Ok(f(v)),
                    .err => |e| Result(U, E).Err(e),
                },
            };
        }

        /// mapErr - 映射错误
        pub fn mapErr(self: Self, comptime F: type, f: *const fn (E) F) DoResult(T, F) {
            return .{
                .value = switch (self.value) {
                    .ok => |v| Result(T, F).Ok(v),
                    .err => |e| Result(T, F).Err(f(e)),
                },
            };
        }

        /// then (>>) - 执行但忽略前一个值
        pub fn then(self: Self, comptime U: type, next: Result(U, E)) DoResult(U, E) {
            return .{
                .value = switch (self.value) {
                    .ok => next,
                    .err => |e| Result(U, E).Err(e),
                },
            };
        }

        /// guard - 条件检查，失败返回错误
        pub fn guard(self: Self, predicate: *const fn (T) bool, err: E) Self {
            return .{
                .value = switch (self.value) {
                    .ok => |v| if (predicate(v)) self.value else Result(T, E).Err(err),
                    .err => self.value,
                },
            };
        }

        /// ensure - 确保条件成立
        pub fn ensure(self: Self, predicate: *const fn (T) bool, err: E) Self {
            return self.guard(predicate, err);
        }

        /// 获取最终结果
        pub fn run(self: Self) Result(T, E) {
            return self.value;
        }

        /// 解包或返回默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self.value) {
                .ok => |v| v,
                .err => default,
            };
        }

        /// 检查是否成功
        pub fn isOk(self: Self) bool {
            return self.value == .ok;
        }

        /// 检查是否失败
        pub fn isErr(self: Self) bool {
            return self.value == .err;
        }
    };
}

// ============ Sequence Do - 用于列表推导 ============

/// 列表推导风格的 Do-notation
/// 类似 Haskell 的 list comprehension
pub fn DoList(comptime T: type) type {
    return struct {
        items: []const T,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// 从切片开始
        pub fn from(allocator: std.mem.Allocator, items: []const T) Self {
            return .{ .items = items, .allocator = allocator };
        }

        /// 从范围开始
        pub fn range(allocator: std.mem.Allocator, start: T, end: T) !Self {
            if (@typeInfo(T) != .int) {
                @compileError("range only works with integer types");
            }
            if (end <= start) {
                return Self{ .items = &[_]T{}, .allocator = allocator };
            }

            const len: usize = @intCast(end - start);
            const items = try allocator.alloc(T, len);
            for (0..len) |i| {
                items[i] = start + @as(T, @intCast(i));
            }
            return Self{ .items = items, .allocator = allocator };
        }

        /// flatMap / concatMap
        pub fn flatMap(self: Self, comptime U: type, f: *const fn (std.mem.Allocator, T) anyerror![]U) !DoList(U) {
            var result = try std.ArrayList(U).initCapacity(self.allocator, self.items.len);
            errdefer result.deinit(self.allocator);

            for (self.items) |item| {
                const mapped = try f(self.allocator, item);
                defer self.allocator.free(mapped);
                try result.appendSlice(self.allocator, mapped);
            }

            return DoList(U){
                .items = try result.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }

        /// map
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) !DoList(U) {
            const items = try self.allocator.alloc(U, self.items.len);
            for (self.items, 0..) |item, i| {
                items[i] = f(item);
            }
            return DoList(U){ .items = items, .allocator = self.allocator };
        }

        /// filter
        pub fn filter(self: Self, predicate: *const fn (T) bool) !Self {
            var result = try std.ArrayList(T).initCapacity(self.allocator, self.items.len);
            errdefer result.deinit(self.allocator);

            for (self.items) |item| {
                if (predicate(item)) {
                    try result.append(self.allocator, item);
                }
            }

            return Self{
                .items = try result.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }

        /// 获取结果
        pub fn run(self: Self) []const T {
            return self.items;
        }

        /// 释放内存
        pub fn deinit(self: Self) void {
            if (self.items.len > 0) {
                self.allocator.free(self.items);
            }
        }
    };
}

// ============ 辅助函数 ============

/// 创建 Option Do 块
pub fn doOption(comptime T: type, opt: Option(T)) DoOption(T) {
    return DoOption(T).start(opt);
}

/// 创建 Result Do 块
pub fn doResult(comptime T: type, comptime E: type, res: Result(T, E)) DoResult(T, E) {
    return DoResult(T, E).start(res);
}

/// 创建纯值 Option Do 块
pub fn pureOption(comptime T: type, val: T) DoOption(T) {
    return DoOption(T).pure(val);
}

/// 创建纯值 Result Do 块
pub fn pureResult(comptime T: type, comptime E: type, val: T) DoResult(T, E) {
    return DoResult(T, E).pure(val);
}

// ============ 测试 ============

test "DoOption.start and run" {
    const result = DoOption(i32).start(Option(i32).Some(42)).run();
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoOption.pure" {
    const result = DoOption(i32).pure(42).run();
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoOption.andThen" {
    const result = DoOption(i32)
        .pure(10)
        .andThen(i32, struct {
            fn f(x: i32) Option(i32) {
                return Option(i32).Some(x * 2);
            }
        }.f)
        .andThen(i32, struct {
            fn f(x: i32) Option(i32) {
                return Option(i32).Some(x + 1);
            }
        }.f)
        .run();

    try std.testing.expectEqual(@as(i32, 21), result.unwrap());
}

test "DoOption.andThen with None" {
    const result = DoOption(i32)
        .pure(10)
        .andThen(i32, struct {
            fn f(_: i32) Option(i32) {
                return Option(i32).None();
            }
        }.f)
        .andThen(i32, struct {
            fn f(x: i32) Option(i32) {
                return Option(i32).Some(x + 100); // 不会执行
            }
        }.f)
        .run();

    try std.testing.expect(result.isNone());
}

test "DoOption.map" {
    const result = DoOption(i32)
        .pure(21)
        .map(i32, struct {
            fn f(x: i32) i32 {
                return x * 2;
            }
        }.f)
        .run();

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoOption.then" {
    const result = DoOption(i32)
        .pure(100)
        .then(i32, Option(i32).Some(42))
        .run();

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoOption.guard success" {
    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const result = DoOption(i32)
        .pure(42)
        .guard(isPositive)
        .run();

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoOption.guard failure" {
    const isNegative = struct {
        fn f(x: i32) bool {
            return x < 0;
        }
    }.f;

    const result = DoOption(i32)
        .pure(42)
        .guard(isNegative)
        .run();

    try std.testing.expect(result.isNone());
}

test "DoOption.unwrapOr" {
    const some_result = DoOption(i32).pure(42).unwrapOr(0);
    try std.testing.expectEqual(@as(i32, 42), some_result);

    const none_result = DoOption(i32).start(Option(i32).None()).unwrapOr(0);
    try std.testing.expectEqual(@as(i32, 0), none_result);
}

test "DoResult.start and run" {
    const TestError = error{TestError};
    const result = DoResult(i32, TestError).start(Result(i32, TestError).Ok(42)).run();
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoResult.pure" {
    const TestError = error{TestError};
    const result = DoResult(i32, TestError).pure(42).run();
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoResult.fail" {
    const TestError = error{TestError};
    const result = DoResult(i32, TestError).fail(TestError.TestError).run();
    try std.testing.expect(result.isErr());
}

test "DoResult.andThen" {
    const TestError = error{DivByZero};

    const safeDivide = struct {
        fn f(x: i32) Result(i32, TestError) {
            if (x == 0) return Result(i32, TestError).Err(TestError.DivByZero);
            return Result(i32, TestError).Ok(@divTrunc(100, x));
        }
    }.f;

    const success = DoResult(i32, TestError)
        .pure(10)
        .andThen(i32, safeDivide)
        .run();

    try std.testing.expectEqual(@as(i32, 10), success.unwrap());

    const failure = DoResult(i32, TestError)
        .pure(0)
        .andThen(i32, safeDivide)
        .run();

    try std.testing.expect(failure.isErr());
}

test "DoResult.map" {
    const TestError = error{TestError};

    const result = DoResult(i32, TestError)
        .pure(21)
        .map(i32, struct {
            fn f(x: i32) i32 {
                return x * 2;
            }
        }.f)
        .run();

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoResult.guard success" {
    const TestError = error{NotPositive};

    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const result = DoResult(i32, TestError)
        .pure(42)
        .guard(isPositive, TestError.NotPositive)
        .run();

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoResult.guard failure" {
    const TestError = error{NotPositive};

    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const result = DoResult(i32, TestError)
        .pure(-5)
        .guard(isPositive, TestError.NotPositive)
        .run();

    try std.testing.expect(result.isErr());
    try std.testing.expectEqual(TestError.NotPositive, result.unwrapErr());
}

test "doOption helper" {
    const result = doOption(i32, Option(i32).Some(42))
        .map(i32, struct {
            fn f(x: i32) i32 {
                return x + 1;
            }
        }.f)
        .run();

    try std.testing.expectEqual(@as(i32, 43), result.unwrap());
}

test "pureOption helper" {
    const result = pureOption(i32, 42).run();
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "DoList.from and map" {
    const allocator = std.testing.allocator;

    const list = DoList(i32).from(allocator, &[_]i32{ 1, 2, 3 });

    const doubled = try list.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer doubled.deinit();

    const result = doubled.run();
    try std.testing.expectEqualSlices(i32, &[_]i32{ 2, 4, 6 }, result);
}

test "DoList.filter" {
    const allocator = std.testing.allocator;

    const list = DoList(i32).from(allocator, &[_]i32{ 1, 2, 3, 4, 5 });

    const evens = try list.filter(struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f);
    defer evens.deinit();

    const result = evens.run();
    try std.testing.expectEqualSlices(i32, &[_]i32{ 2, 4 }, result);
}

test "complex do-notation chain" {
    // 模拟复杂的 monadic 计算链
    const TestError = error{InvalidInput};

    const validate = struct {
        fn f(x: i32) Result(i32, TestError) {
            if (x < 0) return Result(i32, TestError).Err(TestError.InvalidInput);
            return Result(i32, TestError).Ok(x);
        }
    }.f;

    const double = struct {
        fn f(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x * 2);
        }
    }.f;

    const addTen = struct {
        fn f(x: i32) Result(i32, TestError) {
            return Result(i32, TestError).Ok(x + 10);
        }
    }.f;

    // 成功路径
    const success = DoResult(i32, TestError)
        .pure(5)
        .andThen(i32, validate)
        .andThen(i32, double)
        .andThen(i32, addTen)
        .run();

    try std.testing.expectEqual(@as(i32, 20), success.unwrap());

    // 失败路径
    const failure = DoResult(i32, TestError)
        .pure(-5)
        .andThen(i32, validate)
        .andThen(i32, double)
        .andThen(i32, addTen)
        .run();

    try std.testing.expect(failure.isErr());
}
