//! Foldable 模块
//!
//! Foldable 表示可以被"折叠"或"归约"成单一值的数据结构。
//! 提供了 foldl、foldr、foldMap 等核心操作。
//!
//! 类似于 Haskell 的 Foldable 类型类

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============ Slice Foldable ============

/// 切片/数组的 Foldable 实现
pub fn SliceFoldable(comptime A: type) type {
    return struct {
        const Self = @This();

        // ============ 核心折叠操作 ============

        /// foldl: 左折叠
        /// foldl f z [a, b, c] = f(f(f(z, a), b), c)
        pub fn foldl(
            comptime B: type,
            slice: []const A,
            initial: B,
            f: *const fn (B, A) B,
        ) B {
            var acc = initial;
            for (slice) |item| {
                acc = f(acc, item);
            }
            return acc;
        }

        /// foldr: 右折叠
        /// foldr f z [a, b, c] = f(a, f(b, f(c, z)))
        pub fn foldr(
            comptime B: type,
            slice: []const A,
            initial: B,
            f: *const fn (A, B) B,
        ) B {
            var acc = initial;
            var i = slice.len;
            while (i > 0) {
                i -= 1;
                acc = f(slice[i], acc);
            }
            return acc;
        }

        /// foldMap: 先映射再使用 Monoid 折叠
        pub fn foldMap(
            comptime M: type,
            slice: []const A,
            f: *const fn (A) M,
            empty: M,
            combine: *const fn (M, M) M,
        ) M {
            var acc = empty;
            for (slice) |item| {
                acc = combine(acc, f(item));
            }
            return acc;
        }

        // ============ 派生操作 ============

        /// fold: 使用 Monoid 折叠（元素类型必须是 Monoid）
        pub fn fold(
            slice: []const A,
            empty: A,
            combine: *const fn (A, A) A,
        ) A {
            return foldl(A, slice, empty, combine);
        }

        /// length: 计算长度
        pub fn length(slice: []const A) usize {
            return slice.len;
        }

        /// isEmpty: 是否为空
        pub fn isEmpty(slice: []const A) bool {
            return slice.len == 0;
        }

        /// contains: 是否包含元素
        pub fn contains(slice: []const A, target: A) bool {
            for (slice) |item| {
                if (std.meta.eql(item, target)) {
                    return true;
                }
            }
            return false;
        }

        /// find: 查找满足条件的第一个元素
        pub fn find(slice: []const A, pred: *const fn (A) bool) ?A {
            for (slice) |item| {
                if (pred(item)) {
                    return item;
                }
            }
            return null;
        }

        /// any: 是否存在满足条件的元素
        pub fn any(slice: []const A, pred: *const fn (A) bool) bool {
            for (slice) |item| {
                if (pred(item)) {
                    return true;
                }
            }
            return false;
        }

        /// all: 是否所有元素都满足条件
        pub fn all(slice: []const A, pred: *const fn (A) bool) bool {
            for (slice) |item| {
                if (!pred(item)) {
                    return false;
                }
            }
            return true;
        }

        /// count: 统计满足条件的元素数量
        pub fn count(slice: []const A, pred: *const fn (A) bool) usize {
            var n: usize = 0;
            for (slice) |item| {
                if (pred(item)) {
                    n += 1;
                }
            }
            return n;
        }

        /// toList: 转换为分配的切片
        pub fn toList(allocator: Allocator, slice: []const A) ![]A {
            return try allocator.dupe(A, slice);
        }

        /// head: 获取第一个元素
        pub fn head(slice: []const A) ?A {
            if (slice.len == 0) return null;
            return slice[0];
        }

        /// last: 获取最后一个元素
        pub fn last(slice: []const A) ?A {
            if (slice.len == 0) return null;
            return slice[slice.len - 1];
        }

        /// nth: 获取第 n 个元素
        pub fn nth(slice: []const A, n: usize) ?A {
            if (n >= slice.len) return null;
            return slice[n];
        }
    };
}

// ============ 数值折叠操作 ============

/// 数值切片的折叠操作
pub fn NumericFoldable(comptime T: type) type {
    return struct {
        const Self = @This();
        const SliceF = SliceFoldable(T);

        /// sum: 求和
        pub fn sum(slice: []const T) T {
            return SliceF.foldl(T, slice, 0, struct {
                fn add(a: T, b: T) T {
                    return a + b;
                }
            }.add);
        }

        /// product: 求积
        pub fn product(slice: []const T) T {
            return SliceF.foldl(T, slice, 1, struct {
                fn mul(a: T, b: T) T {
                    return a * b;
                }
            }.mul);
        }

        /// maximum: 最大值
        pub fn maximum(slice: []const T) ?T {
            if (slice.len == 0) return null;
            return SliceF.foldl(T, slice[1..], slice[0], struct {
                fn max(a: T, b: T) T {
                    return if (b > a) b else a;
                }
            }.max);
        }

        /// minimum: 最小值
        pub fn minimum(slice: []const T) ?T {
            if (slice.len == 0) return null;
            return SliceF.foldl(T, slice[1..], slice[0], struct {
                fn min(a: T, b: T) T {
                    return if (b < a) b else a;
                }
            }.min);
        }

        /// average: 平均值（返回浮点数）
        pub fn average(slice: []const T) ?f64 {
            if (slice.len == 0) return null;
            const s = sum(slice);
            return @as(f64, @floatFromInt(s)) / @as(f64, @floatFromInt(slice.len));
        }
    };
}

// ============ Option Foldable ============

/// Option 的 Foldable 实现
pub fn OptionFoldable(comptime A: type) type {
    return struct {
        const Self = @This();

        pub const Option = union(enum) {
            some_val: A,
            none_val: void,

            pub fn isSome(self: @This()) bool {
                return self == .some_val;
            }

            pub fn isNone(self: @This()) bool {
                return self == .none_val;
            }
        };

        pub fn some(value: A) Option {
            return .{ .some_val = value };
        }

        pub fn none() Option {
            return .{ .none_val = {} };
        }

        /// foldl: 左折叠
        pub fn foldl(
            comptime B: type,
            opt: Option,
            initial: B,
            f: *const fn (B, A) B,
        ) B {
            return switch (opt) {
                .some_val => |v| f(initial, v),
                .none_val => initial,
            };
        }

        /// foldr: 右折叠
        pub fn foldr(
            comptime B: type,
            opt: Option,
            initial: B,
            f: *const fn (A, B) B,
        ) B {
            return switch (opt) {
                .some_val => |v| f(v, initial),
                .none_val => initial,
            };
        }

        /// foldMap: 映射后折叠
        pub fn foldMap(
            comptime M: type,
            opt: Option,
            f: *const fn (A) M,
            empty: M,
        ) M {
            return switch (opt) {
                .some_val => |v| f(v),
                .none_val => empty,
            };
        }

        /// length: Option 长度（0 或 1）
        pub fn length(opt: Option) usize {
            return switch (opt) {
                .some_val => 1,
                .none_val => 0,
            };
        }

        /// isEmpty: 是否为空
        pub fn isEmpty(opt: Option) bool {
            return opt.isNone();
        }

        /// toList: 转换为切片
        pub fn toList(allocator: Allocator, opt: Option) ![]A {
            return switch (opt) {
                .some_val => |v| {
                    const result = try allocator.alloc(A, 1);
                    result[0] = v;
                    return result;
                },
                .none_val => try allocator.alloc(A, 0),
            };
        }

        /// any: 是否满足条件
        pub fn any(opt: Option, pred: *const fn (A) bool) bool {
            return switch (opt) {
                .some_val => |v| pred(v),
                .none_val => false,
            };
        }

        /// all: 是否所有元素满足条件
        pub fn all(opt: Option, pred: *const fn (A) bool) bool {
            return switch (opt) {
                .some_val => |v| pred(v),
                .none_val => true,
            };
        }
    };
}

// ============ 通用工具函数 ============

/// 使用 Monoid 折叠切片
pub fn foldWithMonoid(
    comptime A: type,
    slice: []const A,
    empty: A,
    combine: *const fn (A, A) A,
) A {
    return SliceFoldable(A).fold(slice, empty, combine);
}

/// 左折叠
pub fn foldLeft(
    comptime A: type,
    comptime B: type,
    slice: []const A,
    initial: B,
    f: *const fn (B, A) B,
) B {
    return SliceFoldable(A).foldl(B, slice, initial, f);
}

/// 右折叠
pub fn foldRight(
    comptime A: type,
    comptime B: type,
    slice: []const A,
    initial: B,
    f: *const fn (A, B) B,
) B {
    return SliceFoldable(A).foldr(B, slice, initial, f);
}

// ============ 测试 ============

test "SliceFoldable.foldl" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    // 求和
    const sum = FoldInt.foldl(i32, &nums, 0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);
    try std.testing.expectEqual(@as(i32, 15), sum);

    // 求积
    const prod = FoldInt.foldl(i32, &nums, 1, struct {
        fn mul(a: i32, b: i32) i32 {
            return a * b;
        }
    }.mul);
    try std.testing.expectEqual(@as(i32, 120), prod);
}

test "SliceFoldable.foldr" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3 };

    // 右折叠构建字符串描述
    // foldr(-, 0, [1,2,3]) = 1 - (2 - (3 - 0)) = 1 - (2 - 3) = 1 - (-1) = 2
    const result = FoldInt.foldr(i32, &nums, 0, struct {
        fn sub(a: i32, b: i32) i32 {
            return a - b;
        }
    }.sub);
    try std.testing.expectEqual(@as(i32, 2), result);
}

test "SliceFoldable.foldMap" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3 };

    // 映射为字符串长度后求和
    const result = FoldInt.foldMap(i32, &nums, struct {
        fn toLen(x: i32) i32 {
            return x * 10; // 示例：乘以10
        }
    }.toLen, 0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    // 10 + 20 + 30 = 60
    try std.testing.expectEqual(@as(i32, 60), result);
}

test "SliceFoldable.length" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expectEqual(@as(usize, 5), FoldInt.length(&nums));
    try std.testing.expectEqual(@as(usize, 0), FoldInt.length(&[_]i32{}));
}

test "SliceFoldable.isEmpty" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3 };

    try std.testing.expect(!FoldInt.isEmpty(&nums));
    try std.testing.expect(FoldInt.isEmpty(&[_]i32{}));
}

test "SliceFoldable.contains" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expect(FoldInt.contains(&nums, 3));
    try std.testing.expect(!FoldInt.contains(&nums, 10));
}

test "SliceFoldable.find" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const found = FoldInt.find(&nums, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expectEqual(@as(?i32, 2), found);

    const notFound = FoldInt.find(&nums, struct {
        fn isNegative(x: i32) bool {
            return x < 0;
        }
    }.isNegative);

    try std.testing.expectEqual(@as(?i32, null), notFound);
}

test "SliceFoldable.any" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expect(FoldInt.any(&nums, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven));

    try std.testing.expect(!FoldInt.any(&nums, struct {
        fn isNegative(x: i32) bool {
            return x < 0;
        }
    }.isNegative));
}

test "SliceFoldable.all" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 2, 4, 6, 8 };

    try std.testing.expect(FoldInt.all(&nums, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven));

    try std.testing.expect(!FoldInt.all(&nums, struct {
        fn isGreaterThan5(x: i32) bool {
            return x > 5;
        }
    }.isGreaterThan5));
}

test "SliceFoldable.count" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5, 6 };

    const evenCount = FoldInt.count(&nums, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expectEqual(@as(usize, 3), evenCount);
}

test "SliceFoldable.head and last" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 1, 2, 3 };

    try std.testing.expectEqual(@as(?i32, 1), FoldInt.head(&nums));
    try std.testing.expectEqual(@as(?i32, 3), FoldInt.last(&nums));

    try std.testing.expectEqual(@as(?i32, null), FoldInt.head(&[_]i32{}));
    try std.testing.expectEqual(@as(?i32, null), FoldInt.last(&[_]i32{}));
}

test "SliceFoldable.nth" {
    const FoldInt = SliceFoldable(i32);
    const nums = [_]i32{ 10, 20, 30 };

    try std.testing.expectEqual(@as(?i32, 10), FoldInt.nth(&nums, 0));
    try std.testing.expectEqual(@as(?i32, 20), FoldInt.nth(&nums, 1));
    try std.testing.expectEqual(@as(?i32, 30), FoldInt.nth(&nums, 2));
    try std.testing.expectEqual(@as(?i32, null), FoldInt.nth(&nums, 3));
}

test "NumericFoldable.sum" {
    const NumInt = NumericFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expectEqual(@as(i32, 15), NumInt.sum(&nums));
    try std.testing.expectEqual(@as(i32, 0), NumInt.sum(&[_]i32{}));
}

test "NumericFoldable.product" {
    const NumInt = NumericFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expectEqual(@as(i32, 120), NumInt.product(&nums));
    try std.testing.expectEqual(@as(i32, 1), NumInt.product(&[_]i32{}));
}

test "NumericFoldable.maximum" {
    const NumInt = NumericFoldable(i32);
    const nums = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };

    try std.testing.expectEqual(@as(?i32, 9), NumInt.maximum(&nums));
    try std.testing.expectEqual(@as(?i32, null), NumInt.maximum(&[_]i32{}));
}

test "NumericFoldable.minimum" {
    const NumInt = NumericFoldable(i32);
    const nums = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };

    try std.testing.expectEqual(@as(?i32, 1), NumInt.minimum(&nums));
    try std.testing.expectEqual(@as(?i32, null), NumInt.minimum(&[_]i32{}));
}

test "NumericFoldable.average" {
    const NumInt = NumericFoldable(i32);
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const avg = NumInt.average(&nums).?;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), avg, 0.001);

    try std.testing.expectEqual(@as(?f64, null), NumInt.average(&[_]i32{}));
}

test "OptionFoldable.foldl" {
    const OptInt = OptionFoldable(i32);

    const some = OptInt.some(10);
    const result1 = OptInt.foldl(i32, some, 5, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);
    try std.testing.expectEqual(@as(i32, 15), result1);

    const non = OptInt.none();
    const result2 = OptInt.foldl(i32, non, 5, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);
    try std.testing.expectEqual(@as(i32, 5), result2);
}

test "OptionFoldable.length" {
    const OptInt = OptionFoldable(i32);

    try std.testing.expectEqual(@as(usize, 1), OptInt.length(OptInt.some(42)));
    try std.testing.expectEqual(@as(usize, 0), OptInt.length(OptInt.none()));
}

test "OptionFoldable.toList" {
    const allocator = std.testing.allocator;
    const OptInt = OptionFoldable(i32);

    const someList = try OptInt.toList(allocator, OptInt.some(42));
    defer allocator.free(someList);
    try std.testing.expectEqual(@as(usize, 1), someList.len);
    try std.testing.expectEqual(@as(i32, 42), someList[0]);

    const noneList = try OptInt.toList(allocator, OptInt.none());
    defer allocator.free(noneList);
    try std.testing.expectEqual(@as(usize, 0), noneList.len);
}

test "OptionFoldable.any and all" {
    const OptInt = OptionFoldable(i32);

    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    // Some(10) - positive
    try std.testing.expect(OptInt.any(OptInt.some(10), isPositive));
    try std.testing.expect(OptInt.all(OptInt.some(10), isPositive));

    // Some(-10) - negative
    try std.testing.expect(!OptInt.any(OptInt.some(-10), isPositive));
    try std.testing.expect(!OptInt.all(OptInt.some(-10), isPositive));

    // None
    try std.testing.expect(!OptInt.any(OptInt.none(), isPositive));
    try std.testing.expect(OptInt.all(OptInt.none(), isPositive)); // vacuously true
}

test "foldWithMonoid" {
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const sum = foldWithMonoid(i32, &nums, 0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), sum);
}

test "foldLeft" {
    const chars = [_]u8{ 'a', 'b', 'c' };

    // 构建字符串（模拟）
    var result: i32 = 0;
    result = foldLeft(u8, i32, &chars, result, struct {
        fn append(acc: i32, c: u8) i32 {
            return acc * 256 + @as(i32, c);
        }
    }.append);

    // 'a' * 256^2 + 'b' * 256 + 'c' = 97 * 65536 + 98 * 256 + 99
    try std.testing.expectEqual(@as(i32, 6382179), result);
}

test "foldRight" {
    const nums = [_]i32{ 1, 2, 3 };

    // 右折叠：1 - (2 - (3 - 0)) = 2
    const result = foldRight(i32, i32, &nums, 0, struct {
        fn sub(a: i32, b: i32) i32 {
            return a - b;
        }
    }.sub);

    try std.testing.expectEqual(@as(i32, 2), result);
}
