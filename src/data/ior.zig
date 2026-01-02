//! Ior - Inclusive Or with Error Accumulation
//!
//! Ior 是带错误累积的包含性或类型，适用于"警告但继续"的场景。
//! 它类似于 These，但专门设计用于错误/警告累积。
//!
//! 三种状态：
//! - Left: 只有错误（失败）
//! - Right: 只有成功值（完全成功）
//! - Both: 错误和成功值都有（带警告的成功）
//!
//! 与 Result 的区别：Result 是 Either（要么成功要么失败），
//! 而 Ior 允许"部分成功"（有警告但仍有结果）。

const std = @import("std");

/// Ior - Inclusive Or
/// 表示一个值可以是 Left E（错误），Right A（成功），或 Both E A（警告+成功）
pub fn Ior(comptime E: type, comptime A: type) type {
    return union(enum) {
        const Self = @This();

        /// 只有错误
        left: E,
        /// 只有成功值
        right: A,
        /// 错误和成功值都有（警告场景）
        both: struct { e: E, a: A },

        // ============ 构造函数 ============

        /// 创建 Left（只有错误）
        pub fn Left(e: E) Self {
            return .{ .left = e };
        }

        /// 创建 Right（只有成功）
        pub fn Right(a: A) Self {
            return .{ .right = a };
        }

        /// 创建 Both（错误和成功都有）
        pub fn Both(e: E, a: A) Self {
            return .{ .both = .{ .e = e, .a = a } };
        }

        // ============ 类型检查 ============

        /// 是否是 Left
        pub fn isLeft(self: Self) bool {
            return self == .left;
        }

        /// 是否是 Right
        pub fn isRight(self: Self) bool {
            return self == .right;
        }

        /// 是否是 Both
        pub fn isBoth(self: Self) bool {
            return self == .both;
        }

        /// 是否有成功值（Right 或 Both）
        pub fn hasRight(self: Self) bool {
            return self == .right or self == .both;
        }

        /// 是否有错误（Left 或 Both）
        pub fn hasLeft(self: Self) bool {
            return self == .left or self == .both;
        }

        // ============ 访问器 ============

        /// 获取错误值（如果存在）
        pub fn getLeft(self: Self) ?E {
            return switch (self) {
                .left => |e| e,
                .right => null,
                .both => |b| b.e,
            };
        }

        /// 获取成功值（如果存在）
        pub fn getRight(self: Self) ?A {
            return switch (self) {
                .left => null,
                .right => |a| a,
                .both => |b| b.a,
            };
        }

        /// Both 值的类型
        pub const BothValue = struct { e: E, a: A };

        /// 获取 Both 的值对（如果是 Both）
        pub fn getBoth(self: Self) ?BothValue {
            return switch (self) {
                .both => |b| .{ .e = b.e, .a = b.a },
                else => null,
            };
        }

        /// 获取成功值或默认值
        pub fn rightOr(self: Self, default: A) A {
            return self.getRight() orelse default;
        }

        /// 获取错误值或默认值
        pub fn leftOr(self: Self, default: E) E {
            return self.getLeft() orelse default;
        }

        // ============ 映射操作 ============

        /// 映射成功值
        pub fn map(self: Self, comptime B: type, f: fn (A) B) Ior(E, B) {
            return switch (self) {
                .left => |e| Ior(E, B).Left(e),
                .right => |a| Ior(E, B).Right(f(a)),
                .both => |b| Ior(E, B).Both(b.e, f(b.a)),
            };
        }

        /// 映射错误值
        pub fn mapLeft(self: Self, comptime F: type, f: fn (E) F) Ior(F, A) {
            return switch (self) {
                .left => |e| Ior(F, A).Left(f(e)),
                .right => |a| Ior(F, A).Right(a),
                .both => |b| Ior(F, A).Both(f(b.e), b.a),
            };
        }

        /// 双向映射
        pub fn bimap(self: Self, comptime F: type, comptime B: type, fe: fn (E) F, fa: fn (A) B) Ior(F, B) {
            return switch (self) {
                .left => |e| Ior(F, B).Left(fe(e)),
                .right => |a| Ior(F, B).Right(fa(a)),
                .both => |b| Ior(F, B).Both(fe(b.e), fa(b.a)),
            };
        }

        // ============ 折叠操作 ============

        /// 折叠 Ior 为单一值
        pub fn fold(
            self: Self,
            comptime B: type,
            onLeft: fn (E) B,
            onRight: fn (A) B,
            onBoth: fn (E, A) B,
        ) B {
            return switch (self) {
                .left => |e| onLeft(e),
                .right => |a| onRight(a),
                .both => |b| onBoth(b.e, b.a),
            };
        }

        // ============ 类型转换 ============

        /// 转换为 Option（只保留成功值）
        pub fn toOption(self: Self) @import("../core/option.zig").Option(A) {
            const Option = @import("../core/option.zig").Option;
            return switch (self) {
                .left => Option(A).None(),
                .right => |a| Option(A).Some(a),
                .both => |b| Option(A).Some(b.a),
            };
        }

        /// 转换为 Result（丢弃 Both 中的错误）
        pub fn toResult(self: Self) @import("../core/result.zig").Result(A, E) {
            const Result = @import("../core/result.zig").Result;
            return switch (self) {
                .left => |e| Result(A, E).Err(e),
                .right => |a| Result(A, E).Ok(a),
                .both => |b| Result(A, E).Ok(b.a),
            };
        }

        /// 转换为 Result（优先返回错误）
        pub fn toResultStrict(self: Self) @import("../core/result.zig").Result(A, E) {
            const Result = @import("../core/result.zig").Result;
            return switch (self) {
                .left => |e| Result(A, E).Err(e),
                .right => |a| Result(A, E).Ok(a),
                .both => |b| Result(A, E).Err(b.e),
            };
        }

        /// 转换为 These
        pub fn toThese(self: Self) @import("these.zig").These(E, A) {
            const These = @import("these.zig").These;
            return switch (self) {
                .left => |e| These(E, A).This(e),
                .right => |a| These(E, A).That(a),
                .both => |b| These(E, A).Both(b.e, b.a),
            };
        }

        /// 交换 Left 和 Right
        pub fn swap(self: Self) Ior(A, E) {
            return switch (self) {
                .left => |e| Ior(A, E).Right(e),
                .right => |a| Ior(A, E).Left(a),
                .both => |b| Ior(A, E).Both(b.a, b.e),
            };
        }

        // ============ 静态构造函数 ============

        /// 从 Result 创建 Ior
        pub fn fromResult(result: @import("../core/result.zig").Result(A, E)) Self {
            if (result.isOk()) {
                return Self.Right(result.unwrap());
            } else {
                return Self.Left(result.unwrapErr());
            }
        }

        /// 从 These 创建 Ior
        pub fn fromThese(these: @import("these.zig").These(E, A)) Self {
            return switch (these) {
                .this => |e| Self.Left(e),
                .that => |a| Self.Right(a),
                .both => |b| Self.Both(b.a, b.b),
            };
        }

        /// 从两个 Option 创建 Ior
        pub fn fromOptions(optE: ?E, optA: ?A) ?Self {
            if (optE) |e| {
                if (optA) |a| {
                    return Self.Both(e, a);
                } else {
                    return Self.Left(e);
                }
            } else {
                if (optA) |a| {
                    return Self.Right(a);
                } else {
                    return null;
                }
            }
        }
    };
}

/// 创建 Left Ior
pub fn iorLeft(comptime E: type, comptime A: type, e: E) Ior(E, A) {
    return Ior(E, A).Left(e);
}

/// 创建 Right Ior
pub fn iorRight(comptime E: type, comptime A: type, a: A) Ior(E, A) {
    return Ior(E, A).Right(a);
}

/// 创建 Both Ior
pub fn iorBoth(comptime E: type, comptime A: type, e: E, a: A) Ior(E, A) {
    return Ior(E, A).Both(e, a);
}

// ============ 测试 ============

test "Ior constructors" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expect(left.isLeft());
    try std.testing.expect(!left.isRight());
    try std.testing.expect(!left.isBoth());

    const right = IorType.Right(42);
    try std.testing.expect(!right.isLeft());
    try std.testing.expect(right.isRight());
    try std.testing.expect(!right.isBoth());

    const both = IorType.Both("warning", 42);
    try std.testing.expect(!both.isLeft());
    try std.testing.expect(!both.isRight());
    try std.testing.expect(both.isBoth());
}

test "Ior hasRight and hasLeft" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expect(left.hasLeft());
    try std.testing.expect(!left.hasRight());

    const right = IorType.Right(42);
    try std.testing.expect(!right.hasLeft());
    try std.testing.expect(right.hasRight());

    const both = IorType.Both("warning", 42);
    try std.testing.expect(both.hasLeft());
    try std.testing.expect(both.hasRight());
}

test "Ior getters" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expectEqualStrings("error", left.getLeft().?);
    try std.testing.expect(left.getRight() == null);

    const right = IorType.Right(42);
    try std.testing.expect(right.getLeft() == null);
    try std.testing.expectEqual(@as(i32, 42), right.getRight().?);

    const both = IorType.Both("warning", 100);
    try std.testing.expectEqualStrings("warning", both.getLeft().?);
    try std.testing.expectEqual(@as(i32, 100), both.getRight().?);
    const b = both.getBoth().?;
    try std.testing.expectEqualStrings("warning", b.e);
    try std.testing.expectEqual(@as(i32, 100), b.a);
}

test "Ior rightOr and leftOr" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expectEqual(@as(i32, 0), left.rightOr(0));
    try std.testing.expectEqualStrings("error", left.leftOr("default"));

    const right = IorType.Right(42);
    try std.testing.expectEqual(@as(i32, 42), right.rightOr(0));
    try std.testing.expectEqualStrings("default", right.leftOr("default"));
}

test "Ior map" {
    const IorType = Ior([]const u8, i32);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const left = IorType.Left("error");
    const mappedLeft = left.map(i32, double);
    try std.testing.expect(mappedLeft.isLeft());
    try std.testing.expectEqualStrings("error", mappedLeft.getLeft().?);

    const right = IorType.Right(21);
    const mappedRight = right.map(i32, double);
    try std.testing.expect(mappedRight.isRight());
    try std.testing.expectEqual(@as(i32, 42), mappedRight.getRight().?);

    const both = IorType.Both("warning", 10);
    const mappedBoth = both.map(i32, double);
    try std.testing.expect(mappedBoth.isBoth());
    try std.testing.expectEqual(@as(i32, 20), mappedBoth.getRight().?);
    try std.testing.expectEqualStrings("warning", mappedBoth.getLeft().?);
}

test "Ior mapLeft" {
    const IorType = Ior([]const u8, i32);

    const toUpper = struct {
        fn f(s: []const u8) []const u8 {
            _ = s;
            return "ERROR";
        }
    }.f;

    const left = IorType.Left("error");
    const mappedLeft = left.mapLeft([]const u8, toUpper);
    try std.testing.expectEqualStrings("ERROR", mappedLeft.getLeft().?);

    const right = IorType.Right(42);
    const mappedRight = right.mapLeft([]const u8, toUpper);
    try std.testing.expectEqual(@as(i32, 42), mappedRight.getRight().?);

    const both = IorType.Both("warning", 42);
    const mappedBoth = both.mapLeft([]const u8, toUpper);
    try std.testing.expectEqualStrings("ERROR", mappedBoth.getLeft().?);
    try std.testing.expectEqual(@as(i32, 42), mappedBoth.getRight().?);
}

test "Ior bimap" {
    const IorType = Ior(i32, i32);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const triple = struct {
        fn f(x: i32) i32 {
            return x * 3;
        }
    }.f;

    const left = IorType.Left(5);
    const mappedLeft = left.bimap(i32, i32, double, triple);
    try std.testing.expectEqual(@as(i32, 10), mappedLeft.getLeft().?);

    const right = IorType.Right(10);
    const mappedRight = right.bimap(i32, i32, double, triple);
    try std.testing.expectEqual(@as(i32, 30), mappedRight.getRight().?);

    const both = IorType.Both(2, 3);
    const mappedBoth = both.bimap(i32, i32, double, triple);
    try std.testing.expectEqual(@as(i32, 4), mappedBoth.getLeft().?);
    try std.testing.expectEqual(@as(i32, 9), mappedBoth.getRight().?);
}

test "Ior fold" {
    const IorType = Ior([]const u8, i32);

    const onLeft = struct {
        fn f(_: []const u8) []const u8 {
            return "was left";
        }
    }.f;

    const onRight = struct {
        fn f(_: i32) []const u8 {
            return "was right";
        }
    }.f;

    const onBoth = struct {
        fn f(_: []const u8, _: i32) []const u8 {
            return "was both";
        }
    }.f;

    const left = IorType.Left("error");
    try std.testing.expectEqualStrings("was left", left.fold([]const u8, onLeft, onRight, onBoth));

    const right = IorType.Right(42);
    try std.testing.expectEqualStrings("was right", right.fold([]const u8, onLeft, onRight, onBoth));

    const both = IorType.Both("warning", 42);
    try std.testing.expectEqualStrings("was both", both.fold([]const u8, onLeft, onRight, onBoth));
}

test "Ior toOption" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expect(left.toOption().isNone());

    const right = IorType.Right(42);
    try std.testing.expect(right.toOption().isSome());
    try std.testing.expectEqual(@as(i32, 42), right.toOption().unwrap());

    const both = IorType.Both("warning", 100);
    try std.testing.expect(both.toOption().isSome());
    try std.testing.expectEqual(@as(i32, 100), both.toOption().unwrap());
}

test "Ior toResult" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    try std.testing.expect(left.toResult().isErr());

    const right = IorType.Right(42);
    try std.testing.expect(right.toResult().isOk());
    try std.testing.expectEqual(@as(i32, 42), right.toResult().unwrap());

    // Both -> Ok (lenient)
    const both = IorType.Both("warning", 100);
    try std.testing.expect(both.toResult().isOk());
    try std.testing.expectEqual(@as(i32, 100), both.toResult().unwrap());

    // Both -> Err (strict)
    try std.testing.expect(both.toResultStrict().isErr());
}

test "Ior swap" {
    const IorType = Ior([]const u8, i32);

    const left = IorType.Left("error");
    const swappedLeft = left.swap();
    try std.testing.expect(swappedLeft.isRight());

    const right = IorType.Right(42);
    const swappedRight = right.swap();
    try std.testing.expect(swappedRight.isLeft());

    const both = IorType.Both("warning", 42);
    const swappedBoth = both.swap();
    try std.testing.expect(swappedBoth.isBoth());
    try std.testing.expectEqual(@as(i32, 42), swappedBoth.getLeft().?);
}

test "Ior fromResult" {
    const Result = @import("../core/result.zig").Result;
    const IorType = Ior([]const u8, i32);

    const okResult = Result(i32, []const u8).Ok(42);
    const fromOk = IorType.fromResult(okResult);
    try std.testing.expect(fromOk.isRight());
    try std.testing.expectEqual(@as(i32, 42), fromOk.getRight().?);

    const errResult = Result(i32, []const u8).Err("error");
    const fromErr = IorType.fromResult(errResult);
    try std.testing.expect(fromErr.isLeft());
    try std.testing.expectEqualStrings("error", fromErr.getLeft().?);
}

test "Ior fromOptions" {
    const IorType = Ior([]const u8, i32);

    // Both options present -> Both
    const both = IorType.fromOptions("warning", 42);
    try std.testing.expect(both != null);
    try std.testing.expect(both.?.isBoth());

    // Only error -> Left
    const left = IorType.fromOptions("error", null);
    try std.testing.expect(left != null);
    try std.testing.expect(left.?.isLeft());

    // Only value -> Right
    const right = IorType.fromOptions(null, 42);
    try std.testing.expect(right != null);
    try std.testing.expect(right.?.isRight());

    // Neither -> null
    const neither = IorType.fromOptions(null, null);
    try std.testing.expect(neither == null);
}

test "Ior convenience constructors" {
    const left = iorLeft([]const u8, i32, "error");
    try std.testing.expect(left.isLeft());

    const right = iorRight([]const u8, i32, 42);
    try std.testing.expect(right.isRight());

    const both = iorBoth([]const u8, i32, "warning", 42);
    try std.testing.expect(both.isBoth());
}
