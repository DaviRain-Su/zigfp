//! Tuple - 函数式元组工具
//!
//! 提供 Pair 和 Triple 类型，以及相关的函数式操作。
//! 这些是函数式编程中常用的积类型。

const std = @import("std");

/// Pair - 二元组
/// 存储两个可能不同类型的值
pub fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        const Self = @This();

        fst: A,
        snd: B,

        /// 创建 Pair
        pub fn init(a: A, b: B) Self {
            return .{ .fst = a, .snd = b };
        }

        /// 获取第一个元素
        pub fn first(self: Self) A {
            return self.fst;
        }

        /// 获取第二个元素
        pub fn second(self: Self) B {
            return self.snd;
        }

        /// 交换两个元素
        pub fn swap(self: Self) Pair(B, A) {
            return Pair(B, A).init(self.snd, self.fst);
        }

        /// 映射第一个元素
        pub fn mapFst(self: Self, comptime C: type, f: fn (A) C) Pair(C, B) {
            return Pair(C, B).init(f(self.fst), self.snd);
        }

        /// 映射第二个元素
        pub fn mapSnd(self: Self, comptime C: type, f: fn (B) C) Pair(A, C) {
            return Pair(A, C).init(self.fst, f(self.snd));
        }

        /// 双向映射
        pub fn bimap(self: Self, comptime C: type, comptime D: type, f: fn (A) C, g: fn (B) D) Pair(C, D) {
            return Pair(C, D).init(f(self.fst), g(self.snd));
        }

        /// 应用函数到两个元素（相同类型时）
        pub fn both(self: Self, comptime C: type, f: fn (A) C) Pair(C, C) {
            // 只有当 A == B 时才能使用
            if (A != B) @compileError("both requires A == B");
            return Pair(C, C).init(f(self.fst), f(@as(A, self.snd)));
        }

        /// 转换为数组（仅当 A == B）
        pub fn toArray(self: Self) [2]A {
            if (A != B) @compileError("toArray requires A == B");
            return .{ self.fst, @as(A, self.snd) };
        }

        /// 折叠为单一值
        pub fn fold(self: Self, comptime C: type, f: fn (A, B) C) C {
            return f(self.fst, self.snd);
        }
    };
}

/// Triple - 三元组
/// 存储三个可能不同类型的值
pub fn Triple(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        const Self = @This();

        fst: A,
        snd: B,
        thd: C,

        /// 创建 Triple
        pub fn init(a: A, b: B, c: C) Self {
            return .{ .fst = a, .snd = b, .thd = c };
        }

        /// 获取第一个元素
        pub fn first(self: Self) A {
            return self.fst;
        }

        /// 获取第二个元素
        pub fn second(self: Self) B {
            return self.snd;
        }

        /// 获取第三个元素
        pub fn third(self: Self) C {
            return self.thd;
        }

        /// 映射第一个元素
        pub fn mapFst(self: Self, comptime D: type, f: fn (A) D) Triple(D, B, C) {
            return Triple(D, B, C).init(f(self.fst), self.snd, self.thd);
        }

        /// 映射第二个元素
        pub fn mapSnd(self: Self, comptime D: type, f: fn (B) D) Triple(A, D, C) {
            return Triple(A, D, C).init(self.fst, f(self.snd), self.thd);
        }

        /// 映射第三个元素
        pub fn mapThd(self: Self, comptime D: type, f: fn (C) D) Triple(A, B, D) {
            return Triple(A, B, D).init(self.fst, self.snd, f(self.thd));
        }

        /// 三向映射
        pub fn trimap(
            self: Self,
            comptime D: type,
            comptime E: type,
            comptime F: type,
            fa: fn (A) D,
            fb: fn (B) E,
            fc: fn (C) F,
        ) Triple(D, E, F) {
            return Triple(D, E, F).init(fa(self.fst), fb(self.snd), fc(self.thd));
        }

        /// 转换为数组（仅当 A == B == C）
        pub fn toArray(self: Self) [3]A {
            if (A != B or B != C) @compileError("toArray requires A == B == C");
            return .{ self.fst, @as(A, self.snd), @as(A, self.thd) };
        }

        /// 折叠为单一值
        pub fn fold(self: Self, comptime D: type, f: fn (A, B, C) D) D {
            return f(self.fst, self.snd, self.thd);
        }

        /// 转换为 Pair（丢弃第三个元素）
        pub fn toPairFst(self: Self) Pair(A, B) {
            return Pair(A, B).init(self.fst, self.snd);
        }

        /// 转换为 Pair（丢弃第一个元素）
        pub fn toPairSnd(self: Self) Pair(B, C) {
            return Pair(B, C).init(self.snd, self.thd);
        }
    };
}

// ============ 便捷构造函数 ============

/// 创建 Pair
pub fn pair(comptime A: type, comptime B: type, a: A, b: B) Pair(A, B) {
    return Pair(A, B).init(a, b);
}

/// 创建 Triple
pub fn triple(comptime A: type, comptime B: type, comptime C: type, a: A, b: B, c: C) Triple(A, B, C) {
    return Triple(A, B, C).init(a, b, c);
}

// ============ 工具函数 ============

/// 复制值为 Pair
pub fn dup(comptime A: type, a: A) Pair(A, A) {
    return Pair(A, A).init(a, a);
}

/// fanout - 对同一输入应用两个函数，结果组成 Pair
/// (f &&& g)(x) = (f(x), g(x))
pub fn fanout(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: fn (A) B,
    g: fn (A) C,
    a: A,
) Pair(B, C) {
    return Pair(B, C).init(f(a), g(a));
}

/// fanout3 - 对同一输入应用三个函数，结果组成 Triple
pub fn fanout3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    f: fn (A) B,
    g: fn (A) C,
    h: fn (A) D,
    a: A,
) Triple(B, C, D) {
    return Triple(B, C, D).init(f(a), g(a), h(a));
}

/// 左结合变换: ((A, B), C) -> (A, (B, C))
pub fn assocR(comptime A: type, comptime B: type, comptime C: type, p: Pair(Pair(A, B), C)) Pair(A, Pair(B, C)) {
    return Pair(A, Pair(B, C)).init(p.fst.fst, Pair(B, C).init(p.fst.snd, p.snd));
}

/// 右结合变换: (A, (B, C)) -> ((A, B), C)
pub fn assocL(comptime A: type, comptime B: type, comptime C: type, p: Pair(A, Pair(B, C))) Pair(Pair(A, B), C) {
    return Pair(Pair(A, B), C).init(Pair(A, B).init(p.fst, p.snd.fst), p.snd.snd);
}

/// 从数组创建 Pair
pub fn pairFromArray(comptime T: type, arr: [2]T) Pair(T, T) {
    return Pair(T, T).init(arr[0], arr[1]);
}

/// 从数组创建 Triple
pub fn tripleFromArray(comptime T: type, arr: [3]T) Triple(T, T, T) {
    return Triple(T, T, T).init(arr[0], arr[1], arr[2]);
}

/// 使用 Pair 进行柯里化
pub fn curryPair(comptime A: type, comptime B: type, comptime C: type, f: fn (Pair(A, B)) C) fn (A) fn (B) C {
    return struct {
        fn outer(a: A) fn (B) C {
            return struct {
                fn inner(b: B) C {
                    return f(Pair(A, B).init(a, b));
                }
            }.inner;
        }
    }.outer;
}

/// 使用 Pair 进行反柯里化
pub fn uncurryPair(comptime A: type, comptime B: type, comptime C: type, f: fn (A, B) C, p: Pair(A, B)) C {
    return f(p.fst, p.snd);
}

// ============ 测试 ============

test "Pair basic operations" {
    const p = Pair(i32, []const u8).init(42, "hello");

    try std.testing.expectEqual(@as(i32, 42), p.first());
    try std.testing.expectEqualStrings("hello", p.second());
}

test "Pair swap" {
    const p = Pair(i32, []const u8).init(42, "hello");
    const swapped = p.swap();

    try std.testing.expectEqualStrings("hello", swapped.first());
    try std.testing.expectEqual(@as(i32, 42), swapped.second());
}

test "Pair mapFst" {
    const p = Pair(i32, []const u8).init(21, "hello");

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const mapped = p.mapFst(i32, double);
    try std.testing.expectEqual(@as(i32, 42), mapped.first());
    try std.testing.expectEqualStrings("hello", mapped.second());
}

test "Pair mapSnd" {
    const p = Pair(i32, []const u8).init(42, "hello");

    const len = struct {
        fn f(s: []const u8) usize {
            return s.len;
        }
    }.f;

    const mapped = p.mapSnd(usize, len);
    try std.testing.expectEqual(@as(i32, 42), mapped.first());
    try std.testing.expectEqual(@as(usize, 5), mapped.second());
}

test "Pair bimap" {
    const p = Pair(i32, i32).init(10, 20);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const tripleIt = struct {
        fn f(x: i32) i32 {
            return x * 3;
        }
    }.f;

    const mapped = p.bimap(i32, i32, double, tripleIt);
    try std.testing.expectEqual(@as(i32, 20), mapped.first());
    try std.testing.expectEqual(@as(i32, 60), mapped.second());
}

test "Pair toArray" {
    const p = Pair(i32, i32).init(1, 2);
    const arr = p.toArray();
    try std.testing.expectEqual(@as(i32, 1), arr[0]);
    try std.testing.expectEqual(@as(i32, 2), arr[1]);
}

test "Pair fold" {
    const p = Pair(i32, i32).init(10, 20);

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    try std.testing.expectEqual(@as(i32, 30), p.fold(i32, add));
}

test "Triple basic operations" {
    const t = Triple(i32, []const u8, bool).init(42, "hello", true);

    try std.testing.expectEqual(@as(i32, 42), t.first());
    try std.testing.expectEqualStrings("hello", t.second());
    try std.testing.expect(t.third());
}

test "Triple mapFst" {
    const t = Triple(i32, []const u8, bool).init(21, "hello", true);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const mapped = t.mapFst(i32, double);
    try std.testing.expectEqual(@as(i32, 42), mapped.first());
    try std.testing.expectEqualStrings("hello", mapped.second());
    try std.testing.expect(mapped.third());
}

test "Triple trimap" {
    const t = Triple(i32, i32, i32).init(1, 2, 3);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const tripleIt = struct {
        fn f(x: i32) i32 {
            return x * 3;
        }
    }.f;

    const quad = struct {
        fn f(x: i32) i32 {
            return x * 4;
        }
    }.f;

    const mapped = t.trimap(i32, i32, i32, double, tripleIt, quad);
    try std.testing.expectEqual(@as(i32, 2), mapped.first());
    try std.testing.expectEqual(@as(i32, 6), mapped.second());
    try std.testing.expectEqual(@as(i32, 12), mapped.third());
}

test "Triple toPair" {
    const t = Triple(i32, []const u8, bool).init(42, "hello", true);

    const p1 = t.toPairFst();
    try std.testing.expectEqual(@as(i32, 42), p1.first());
    try std.testing.expectEqualStrings("hello", p1.second());

    const p2 = t.toPairSnd();
    try std.testing.expectEqualStrings("hello", p2.first());
    try std.testing.expect(p2.second());
}

test "convenience constructors" {
    const p = pair(i32, []const u8, 42, "hello");
    try std.testing.expectEqual(@as(i32, 42), p.first());

    const t = triple(i32, i32, i32, 1, 2, 3);
    try std.testing.expectEqual(@as(i32, 1), t.first());
    try std.testing.expectEqual(@as(i32, 2), t.second());
    try std.testing.expectEqual(@as(i32, 3), t.third());
}

test "dup" {
    const p = dup(i32, 42);
    try std.testing.expectEqual(@as(i32, 42), p.first());
    try std.testing.expectEqual(@as(i32, 42), p.second());
}

test "fanout" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const negate = struct {
        fn f(x: i32) i32 {
            return -x;
        }
    }.f;

    const p = fanout(i32, i32, i32, double, negate, 5);
    try std.testing.expectEqual(@as(i32, 10), p.first());
    try std.testing.expectEqual(@as(i32, -5), p.second());
}

test "fanout3" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const negate = struct {
        fn f(x: i32) i32 {
            return -x;
        }
    }.f;

    const square = struct {
        fn f(x: i32) i32 {
            return x * x;
        }
    }.f;

    const t = fanout3(i32, i32, i32, i32, double, negate, square, 3);
    try std.testing.expectEqual(@as(i32, 6), t.first());
    try std.testing.expectEqual(@as(i32, -3), t.second());
    try std.testing.expectEqual(@as(i32, 9), t.third());
}

test "assocR and assocL" {
    // ((1, 2), 3) -> (1, (2, 3))
    const nested_left = Pair(Pair(i32, i32), i32).init(Pair(i32, i32).init(1, 2), 3);
    const right_assoc = assocR(i32, i32, i32, nested_left);

    try std.testing.expectEqual(@as(i32, 1), right_assoc.first());
    try std.testing.expectEqual(@as(i32, 2), right_assoc.second().first());
    try std.testing.expectEqual(@as(i32, 3), right_assoc.second().second());

    // (1, (2, 3)) -> ((1, 2), 3)
    const nested_right = Pair(i32, Pair(i32, i32)).init(1, Pair(i32, i32).init(2, 3));
    const left_assoc = assocL(i32, i32, i32, nested_right);

    try std.testing.expectEqual(@as(i32, 1), left_assoc.first().first());
    try std.testing.expectEqual(@as(i32, 2), left_assoc.first().second());
    try std.testing.expectEqual(@as(i32, 3), left_assoc.second());
}

test "pairFromArray and tripleFromArray" {
    const p = pairFromArray(i32, .{ 1, 2 });
    try std.testing.expectEqual(@as(i32, 1), p.first());
    try std.testing.expectEqual(@as(i32, 2), p.second());

    const t = tripleFromArray(i32, .{ 1, 2, 3 });
    try std.testing.expectEqual(@as(i32, 1), t.first());
    try std.testing.expectEqual(@as(i32, 2), t.second());
    try std.testing.expectEqual(@as(i32, 3), t.third());
}

test "uncurryPair" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const p = Pair(i32, i32).init(10, 20);
    const result = uncurryPair(i32, i32, i32, add, p);
    try std.testing.expectEqual(@as(i32, 30), result);
}
