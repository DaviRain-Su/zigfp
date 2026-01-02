//! Option 类型 - 安全空值处理
//!
//! `Option(T)` 表示一个值要么存在（`some`），要么不存在（`none`）。
//! 类似 Haskell 的 `Maybe`、Rust 的 `Option`。

const std = @import("std");

/// Option 类型 - 表示可能存在或不存在的值
pub fn Option(comptime T: type) type {
    return union(enum) {
        some: T,
        none,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建包含值的 Option
        pub fn Some(value: T) Self {
            return .{ .some = value };
        }

        /// 创建空的 Option
        pub fn None() Self {
            return .none;
        }

        /// 从 Zig 原生可选类型转换
        pub fn fromNullable(value: ?T) Self {
            return if (value) |v| Self.Some(v) else Self.None();
        }

        // ============ 检查方法 ============

        /// 检查是否有值
        pub fn isSome(self: Self) bool {
            return self == .some;
        }

        /// 检查是否为空
        pub fn isNone(self: Self) bool {
            return self == .none;
        }

        // ============ 解包方法 ============

        /// 获取内部值，如果是 none 则 panic
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .some => |v| v,
                .none => @panic("called `Option.unwrap()` on a `none` value"),
            };
        }

        /// 获取内部值，如果是 none 则返回默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .some => |v| v,
                .none => default,
            };
        }

        /// 获取内部值，如果是 none 则调用函数获取默认值
        pub fn unwrapOrElse(self: Self, f: *const fn () T) T {
            return switch (self) {
                .some => |v| v,
                .none => f(),
            };
        }

        // ============ Functor 操作 ============

        /// 对内部值应用函数，返回新的 Option
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Option(U) {
            return switch (self) {
                .some => |v| Option(U).Some(f(v)),
                .none => Option(U).None(),
            };
        }

        // ============ Monad 操作 ============

        /// 对内部值应用返回 Option 的函数，扁平化结果
        pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) Option(U)) Option(U) {
            return switch (self) {
                .some => |v| f(v),
                .none => Option(U).None(),
            };
        }

        // ============ 过滤 ============

        /// 如果满足条件则保留值，否则返回 none
        pub fn filter(self: Self, predicate: *const fn (T) bool) Self {
            return switch (self) {
                .some => |v| if (predicate(v)) self else Self.None(),
                .none => Self.None(),
            };
        }

        // ============ 组合操作 ============

        /// 组合两个 Option，都有值时返回元组
        pub fn zip(self: Self, comptime U: type, other: Option(U)) Option(struct { T, U }) {
            const Tuple = struct { T, U };
            return switch (self) {
                .some => |a| switch (other) {
                    .some => |b| Option(Tuple).Some(.{ a, b }),
                    .none => Option(Tuple).None(),
                },
                .none => Option(Tuple).None(),
            };
        }

        /// 如果 self 是 none，返回 other
        pub fn @"or"(self: Self, other: Self) Self {
            return switch (self) {
                .some => self,
                .none => other,
            };
        }

        /// 如果 self 是 none，调用函数获取替代值
        pub fn orElse(self: Self, f: *const fn () Self) Self {
            return switch (self) {
                .some => self,
                .none => f(),
            };
        }

        // ============ 转换方法 ============

        /// 转换为 Zig 原生可选类型
        pub fn toNullable(self: Self) ?T {
            return switch (self) {
                .some => |v| v,
                .none => null,
            };
        }

        /// 转换为 Result，none 变为指定的错误
        pub fn okOr(self: Self, comptime E: type, err: E) @import("result.zig").Result(T, E) {
            const Result = @import("result.zig").Result;
            return switch (self) {
                .some => |v| Result(T, E).Ok(v),
                .none => Result(T, E).Err(err),
            };
        }
    };
}

/// 便捷函数：创建 some 值
pub fn some(comptime T: type, value: T) Option(T) {
    return Option(T).Some(value);
}

/// 便捷函数：创建 none 值
pub fn none(comptime T: type) Option(T) {
    return Option(T).None();
}

// ============ 测试 ============

test "Option.Some and Option.None" {
    const opt = Option(i32).Some(42);
    try std.testing.expect(opt.isSome());
    try std.testing.expect(!opt.isNone());

    const empty = Option(i32).None();
    try std.testing.expect(!empty.isSome());
    try std.testing.expect(empty.isNone());
}

test "Option.fromNullable" {
    const value: ?i32 = 42;
    const opt = Option(i32).fromNullable(value);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    const empty: ?i32 = null;
    const optEmpty = Option(i32).fromNullable(empty);
    try std.testing.expect(optEmpty.isNone());
}

test "Option.unwrap" {
    const opt = Option(i32).Some(42);
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());
}

test "Option.unwrapOr" {
    const opt = Option(i32).Some(42);
    try std.testing.expectEqual(@as(i32, 42), opt.unwrapOr(0));

    const empty = Option(i32).None();
    try std.testing.expectEqual(@as(i32, 0), empty.unwrapOr(0));
}

test "Option.unwrapOrElse" {
    const getDefault = struct {
        fn f() i32 {
            return 100;
        }
    }.f;

    const opt = Option(i32).Some(42);
    try std.testing.expectEqual(@as(i32, 42), opt.unwrapOrElse(getDefault));

    const empty = Option(i32).None();
    try std.testing.expectEqual(@as(i32, 100), empty.unwrapOrElse(getDefault));
}

test "Option.map" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const opt = Option(i32).Some(21);
    const doubled = opt.map(i32, double);
    try std.testing.expectEqual(@as(i32, 42), doubled.unwrap());

    const empty = Option(i32).None();
    const emptyDoubled = empty.map(i32, double);
    try std.testing.expect(emptyDoubled.isNone());
}

test "Option.flatMap" {
    const safeDiv = struct {
        fn f(x: i32) Option(i32) {
            if (x == 0) return Option(i32).None();
            return Option(i32).Some(@divTrunc(100, x));
        }
    }.f;

    const opt = Option(i32).Some(10);
    const result = opt.flatMap(i32, safeDiv);
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());

    const zero = Option(i32).Some(0);
    const zeroResult = zero.flatMap(i32, safeDiv);
    try std.testing.expect(zeroResult.isNone());

    const empty = Option(i32).None();
    const emptyResult = empty.flatMap(i32, safeDiv);
    try std.testing.expect(emptyResult.isNone());
}

test "Option.filter" {
    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const positive = Option(i32).Some(42);
    try std.testing.expect(positive.filter(isPositive).isSome());

    const negative = Option(i32).Some(-1);
    try std.testing.expect(negative.filter(isPositive).isNone());

    const empty = Option(i32).None();
    try std.testing.expect(empty.filter(isPositive).isNone());
}

test "Option.zip" {
    const opt1 = Option(i32).Some(1);
    const opt2 = Option(i32).Some(2);
    const zipped = opt1.zip(i32, opt2);
    try std.testing.expect(zipped.isSome());
    const tuple = zipped.unwrap();
    try std.testing.expectEqual(@as(i32, 1), tuple[0]);
    try std.testing.expectEqual(@as(i32, 2), tuple[1]);

    const empty = Option(i32).None();
    const zippedEmpty = opt1.zip(i32, empty);
    try std.testing.expect(zippedEmpty.isNone());
}

test "Option.or" {
    const opt1 = Option(i32).Some(1);
    const opt2 = Option(i32).Some(2);
    try std.testing.expectEqual(@as(i32, 1), opt1.@"or"(opt2).unwrap());

    const empty = Option(i32).None();
    try std.testing.expectEqual(@as(i32, 2), empty.@"or"(opt2).unwrap());
}

test "Option.toNullable" {
    const opt = Option(i32).Some(42);
    const nullable: ?i32 = opt.toNullable();
    try std.testing.expectEqual(@as(?i32, 42), nullable);

    const empty = Option(i32).None();
    const emptyNullable: ?i32 = empty.toNullable();
    try std.testing.expectEqual(@as(?i32, null), emptyNullable);
}

test "convenience functions" {
    const opt = some(i32, 42);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    const empty = none(i32);
    try std.testing.expect(empty.isNone());
}

// ============ Functor 法则测试 ============

test "Functor identity law" {
    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const opt = Option(i32).Some(42);
    try std.testing.expectEqual(opt.unwrap(), opt.map(i32, id).unwrap());

    const empty = Option(i32).None();
    try std.testing.expect(empty.map(i32, id).isNone());
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

    const opt = Option(i32).Some(5);
    // map(f . g) == map(g) . map(f) 注意顺序
    try std.testing.expectEqual(
        opt.map(i32, g).map(i32, f).unwrap(),
        opt.map(i32, fg).unwrap(),
    );
}

// ============ Monad 法则测试 ============

test "Monad left identity law" {
    const f = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f;

    const a: i32 = 21;
    const lhs = Option(i32).Some(a).flatMap(i32, f);
    const rhs = f(a);
    try std.testing.expectEqual(lhs.unwrap(), rhs.unwrap());
}

test "Monad right identity law" {
    const pure = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x);
        }
    }.f;

    const opt = Option(i32).Some(42);
    try std.testing.expectEqual(opt.unwrap(), opt.flatMap(i32, pure).unwrap());
}

test "Monad associativity law" {
    const f = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x + 1);
        }
    }.f;
    const g = struct {
        fn g(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.g;

    const opt = Option(i32).Some(5);

    // (opt >>= f) >>= g
    const lhs = opt.flatMap(i32, f).flatMap(i32, g);

    // opt >>= (\x -> f(x) >>= g)
    const fg = struct {
        fn fg(x: i32) Option(i32) {
            return f(x).flatMap(i32, g);
        }
    }.fg;
    const rhs = opt.flatMap(i32, fg);

    try std.testing.expectEqual(lhs.unwrap(), rhs.unwrap());
}
