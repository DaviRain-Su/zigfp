//! Monoid - 可组合的代数结构
//!
//! Monoid 定义了一个类型的组合方式：单位元（empty）和结合操作（combine）。

const std = @import("std");

/// Monoid 类型 - 定义组合规则
pub fn Monoid(comptime T: type) type {
    return struct {
        /// 单位元
        empty: T,
        /// 结合操作
        combine: *const fn (T, T) T,

        const Self = @This();

        /// 合并多个值
        pub fn concat(self: Self, items: []const T) T {
            var result = self.empty;
            for (items) |item| {
                result = self.combine(result, item);
            }
            return result;
        }

        /// 合并两个值
        pub fn append(self: Self, a: T, b: T) T {
            return self.combine(a, b);
        }
    };
}

// ============ 内置 Monoid 实例 ============

/// 加法 Monoid (i64)
pub const sumMonoid = Monoid(i64){
    .empty = 0,
    .combine = struct {
        fn f(a: i64, b: i64) i64 {
            return a + b;
        }
    }.f,
};

/// 乘法 Monoid (i64)
pub const productMonoid = Monoid(i64){
    .empty = 1,
    .combine = struct {
        fn f(a: i64, b: i64) i64 {
            return a * b;
        }
    }.f,
};

/// 与 Monoid (bool)
pub const allMonoid = Monoid(bool){
    .empty = true,
    .combine = struct {
        fn f(a: bool, b: bool) bool {
            return a and b;
        }
    }.f,
};

/// 或 Monoid (bool)
pub const anyMonoid = Monoid(bool){
    .empty = false,
    .combine = struct {
        fn f(a: bool, b: bool) bool {
            return a or b;
        }
    }.f,
};

/// 加法 Monoid (i32)
pub const sumMonoidI32 = Monoid(i32){
    .empty = 0,
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f,
};

/// 乘法 Monoid (i32)
pub const productMonoidI32 = Monoid(i32){
    .empty = 1,
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return a * b;
        }
    }.f,
};

/// 最大值 Monoid (i32)
/// 注意：单位元使用 minInt
pub const maxMonoidI32 = Monoid(i32){
    .empty = std.math.minInt(i32),
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return @max(a, b);
        }
    }.f,
};

/// 最小值 Monoid (i32)
/// 注意：单位元使用 maxInt
pub const minMonoidI32 = Monoid(i32){
    .empty = std.math.maxInt(i32),
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return @min(a, b);
        }
    }.f,
};

// ============ 测试 ============

test "sumMonoid" {
    const numbers = [_]i64{ 1, 2, 3, 4, 5 };
    const sum = sumMonoid.concat(&numbers);
    try std.testing.expectEqual(@as(i64, 15), sum);
}

test "sumMonoid empty" {
    const empty = [_]i64{};
    const sum = sumMonoid.concat(&empty);
    try std.testing.expectEqual(@as(i64, 0), sum);
}

test "productMonoid" {
    const numbers = [_]i64{ 1, 2, 3, 4, 5 };
    const product = productMonoid.concat(&numbers);
    try std.testing.expectEqual(@as(i64, 120), product);
}

test "productMonoid empty" {
    const empty = [_]i64{};
    const product = productMonoid.concat(&empty);
    try std.testing.expectEqual(@as(i64, 1), product);
}

test "allMonoid all true" {
    const bools = [_]bool{ true, true, true };
    const result = allMonoid.concat(&bools);
    try std.testing.expect(result);
}

test "allMonoid some false" {
    const bools = [_]bool{ true, false, true };
    const result = allMonoid.concat(&bools);
    try std.testing.expect(!result);
}

test "allMonoid empty" {
    const empty = [_]bool{};
    const result = allMonoid.concat(&empty);
    try std.testing.expect(result); // empty 返回 true (单位元)
}

test "anyMonoid some true" {
    const bools = [_]bool{ false, true, false };
    const result = anyMonoid.concat(&bools);
    try std.testing.expect(result);
}

test "anyMonoid all false" {
    const bools = [_]bool{ false, false, false };
    const result = anyMonoid.concat(&bools);
    try std.testing.expect(!result);
}

test "anyMonoid empty" {
    const empty = [_]bool{};
    const result = anyMonoid.concat(&empty);
    try std.testing.expect(!result); // empty 返回 false (单位元)
}

test "maxMonoidI32" {
    const numbers = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    const max = maxMonoidI32.concat(&numbers);
    try std.testing.expectEqual(@as(i32, 9), max);
}

test "minMonoidI32" {
    const numbers = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    const min = minMonoidI32.concat(&numbers);
    try std.testing.expectEqual(@as(i32, 1), min);
}

test "Monoid.append" {
    const result = sumMonoidI32.append(3, 5);
    try std.testing.expectEqual(@as(i32, 8), result);
}

// ============ Monoid 法则测试 ============

test "Monoid left identity law" {
    // combine(empty, x) == x
    const x: i64 = 42;
    try std.testing.expectEqual(x, sumMonoid.combine(sumMonoid.empty, x));
    try std.testing.expectEqual(x, productMonoid.combine(productMonoid.empty, x));
}

test "Monoid right identity law" {
    // combine(x, empty) == x
    const x: i64 = 42;
    try std.testing.expectEqual(x, sumMonoid.combine(x, sumMonoid.empty));
    try std.testing.expectEqual(x, productMonoid.combine(x, productMonoid.empty));
}

test "Monoid associativity law" {
    // combine(combine(x, y), z) == combine(x, combine(y, z))
    const x: i64 = 1;
    const y: i64 = 2;
    const z: i64 = 3;

    const lhs = sumMonoid.combine(sumMonoid.combine(x, y), z);
    const rhs = sumMonoid.combine(x, sumMonoid.combine(y, z));
    try std.testing.expectEqual(lhs, rhs);
}
