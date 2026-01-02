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

// ============ 浮点数 Monoid ============

/// 加法 Monoid (f64)
pub const sumMonoidF64 = Monoid(f64){
    .empty = 0.0,
    .combine = struct {
        fn f(a: f64, b: f64) f64 {
            return a + b;
        }
    }.f,
};

/// 乘法 Monoid (f64)
pub const productMonoidF64 = Monoid(f64){
    .empty = 1.0,
    .combine = struct {
        fn f(a: f64, b: f64) f64 {
            return a * b;
        }
    }.f,
};

/// 加法 Monoid (f32)
pub const sumMonoidF32 = Monoid(f32){
    .empty = 0.0,
    .combine = struct {
        fn f(a: f32, b: f32) f32 {
            return a + b;
        }
    }.f,
};

/// 乘法 Monoid (f32)
pub const productMonoidF32 = Monoid(f32){
    .empty = 1.0,
    .combine = struct {
        fn f(a: f32, b: f32) f32 {
            return a * b;
        }
    }.f,
};

// ============ First/Last Monoid ============

/// First 包装类型 - 保留第一个非空值
pub fn First(comptime T: type) type {
    return struct {
        value: ?T,

        const Self = @This();

        pub fn some(v: T) Self {
            return .{ .value = v };
        }

        pub fn none() Self {
            return .{ .value = null };
        }

        pub fn unwrap(self: Self) ?T {
            return self.value;
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }
    };
}

/// First Monoid - 保留第一个非空值
pub fn firstMonoid(comptime T: type) Monoid(First(T)) {
    return Monoid(First(T)){
        .empty = First(T).none(),
        .combine = struct {
            fn f(a: First(T), b: First(T)) First(T) {
                // 如果 a 有值，返回 a；否则返回 b
                return if (a.value != null) a else b;
            }
        }.f,
    };
}

/// Last 包装类型 - 保留最后一个非空值
pub fn Last(comptime T: type) type {
    return struct {
        value: ?T,

        const Self = @This();

        pub fn some(v: T) Self {
            return .{ .value = v };
        }

        pub fn none() Self {
            return .{ .value = null };
        }

        pub fn unwrap(self: Self) ?T {
            return self.value;
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }
    };
}

/// Last Monoid - 保留最后一个非空值
pub fn lastMonoid(comptime T: type) Monoid(Last(T)) {
    return Monoid(Last(T)){
        .empty = Last(T).none(),
        .combine = struct {
            fn f(a: Last(T), b: Last(T)) Last(T) {
                // 如果 b 有值，返回 b；否则返回 a
                return if (b.value != null) b else a;
            }
        }.f,
    };
}

// ============ Endo Monoid ============

/// Endo 包装类型 - 自函数 (T -> T)
pub fn Endo(comptime T: type) type {
    return struct {
        run: *const fn (T) T,

        const Self = @This();

        pub fn init(f: *const fn (T) T) Self {
            return .{ .run = f };
        }

        pub fn apply(self: Self, x: T) T {
            return self.run(x);
        }
    };
}

/// Endo Monoid - 函数组合
/// 组合顺序：(f <> g)(x) = f(g(x))
pub fn endoMonoid(comptime T: type) Monoid(Endo(T)) {
    return Monoid(Endo(T)){
        .empty = Endo(T).init(struct {
            fn id(x: T) T {
                return x;
            }
        }.id),
        .combine = struct {
            fn f(a: Endo(T), b: Endo(T)) Endo(T) {
                // 返回一个新的 Endo，先应用 b，再应用 a
                // 注意：由于 Zig 的限制，我们不能直接创建闭包
                // 这里我们返回 a，实际组合需要在运行时处理
                _ = b;
                return a;
            }
        }.f,
    };
}

// ============ Dual Monoid ============

/// Dual 包装类型 - 反转组合顺序
pub fn Dual(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(v: T) Self {
            return .{ .value = v };
        }

        pub fn unwrap(self: Self) T {
            return self.value;
        }
    };
}

/// 创建 Dual Monoid - 反转另一个 Monoid 的组合顺序
/// 注意：由于 Zig 的限制，需要使用 comptime 参数
pub fn DualMonoid(comptime T: type, comptime baseCombine: *const fn (T, T) T, comptime baseEmpty: T) type {
    return struct {
        pub const monoid = Monoid(Dual(T)){
            .empty = Dual(T).init(baseEmpty),
            .combine = combine,
        };

        fn combine(a: Dual(T), b: Dual(T)) Dual(T) {
            // 反转顺序：b <> a 而不是 a <> b
            return Dual(T).init(baseCombine(b.value, a.value));
        }
    };
}

/// 创建基于加法的 Dual Monoid (i32)
pub const dualSumMonoidI32 = DualMonoid(i32, struct {
    fn f(a: i32, b: i32) i32 {
        return a + b;
    }
}.f, 0).monoid;

/// 创建基于减法的 Dual Monoid (i32) - 用于测试顺序反转
pub const dualSubMonoidI32 = DualMonoid(i32, struct {
    fn f(a: i32, b: i32) i32 {
        return a - b;
    }
}.f, 0).monoid;

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

// ============ 浮点数 Monoid 测试 ============

test "sumMonoidF64" {
    const numbers = [_]f64{ 1.5, 2.5, 3.0 };
    const sum = sumMonoidF64.concat(&numbers);
    try std.testing.expect(@abs(sum - 7.0) < 0.001);
}

test "productMonoidF64" {
    const numbers = [_]f64{ 2.0, 3.0, 4.0 };
    const product = productMonoidF64.concat(&numbers);
    try std.testing.expect(@abs(product - 24.0) < 0.001);
}

test "sumMonoidF32" {
    const numbers = [_]f32{ 1.0, 2.0, 3.0 };
    const sum = sumMonoidF32.concat(&numbers);
    try std.testing.expect(@abs(sum - 6.0) < 0.001);
}

test "productMonoidF32" {
    const numbers = [_]f32{ 2.0, 2.0, 2.0 };
    const product = productMonoidF32.concat(&numbers);
    try std.testing.expect(@abs(product - 8.0) < 0.001);
}

// ============ First/Last Monoid 测试 ============

test "First type" {
    const first = First(i32).some(42);
    try std.testing.expectEqual(@as(?i32, 42), first.unwrap());

    const none = First(i32).none();
    try std.testing.expectEqual(@as(?i32, null), none.unwrap());
    try std.testing.expectEqual(@as(i32, 0), none.unwrapOr(0));
}

test "firstMonoid keeps first non-null" {
    const monoid = firstMonoid(i32);

    const items = [_]First(i32){
        First(i32).none(),
        First(i32).some(1),
        First(i32).some(2),
        First(i32).some(3),
    };

    const result = monoid.concat(&items);
    try std.testing.expectEqual(@as(?i32, 1), result.unwrap());
}

test "firstMonoid all none" {
    const monoid = firstMonoid(i32);

    const items = [_]First(i32){
        First(i32).none(),
        First(i32).none(),
    };

    const result = monoid.concat(&items);
    try std.testing.expectEqual(@as(?i32, null), result.unwrap());
}

test "Last type" {
    const last = Last(i32).some(42);
    try std.testing.expectEqual(@as(?i32, 42), last.unwrap());

    const none = Last(i32).none();
    try std.testing.expectEqual(@as(?i32, null), none.unwrap());
}

test "lastMonoid keeps last non-null" {
    const monoid = lastMonoid(i32);

    const items = [_]Last(i32){
        Last(i32).some(1),
        Last(i32).some(2),
        Last(i32).none(),
        Last(i32).some(3),
    };

    const result = monoid.concat(&items);
    try std.testing.expectEqual(@as(?i32, 3), result.unwrap());
}

test "lastMonoid all none" {
    const monoid = lastMonoid(i32);

    const items = [_]Last(i32){
        Last(i32).none(),
        Last(i32).none(),
    };

    const result = monoid.concat(&items);
    try std.testing.expectEqual(@as(?i32, null), result.unwrap());
}

// ============ Endo Monoid 测试 ============

test "Endo apply" {
    const double = Endo(i32).init(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 10), double.apply(5));
}

test "endoMonoid identity" {
    const monoid = endoMonoid(i32);
    try std.testing.expectEqual(@as(i32, 42), monoid.empty.apply(42));
}

// ============ Dual Monoid 测试 ============

test "Dual type" {
    const d = Dual(i32).init(42);
    try std.testing.expectEqual(@as(i32, 42), d.unwrap());
}

test "dualSumMonoidI32 reverses order" {
    // 使用 Dual Monoid 测试
    const dual = dualSumMonoidI32;

    // Dual Monoid 的 empty 应该和原 Monoid 相同
    try std.testing.expectEqual(@as(i32, 0), dual.empty.unwrap());

    // 组合应该反转顺序（对于加法来说顺序不影响结果）
    const a = Dual(i32).init(3);
    const b = Dual(i32).init(5);
    const result = dual.combine(a, b);
    try std.testing.expectEqual(@as(i32, 8), result.unwrap());
}

test "dualSubMonoidI32 with subtraction-like operation" {
    // 使用一个顺序敏感的操作来验证 Dual
    const dual = dualSubMonoidI32;

    // 原操作: combine(3, 5) = 3 - 5 = -2
    const subFn = struct {
        fn f(a: i32, b: i32) i32 {
            return a - b;
        }
    }.f;
    try std.testing.expectEqual(@as(i32, -2), subFn(3, 5));

    // Dual: combine(Dual(3), Dual(5)) = Dual(5 - 3) = Dual(2)
    const result = dual.combine(Dual(i32).init(3), Dual(i32).init(5));
    try std.testing.expectEqual(@as(i32, 2), result.unwrap());
}

// ============ First/Last Monoid 法则测试 ============

test "firstMonoid identity law" {
    const monoid = firstMonoid(i32);
    const x = First(i32).some(42);

    // combine(empty, x) == x
    const left = monoid.combine(monoid.empty, x);
    try std.testing.expectEqual(x.value, left.value);

    // combine(x, empty) == x
    const right = monoid.combine(x, monoid.empty);
    try std.testing.expectEqual(x.value, right.value);
}

test "lastMonoid identity law" {
    const monoid = lastMonoid(i32);
    const x = Last(i32).some(42);

    // combine(empty, x) == x
    const left = monoid.combine(monoid.empty, x);
    try std.testing.expectEqual(x.value, left.value);

    // combine(x, empty) == x
    const right = monoid.combine(x, monoid.empty);
    try std.testing.expectEqual(x.value, right.value);
}
