//! These - 同时持有两个值的类型
//!
//! `These(A, B)` 可以是：
//! - `This(A)` - 只有 A
//! - `That(B)` - 只有 B
//! - `Both(A, B)` - 同时有 A 和 B
//!
//! 类似 Haskell 的 `These` 类型，用于表示"至少有一个"的情况。
//! 与 Result/Either 不同，These 可以同时持有两个值。
//!
//! ## 用途
//!
//! - 合并操作（保留两边的信息）
//! - 部分成功/部分失败
//! - 同时收集结果和警告
//!
//! ## 示例
//!
//! ```zig
//! const result: These(Warnings, Value) = These(Warnings, Value).both(
//!     .{ "warning1", "warning2" },
//!     computed_value,
//! );
//! ```

const std = @import("std");
const Option = @import("../core/option.zig").Option;
const Result = @import("../core/result.zig").Result;

/// These - 至少有一个值的类型
pub fn These(comptime A: type, comptime B: type) type {
    return union(enum) {
        /// 只有 A
        this: A,
        /// 只有 B
        that: B,
        /// 同时有 A 和 B
        both: struct { a: A, b: B },

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建只有 A 的 These
        pub fn This(a: A) Self {
            return .{ .this = a };
        }

        /// 创建只有 B 的 These
        pub fn That(b: B) Self {
            return .{ .that = b };
        }

        /// 创建同时有 A 和 B 的 These
        pub fn Both(a: A, b: B) Self {
            return .{ .both = .{ .a = a, .b = b } };
        }

        // ============ 类型检查 ============

        /// 检查是否只有 A
        pub fn isThis(self: Self) bool {
            return self == .this;
        }

        /// 检查是否只有 B
        pub fn isThat(self: Self) bool {
            return self == .that;
        }

        /// 检查是否同时有 A 和 B
        pub fn isBoth(self: Self) bool {
            return self == .both;
        }

        // ============ 访问操作 ============

        /// 获取 A（如果存在）
        pub fn getThis(self: Self) Option(A) {
            return switch (self) {
                .this => |a| Option(A).Some(a),
                .that => Option(A).None(),
                .both => |pair| Option(A).Some(pair.a),
            };
        }

        /// 获取 B（如果存在）
        pub fn getThat(self: Self) Option(B) {
            return switch (self) {
                .this => Option(B).None(),
                .that => |b| Option(B).Some(b),
                .both => |pair| Option(B).Some(pair.b),
            };
        }

        /// 获取两个值的结构类型
        pub const BothPair = struct { a: A, b: B };

        /// 获取两个值（如果都存在）
        pub fn getBoth(self: Self) Option(BothPair) {
            return switch (self) {
                .both => |pair| Option(BothPair).Some(.{ .a = pair.a, .b = pair.b }),
                else => Option(BothPair).None(),
            };
        }

        // ============ 转换操作 ============

        /// 从 Result 转换（Ok -> That, Err -> This）
        pub fn fromResult(res: Result(B, A)) Self {
            return switch (res) {
                .ok => |b| Self.That(b),
                .err => |a| Self.This(a),
            };
        }

        /// 转换为 Option 对
        pub fn toOptionPair(self: Self) struct { Option(A), Option(B) } {
            return switch (self) {
                .this => |a| .{ Option(A).Some(a), Option(B).None() },
                .that => |b| .{ Option(A).None(), Option(B).Some(b) },
                .both => |pair| .{ Option(A).Some(pair.a), Option(B).Some(pair.b) },
            };
        }

        // ============ 映射操作 ============

        /// 映射 A
        pub fn mapThis(self: Self, comptime C: type, f: *const fn (A) C) These(C, B) {
            return switch (self) {
                .this => |a| These(C, B).This(f(a)),
                .that => |b| These(C, B).That(b),
                .both => |pair| These(C, B).Both(f(pair.a), pair.b),
            };
        }

        /// 映射 B
        pub fn mapThat(self: Self, comptime C: type, f: *const fn (B) C) These(A, C) {
            return switch (self) {
                .this => |a| These(A, C).This(a),
                .that => |b| These(A, C).That(f(b)),
                .both => |pair| These(A, C).Both(pair.a, f(pair.b)),
            };
        }

        /// 双向映射
        pub fn bimap(
            self: Self,
            comptime C: type,
            comptime D: type,
            f: *const fn (A) C,
            g: *const fn (B) D,
        ) These(C, D) {
            return switch (self) {
                .this => |a| These(C, D).This(f(a)),
                .that => |b| These(C, D).That(g(b)),
                .both => |pair| These(C, D).Both(f(pair.a), g(pair.b)),
            };
        }

        // ============ 折叠操作 ============

        /// 折叠 These 为单一值
        pub fn fold(
            self: Self,
            comptime R: type,
            onThis: *const fn (A) R,
            onThat: *const fn (B) R,
            onBoth: *const fn (A, B) R,
        ) R {
            return switch (self) {
                .this => |a| onThis(a),
                .that => |b| onThat(b),
                .both => |pair| onBoth(pair.a, pair.b),
            };
        }

        /// 使用 Semigroup 合并（A 必须有 combine 方法）
        pub fn mergeWith(
            self: Self,
            combineA: *const fn (A, A) A,
            combineB: *const fn (B, B) B,
            other: Self,
        ) Self {
            return switch (self) {
                .this => |a1| switch (other) {
                    .this => |a2| Self.This(combineA(a1, a2)),
                    .that => |b2| Self.Both(a1, b2),
                    .both => |pair2| Self.Both(combineA(a1, pair2.a), pair2.b),
                },
                .that => |b1| switch (other) {
                    .this => |a2| Self.Both(a2, b1),
                    .that => |b2| Self.That(combineB(b1, b2)),
                    .both => |pair2| Self.Both(pair2.a, combineB(b1, pair2.b)),
                },
                .both => |pair1| switch (other) {
                    .this => |a2| Self.Both(combineA(pair1.a, a2), pair1.b),
                    .that => |b2| Self.Both(pair1.a, combineB(pair1.b, b2)),
                    .both => |pair2| Self.Both(combineA(pair1.a, pair2.a), combineB(pair1.b, pair2.b)),
                },
            };
        }

        /// 将 This 中的值转换为 B，得到 Option(B)
        pub fn justThat(self: Self) Option(B) {
            return switch (self) {
                .this => Option(B).None(),
                .that => |b| Option(B).Some(b),
                .both => |pair| Option(B).Some(pair.b),
            };
        }

        /// 将 That 中的值转换为 A，得到 Option(A)
        pub fn justThis(self: Self) Option(A) {
            return switch (self) {
                .this => |a| Option(A).Some(a),
                .that => Option(A).None(),
                .both => |pair| Option(A).Some(pair.a),
            };
        }

        /// 如果有 B，则提取；否则返回默认值
        pub fn thatOr(self: Self, default: B) B {
            return switch (self) {
                .this => default,
                .that => |b| b,
                .both => |pair| pair.b,
            };
        }

        /// 如果有 A，则提取；否则返回默认值
        pub fn thisOr(self: Self, default: A) A {
            return switch (self) {
                .this => |a| a,
                .that => default,
                .both => |pair| pair.a,
            };
        }

        /// swap - 交换 A 和 B 的位置
        pub fn swap(self: Self) These(B, A) {
            return switch (self) {
                .this => |a| These(B, A).That(a),
                .that => |b| These(B, A).This(b),
                .both => |pair| These(B, A).Both(pair.b, pair.a),
            };
        }
    };
}

// ============ 辅助函数 ============

/// 从两个 Option 创建 These
pub fn fromOptions(comptime A: type, comptime B: type, optA: Option(A), optB: Option(B)) Option(These(A, B)) {
    const hasA = optA.isSome();
    const hasB = optB.isSome();

    if (hasA and hasB) {
        return Option(These(A, B)).Some(These(A, B).Both(optA.unwrap(), optB.unwrap()));
    } else if (hasA) {
        return Option(These(A, B)).Some(These(A, B).This(optA.unwrap()));
    } else if (hasB) {
        return Option(These(A, B)).Some(These(A, B).That(optB.unwrap()));
    } else {
        return Option(These(A, B)).None();
    }
}

// ============ 测试 ============

test "These.This" {
    const t: These(i32, []const u8) = These(i32, []const u8).This(42);
    try std.testing.expect(t.isThis());
    try std.testing.expect(!t.isThat());
    try std.testing.expect(!t.isBoth());
    try std.testing.expectEqual(@as(i32, 42), t.getThis().unwrap());
    try std.testing.expect(t.getThat().isNone());
}

test "These.That" {
    const t: These(i32, []const u8) = These(i32, []const u8).That("hello");
    try std.testing.expect(!t.isThis());
    try std.testing.expect(t.isThat());
    try std.testing.expect(!t.isBoth());
    try std.testing.expect(t.getThis().isNone());
    try std.testing.expectEqualStrings("hello", t.getThat().unwrap());
}

test "These.Both" {
    const t: These(i32, []const u8) = These(i32, []const u8).Both(42, "hello");
    try std.testing.expect(!t.isThis());
    try std.testing.expect(!t.isThat());
    try std.testing.expect(t.isBoth());
    try std.testing.expectEqual(@as(i32, 42), t.getThis().unwrap());
    try std.testing.expectEqualStrings("hello", t.getThat().unwrap());

    const pair = t.getBoth().unwrap();
    try std.testing.expectEqual(@as(i32, 42), pair.a);
    try std.testing.expectEqualStrings("hello", pair.b);
}

test "These.fromResult" {
    const TestError = error{TestError};

    const ok_result = Result(i32, TestError).Ok(42);
    const these_ok = These(TestError, i32).fromResult(ok_result);
    try std.testing.expect(these_ok.isThat());
    try std.testing.expectEqual(@as(i32, 42), these_ok.getThat().unwrap());

    const err_result = Result(i32, TestError).Err(TestError.TestError);
    const these_err = These(TestError, i32).fromResult(err_result);
    try std.testing.expect(these_err.isThis());
}

test "These.toOptionPair" {
    const t: These(i32, []const u8) = These(i32, []const u8).Both(42, "hello");
    const pair = t.toOptionPair();

    try std.testing.expectEqual(@as(i32, 42), pair[0].unwrap());
    try std.testing.expectEqualStrings("hello", pair[1].unwrap());
}

test "These.mapThis" {
    const t: These(i32, []const u8) = These(i32, []const u8).Both(21, "hello");
    const mapped = t.mapThis(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expect(mapped.isBoth());
    try std.testing.expectEqual(@as(i32, 42), mapped.getThis().unwrap());
    try std.testing.expectEqualStrings("hello", mapped.getThat().unwrap());
}

test "These.mapThat" {
    const t: These(i32, i32) = These(i32, i32).That(21);
    const mapped = t.mapThat(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expect(mapped.isThat());
    try std.testing.expectEqual(@as(i32, 42), mapped.getThat().unwrap());
}

test "These.bimap" {
    const t: These(i32, i32) = These(i32, i32).Both(10, 20);
    const mapped = t.bimap(i32, i32, struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expect(mapped.isBoth());
    try std.testing.expectEqual(@as(i32, 11), mapped.getThis().unwrap());
    try std.testing.expectEqual(@as(i32, 40), mapped.getThat().unwrap());
}

test "These.fold" {
    const onThis = struct {
        fn f(a: i32) i32 {
            return a;
        }
    }.f;

    const onThat = struct {
        fn f(b: i32) i32 {
            return b * 10;
        }
    }.f;

    const onBoth = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const t1: These(i32, i32) = These(i32, i32).This(5);
    try std.testing.expectEqual(@as(i32, 5), t1.fold(i32, onThis, onThat, onBoth));

    const t2: These(i32, i32) = These(i32, i32).That(3);
    try std.testing.expectEqual(@as(i32, 30), t2.fold(i32, onThis, onThat, onBoth));

    const t3: These(i32, i32) = These(i32, i32).Both(5, 3);
    try std.testing.expectEqual(@as(i32, 8), t3.fold(i32, onThis, onThat, onBoth));
}

test "These.mergeWith" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    // This + This = This (combined)
    const t1: These(i32, i32) = These(i32, i32).This(1);
    const t2: These(i32, i32) = These(i32, i32).This(2);
    const r1 = t1.mergeWith(add, add, t2);
    try std.testing.expect(r1.isThis());
    try std.testing.expectEqual(@as(i32, 3), r1.getThis().unwrap());

    // This + That = Both
    const t3: These(i32, i32) = These(i32, i32).This(1);
    const t4: These(i32, i32) = These(i32, i32).That(2);
    const r2 = t3.mergeWith(add, add, t4);
    try std.testing.expect(r2.isBoth());
    try std.testing.expectEqual(@as(i32, 1), r2.getThis().unwrap());
    try std.testing.expectEqual(@as(i32, 2), r2.getThat().unwrap());

    // Both + Both = Both (combined)
    const t5: These(i32, i32) = These(i32, i32).Both(1, 10);
    const t6: These(i32, i32) = These(i32, i32).Both(2, 20);
    const r3 = t5.mergeWith(add, add, t6);
    try std.testing.expect(r3.isBoth());
    try std.testing.expectEqual(@as(i32, 3), r3.getThis().unwrap());
    try std.testing.expectEqual(@as(i32, 30), r3.getThat().unwrap());
}

test "These.swap" {
    const t: These(i32, []const u8) = These(i32, []const u8).Both(42, "hello");
    const swapped = t.swap();

    try std.testing.expect(swapped.isBoth());
    try std.testing.expectEqualStrings("hello", swapped.getThis().unwrap());
    try std.testing.expectEqual(@as(i32, 42), swapped.getThat().unwrap());
}

test "These.thisOr and thatOr" {
    const t1: These(i32, i32) = These(i32, i32).This(42);
    try std.testing.expectEqual(@as(i32, 42), t1.thisOr(0));
    try std.testing.expectEqual(@as(i32, 0), t1.thatOr(0));

    const t2: These(i32, i32) = These(i32, i32).That(100);
    try std.testing.expectEqual(@as(i32, 0), t2.thisOr(0));
    try std.testing.expectEqual(@as(i32, 100), t2.thatOr(0));

    const t3: These(i32, i32) = These(i32, i32).Both(42, 100);
    try std.testing.expectEqual(@as(i32, 42), t3.thisOr(0));
    try std.testing.expectEqual(@as(i32, 100), t3.thatOr(0));
}

test "fromOptions" {
    const some_a = Option(i32).Some(42);
    const some_b = Option([]const u8).Some("hello");
    const none_a = Option(i32).None();
    const none_b = Option([]const u8).None();

    // Both Some -> Both
    const both = fromOptions(i32, []const u8, some_a, some_b);
    try std.testing.expect(both.isSome());
    try std.testing.expect(both.unwrap().isBoth());

    // Some, None -> This
    const this_ = fromOptions(i32, []const u8, some_a, none_b);
    try std.testing.expect(this_.isSome());
    try std.testing.expect(this_.unwrap().isThis());

    // None, Some -> That
    const that = fromOptions(i32, []const u8, none_a, some_b);
    try std.testing.expect(that.isSome());
    try std.testing.expect(that.unwrap().isThat());

    // None, None -> None
    const none_ = fromOptions(i32, []const u8, none_a, none_b);
    try std.testing.expect(none_.isNone());
}
