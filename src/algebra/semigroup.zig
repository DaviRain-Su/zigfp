//! Semigroup 模块
//!
//! Semigroup 是具有结合操作的代数结构。
//! 只需要实现一个 `combine` 操作，要求满足结合律。
//!
//! 法则：
//! - 结合律: a <> (b <> c) = (a <> b) <> c
//!
//! Semigroup 是 Monoid 的基础（Monoid 多了 identity 元素）。

const std = @import("std");

/// Semigroup 类型类
/// T 必须有 combine 操作，且满足结合律
pub fn Semigroup(comptime T: type) type {
    return struct {
        combine_fn: *const fn (T, T) T,

        const Self = @This();

        /// 创建 Semigroup 实例
        pub fn init(combine_fn: *const fn (T, T) T) Self {
            return .{ .combine_fn = combine_fn };
        }

        /// 结合两个值
        pub fn combine(self: Self, a: T, b: T) T {
            return self.combine_fn(a, b);
        }

        /// 结合多个值（左折叠）
        pub fn concat(self: Self, values: []const T) !T {
            if (values.len == 0) {
                return error.EmptySequence;
            }

            var result = values[0];
            for (values[1..]) |value| {
                result = self.combine(result, value);
            }
            return result;
        }

        /// 重复结合 n 次
        pub fn repeat(self: Self, value: T, n: usize) !T {
            if (n == 0) {
                return error.InvalidRepeatCount;
            }

            var result = value;
            var i: usize = 1;
            while (i < n) : (i += 1) {
                result = self.combine(result, value);
            }
            return result;
        }

        /// 在元素之间插入分隔符
        pub fn intersperse(self: Self, values: []const T, separator: T) !T {
            if (values.len == 0) {
                return error.EmptySequence;
            }

            if (values.len == 1) {
                return values[0];
            }

            var result = values[0];
            for (values[1..]) |value| {
                result = self.combine(result, separator);
                result = self.combine(result, value);
            }
            return result;
        }

        /// 折叠操作（左折叠）
        pub fn foldLeft(self: Self, values: []const T, initial: T) T {
            var result = initial;
            for (values) |value| {
                result = self.combine(result, value);
            }
            return result;
        }

        /// 折叠操作（右折叠）
        pub fn foldRight(self: Self, values: []const T, initial: T) T {
            var result = initial;
            var i = values.len;
            while (i > 0) {
                i -= 1;
                result = self.combine(values[i], result);
            }
            return result;
        }
    };
}

// ============ 常用 Semigroup 实例 ============

/// 字符串连接 Semigroup
pub const stringSemigroup = Semigroup([]const u8).init(struct {
    fn combine(a: []const u8, b: []const u8) []const u8 {
        // 注意：这只是概念演示，实际使用需要分配器
        // 完整实现应该返回新分配的字符串
        _ = a;
        _ = b;
        @compileError("String semigroup needs allocator - use stringSemigroupAlloc");
    }
}.combine);

/// 字符串连接 Semigroup（带分配器）
pub fn stringSemigroupAlloc(allocator: std.mem.Allocator) Semigroup([]const u8) {
    const StringCombine = struct {
        var alloc: std.mem.Allocator = undefined;

        fn init(allocator_: std.mem.Allocator) void {
            alloc = allocator_;
        }

        fn combine(a: []const u8, b: []const u8) []const u8 {
            const result = alloc.alloc(u8, a.len + b.len) catch unreachable;
            @memcpy(result[0..a.len], a);
            @memcpy(result[a.len..], b);
            return result;
        }
    };

    StringCombine.init(allocator);
    return Semigroup([]const u8).init(&StringCombine.combine);
}

/// 数组连接 Semigroup
pub fn arraySemigroupAlloc(comptime T: type, allocator: std.mem.Allocator) Semigroup([]const T) {
    const ArrayCombine = struct {
        var alloc: std.mem.Allocator = undefined;

        fn init(allocator_: std.mem.Allocator) void {
            alloc = allocator_;
        }

        fn combine(a: []const T, b: []const T) []const T {
            const result = alloc.alloc(T, a.len + b.len) catch unreachable;
            @memcpy(result[0..a.len], a);
            @memcpy(result[a.len..], b);
            return result;
        }
    };

    ArrayCombine.init(allocator);
    return Semigroup([]const T).init(&ArrayCombine.combine);
}

/// 数值求和 Semigroup
pub fn sumSemigroup(comptime T: type) Semigroup(T) {
    return Semigroup(T).init(struct {
        fn combine(a: T, b: T) T {
            return a + b;
        }
    }.combine);
}

/// 数值求积 Semigroup
pub fn productSemigroup(comptime T: type) Semigroup(T) {
    return Semigroup(T).init(struct {
        fn combine(a: T, b: T) T {
            return a * b;
        }
    }.combine);
}

/// 数值最大值 Semigroup
pub fn maxSemigroup(comptime T: type) Semigroup(T) {
    return Semigroup(T).init(struct {
        fn combine(a: T, b: T) T {
            return if (a > b) a else b;
        }
    }.combine);
}

/// 数值最小值 Semigroup
pub fn minSemigroup(comptime T: type) Semigroup(T) {
    return Semigroup(T).init(struct {
        fn combine(a: T, b: T) T {
            return if (a < b) a else b;
        }
    }.combine);
}

/// 布尔与 Semigroup
pub const allSemigroup = Semigroup(bool).init(struct {
    fn combine(a: bool, b: bool) bool {
        return a and b;
    }
}.combine);

/// 布尔或 Semigroup
pub const anySemigroup = Semigroup(bool).init(struct {
    fn combine(a: bool, b: bool) bool {
        return a or b;
    }
}.combine);

/// 函数组合 Semigroup
/// (A -> A) 的 Semigroup，使用函数组合
pub fn functionSemigroup(comptime A: type) Semigroup(*const fn (A) A) {
    const FnCombine = struct {
        fn combine(f: *const fn (A) A, g: *const fn (A) A) *const fn (A) A {
            return FunctionCombine(A).create(f, g);
        }
    };

    return Semigroup(*const fn (A) A).init(&FnCombine.combine);
}

/// 函数组合包装器
fn FunctionCombine(comptime A: type) type {
    return struct {
        var f1: *const fn (A) A = undefined;
        var f2: *const fn (A) A = undefined;

        fn call(x: A) A {
            return f1(f2(x));
        }

        pub fn create(f: *const fn (A) A, g: *const fn (A) A) *const fn (A) A {
            f1 = f;
            f2 = g;
            return &call;
        }
    };
}

/// Option 组合 Semigroup
/// 如果两个 Option 都有值，则组合它们的值
pub fn optionSemigroup(comptime T: type, inner_sg: Semigroup(T)) Semigroup(?T) {
    const OptionCombine = struct {
        var sg: Semigroup(T) = undefined;

        fn init(sg_: Semigroup(T)) void {
            sg = sg_;
        }

        fn combine(a: ?T, b: ?T) ?T {
            if (a == null) return b;
            if (b == null) return a;
            return sg.combine(a.?, b.?);
        }
    };

    OptionCombine.init(inner_sg);
    return Semigroup(?T).init(&OptionCombine.combine);
}

// ============ 测试 ============

test "Semigroup string operations" {
    const allocator = std.testing.allocator;

    // 字符串连接
    var str_sg = stringSemigroupAlloc(allocator);
    defer {
        // 注意：实际使用中需要释放分配的字符串
        // 这里只是测试基本功能
    }

    const s1 = "hello";
    const s2 = "world";
    const combined = str_sg.combine(s1, s2);
    defer allocator.free(combined);

    try std.testing.expectEqualStrings("helloworld", combined);
}

test "Semigroup numeric operations" {
    // 求和
    const sum_sg = sumSemigroup(i32);
    const result1 = sum_sg.combine(5, 3);
    try std.testing.expectEqual(@as(i32, 8), result1);

    // 求积
    const prod_sg = productSemigroup(i32);
    const result2 = prod_sg.combine(4, 7);
    try std.testing.expectEqual(@as(i32, 28), result2);

    // 最大值
    const max_sg = maxSemigroup(i32);
    const result3 = max_sg.combine(10, 20);
    try std.testing.expectEqual(@as(i32, 20), result3);

    // 最小值
    const min_sg = minSemigroup(i32);
    const result4 = min_sg.combine(10, 20);
    try std.testing.expectEqual(@as(i32, 10), result4);
}

test "Semigroup boolean operations" {
    // 逻辑与
    const result1 = allSemigroup.combine(true, true);
    try std.testing.expect(result1);

    const result2 = allSemigroup.combine(true, false);
    try std.testing.expect(!result2);

    // 逻辑或
    const result3 = anySemigroup.combine(false, true);
    try std.testing.expect(result3);

    const result4 = anySemigroup.combine(false, false);
    try std.testing.expect(!result4);
}

test "Semigroup associativity law" {
    // 测试结合律: a <> (b <> c) = (a <> b) <> c
    const sum_sg = sumSemigroup(i32);

    const a: i32 = 1;
    const b: i32 = 2;
    const c: i32 = 3;

    const left = sum_sg.combine(a, sum_sg.combine(b, c));
    const right = sum_sg.combine(sum_sg.combine(a, b), c);

    try std.testing.expectEqual(left, right);
    try std.testing.expectEqual(@as(i32, 6), left);
}

test "Semigroup concat" {
    const sum_sg = sumSemigroup(i32);

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try sum_sg.concat(&values);

    try std.testing.expectEqual(@as(i32, 15), result);
}

test "Semigroup repeat" {
    const sum_sg = sumSemigroup(i32);

    const result = try sum_sg.repeat(3, 4);
    try std.testing.expectEqual(@as(i32, 12), result); // 3 + 3 + 3 + 3 = 12
}

test "Semigroup intersperse" {
    const sum_sg = sumSemigroup(i32);

    const values = [_]i32{ 1, 2, 3 };
    const result = try sum_sg.intersperse(&values, 10);

    // 1 + 10 + 2 + 10 + 3 = 26
    try std.testing.expectEqual(@as(i32, 26), result);
}

test "Semigroup foldLeft vs foldRight" {
    const sum_sg = sumSemigroup(i32);

    const values = [_]i32{ 1, 2, 3, 4 };

    // 对于交换操作（如加法），左右折叠结果相同
    const left_result = sum_sg.foldLeft(&values, 0);
    const right_result = sum_sg.foldRight(&values, 0);

    try std.testing.expectEqual(@as(i32, 10), left_result);
    try std.testing.expectEqual(@as(i32, 10), right_result);
}

test "Semigroup function composition" {
    const fn_sg = functionSemigroup(i32);

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

    // 组合函数：double . addOne
    const combined = fn_sg.combine(double, addOne);

    // (5 + 1) * 2 = 12
    const result = combined(5);
    try std.testing.expectEqual(@as(i32, 12), result);
}

test "Semigroup option combination" {
    const sum_sg = sumSemigroup(i32);
    const opt_sg = optionSemigroup(i32, sum_sg);

    // None + Some(5) = Some(5)
    const result1 = opt_sg.combine(null, @as(?i32, 5));
    try std.testing.expectEqual(@as(?i32, 5), result1);

    // Some(3) + Some(7) = Some(10)
    const result2 = opt_sg.combine(@as(?i32, 3), @as(?i32, 7));
    try std.testing.expectEqual(@as(?i32, 10), result2);

    // None + None = None
    const result3 = opt_sg.combine(null, null);
    try std.testing.expect(result3 == null);
}
