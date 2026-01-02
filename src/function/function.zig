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

// ============ 柯里化 (Currying) ============

/// Curry2 类型 - 二元函数的柯里化结果
/// 由于 Zig 不支持闭包，使用结构体存储中间状态
pub fn Curry2(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        f: *const fn (A, B) C,

        const Self = @This();

        /// 创建柯里化函数
        pub fn init(f: *const fn (A, B) C) Self {
            return .{ .f = f };
        }

        /// 应用第一个参数，返回等待第二个参数的结构体
        pub fn apply(self: Self, a: A) Curry2Applied(A, B, C) {
            return Curry2Applied(A, B, C).init(self.f, a);
        }

        /// 直接调用原函数
        pub fn call(self: Self, a: A, b: B) C {
            return self.f(a, b);
        }
    };
}

/// Curry2Applied - 已应用第一个参数的柯里化函数
pub fn Curry2Applied(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        f: *const fn (A, B) C,
        a: A,

        const Self = @This();

        pub fn init(f: *const fn (A, B) C, a: A) Self {
            return .{ .f = f, .a = a };
        }

        /// 应用第二个参数，返回结果
        pub fn apply(self: Self, b: B) C {
            return self.f(self.a, b);
        }

        /// 别名
        pub fn call(self: Self, b: B) C {
            return self.apply(b);
        }
    };
}

/// 创建二元柯里化函数
pub fn curry2(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (A, B) C,
) Curry2(A, B, C) {
    return Curry2(A, B, C).init(f);
}

/// Curry3 类型 - 三元函数的柯里化结果
pub fn Curry3(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        f: *const fn (A, B, C) D,

        const Self = @This();

        pub fn init(f: *const fn (A, B, C) D) Self {
            return .{ .f = f };
        }

        /// 应用第一个参数
        pub fn apply(self: Self, a: A) Curry3Applied1(A, B, C, D) {
            return Curry3Applied1(A, B, C, D).init(self.f, a);
        }

        /// 直接调用原函数
        pub fn call(self: Self, a: A, b: B, c: C) D {
            return self.f(a, b, c);
        }
    };
}

/// Curry3Applied1 - 已应用第一个参数
pub fn Curry3Applied1(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        f: *const fn (A, B, C) D,
        a: A,

        const Self = @This();

        pub fn init(f: *const fn (A, B, C) D, a: A) Self {
            return .{ .f = f, .a = a };
        }

        /// 应用第二个参数
        pub fn apply(self: Self, b: B) Curry3Applied2(A, B, C, D) {
            return Curry3Applied2(A, B, C, D).init(self.f, self.a, b);
        }
    };
}

/// Curry3Applied2 - 已应用前两个参数
pub fn Curry3Applied2(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        f: *const fn (A, B, C) D,
        a: A,
        b: B,

        const Self = @This();

        pub fn init(f: *const fn (A, B, C) D, a: A, b: B) Self {
            return .{ .f = f, .a = a, .b = b };
        }

        /// 应用第三个参数，返回最终结果
        pub fn apply(self: Self, c: C) D {
            return self.f(self.a, self.b, c);
        }

        pub fn call(self: Self, c: C) D {
            return self.apply(c);
        }
    };
}

/// 创建三元柯里化函数
pub fn curry3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    f: *const fn (A, B, C) D,
) Curry3(A, B, C, D) {
    return Curry3(A, B, C, D).init(f);
}

/// 反柯里化：将 Curry2 转换回普通二元函数
pub fn uncurry2(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    curried: Curry2(A, B, C),
) *const fn (A, B) C {
    _ = curried;
    return struct {
        fn uncurried(a: A, b: B) C {
            // 由于我们需要访问原始函数，这里返回一个新函数
            // 在实际使用中，可以直接调用 curried.call(a, b)
            _ = a;
            _ = b;
            unreachable; // 实际实现见下面的 uncurry2Call
        }
    }.uncurried;
}

/// 更实用的反柯里化：直接调用
pub fn uncurry2Call(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    curried: Curry2(A, B, C),
    a: A,
    b: B,
) C {
    return curried.call(a, b);
}

/// 更实用的反柯里化：直接调用三元函数
pub fn uncurry3Call(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    curried: Curry3(A, B, C, D),
    a: A,
    b: B,
    c: C,
) D {
    return curried.call(a, b, c);
}

// ============ 常量函数 ============

/// 常量函数：忽略参数，始终返回固定值
/// const_(x)(y) = x
pub fn Const(comptime A: type, comptime B: type) type {
    return struct {
        value: A,

        const Self = @This();

        pub fn init(value: A) Self {
            return .{ .value = value };
        }

        pub fn apply(self: Self, _: B) A {
            return self.value;
        }
    };
}

/// 创建常量函数
pub fn const_(comptime A: type, comptime B: type, value: A) Const(A, B) {
    return Const(A, B).init(value);
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

// ============ 柯里化测试 ============

test "curry2 basic" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const curriedAdd = curry2(i32, i32, i32, add);

    // 直接调用
    try std.testing.expectEqual(@as(i32, 8), curriedAdd.call(3, 5));

    // 柯里化调用
    const add3 = curriedAdd.apply(3);
    try std.testing.expectEqual(@as(i32, 8), add3.apply(5));
    try std.testing.expectEqual(@as(i32, 13), add3.apply(10));
}

test "curry2 with different types" {
    const repeat = struct {
        fn f(s: []const u8, n: i32) i32 {
            return @as(i32, @intCast(s.len)) * n;
        }
    }.f;

    const curriedRepeat = curry2([]const u8, i32, i32, repeat);
    const repeatHello = curriedRepeat.apply("hello");

    try std.testing.expectEqual(@as(i32, 15), repeatHello.apply(3));
    try std.testing.expectEqual(@as(i32, 25), repeatHello.apply(5));
}

test "curry3 basic" {
    const add3 = struct {
        fn f(a: i32, b: i32, c: i32) i32 {
            return a + b + c;
        }
    }.f;

    const curried = curry3(i32, i32, i32, i32, add3);

    // 直接调用
    try std.testing.expectEqual(@as(i32, 6), curried.call(1, 2, 3));

    // 逐步应用
    const add1 = curried.apply(1);
    const add1_2 = add1.apply(2);
    try std.testing.expectEqual(@as(i32, 6), add1_2.apply(3));
    try std.testing.expectEqual(@as(i32, 13), add1_2.apply(10));
}

test "curry3 multiply" {
    const mul3 = struct {
        fn f(a: i32, b: i32, c: i32) i32 {
            return a * b * c;
        }
    }.f;

    const curried = curry3(i32, i32, i32, i32, mul3);
    const mul2 = curried.apply(2);
    const mul2_3 = mul2.apply(3);

    try std.testing.expectEqual(@as(i32, 24), mul2_3.apply(4)); // 2 * 3 * 4 = 24
    try std.testing.expectEqual(@as(i32, 30), mul2_3.apply(5)); // 2 * 3 * 5 = 30
}

test "uncurry2Call" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const curried = curry2(i32, i32, i32, add);
    const result = uncurry2Call(i32, i32, i32, curried, 3, 5);
    try std.testing.expectEqual(@as(i32, 8), result);
}

test "uncurry3Call" {
    const add3 = struct {
        fn f(a: i32, b: i32, c: i32) i32 {
            return a + b + c;
        }
    }.f;

    const curried = curry3(i32, i32, i32, i32, add3);
    const result = uncurry3Call(i32, i32, i32, i32, curried, 1, 2, 3);
    try std.testing.expectEqual(@as(i32, 6), result);
}

test "const_ function" {
    const always42 = const_(i32, []const u8, 42);

    try std.testing.expectEqual(@as(i32, 42), always42.apply("hello"));
    try std.testing.expectEqual(@as(i32, 42), always42.apply("world"));
    try std.testing.expectEqual(@as(i32, 42), always42.apply(""));
}

test "curry2 with Curry2Applied reuse" {
    const sub = struct {
        fn f(a: i32, b: i32) i32 {
            return a - b;
        }
    }.f;

    const curried = curry2(i32, i32, i32, sub);
    const sub10 = curried.apply(10);
    const sub20 = curried.apply(20);

    // 10 - 3 = 7
    try std.testing.expectEqual(@as(i32, 7), sub10.apply(3));
    // 20 - 3 = 17
    try std.testing.expectEqual(@as(i32, 17), sub20.apply(3));
}
