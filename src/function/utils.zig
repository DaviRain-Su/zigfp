//! Utils - 实用函数式编程工具函数
//!
//! 提供常用的函数式编程工具函数。

const std = @import("std");
const root = @import("../root.zig");
const Option = root.Option;

/// 条件执行 - 如果条件为真，返回 Some(value)，否则返回 None
pub fn when(comptime T: type, condition: bool, value: T) Option(T) {
    if (condition) {
        return Option(T).Some(value);
    } else {
        return Option(T).None();
    }
}

/// 条件执行（惰性版本）- 如果条件为真，执行函数并返回 Some，否则返回 None
pub fn whenLazy(comptime T: type, condition: bool, f: *const fn () T) Option(T) {
    if (condition) {
        return Option(T).Some(f());
    } else {
        return Option(T).None();
    }
}

/// 否定条件执行 - 如果条件为假，返回 Some(value)，否则返回 None
pub fn unless(comptime T: type, condition: bool, value: T) Option(T) {
    return when(T, !condition, value);
}

/// 守卫表达式 - 如果条件为真，返回 Some(())，否则返回 None
pub fn guard(condition: bool) Option(void) {
    if (condition) {
        return Option(void).Some({});
    } else {
        return Option(void).None();
    }
}

/// 条件表达式 - if-then-else 的函数式版本
pub fn ifThenElse(comptime T: type, condition: bool, thenValue: T, elseValue: T) T {
    return if (condition) thenValue else elseValue;
}

/// 条件表达式（惰性版本）
pub fn ifThenElseLazy(
    comptime T: type,
    condition: bool,
    thenFn: *const fn () T,
    elseFn: *const fn () T,
) T {
    return if (condition) thenFn() else elseFn();
}

/// 应用函数 N 次
pub fn applyN(comptime T: type, f: *const fn (T) T, n: usize, initial: T) T {
    var result = initial;
    for (0..n) |_| {
        result = f(result);
    }
    return result;
}

/// 重复直到条件满足
pub fn until(comptime T: type, predicate: *const fn (T) bool, f: *const fn (T) T, initial: T) T {
    var result = initial;
    while (!predicate(result)) {
        result = f(result);
    }
    return result;
}

/// 重复直到条件满足（带最大迭代次数）
pub fn untilMax(
    comptime T: type,
    predicate: *const fn (T) bool,
    f: *const fn (T) T,
    initial: T,
    maxIter: usize,
) struct { value: T, iterations: usize } {
    var result = initial;
    var iterations: usize = 0;
    while (!predicate(result) and iterations < maxIter) {
        result = f(result);
        iterations += 1;
    }
    return .{ .value = result, .iterations = iterations };
}

/// 重复直到条件不满足
pub fn while_(comptime T: type, predicate: *const fn (T) bool, f: *const fn (T) T, initial: T) T {
    var result = initial;
    while (predicate(result)) {
        result = f(result);
    }
    return result;
}

/// on 组合子 - 使用函数变换输入后应用二元操作
/// on(op, f)(a, b) = op(f(a), f(b))
pub fn on(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    op: *const fn (B, B) C,
    f: *const fn (A) B,
) *const fn (A, A) C {
    return &struct {
        fn combined(a1: A, a2: A) C {
            return op(f(a1), f(a2));
        }
    }.combined;
}

/// 布尔操作的函数式版本
pub const bool_ = struct {
    /// 逻辑与
    pub fn and_(a: bool, b: bool) bool {
        return a and b;
    }

    /// 逻辑或
    pub fn or_(a: bool, b: bool) bool {
        return a or b;
    }

    /// 逻辑非
    pub fn not_(a: bool) bool {
        return !a;
    }

    /// 逻辑异或
    pub fn xor_(a: bool, b: bool) bool {
        return (a or b) and !(a and b);
    }

    /// 蕴含
    pub fn implies(a: bool, b: bool) bool {
        return !a or b;
    }

    /// 等价
    pub fn iff(a: bool, b: bool) bool {
        return a == b;
    }
};

/// 数值操作的函数式版本
pub fn numeric(comptime T: type) type {
    return struct {
        /// 加法
        pub fn add(a: T, b: T) T {
            return a + b;
        }

        /// 减法
        pub fn sub(a: T, b: T) T {
            return a - b;
        }

        /// 乘法
        pub fn mul(a: T, b: T) T {
            return a * b;
        }

        /// 除法
        pub fn div(a: T, b: T) T {
            return @divTrunc(a, b);
        }

        /// 取模
        pub fn mod(a: T, b: T) T {
            return @mod(a, b);
        }

        /// 取反
        pub fn negate(a: T) T {
            return -a;
        }

        /// 绝对值
        pub fn abs(a: T) T {
            return if (a < 0) -a else a;
        }

        /// 符号函数
        pub fn signum(a: T) T {
            if (a < 0) return -1;
            if (a > 0) return 1;
            return 0;
        }

        /// 后继
        pub fn succ(a: T) T {
            return a + 1;
        }

        /// 前驱
        pub fn pred(a: T) T {
            return a - 1;
        }

        /// 是否为偶数
        pub fn isEven(a: T) bool {
            return @mod(a, 2) == 0;
        }

        /// 是否为奇数
        pub fn isOdd(a: T) bool {
            return @mod(a, 2) != 0;
        }

        /// 是否为零
        pub fn isZero(a: T) bool {
            return a == 0;
        }

        /// 是否为正数
        pub fn isPositive(a: T) bool {
            return a > 0;
        }

        /// 是否为负数
        pub fn isNegative(a: T) bool {
            return a < 0;
        }
    };
}

/// 比较操作的函数式版本
pub fn comparing(comptime T: type) type {
    return struct {
        pub fn eq(a: T, b: T) bool {
            return a == b;
        }

        pub fn neq(a: T, b: T) bool {
            return a != b;
        }

        pub fn lt(a: T, b: T) bool {
            return a < b;
        }

        pub fn le(a: T, b: T) bool {
            return a <= b;
        }

        pub fn gt(a: T, b: T) bool {
            return a > b;
        }

        pub fn ge(a: T, b: T) bool {
            return a >= b;
        }
    };
}

/// 创建一个总是返回相同值的函数
pub fn always(comptime T: type, value: T) *const fn () T {
    return &struct {
        fn f() T {
            return value;
        }
    }.f;
}

/// 吸收第一个参数，返回第二个
pub fn constSecond(comptime A: type, comptime B: type, _: A, b: B) B {
    return b;
}

/// 吸收第二个参数，返回第一个
pub fn constFirst(comptime A: type, comptime B: type, a: A, _: B) A {
    return a;
}

// ============ 测试 ============

test "when and unless" {
    const result1 = when(i32, true, 42);
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(i32, 42), result1.unwrap());

    const result2 = when(i32, false, 42);
    try std.testing.expect(result2.isNone());

    const result3 = unless(i32, true, 42);
    try std.testing.expect(result3.isNone());

    const result4 = unless(i32, false, 42);
    try std.testing.expect(result4.isSome());
}

test "whenLazy" {
    const f = struct {
        fn func() i32 {
            return 42;
        }
    }.func;

    const result1 = whenLazy(i32, true, f);
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(i32, 42), result1.unwrap());

    const result2 = whenLazy(i32, false, f);
    try std.testing.expect(result2.isNone());
}

test "guard" {
    const result1 = guard(true);
    try std.testing.expect(result1.isSome());

    const result2 = guard(false);
    try std.testing.expect(result2.isNone());
}

test "ifThenElse" {
    try std.testing.expectEqual(@as(i32, 10), ifThenElse(i32, true, 10, 20));
    try std.testing.expectEqual(@as(i32, 20), ifThenElse(i32, false, 10, 20));
}

test "applyN" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    try std.testing.expectEqual(@as(i32, 8), applyN(i32, double, 3, 1));
    try std.testing.expectEqual(@as(i32, 5), applyN(i32, double, 0, 5));
}

test "until" {
    const isGreaterThan10 = struct {
        fn f(x: i32) bool {
            return x > 10;
        }
    }.f;

    const increment = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    try std.testing.expectEqual(@as(i32, 11), until(i32, isGreaterThan10, increment, 0));
}

test "untilMax" {
    const neverTrue = struct {
        fn f(_: i32) bool {
            return false;
        }
    }.f;

    const increment = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result = untilMax(i32, neverTrue, increment, 0, 5);
    try std.testing.expectEqual(@as(i32, 5), result.value);
    try std.testing.expectEqual(@as(usize, 5), result.iterations);
}

test "while_" {
    const lessThan10 = struct {
        fn f(x: i32) bool {
            return x < 10;
        }
    }.f;

    const increment = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    try std.testing.expectEqual(@as(i32, 10), while_(i32, lessThan10, increment, 0));
}

test "bool_ operations" {
    try std.testing.expect(bool_.and_(true, true));
    try std.testing.expect(!bool_.and_(true, false));

    try std.testing.expect(bool_.or_(true, false));
    try std.testing.expect(!bool_.or_(false, false));

    try std.testing.expect(bool_.not_(false));
    try std.testing.expect(!bool_.not_(true));

    try std.testing.expect(bool_.xor_(true, false));
    try std.testing.expect(!bool_.xor_(true, true));

    try std.testing.expect(bool_.implies(false, false));
    try std.testing.expect(bool_.implies(false, true));
    try std.testing.expect(!bool_.implies(true, false));

    try std.testing.expect(bool_.iff(true, true));
    try std.testing.expect(bool_.iff(false, false));
    try std.testing.expect(!bool_.iff(true, false));
}

test "numeric operations" {
    const int = numeric(i32);

    try std.testing.expectEqual(@as(i32, 5), int.add(2, 3));
    try std.testing.expectEqual(@as(i32, -1), int.sub(2, 3));
    try std.testing.expectEqual(@as(i32, 6), int.mul(2, 3));
    try std.testing.expectEqual(@as(i32, 2), int.div(7, 3));
    try std.testing.expectEqual(@as(i32, 1), int.mod(7, 3));
    try std.testing.expectEqual(@as(i32, -5), int.negate(5));
    try std.testing.expectEqual(@as(i32, 5), int.abs(-5));
    try std.testing.expectEqual(@as(i32, -1), int.signum(-10));
    try std.testing.expectEqual(@as(i32, 1), int.signum(10));
    try std.testing.expectEqual(@as(i32, 0), int.signum(0));
    try std.testing.expectEqual(@as(i32, 6), int.succ(5));
    try std.testing.expectEqual(@as(i32, 4), int.pred(5));
    try std.testing.expect(int.isEven(4));
    try std.testing.expect(!int.isEven(5));
    try std.testing.expect(int.isOdd(5));
    try std.testing.expect(int.isZero(0));
    try std.testing.expect(int.isPositive(5));
    try std.testing.expect(int.isNegative(-5));
}

test "comparing operations" {
    const cmp = comparing(i32);

    try std.testing.expect(cmp.eq(5, 5));
    try std.testing.expect(cmp.neq(5, 6));
    try std.testing.expect(cmp.lt(5, 6));
    try std.testing.expect(cmp.le(5, 5));
    try std.testing.expect(cmp.gt(6, 5));
    try std.testing.expect(cmp.ge(5, 5));
}

test "constFirst and constSecond" {
    try std.testing.expectEqual(@as(i32, 10), constFirst(i32, []const u8, 10, "hello"));
    try std.testing.expectEqualStrings("hello", constSecond(i32, []const u8, 10, "hello"));
}
