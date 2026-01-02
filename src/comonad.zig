//! Comonad 模块
//!
//! Comonad 是 Monad 的对偶（dual）。
//! 如果说 Monad 是"将值放入上下文"，那么 Comonad 是"从上下文提取值"。
//!
//! Monad:   pure: A -> M(A),    join: M(M(A)) -> M(A),    flatMap: M(A) -> (A -> M(B)) -> M(B)
//! Comonad: extract: W(A) -> A, duplicate: W(A) -> W(W(A)), extend: W(A) -> (W(A) -> B) -> W(B)
//!
//! Comonad 法则：
//! - extract . duplicate = id
//! - fmap extract . duplicate = id
//! - duplicate . duplicate = fmap duplicate . duplicate
//!
//! 类似于 Haskell 的 Comonad 类型类

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============ Identity Comonad ============

/// Identity Comonad - 最简单的 Comonad
pub fn Identity(comptime A: type) type {
    return struct {
        value: A,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(value: A) Self {
            return .{ .value = value };
        }

        // ============ Comonad 操作 ============

        /// extract: 提取值 (Monad.pure 的对偶)
        pub fn extract(self: Self) A {
            return self.value;
        }

        /// duplicate: 复制结构 (Monad.join 的对偶)
        pub fn duplicate(self: Self) Identity(Self) {
            return Identity(Self).init(self);
        }

        /// extend: 扩展 (Monad.flatMap 的对偶)
        /// extend f = fmap f . duplicate
        pub fn extend(self: Self, comptime B: type, f: *const fn (Self) B) Identity(B) {
            return Identity(B).init(f(self));
        }

        /// coflatMap: extend 的别名
        pub fn coflatMap(self: Self, comptime B: type, f: *const fn (Self) B) Identity(B) {
            return self.extend(B, f);
        }

        // ============ Functor 操作 ============

        /// map: Functor 操作
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) Identity(B) {
            return Identity(B).init(f(self.value));
        }
    };
}

// ============ NonEmpty Comonad ============

/// NonEmpty List Comonad - 非空列表
pub fn NonEmpty(comptime A: type) type {
    return struct {
        head_val: A,
        tail_vals: []const A,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(head_val: A, tail_vals: []const A) Self {
            return .{ .head_val = head_val, .tail_vals = tail_vals };
        }

        pub fn singleton(value: A) Self {
            return .{ .head_val = value, .tail_vals = &[_]A{} };
        }

        // ============ 访问器 ============

        pub fn head(self: Self) A {
            return self.head_val;
        }

        pub fn tail(self: Self) []const A {
            return self.tail_vals;
        }

        pub fn length(self: Self) usize {
            return 1 + self.tail_vals.len;
        }

        // ============ Comonad 操作 ============

        /// extract: 提取头部元素
        pub fn extract(self: Self) A {
            return self.head_val;
        }

        /// extend: 对每个位置应用函数
        pub fn extend(self: Self, allocator: Allocator, comptime B: type, f: *const fn (Self) B) !NonEmpty(B) {
            // 对当前位置应用 f
            const new_head = f(self);

            // 对每个 tail 位置创建新的 NonEmpty 并应用 f
            const new_tail = try allocator.alloc(B, self.tail_vals.len);
            errdefer allocator.free(new_tail);

            var i: usize = 0;
            while (i < self.tail_vals.len) : (i += 1) {
                // 创建以 tail[i] 为头的 NonEmpty
                const sublist = Self.init(self.tail_vals[i], self.tail_vals[i + 1 ..]);
                new_tail[i] = f(sublist);
            }

            return NonEmpty(B).init(new_head, new_tail);
        }

        // ============ Functor 操作 ============

        /// map: 对所有元素应用函数
        pub fn map(self: Self, allocator: Allocator, comptime B: type, f: *const fn (A) B) !NonEmpty(B) {
            const new_head = f(self.head_val);
            const new_tail = try allocator.alloc(B, self.tail_vals.len);
            errdefer allocator.free(new_tail);

            for (self.tail_vals, 0..) |v, i| {
                new_tail[i] = f(v);
            }

            return NonEmpty(B).init(new_head, new_tail);
        }

        /// toSlice: 转换为切片
        pub fn toSlice(self: Self, allocator: Allocator) ![]A {
            const result = try allocator.alloc(A, self.length());
            result[0] = self.head_val;
            for (self.tail_vals, 0..) |v, i| {
                result[i + 1] = v;
            }
            return result;
        }
    };
}

// ============ Store Comonad ============

/// Store Comonad - 表示一个焦点位置的结构
/// Store s a = (s -> a, s)
/// 可以理解为：一个根据位置返回值的函数，加上当前的位置
pub fn Store(comptime S: type, comptime A: type) type {
    return struct {
        peekFn: *const fn (S) A,
        pos: S,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(peekFn: *const fn (S) A, pos: S) Self {
            return .{ .peekFn = peekFn, .pos = pos };
        }

        // ============ 访问器 ============

        /// peek: 查看指定位置的值
        pub fn peek(self: Self, s: S) A {
            return self.peekFn(s);
        }

        /// pos: 获取当前位置
        pub fn position(self: Self) S {
            return self.pos;
        }

        // ============ Comonad 操作 ============

        /// extract: 提取当前位置的值
        pub fn extract(self: Self) A {
            return self.peekFn(self.pos);
        }

        /// seek: 移动到新位置
        pub fn seek(self: Self, newPos: S) Self {
            return Self.init(self.peekFn, newPos);
        }

        /// seeks: 相对移动
        pub fn seeks(self: Self, f: *const fn (S) S) Self {
            return Self.init(self.peekFn, f(self.pos));
        }

        // ============ Functor 操作 ============

        /// map: 对所有值应用函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) StoreMap(S, A, B) {
            return StoreMap(S, A, B).init(self.peekFn, f, self.pos);
        }
    };
}

/// Store 的 map 结果类型（由于 Zig 不支持闭包）
pub fn StoreMap(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        innerFn: *const fn (S) A,
        mapFn: *const fn (A) B,
        pos: S,

        const Self = @This();

        pub fn init(innerFn: *const fn (S) A, mapFn: *const fn (A) B, pos: S) Self {
            return .{ .innerFn = innerFn, .mapFn = mapFn, .pos = pos };
        }

        pub fn extract(self: Self) B {
            return self.mapFn(self.innerFn(self.pos));
        }

        pub fn peek(self: Self, s: S) B {
            return self.mapFn(self.innerFn(s));
        }

        pub fn position(self: Self) S {
            return self.pos;
        }
    };
}

// ============ Env Comonad ============

/// Env Comonad (也叫 Coreader 或 Traced)
/// Env e a = (e, a)
/// 携带一个环境值的容器
pub fn Env(comptime E: type, comptime A: type) type {
    return struct {
        env: E,
        value: A,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(env: E, value: A) Self {
            return .{ .env = env, .value = value };
        }

        // ============ 访问器 ============

        pub fn ask(self: Self) E {
            return self.env;
        }

        // ============ Comonad 操作 ============

        /// extract: 提取值
        pub fn extract(self: Self) A {
            return self.value;
        }

        /// duplicate: 复制结构
        pub fn duplicate(self: Self) Env(E, Self) {
            return Env(E, Self).init(self.env, self);
        }

        /// extend: 扩展
        pub fn extend(self: Self, comptime B: type, f: *const fn (Self) B) Env(E, B) {
            return Env(E, B).init(self.env, f(self));
        }

        // ============ Functor 操作 ============

        /// map: 对值应用函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) Env(E, B) {
            return Env(E, B).init(self.env, f(self.value));
        }

        /// local: 修改环境
        pub fn local(self: Self, f: *const fn (E) E) Self {
            return Self.init(f(self.env), self.value);
        }
    };
}

// ============ Traced Comonad ============

/// Traced Comonad
/// Traced m a = m -> a
/// 根据追踪信息（通常是 Monoid）返回值
pub fn Traced(comptime M: type, comptime A: type) type {
    return struct {
        runFn: *const fn (M) A,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(f: *const fn (M) A) Self {
            return .{ .runFn = f };
        }

        // ============ 执行 ============

        pub fn run(self: Self, m: M) A {
            return self.runFn(m);
        }

        // ============ Comonad 操作 ============

        /// extract: 使用空追踪提取值
        pub fn extract(self: Self, empty: M) A {
            return self.runFn(empty);
        }

        // ============ Functor 操作 ============

        /// map: 对结果应用函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) TracedMap(M, A, B) {
            return TracedMap(M, A, B).init(self.runFn, f);
        }
    };
}

/// Traced 的 map 结果类型
pub fn TracedMap(comptime M: type, comptime A: type, comptime B: type) type {
    return struct {
        innerFn: *const fn (M) A,
        mapFn: *const fn (A) B,

        const Self = @This();

        pub fn init(innerFn: *const fn (M) A, mapFn: *const fn (A) B) Self {
            return .{ .innerFn = innerFn, .mapFn = mapFn };
        }

        pub fn run(self: Self, m: M) B {
            return self.mapFn(self.innerFn(m));
        }

        pub fn extract(self: Self, empty: M) B {
            return self.mapFn(self.innerFn(empty));
        }
    };
}

// ============ 测试 ============

test "Identity.extract" {
    const id = Identity(i32).init(42);
    try std.testing.expectEqual(@as(i32, 42), id.extract());
}

test "Identity.duplicate" {
    const id = Identity(i32).init(42);
    const dup = id.duplicate();
    try std.testing.expectEqual(@as(i32, 42), dup.extract().extract());
}

test "Identity.extend" {
    const id = Identity(i32).init(42);
    const extended = id.extend(i32, struct {
        fn f(w: Identity(i32)) i32 {
            return w.extract() * 2;
        }
    }.f);
    try std.testing.expectEqual(@as(i32, 84), extended.extract());
}

test "Identity.map" {
    const id = Identity(i32).init(21);
    const mapped = id.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    try std.testing.expectEqual(@as(i32, 42), mapped.extract());
}

test "Identity Comonad law: extract . duplicate = id" {
    const id = Identity(i32).init(42);
    const dup = id.duplicate();
    const extracted = dup.extract();
    try std.testing.expectEqual(id.extract(), extracted.extract());
}

test "NonEmpty.extract" {
    const ne = NonEmpty(i32).init(1, &[_]i32{ 2, 3, 4 });
    try std.testing.expectEqual(@as(i32, 1), ne.extract());
}

test "NonEmpty.length" {
    const ne = NonEmpty(i32).init(1, &[_]i32{ 2, 3, 4 });
    try std.testing.expectEqual(@as(usize, 4), ne.length());

    const singleton = NonEmpty(i32).singleton(42);
    try std.testing.expectEqual(@as(usize, 1), singleton.length());
}

test "NonEmpty.map" {
    const allocator = std.testing.allocator;
    const ne = NonEmpty(i32).init(1, &[_]i32{ 2, 3 });

    const mapped = try ne.map(allocator, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer allocator.free(mapped.tail_vals);

    try std.testing.expectEqual(@as(i32, 2), mapped.head_val);
    try std.testing.expectEqual(@as(i32, 4), mapped.tail_vals[0]);
    try std.testing.expectEqual(@as(i32, 6), mapped.tail_vals[1]);
}

test "NonEmpty.toSlice" {
    const allocator = std.testing.allocator;
    const ne = NonEmpty(i32).init(1, &[_]i32{ 2, 3 });

    const slice = try ne.toSlice(allocator);
    defer allocator.free(slice);

    try std.testing.expectEqual(@as(usize, 3), slice.len);
    try std.testing.expectEqual(@as(i32, 1), slice[0]);
    try std.testing.expectEqual(@as(i32, 2), slice[1]);
    try std.testing.expectEqual(@as(i32, 3), slice[2]);
}

test "Store.extract" {
    const store = Store(i32, i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, 5);

    try std.testing.expectEqual(@as(i32, 10), store.extract());
}

test "Store.peek" {
    const store = Store(i32, i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, 5);

    try std.testing.expectEqual(@as(i32, 20), store.peek(10));
    try std.testing.expectEqual(@as(i32, 10), store.peek(5));
}

test "Store.seek" {
    const store = Store(i32, i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, 5);

    const moved = store.seek(10);
    try std.testing.expectEqual(@as(i32, 20), moved.extract());
    try std.testing.expectEqual(@as(i32, 10), moved.position());
}

test "Store.seeks" {
    const store = Store(i32, i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, 5);

    const moved = store.seeks(struct {
        fn addOne(x: i32) i32 {
            return x + 1;
        }
    }.addOne);

    try std.testing.expectEqual(@as(i32, 6), moved.position());
    try std.testing.expectEqual(@as(i32, 12), moved.extract());
}

test "Store.map" {
    const store = Store(i32, i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f, 5);

    const mapped = store.map(i32, struct {
        fn addOne(x: i32) i32 {
            return x + 1;
        }
    }.addOne);

    // (5 * 2) + 1 = 11
    try std.testing.expectEqual(@as(i32, 11), mapped.extract());
}

test "Env.extract" {
    const env = Env([]const u8, i32).init("context", 42);
    try std.testing.expectEqual(@as(i32, 42), env.extract());
}

test "Env.ask" {
    const env = Env([]const u8, i32).init("context", 42);
    try std.testing.expectEqualStrings("context", env.ask());
}

test "Env.duplicate" {
    const env = Env([]const u8, i32).init("context", 42);
    const dup = env.duplicate();

    try std.testing.expectEqualStrings("context", dup.ask());
    try std.testing.expectEqual(@as(i32, 42), dup.extract().extract());
}

test "Env.extend" {
    const env = Env(i32, i32).init(10, 5);
    const extended = env.extend(i32, struct {
        fn f(w: Env(i32, i32)) i32 {
            return w.ask() + w.extract();
        }
    }.f);

    // 10 + 5 = 15
    try std.testing.expectEqual(@as(i32, 15), extended.extract());
    try std.testing.expectEqual(@as(i32, 10), extended.ask());
}

test "Env.map" {
    const env = Env([]const u8, i32).init("context", 21);
    const mapped = env.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), mapped.extract());
    try std.testing.expectEqualStrings("context", mapped.ask());
}

test "Env.local" {
    const env = Env(i32, i32).init(10, 42);
    const modified = env.local(struct {
        fn f(e: i32) i32 {
            return e * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 20), modified.ask());
    try std.testing.expectEqual(@as(i32, 42), modified.extract());
}

test "Traced.run" {
    const traced = Traced(i32, i32).init(struct {
        fn f(m: i32) i32 {
            return m + 10;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 15), traced.run(5));
    try std.testing.expectEqual(@as(i32, 20), traced.run(10));
}

test "Traced.extract" {
    const traced = Traced(i32, i32).init(struct {
        fn f(m: i32) i32 {
            return m + 10;
        }
    }.f);

    // extract 使用 0 作为空追踪
    try std.testing.expectEqual(@as(i32, 10), traced.extract(0));
}

test "Traced.map" {
    const traced = Traced(i32, i32).init(struct {
        fn f(m: i32) i32 {
            return m + 10;
        }
    }.f);

    const mapped = traced.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    // (5 + 10) * 2 = 30
    try std.testing.expectEqual(@as(i32, 30), mapped.run(5));
}
