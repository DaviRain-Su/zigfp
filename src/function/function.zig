//! 函数工具 - 函数组合、柯里化等
//!
//! 提供函数式编程中常用的函数操作工具。
//! 注意：由于 Zig 不支持闭包，某些函数需要使用 comptime 参数。

const std = @import("std");

/// 函数组合: compose(f, g)(x) = f(g(x))
/// 先执行 g，再执行 f
/// 注意：f 和 g 必须是 comptime 已知的
pub fn compose(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime f: *const fn (B) C,
    comptime g: *const fn (A) B,
) *const fn (A) C {
    return struct {
        fn composed(a: A) C {
            return f(g(a));
        }
    }.composed;
}

/// 恒等函数: identity(x) = x
pub fn identity(comptime T: type) *const fn (T) T {
    return struct {
        fn id(x: T) T {
            return x;
        }
    }.id;
}

/// 参数翻转: flip(f)(b, a) = f(a, b)
pub fn flip(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime f: *const fn (A, B) C,
) *const fn (B, A) C {
    return struct {
        fn flipped(b: B, a: A) C {
            return f(a, b);
        }
    }.flipped;
}

/// 应用函数: apply(f, x) = f(x)
pub fn apply(
    comptime A: type,
    comptime B: type,
    f: *const fn (A) B,
    x: A,
) B {
    return f(x);
}

/// 管道操作: pipe(x, f) = f(x)
/// 与 apply 相同，但参数顺序不同，更适合链式调用
pub fn pipe(
    comptime A: type,
    comptime B: type,
    x: A,
    f: *const fn (A) B,
) B {
    return f(x);
}

/// 二元函数转一元: 将 f(a, b) 转换为 f((a, b))
pub fn tupled(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime f: *const fn (A, B) C,
) *const fn (struct { A, B }) C {
    return struct {
        fn tupledFn(args: struct { A, B }) C {
            return f(args[0], args[1]);
        }
    }.tupledFn;
}

/// 将元组参数函数转换为二元函数
pub fn untupled(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime f: *const fn (struct { A, B }) C,
) *const fn (A, B) C {
    return struct {
        fn untupledFn(a: A, b: B) C {
            return f(.{ a, b });
        }
    }.untupledFn;
}

/// 部分应用辅助结构：用于模拟柯里化
/// 由于 Zig 不支持闭包，使用结构体存储捕获的值
pub fn Partial(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        f: *const fn (A, B) C,
        a: A,

        const Self = @This();

        pub fn init(f: *const fn (A, B) C, a: A) Self {
            return .{ .f = f, .a = a };
        }

        pub fn call(self: Self, b: B) C {
            return self.f(self.a, b);
        }
    };
}

/// 创建部分应用
pub fn partial(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (A, B) C,
    a: A,
) Partial(A, B, C) {
    return Partial(A, B, C).init(f, a);
}

// ============ 测试 ============

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

test "compose" {
    // compose(double, addOne)(5) = double(addOne(5)) = double(6) = 12
    const composed = compose(i32, i32, i32, double, addOne);
    try std.testing.expectEqual(@as(i32, 12), composed(5));

    // compose(addOne, double)(5) = addOne(double(5)) = addOne(10) = 11
    const composed2 = compose(i32, i32, i32, addOne, double);
    try std.testing.expectEqual(@as(i32, 11), composed2(5));
}

test "identity" {
    const id_i32 = identity(i32);
    try std.testing.expectEqual(@as(i32, 42), id_i32(42));

    const id_bool = identity(bool);
    try std.testing.expectEqual(true, id_bool(true));
}

test "flip" {
    const subtract = struct {
        fn f(a: i32, b: i32) i32 {
            return a - b;
        }
    }.f;

    const flipped = flip(i32, i32, i32, subtract);
    // flipped(3, 10) = subtract(10, 3) = 7
    try std.testing.expectEqual(@as(i32, 7), flipped(3, 10));
}

test "apply" {
    const result = apply(i32, i32, double, 21);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "pipe" {
    const result = pipe(i32, i32, 21, double);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "tupled" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const tupledAdd = tupled(i32, i32, i32, add);
    try std.testing.expectEqual(@as(i32, 5), tupledAdd(.{ 2, 3 }));
}

test "untupled" {
    const addTuple = struct {
        fn f(args: struct { i32, i32 }) i32 {
            return args[0] + args[1];
        }
    }.f;

    const untupledAdd = untupled(i32, i32, i32, addTuple);
    try std.testing.expectEqual(@as(i32, 5), untupledAdd(2, 3));
}

test "compose with type conversion" {
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

    const composed = compose(i32, f64, f64, doubleFloat, intToFloat);
    try std.testing.expectEqual(@as(f64, 42.0), composed(21));
}

test "compose chain" {
    const f1 = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;
    const f2 = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;
    const f3 = struct {
        fn f(x: i32) i32 {
            return x - 3;
        }
    }.f;

    // f1(f2(f3(x))) = (x - 3) * 2 + 1
    const chain = compose(i32, i32, i32, f1, compose(i32, i32, i32, f2, f3));
    // chain(10) = (10 - 3) * 2 + 1 = 7 * 2 + 1 = 15
    try std.testing.expectEqual(@as(i32, 15), chain(10));
}

test "partial application" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const add5 = partial(i32, i32, i32, add, 5);
    try std.testing.expectEqual(@as(i32, 8), add5.call(3));
    try std.testing.expectEqual(@as(i32, 15), add5.call(10));
}
