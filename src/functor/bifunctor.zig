//! Bifunctor 模块
//!
//! Bifunctor 是两个类型参数的 Functor。
//! 可以同时对两个类型参数进行 map 操作。
//!
//! 法则：
//! - Identity: bimap(id, id) = id
//! - Composition: bimap(f, g) . bimap(h, i) = bimap(f . h, g . i)
//!
//! 类似于 Haskell 的 Bifunctor 类型类

const std = @import("std");

// ============ Pair Bifunctor ============

/// Pair 类型 - 最简单的 Bifunctor
pub fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(first: A, second: B) Self {
            return .{ .first = first, .second = second };
        }

        // ============ 访问器 ============

        pub fn fst(self: Self) A {
            return self.first;
        }

        pub fn snd(self: Self) B {
            return self.second;
        }

        // ============ Bifunctor 操作 ============

        /// bimap: 同时 map 两个参数
        pub fn bimap(
            self: Self,
            comptime C: type,
            comptime D: type,
            f: *const fn (A) C,
            g: *const fn (B) D,
        ) Pair(C, D) {
            return Pair(C, D).init(f(self.first), g(self.second));
        }

        /// mapFirst: 只 map 第一个参数
        pub fn mapFirst(self: Self, comptime C: type, f: *const fn (A) C) Pair(C, B) {
            return Pair(C, B).init(f(self.first), self.second);
        }

        /// mapSecond: 只 map 第二个参数
        pub fn mapSecond(self: Self, comptime D: type, g: *const fn (B) D) Pair(A, D) {
            return Pair(A, D).init(self.first, g(self.second));
        }

        /// swap: 交换两个元素
        pub fn swap(self: Self) Pair(B, A) {
            return Pair(B, A).init(self.second, self.first);
        }

        /// dup: 复制值到 Pair
        pub fn dup(value: A) Pair(A, A) {
            return Pair(A, A).init(value, value);
        }

        // ============ 组合操作 ============

        /// assocL: 左结合 ((A, B), C) -> (A, (B, C))
        pub fn assocL(comptime C: type, nested: Pair(Self, C)) Pair(A, Pair(B, C)) {
            return Pair(A, Pair(B, C)).init(
                nested.first.first,
                Pair(B, C).init(nested.first.second, nested.second),
            );
        }

        /// assocR: 右结合 (A, (B, C)) -> ((A, B), C)
        pub fn assocR(comptime C: type, nested: Pair(A, Pair(B, C))) Pair(Pair(A, B), C) {
            return Pair(Pair(A, B), C).init(
                Pair(A, B).init(nested.first, nested.second.first),
                nested.second.second,
            );
        }
    };
}

// ============ Either Bifunctor ============

/// Either 类型 - 和类型的 Bifunctor
///
/// ## Either vs Result 的区别
///
/// | 特性 | Either(A, B) | Result(T, E) |
/// |------|--------------|--------------|
/// | 语义 | 两种可能的值 | 成功/失败 |
/// | 偏向性 | 无偏向 | 右偏 (Ok) |
/// | 用途 | Bifunctor/Profunctor 抽象 | 错误处理 |
/// | Left/Err | 表示"另一种可能" | 表示"错误" |
/// | Right/Ok | 表示"另一种可能" | 表示"成功值" |
///
/// ## 何时使用 Either
///
/// - 需要 Bifunctor 操作（bimap, mapLeft, mapRight）
/// - 用于 Profunctor/Choice 抽象
/// - 表示两种等价的可能性（无好坏之分）
///
/// ## 何时使用 Result
///
/// - 错误处理场景
/// - 需要与 Zig 的 try/catch 配合
/// - 明确区分成功和失败
///
pub fn Either(comptime A: type, comptime B: type) type {
    return union(enum) {
        left_val: A,
        right_val: B,

        const Self = @This();

        // ============ 构造器 ============

        pub fn left(value: A) Self {
            return .{ .left_val = value };
        }

        pub fn right(value: B) Self {
            return .{ .right_val = value };
        }

        // ============ 查询 ============

        pub fn isLeft(self: Self) bool {
            return self == .left_val;
        }

        pub fn isRight(self: Self) bool {
            return self == .right_val;
        }

        pub fn getLeft(self: Self) ?A {
            return switch (self) {
                .left_val => |v| v,
                .right_val => null,
            };
        }

        pub fn getRight(self: Self) ?B {
            return switch (self) {
                .left_val => null,
                .right_val => |v| v,
            };
        }

        // ============ Bifunctor 操作 ============

        /// bimap: 同时 map 两个参数
        pub fn bimap(
            self: Self,
            comptime C: type,
            comptime D: type,
            f: *const fn (A) C,
            g: *const fn (B) D,
        ) Either(C, D) {
            return switch (self) {
                .left_val => |a| Either(C, D).left(f(a)),
                .right_val => |b| Either(C, D).right(g(b)),
            };
        }

        /// mapLeft: 只 map 左边
        pub fn mapLeft(self: Self, comptime C: type, f: *const fn (A) C) Either(C, B) {
            return switch (self) {
                .left_val => |a| Either(C, B).left(f(a)),
                .right_val => |b| Either(C, B).right(b),
            };
        }

        /// mapRight: 只 map 右边
        pub fn mapRight(self: Self, comptime D: type, g: *const fn (B) D) Either(A, D) {
            return switch (self) {
                .left_val => |a| Either(A, D).left(a),
                .right_val => |b| Either(A, D).right(g(b)),
            };
        }

        /// swap: 交换 Left 和 Right
        pub fn swap(self: Self) Either(B, A) {
            return switch (self) {
                .left_val => |a| Either(B, A).right(a),
                .right_val => |b| Either(B, A).left(b),
            };
        }

        // ============ 折叠操作 ============

        /// either: 折叠 Either
        pub fn either(
            self: Self,
            comptime C: type,
            onLeft: *const fn (A) C,
            onRight: *const fn (B) C,
        ) C {
            return switch (self) {
                .left_val => |a| onLeft(a),
                .right_val => |b| onRight(b),
            };
        }

        /// fromLeft: 获取左值或默认值
        pub fn fromLeft(self: Self, default: A) A {
            return switch (self) {
                .left_val => |a| a,
                .right_val => default,
            };
        }

        /// fromRight: 获取右值或默认值
        pub fn fromRight(self: Self, default: B) B {
            return switch (self) {
                .left_val => default,
                .right_val => |b| b,
            };
        }

        // ============ Monad 操作（Right-biased） ============

        /// map: Functor（对 Right 操作）
        pub fn map(self: Self, comptime D: type, f: *const fn (B) D) Either(A, D) {
            return self.mapRight(D, f);
        }

        /// flatMap: Monad bind（对 Right 操作）
        pub fn flatMap(self: Self, comptime D: type, f: *const fn (B) Either(A, D)) Either(A, D) {
            return switch (self) {
                .left_val => |a| Either(A, D).left(a),
                .right_val => |b| f(b),
            };
        }
    };
}

// ============ Result Bifunctor ============

/// Result 类型 - 错误处理的 Bifunctor（通常 map 成功值）
pub fn ResultBifunctor(comptime T: type, comptime E: type) type {
    return struct {
        inner: Either(E, T),

        const Self = @This();

        // ============ 构造器 ============

        pub fn ok(value: T) Self {
            return .{ .inner = Either(E, T).right(value) };
        }

        pub fn err(error_val: E) Self {
            return .{ .inner = Either(E, T).left(error_val) };
        }

        // ============ 查询 ============

        pub fn isOk(self: Self) bool {
            return self.inner.isRight();
        }

        pub fn isErr(self: Self) bool {
            return self.inner.isLeft();
        }

        pub fn getValue(self: Self) ?T {
            return self.inner.getRight();
        }

        pub fn getError(self: Self) ?E {
            return self.inner.getLeft();
        }

        // ============ Bifunctor 操作 ============

        /// bimap: 同时 map 错误和成功值
        pub fn bimap(
            self: Self,
            comptime E2: type,
            comptime T2: type,
            onErr: *const fn (E) E2,
            onOk: *const fn (T) T2,
        ) ResultBifunctor(T2, E2) {
            return .{
                .inner = self.inner.bimap(E2, T2, onErr, onOk),
            };
        }

        /// map: 只 map 成功值
        pub fn map(self: Self, comptime T2: type, f: *const fn (T) T2) ResultBifunctor(T2, E) {
            return .{
                .inner = self.inner.mapRight(T2, f),
            };
        }

        /// mapErr: 只 map 错误值
        pub fn mapErr(self: Self, comptime E2: type, f: *const fn (E) E2) ResultBifunctor(T, E2) {
            return .{
                .inner = self.inner.mapLeft(E2, f),
            };
        }

        /// flatMap: Monad bind
        pub fn flatMap(self: Self, comptime T2: type, f: *const fn (T) ResultBifunctor(T2, E)) ResultBifunctor(T2, E) {
            return switch (self.inner) {
                .left_val => |e| ResultBifunctor(T2, E).err(e),
                .right_val => |t| f(t),
            };
        }

        /// unwrapOr: 获取成功值或默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return self.inner.fromRight(default);
        }
    };
}

// ============ These Bifunctor ============

/// These 类型 - 可以同时包含两个值
pub fn These(comptime A: type, comptime B: type) type {
    return union(enum) {
        this_val: A,
        that_val: B,
        both_val: struct { A, B },

        const Self = @This();

        // ============ 构造器 ============

        pub fn this(value: A) Self {
            return .{ .this_val = value };
        }

        pub fn that(value: B) Self {
            return .{ .that_val = value };
        }

        pub fn both(a: A, b: B) Self {
            return .{ .both_val = .{ a, b } };
        }

        // ============ 查询 ============

        pub fn isThis(self: Self) bool {
            return self == .this_val;
        }

        pub fn isThat(self: Self) bool {
            return self == .that_val;
        }

        pub fn isBoth(self: Self) bool {
            return self == .both_val;
        }

        pub fn getThis(self: Self) ?A {
            return switch (self) {
                .this_val => |a| a,
                .that_val => null,
                .both_val => |p| p[0],
            };
        }

        pub fn getThat(self: Self) ?B {
            return switch (self) {
                .this_val => null,
                .that_val => |b| b,
                .both_val => |p| p[1],
            };
        }

        // ============ Bifunctor 操作 ============

        /// bimap: 同时 map 两个参数
        pub fn bimap(
            self: Self,
            comptime C: type,
            comptime D: type,
            f: *const fn (A) C,
            g: *const fn (B) D,
        ) These(C, D) {
            return switch (self) {
                .this_val => |a| These(C, D).this(f(a)),
                .that_val => |b| These(C, D).that(g(b)),
                .both_val => |p| These(C, D).both(f(p[0]), g(p[1])),
            };
        }

        /// mapThis: 只 map This
        pub fn mapThis(self: Self, comptime C: type, f: *const fn (A) C) These(C, B) {
            return switch (self) {
                .this_val => |a| These(C, B).this(f(a)),
                .that_val => |b| These(C, B).that(b),
                .both_val => |p| These(C, B).both(f(p[0]), p[1]),
            };
        }

        /// mapThat: 只 map That
        pub fn mapThat(self: Self, comptime D: type, g: *const fn (B) D) These(A, D) {
            return switch (self) {
                .this_val => |a| These(A, D).this(a),
                .that_val => |b| These(A, D).that(g(b)),
                .both_val => |p| These(A, D).both(p[0], g(p[1])),
            };
        }
    };
}

// ============ 便捷函数 ============

/// 创建 Pair
pub fn pair(comptime A: type, comptime B: type, a: A, b: B) Pair(A, B) {
    return Pair(A, B).init(a, b);
}

/// 创建 Left Either
pub fn left(comptime A: type, comptime B: type, value: A) Either(A, B) {
    return Either(A, B).left(value);
}

/// 创建 Right Either
pub fn right(comptime A: type, comptime B: type, value: B) Either(A, B) {
    return Either(A, B).right(value);
}

// ============ 测试 ============

test "Pair.init and accessors" {
    const p = Pair(i32, []const u8).init(42, "hello");

    try std.testing.expectEqual(@as(i32, 42), p.fst());
    try std.testing.expectEqualStrings("hello", p.snd());
}

test "Pair.bimap" {
    const p = Pair(i32, i32).init(10, 20);

    const mapped = p.bimap(i32, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, struct {
        fn g(x: i32) i32 {
            return x + 1;
        }
    }.g);

    try std.testing.expectEqual(@as(i32, 20), mapped.fst());
    try std.testing.expectEqual(@as(i32, 21), mapped.snd());
}

test "Pair.mapFirst" {
    const p = Pair(i32, []const u8).init(42, "hello");

    const mapped = p.mapFirst(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 84), mapped.fst());
    try std.testing.expectEqualStrings("hello", mapped.snd());
}

test "Pair.mapSecond" {
    const p = Pair(i32, i32).init(42, 10);

    const mapped = p.mapSecond(i32, struct {
        fn f(x: i32) i32 {
            return x + 5;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), mapped.fst());
    try std.testing.expectEqual(@as(i32, 15), mapped.snd());
}

test "Pair.swap" {
    const p = Pair(i32, []const u8).init(42, "hello");
    const swapped = p.swap();

    try std.testing.expectEqualStrings("hello", swapped.fst());
    try std.testing.expectEqual(@as(i32, 42), swapped.snd());
}

test "Pair.dup" {
    const p = Pair(i32, i32).dup(42);

    try std.testing.expectEqual(@as(i32, 42), p.fst());
    try std.testing.expectEqual(@as(i32, 42), p.snd());
}

test "Either.left and right" {
    const l = Either(i32, []const u8).left(42);
    const r = Either(i32, []const u8).right("hello");

    try std.testing.expect(l.isLeft());
    try std.testing.expect(!l.isRight());
    try std.testing.expectEqual(@as(?i32, 42), l.getLeft());

    try std.testing.expect(!r.isLeft());
    try std.testing.expect(r.isRight());
    try std.testing.expectEqualStrings("hello", r.getRight().?);
}

test "Either.bimap" {
    const l = Either(i32, i32).left(10);
    const r = Either(i32, i32).right(20);

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

    const mappedL = l.bimap(i32, i32, double, addOne);
    const mappedR = r.bimap(i32, i32, double, addOne);

    try std.testing.expect(mappedL.isLeft());
    try std.testing.expectEqual(@as(?i32, 20), mappedL.getLeft());

    try std.testing.expect(mappedR.isRight());
    try std.testing.expectEqual(@as(?i32, 21), mappedR.getRight());
}

test "Either.mapLeft" {
    const e = Either(i32, []const u8).left(42);

    const mapped = e.mapLeft(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 84), mapped.getLeft());
}

test "Either.mapRight" {
    const e = Either([]const u8, i32).right(42);

    const mapped = e.mapRight(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 84), mapped.getRight());
}

test "Either.swap" {
    const l = Either(i32, []const u8).left(42);
    const swapped = l.swap();

    try std.testing.expect(swapped.isRight());
    try std.testing.expectEqual(@as(?i32, 42), swapped.getRight());
}

test "Either.either" {
    const l = Either(i32, []const u8).left(42);
    const r = Either(i32, []const u8).right("hello");

    const resultL = l.either(usize, struct {
        fn onLeft(x: i32) usize {
            return @intCast(@as(u32, @bitCast(x)));
        }
    }.onLeft, struct {
        fn onRight(s: []const u8) usize {
            return s.len;
        }
    }.onRight);

    const resultR = r.either(usize, struct {
        fn onLeft(x: i32) usize {
            return @intCast(@as(u32, @bitCast(x)));
        }
    }.onLeft, struct {
        fn onRight(s: []const u8) usize {
            return s.len;
        }
    }.onRight);

    try std.testing.expectEqual(@as(usize, 42), resultL);
    try std.testing.expectEqual(@as(usize, 5), resultR);
}

test "Either.flatMap" {
    const e = Either([]const u8, i32).right(10);

    const result = e.flatMap(i32, struct {
        fn f(x: i32) Either([]const u8, i32) {
            if (x > 5) {
                return Either([]const u8, i32).right(x * 2);
            } else {
                return Either([]const u8, i32).left("too small");
            }
        }
    }.f);

    try std.testing.expect(result.isRight());
    try std.testing.expectEqual(@as(?i32, 20), result.getRight());
}

test "ResultBifunctor.ok and err" {
    const ok_val = ResultBifunctor(i32, []const u8).ok(42);
    const err_val = ResultBifunctor(i32, []const u8).err("error");

    try std.testing.expect(ok_val.isOk());
    try std.testing.expectEqual(@as(?i32, 42), ok_val.getValue());

    try std.testing.expect(err_val.isErr());
    try std.testing.expectEqualStrings("error", err_val.getError().?);
}

test "ResultBifunctor.bimap" {
    const ok_val = ResultBifunctor(i32, []const u8).ok(42);

    const mapped = ok_val.bimap(usize, i32, struct {
        fn onErr(s: []const u8) usize {
            return s.len;
        }
    }.onErr, struct {
        fn onOk(x: i32) i32 {
            return x * 2;
        }
    }.onOk);

    try std.testing.expect(mapped.isOk());
    try std.testing.expectEqual(@as(?i32, 84), mapped.getValue());
}

test "ResultBifunctor.map" {
    const ok_val = ResultBifunctor(i32, []const u8).ok(42);

    const mapped = ok_val.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 84), mapped.getValue());
}

test "ResultBifunctor.mapErr" {
    const err_val = ResultBifunctor(i32, []const u8).err("error");

    const mapped = err_val.mapErr(usize, struct {
        fn f(s: []const u8) usize {
            return s.len;
        }
    }.f);

    try std.testing.expect(mapped.isErr());
    try std.testing.expectEqual(@as(?usize, 5), mapped.getError());
}

test "These.this, that, both" {
    const t = These(i32, []const u8).this(42);
    const h = These(i32, []const u8).that("hello");
    const b = These(i32, []const u8).both(42, "hello");

    try std.testing.expect(t.isThis());
    try std.testing.expect(h.isThat());
    try std.testing.expect(b.isBoth());
}

test "These.bimap" {
    const b = These(i32, i32).both(10, 20);

    const mapped = b.bimap(i32, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, struct {
        fn g(x: i32) i32 {
            return x + 1;
        }
    }.g);

    try std.testing.expect(mapped.isBoth());
    try std.testing.expectEqual(@as(?i32, 20), mapped.getThis());
    try std.testing.expectEqual(@as(?i32, 21), mapped.getThat());
}

test "Bifunctor identity law" {
    // bimap(id, id) = id
    const p = Pair(i32, i32).init(10, 20);

    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const mapped = p.bimap(i32, i32, id, id);

    try std.testing.expectEqual(p.fst(), mapped.fst());
    try std.testing.expectEqual(p.snd(), mapped.snd());
}

test "Bifunctor composition law" {
    // bimap(f, g) . bimap(h, i) = bimap(f . h, g . i)
    const p = Pair(i32, i32).init(5, 10);

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

    // 分开 bimap
    const step1 = p.bimap(i32, i32, double, addOne);
    const left_result = step1.bimap(i32, i32, addOne, double);

    // 组合后 bimap
    const right_result = p.bimap(i32, i32, struct {
        fn f(x: i32) i32 {
            return double(x) + 1; // addOne(double(x))
        }
    }.f, struct {
        fn f(x: i32) i32 {
            return (x + 1) * 2; // double(addOne(x))
        }
    }.f);

    try std.testing.expectEqual(left_result.fst(), right_result.fst());
    try std.testing.expectEqual(left_result.snd(), right_result.snd());
}

test "pair convenience function" {
    const p = pair(i32, []const u8, 42, "hello");

    try std.testing.expectEqual(@as(i32, 42), p.fst());
    try std.testing.expectEqualStrings("hello", p.snd());
}

test "left and right convenience functions" {
    const l = left(i32, []const u8, 42);
    const r = right(i32, []const u8, "hello");

    try std.testing.expect(l.isLeft());
    try std.testing.expect(r.isRight());
}
