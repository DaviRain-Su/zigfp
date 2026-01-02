//! Profunctor 模块
//!
//! Profunctor 是输入逆变、输出协变的 Functor。
//! 对于 P(A, B)，A 是逆变的（contravariant），B 是协变的（covariant）。
//!
//! 核心操作:
//! - dimap: (A' -> A) -> (B -> B') -> P(A, B) -> P(A', B')
//! - lmap:  (A' -> A) -> P(A, B) -> P(A', B)  (逆变映射)
//! - rmap:  (B -> B') -> P(A, B) -> P(A, B')  (协变映射)
//!
//! 法则:
//! - Identity: dimap(id, id) = id
//! - Composition: dimap(f, g) . dimap(h, i) = dimap(h . f, g . i)
//!
//! 类似于 Haskell 的 Profunctor 类型类

const std = @import("std");
const option_mod = @import("../core/option.zig");
const Option = option_mod.Option;

// ============ Function Profunctor ============

/// 函数作为 Profunctor
/// 函数 A -> B 是最基本的 Profunctor 实例
pub fn FunctionProfunctor(comptime A: type, comptime B: type) type {
    return struct {
        runFn: *const fn (A) B,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(f: *const fn (A) B) Self {
            return .{ .runFn = f };
        }

        /// 运行函数
        pub fn run(self: Self, a: A) B {
            return self.runFn(a);
        }

        // ============ Profunctor 操作 ============

        /// dimap: 同时处理输入（逆变）和输出（协变）
        /// dimap :: (A' -> A) -> (B -> B') -> (A -> B) -> (A' -> B')
        pub fn dimap(
            self: Self,
            comptime A2: type,
            comptime B2: type,
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) FunctionProfunctor(A2, B2) {
            // 由于 Zig 不支持闭包，我们使用静态包装器来模拟
            return DimapWrapper(A, B, A2, B2).create(self.runFn, pre, post);
        }

        /// lmap: 只处理输入（逆变）
        /// lmap :: (A' -> A) -> (A -> B) -> (A' -> B)
        pub fn lmap(self: Self, comptime A2: type, pre: *const fn (A2) A) FunctionProfunctor(A2, B) {
            return LmapWrapper(A, B, A2).create(self.runFn, pre);
        }

        /// rmap: 只处理输出（协变）
        /// rmap :: (B -> B') -> (A -> B) -> (A -> B')
        pub fn rmap(self: Self, comptime B2: type, post: *const fn (B) B2) FunctionProfunctor(A, B2) {
            return RmapWrapper(A, B, B2).create(self.runFn, post);
        }

        // ============ Arrow 风格操作 ============

        /// first: 在 pair 的第一个元素上运行
        /// first :: (A -> B) -> (A, C) -> (B, C)
        pub fn first(self: Self, comptime C: type) FunctionProfunctor(struct { A, C }, struct { B, C }) {
            return FirstWrapper(A, B, C).create(self.runFn);
        }

        /// second: 在 pair 的第二个元素上运行
        /// second :: (A -> B) -> (C, A) -> (C, B)
        pub fn second(self: Self, comptime C: type) FunctionProfunctor(struct { C, A }, struct { C, B }) {
            return SecondWrapper(A, B, C).create(self.runFn);
        }
    };
}

// ============ 辅助包装器（用于模拟闭包） ============

/// dimap 包装器
fn DimapWrapper(comptime A: type, comptime B: type, comptime A2: type, comptime B2: type) type {
    return struct {
        var stored_inner: *const fn (A) B = undefined;
        var stored_pre: *const fn (A2) A = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(a2: A2) B2 {
            const a = stored_pre(a2);
            const b = stored_inner(a);
            return stored_post(b);
        }

        pub fn create(
            inner: *const fn (A) B,
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) FunctionProfunctor(A2, B2) {
            stored_inner = inner;
            stored_pre = pre;
            stored_post = post;
            return FunctionProfunctor(A2, B2).init(&call);
        }
    };
}

/// lmap 包装器
fn LmapWrapper(comptime A: type, comptime B: type, comptime A2: type) type {
    return struct {
        var stored_inner: *const fn (A) B = undefined;
        var stored_pre: *const fn (A2) A = undefined;

        fn call(a2: A2) B {
            const a = stored_pre(a2);
            return stored_inner(a);
        }

        pub fn create(inner: *const fn (A) B, pre: *const fn (A2) A) FunctionProfunctor(A2, B) {
            stored_inner = inner;
            stored_pre = pre;
            return FunctionProfunctor(A2, B).init(&call);
        }
    };
}

/// rmap 包装器
fn RmapWrapper(comptime A: type, comptime B: type, comptime B2: type) type {
    return struct {
        var stored_inner: *const fn (A) B = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(a: A) B2 {
            const b = stored_inner(a);
            return stored_post(b);
        }

        pub fn create(inner: *const fn (A) B, post: *const fn (B) B2) FunctionProfunctor(A, B2) {
            stored_inner = inner;
            stored_post = post;
            return FunctionProfunctor(A, B2).init(&call);
        }
    };
}

/// first 包装器
fn FirstWrapper(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        var stored_fn: *const fn (A) B = undefined;

        fn call(pair: struct { A, C }) struct { B, C } {
            return .{ stored_fn(pair[0]), pair[1] };
        }

        pub fn create(f: *const fn (A) B) FunctionProfunctor(struct { A, C }, struct { B, C }) {
            stored_fn = f;
            return FunctionProfunctor(struct { A, C }, struct { B, C }).init(&call);
        }
    };
}

/// second 包装器
fn SecondWrapper(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        var stored_fn: *const fn (A) B = undefined;

        fn call(pair: struct { C, A }) struct { C, B } {
            return .{ pair[0], stored_fn(pair[1]) };
        }

        pub fn create(f: *const fn (A) B) FunctionProfunctor(struct { C, A }, struct { C, B }) {
            stored_fn = f;
            return FunctionProfunctor(struct { C, A }, struct { C, B }).init(&call);
        }
    };
}

// ============ Star Profunctor ============

/// Star - Kleisli 风格的 Profunctor
/// Star F A B = A -> F B
/// 类似于 Kleisli 箭头，将普通值映射到包装在 Functor 中的值
pub fn Star(comptime F: fn (type) type, comptime A: type, comptime B: type) type {
    return struct {
        runStar: *const fn (A) F(B),

        const Self = @This();

        pub fn init(f: *const fn (A) F(B)) Self {
            return .{ .runStar = f };
        }

        pub fn run(self: Self, a: A) F(B) {
            return self.runStar(a);
        }

        /// dimap for Star
        /// 需要 F 是 Functor（有 map 方法）
        pub fn dimap(
            self: Self,
            comptime A2: type,
            comptime B2: type,
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) Star(F, A2, B2) {
            return StarDimapWrapper(F, A, B, A2, B2).create(self.runStar, pre, post);
        }

        /// lmap for Star
        pub fn lmap(self: Self, comptime A2: type, pre: *const fn (A2) A) Star(F, A2, B) {
            return StarLmapWrapper(F, A, B, A2).create(self.runStar, pre);
        }

        /// rmap for Star (需要 F 是 Functor)
        pub fn rmap(self: Self, comptime B2: type, post: *const fn (B) B2) Star(F, A, B2) {
            return StarRmapWrapper(F, A, B, B2).create(self.runStar, post);
        }
    };
}

/// Star dimap 包装器
fn StarDimapWrapper(
    comptime F: fn (type) type,
    comptime A: type,
    comptime B: type,
    comptime A2: type,
    comptime B2: type,
) type {
    return struct {
        var stored_inner: *const fn (A) F(B) = undefined;
        var stored_pre: *const fn (A2) A = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(a2: A2) F(B2) {
            const a = stored_pre(a2);
            const fb = stored_inner(a);
            return fb.map(B2, stored_post);
        }

        pub fn create(
            inner: *const fn (A) F(B),
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) Star(F, A2, B2) {
            stored_inner = inner;
            stored_pre = pre;
            stored_post = post;
            return Star(F, A2, B2).init(&call);
        }
    };
}

/// Star lmap 包装器
fn StarLmapWrapper(comptime F: fn (type) type, comptime A: type, comptime B: type, comptime A2: type) type {
    return struct {
        var stored_inner: *const fn (A) F(B) = undefined;
        var stored_pre: *const fn (A2) A = undefined;

        fn call(a2: A2) F(B) {
            const a = stored_pre(a2);
            return stored_inner(a);
        }

        pub fn create(inner: *const fn (A) F(B), pre: *const fn (A2) A) Star(F, A2, B) {
            stored_inner = inner;
            stored_pre = pre;
            return Star(F, A2, B).init(&call);
        }
    };
}

/// Star rmap 包装器
fn StarRmapWrapper(comptime F: fn (type) type, comptime A: type, comptime B: type, comptime B2: type) type {
    return struct {
        var stored_inner: *const fn (A) F(B) = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(a: A) F(B2) {
            const fb = stored_inner(a);
            return fb.map(B2, stored_post);
        }

        pub fn create(inner: *const fn (A) F(B), post: *const fn (B) B2) Star(F, A, B2) {
            stored_inner = inner;
            stored_post = post;
            return Star(F, A, B2).init(&call);
        }
    };
}

// ============ Costar Profunctor ============

/// Costar - Co-Kleisli 风格的 Profunctor
/// Costar F A B = F A -> B
/// 从包装在 Functor 中的值提取并转换
pub fn Costar(comptime F: fn (type) type, comptime A: type, comptime B: type) type {
    return struct {
        runCostar: *const fn (F(A)) B,

        const Self = @This();

        pub fn init(f: *const fn (F(A)) B) Self {
            return .{ .runCostar = f };
        }

        pub fn run(self: Self, fa: F(A)) B {
            return self.runCostar(fa);
        }

        /// dimap for Costar
        /// 需要 F 是 Functor（有 map 方法）
        pub fn dimap(
            self: Self,
            comptime A2: type,
            comptime B2: type,
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) Costar(F, A2, B2) {
            return CostarDimapWrapper(F, A, B, A2, B2).create(self.runCostar, pre, post);
        }

        /// lmap for Costar (需要 F 是 Functor)
        pub fn lmap(self: Self, comptime A2: type, pre: *const fn (A2) A) Costar(F, A2, B) {
            return CostarLmapWrapper(F, A, B, A2).create(self.runCostar, pre);
        }

        /// rmap for Costar
        pub fn rmap(self: Self, comptime B2: type, post: *const fn (B) B2) Costar(F, A, B2) {
            return CostarRmapWrapper(F, A, B, B2).create(self.runCostar, post);
        }
    };
}

/// Costar dimap 包装器
fn CostarDimapWrapper(
    comptime F: fn (type) type,
    comptime A: type,
    comptime B: type,
    comptime A2: type,
    comptime B2: type,
) type {
    return struct {
        var stored_inner: *const fn (F(A)) B = undefined;
        var stored_pre: *const fn (A2) A = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(fa2: F(A2)) B2 {
            // 对 F(A2) 应用 pre 得到 F(A)
            const fa = fa2.map(A, stored_pre);
            const b = stored_inner(fa);
            return stored_post(b);
        }

        pub fn create(
            inner: *const fn (F(A)) B,
            pre: *const fn (A2) A,
            post: *const fn (B) B2,
        ) Costar(F, A2, B2) {
            stored_inner = inner;
            stored_pre = pre;
            stored_post = post;
            return Costar(F, A2, B2).init(&call);
        }
    };
}

/// Costar lmap 包装器
fn CostarLmapWrapper(comptime F: fn (type) type, comptime A: type, comptime B: type, comptime A2: type) type {
    return struct {
        var stored_inner: *const fn (F(A)) B = undefined;
        var stored_pre: *const fn (A2) A = undefined;

        fn call(fa2: F(A2)) B {
            const fa = fa2.map(A, stored_pre);
            return stored_inner(fa);
        }

        pub fn create(inner: *const fn (F(A)) B, pre: *const fn (A2) A) Costar(F, A2, B) {
            stored_inner = inner;
            stored_pre = pre;
            return Costar(F, A2, B).init(&call);
        }
    };
}

/// Costar rmap 包装器
fn CostarRmapWrapper(comptime F: fn (type) type, comptime A: type, comptime B: type, comptime B2: type) type {
    return struct {
        var stored_inner: *const fn (F(A)) B = undefined;
        var stored_post: *const fn (B) B2 = undefined;

        fn call(fa: F(A)) B2 {
            const b = stored_inner(fa);
            return stored_post(b);
        }

        pub fn create(inner: *const fn (F(A)) B, post: *const fn (B) B2) Costar(F, A, B2) {
            stored_inner = inner;
            stored_post = post;
            return Costar(F, A, B2).init(&call);
        }
    };
}

// ============ UpStar Profunctor ============

/// UpStar - 类似 Star 但用于 Contravariant Functor
/// UpStar F A B = F B -> A
pub fn UpStar(comptime F: fn (type) type, comptime A: type, comptime B: type) type {
    return struct {
        runUpStar: *const fn (F(B)) A,

        const Self = @This();

        pub fn init(f: *const fn (F(B)) A) Self {
            return .{ .runUpStar = f };
        }

        pub fn run(self: Self, fb: F(B)) A {
            return self.runUpStar(fb);
        }
    };
}

// ============ 便捷函数 ============

/// 创建 FunctionProfunctor
pub fn profunctor(comptime A: type, comptime B: type, f: *const fn (A) B) FunctionProfunctor(A, B) {
    return FunctionProfunctor(A, B).init(f);
}

/// 全局 dimap 函数
pub fn dimap(
    comptime A: type,
    comptime B: type,
    comptime A2: type,
    comptime B2: type,
    pre: *const fn (A2) A,
    post: *const fn (B) B2,
    f: *const fn (A) B,
) FunctionProfunctor(A2, B2) {
    return FunctionProfunctor(A, B).init(f).dimap(A2, B2, pre, post);
}

/// 全局 lmap 函数
pub fn lmapFn(
    comptime A: type,
    comptime B: type,
    comptime A2: type,
    pre: *const fn (A2) A,
    f: *const fn (A) B,
) FunctionProfunctor(A2, B) {
    return FunctionProfunctor(A, B).init(f).lmap(A2, pre);
}

/// 全局 rmap 函数
pub fn rmapFn(
    comptime A: type,
    comptime B: type,
    comptime B2: type,
    post: *const fn (B) B2,
    f: *const fn (A) B,
) FunctionProfunctor(A, B2) {
    return FunctionProfunctor(A, B).init(f).rmap(B2, post);
}

/// 创建 Star
pub fn star(comptime F: fn (type) type, comptime A: type, comptime B: type, f: *const fn (A) F(B)) Star(F, A, B) {
    return Star(F, A, B).init(f);
}

/// 创建 Costar
pub fn costar(comptime F: fn (type) type, comptime A: type, comptime B: type, f: *const fn (F(A)) B) Costar(F, A, B) {
    return Costar(F, A, B).init(f);
}

// ============ Strong Profunctor ============

/// Strong Profunctor - 可以与 Pair 一起工作的 Profunctor
/// first' :: p a b -> p (a, c) (b, c)
/// second' :: p a b -> p (c, a) (c, b)
pub fn StrongProfunctor(comptime A: type, comptime B: type) type {
    return struct {
        inner: FunctionProfunctor(A, B),

        const Self = @This();

        pub fn init(f: *const fn (A) B) Self {
            return .{ .inner = FunctionProfunctor(A, B).init(f) };
        }

        pub fn run(self: Self, a: A) B {
            return self.inner.run(a);
        }

        /// first': 在 pair 的第一个元素上应用
        pub fn firstStrong(self: Self, comptime C: type) StrongProfunctor(struct { A, C }, struct { B, C }) {
            const wrapped = self.inner.first(C);
            return .{ .inner = wrapped };
        }

        /// second': 在 pair 的第二个元素上应用
        pub fn secondStrong(self: Self, comptime C: type) StrongProfunctor(struct { C, A }, struct { C, B }) {
            const wrapped = self.inner.second(C);
            return .{ .inner = wrapped };
        }
    };
}

// ============ Choice Profunctor ============

/// Choice Profunctor - 可以与 Either 一起工作的 Profunctor
/// left' :: p a b -> p (Either a c) (Either b c)
/// right' :: p a b -> p (Either c a) (Either c b)
pub fn ChoiceProfunctor(comptime A: type, comptime B: type) type {
    return struct {
        inner: FunctionProfunctor(A, B),

        const Self = @This();

        const bifunctor = @import("bifunctor.zig");
        const Either = bifunctor.Either;

        pub fn init(f: *const fn (A) B) Self {
            return .{ .inner = FunctionProfunctor(A, B).init(f) };
        }

        pub fn run(self: Self, a: A) B {
            return self.inner.run(a);
        }

        /// left': 在 Either 的左边应用
        pub fn leftChoice(self: Self, comptime C: type) ChoiceLeftWrapper(A, B, C) {
            return ChoiceLeftWrapper(A, B, C).create(self.inner.runFn);
        }

        /// right': 在 Either 的右边应用
        pub fn rightChoice(self: Self, comptime C: type) ChoiceRightWrapper(A, B, C) {
            return ChoiceRightWrapper(A, B, C).create(self.inner.runFn);
        }
    };
}

/// Choice left 包装器
fn ChoiceLeftWrapper(comptime A: type, comptime B: type, comptime C: type) type {
    const bifunctor = @import("bifunctor.zig");
    const Either = bifunctor.Either;

    return struct {
        runFn: *const fn (Either(A, C)) Either(B, C),

        const Self = @This();

        var stored_fn: *const fn (A) B = undefined;

        fn call(e: Either(A, C)) Either(B, C) {
            return switch (e) {
                .left_val => |a| Either(B, C).left(stored_fn(a)),
                .right_val => |c| Either(B, C).right(c),
            };
        }

        pub fn create(f: *const fn (A) B) Self {
            stored_fn = f;
            return .{ .runFn = &call };
        }

        pub fn run(self: Self, e: Either(A, C)) Either(B, C) {
            return self.runFn(e);
        }
    };
}

/// Choice right 包装器
fn ChoiceRightWrapper(comptime A: type, comptime B: type, comptime C: type) type {
    const bifunctor = @import("bifunctor.zig");
    const Either = bifunctor.Either;

    return struct {
        runFn: *const fn (Either(C, A)) Either(C, B),

        const Self = @This();

        var stored_fn: *const fn (A) B = undefined;

        fn call(e: Either(C, A)) Either(C, B) {
            return switch (e) {
                .left_val => |c| Either(C, B).left(c),
                .right_val => |a| Either(C, B).right(stored_fn(a)),
            };
        }

        pub fn create(f: *const fn (A) B) Self {
            stored_fn = f;
            return .{ .runFn = &call };
        }

        pub fn run(self: Self, e: Either(C, A)) Either(C, B) {
            return self.runFn(e);
        }
    };
}

// ============ 测试 ============

test "FunctionProfunctor.init and run" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    try std.testing.expectEqual(@as(i32, 10), p.run(5));
}

test "FunctionProfunctor.dimap" {
    // 原函数: i32 -> i32 (乘以 2)
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    // pre: []const u8 -> i32 (取长度)
    const strLen = struct {
        fn f(s: []const u8) i32 {
            return @intCast(s.len);
        }
    }.f;

    // post: i32 -> i64 (转换为 i64)
    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.dimap([]const u8, i64, strLen, toI64);

    // "hello" -> 5 -> 10 -> 10i64
    try std.testing.expectEqual(@as(i64, 10), mapped.run("hello"));
}

test "FunctionProfunctor.lmap" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const strLen = struct {
        fn f(s: []const u8) i32 {
            return @intCast(s.len);
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.lmap([]const u8, strLen);

    try std.testing.expectEqual(@as(i32, 10), mapped.run("hello"));
}

test "FunctionProfunctor.rmap" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.rmap(i64, toI64);

    try std.testing.expectEqual(@as(i64, 10), mapped.run(5));
}

test "FunctionProfunctor.first" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const firsted = p.first([]const u8);

    const result = firsted.run(.{ 5, "hello" });
    try std.testing.expectEqual(@as(i32, 10), result[0]);
    try std.testing.expectEqualStrings("hello", result[1]);
}

test "FunctionProfunctor.second" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const seconded = p.second([]const u8);

    const result = seconded.run(.{ "hello", 5 });
    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqual(@as(i32, 10), result[1]);
}

test "profunctor convenience function" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const p = profunctor(i32, i32, double);
    try std.testing.expectEqual(@as(i32, 10), p.run(5));
}

test "global dimap function" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const strLen = struct {
        fn f(s: []const u8) i32 {
            return @intCast(s.len);
        }
    }.f;

    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const mapped = dimap(i32, i32, []const u8, i64, strLen, toI64, double);
    try std.testing.expectEqual(@as(i64, 10), mapped.run("hello"));
}

test "Star profunctor init and run" {
    const toOption = struct {
        fn f(x: i32) Option(i32) {
            if (x > 0) {
                return Option(i32).Some(x * 2);
            } else {
                return Option(i32).None();
            }
        }
    }.f;

    const s = Star(Option, i32, i32).init(toOption);

    const result1 = s.run(5);
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(i32, 10), result1.unwrap());

    const result2 = s.run(-5);
    try std.testing.expect(result2.isNone());
}

test "Star.lmap" {
    const toOption = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f;

    const strLen = struct {
        fn f(s: []const u8) i32 {
            return @intCast(s.len);
        }
    }.f;

    const s = Star(Option, i32, i32).init(toOption);
    const mapped = s.lmap([]const u8, strLen);

    const result = mapped.run("hello");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());
}

test "Star.rmap" {
    const toOption = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f;

    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const s = Star(Option, i32, i32).init(toOption);
    const mapped = s.rmap(i64, toI64);

    const result = mapped.run(5);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i64, 10), result.unwrap());
}

test "Costar profunctor init and run" {
    const fromOption = struct {
        fn f(opt: Option(i32)) i32 {
            return opt.unwrapOr(0);
        }
    }.f;

    const cs = Costar(Option, i32, i32).init(fromOption);

    const result1 = cs.run(Option(i32).Some(42));
    try std.testing.expectEqual(@as(i32, 42), result1);

    const result2 = cs.run(Option(i32).None());
    try std.testing.expectEqual(@as(i32, 0), result2);
}

test "Costar.rmap" {
    const fromOption = struct {
        fn f(opt: Option(i32)) i32 {
            return opt.unwrapOr(0);
        }
    }.f;

    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const cs = Costar(Option, i32, i32).init(fromOption);
    const mapped = cs.rmap(i64, toI64);

    const result = mapped.run(Option(i32).Some(42));
    try std.testing.expectEqual(@as(i64, 42), result);
}

test "star convenience function" {
    const toOption = struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f;

    const s = star(Option, i32, i32, toOption);
    const result = s.run(5);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());
}

test "costar convenience function" {
    const fromOption = struct {
        fn f(opt: Option(i32)) i32 {
            return opt.unwrapOr(0);
        }
    }.f;

    const cs = costar(Option, i32, i32, fromOption);
    try std.testing.expectEqual(@as(i32, 42), cs.run(Option(i32).Some(42)));
}

test "StrongProfunctor.firstStrong" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const sp = StrongProfunctor(i32, i32).init(double);
    const firsted = sp.firstStrong([]const u8);

    const result = firsted.run(.{ 5, "hello" });
    try std.testing.expectEqual(@as(i32, 10), result[0]);
    try std.testing.expectEqualStrings("hello", result[1]);
}

test "StrongProfunctor.secondStrong" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const sp = StrongProfunctor(i32, i32).init(double);
    const seconded = sp.secondStrong([]const u8);

    const result = seconded.run(.{ "hello", 5 });
    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqual(@as(i32, 10), result[1]);
}

test "ChoiceProfunctor.leftChoice" {
    const bifunctor = @import("bifunctor.zig");
    const Either = bifunctor.Either;

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const cp = ChoiceProfunctor(i32, i32).init(double);
    const lefted = cp.leftChoice([]const u8);

    const leftInput = Either(i32, []const u8).left(5);
    const resultLeft = lefted.run(leftInput);
    try std.testing.expect(resultLeft.isLeft());
    try std.testing.expectEqual(@as(?i32, 10), resultLeft.getLeft());

    const rightInput = Either(i32, []const u8).right("hello");
    const resultRight = lefted.run(rightInput);
    try std.testing.expect(resultRight.isRight());
    try std.testing.expectEqualStrings("hello", resultRight.getRight().?);
}

test "ChoiceProfunctor.rightChoice" {
    const bifunctor = @import("bifunctor.zig");
    const Either = bifunctor.Either;

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const cp = ChoiceProfunctor(i32, i32).init(double);
    const righted = cp.rightChoice([]const u8);

    const rightInput = Either([]const u8, i32).right(5);
    const resultRight = righted.run(rightInput);
    try std.testing.expect(resultRight.isRight());
    try std.testing.expectEqual(@as(?i32, 10), resultRight.getRight());

    const leftInput = Either([]const u8, i32).left("hello");
    const resultLeft = righted.run(leftInput);
    try std.testing.expect(resultLeft.isLeft());
    try std.testing.expectEqualStrings("hello", resultLeft.getLeft().?);
}

// ============ Profunctor 法则测试 ============

test "Profunctor identity law" {
    // dimap(id, id) = id
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.dimap(i32, i32, id, id);

    try std.testing.expectEqual(p.run(5), mapped.run(5));
    try std.testing.expectEqual(p.run(10), mapped.run(10));
}

test "Profunctor lmap identity" {
    // lmap(id) = id
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.lmap(i32, id);

    try std.testing.expectEqual(p.run(5), mapped.run(5));
}

test "Profunctor rmap identity" {
    // rmap(id) = id
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const id = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);
    const mapped = p.rmap(i32, id);

    try std.testing.expectEqual(p.run(5), mapped.run(5));
}

test "dimap is lmap then rmap" {
    // dimap(f, g) = lmap(f) . rmap(g)
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

    const toI64 = struct {
        fn f(x: i32) i64 {
            return @intCast(x);
        }
    }.f;

    const p = FunctionProfunctor(i32, i32).init(double);

    // dimap 方式
    const dimapped = p.dimap(i32, i64, addOne, toI64);

    // lmap then rmap 方式
    const lmapped = p.lmap(i32, addOne);
    const both = lmapped.rmap(i64, toI64);

    // 两种方式结果应该相同
    try std.testing.expectEqual(dimapped.run(5), both.run(5));
}
