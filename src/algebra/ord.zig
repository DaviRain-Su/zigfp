//! Ord - 排序类型类
//!
//! Ord 类型类定义了排序比较操作。
//! 所有实现必须满足以下法则：
//! - 自反性: compare(x, x) = .eq
//! - 反对称性: 如果 compare(x, y) = .lt 则 compare(y, x) = .gt
//! - 传递性: 如果 compare(x, y) = .lt 且 compare(y, z) = .lt，则 compare(x, z) = .lt

const std = @import("std");

/// 比较结果
pub const Ordering = enum {
    lt, // 小于
    eq, // 等于
    gt, // 大于

    /// 反转排序
    pub fn reverse(self: Ordering) Ordering {
        return switch (self) {
            .lt => .gt,
            .eq => .eq,
            .gt => .lt,
        };
    }

    /// 组合两个排序（如果第一个是 eq，则使用第二个）
    pub fn then(self: Ordering, other: Ordering) Ordering {
        return if (self == .eq) other else self;
    }

    /// 转换为整数
    pub fn toInt(self: Ordering) i2 {
        return switch (self) {
            .lt => -1,
            .eq => 0,
            .gt => 1,
        };
    }
};

/// Ord 类型类 - 排序比较
pub fn Ord(comptime T: type) type {
    return struct {
        const Self = @This();

        compareFn: *const fn (T, T) Ordering,

        /// 比较两个值
        pub fn compare(self: Self, a: T, b: T) Ordering {
            return self.compareFn(a, b);
        }

        /// 小于
        pub fn lt(self: Self, a: T, b: T) bool {
            return self.compare(a, b) == .lt;
        }

        /// 小于等于
        pub fn le(self: Self, a: T, b: T) bool {
            return self.compare(a, b) != .gt;
        }

        /// 大于
        pub fn gt(self: Self, a: T, b: T) bool {
            return self.compare(a, b) == .gt;
        }

        /// 大于等于
        pub fn ge(self: Self, a: T, b: T) bool {
            return self.compare(a, b) != .lt;
        }

        /// 等于
        pub fn eq(self: Self, a: T, b: T) bool {
            return self.compare(a, b) == .eq;
        }

        /// 返回较小的值
        pub fn min(self: Self, a: T, b: T) T {
            return if (self.le(a, b)) a else b;
        }

        /// 返回较大的值
        pub fn max(self: Self, a: T, b: T) T {
            return if (self.ge(a, b)) a else b;
        }

        /// 将值限制在范围内
        pub fn clamp(self: Self, value: T, low: T, high: T) T {
            return self.min(high, self.max(low, value));
        }

        /// 检查值是否在范围内（包含边界）
        pub fn between(self: Self, value: T, low: T, high: T) bool {
            return self.ge(value, low) and self.le(value, high);
        }
    };
}

/// 创建默认的 Ord 实例
pub fn defaultOrd(comptime T: type) Ord(T) {
    return .{
        .compareFn = &struct {
            fn f(a: T, b: T) Ordering {
                if (a < b) return .lt;
                if (a > b) return .gt;
                return .eq;
            }
        }.f,
    };
}

/// 使用自定义函数创建 Ord 实例
pub fn ordBy(comptime T: type, comptime B: type, comptime f: *const fn (T) B) Ord(T) {
    return .{
        .compareFn = &struct {
            fn compare(a: T, b: T) Ordering {
                const fa = f(a);
                const fb = f(b);
                if (fa < fb) return .lt;
                if (fa > fb) return .gt;
                return .eq;
            }
        }.compare,
    };
}

/// 反转排序
pub fn reverseOrd(comptime T: type, comptime ordInstance: Ord(T)) Ord(T) {
    return .{
        .compareFn = &struct {
            fn compare(a: T, b: T) Ordering {
                return ordInstance.compare(a, b).reverse();
            }
        }.compare,
    };
}

/// 获取切片中的最小值
pub fn minimum(comptime T: type, ordInstance: Ord(T), slice: []const T) ?T {
    if (slice.len == 0) return null;
    var result = slice[0];
    for (slice[1..]) |item| {
        if (ordInstance.lt(item, result)) result = item;
    }
    return result;
}

/// 获取切片中的最大值
pub fn maximum(comptime T: type, ordInstance: Ord(T), slice: []const T) ?T {
    if (slice.len == 0) return null;
    var result = slice[0];
    for (slice[1..]) |item| {
        if (ordInstance.gt(item, result)) result = item;
    }
    return result;
}

/// 使用函数获取切片中的最小值
pub fn minimumBy(
    comptime T: type,
    comptime B: type,
    f: *const fn (T) B,
    slice: []const T,
) ?T {
    if (slice.len == 0) return null;
    var result = slice[0];
    var resultKey = f(result);
    for (slice[1..]) |item| {
        const key = f(item);
        if (key < resultKey) {
            result = item;
            resultKey = key;
        }
    }
    return result;
}

/// 使用函数获取切片中的最大值
pub fn maximumBy(
    comptime T: type,
    comptime B: type,
    f: *const fn (T) B,
    slice: []const T,
) ?T {
    if (slice.len == 0) return null;
    var result = slice[0];
    var resultKey = f(result);
    for (slice[1..]) |item| {
        const key = f(item);
        if (key > resultKey) {
            result = item;
            resultKey = key;
        }
    }
    return result;
}

/// 检查切片是否已排序（升序）
pub fn isSorted(comptime T: type, ordInstance: Ord(T), slice: []const T) bool {
    if (slice.len <= 1) return true;
    for (0..slice.len - 1) |i| {
        if (ordInstance.gt(slice[i], slice[i + 1])) return false;
    }
    return true;
}

/// 检查切片是否已排序（降序）
pub fn isSortedDesc(comptime T: type, ordInstance: Ord(T), slice: []const T) bool {
    if (slice.len <= 1) return true;
    for (0..slice.len - 1) |i| {
        if (ordInstance.lt(slice[i], slice[i + 1])) return false;
    }
    return true;
}

/// 使用 Ord 实例对切片进行排序（就地）
pub fn sortWith(comptime T: type, ordInstance: Ord(T), slice: []T) void {
    std.mem.sort(T, slice, ordInstance, struct {
        fn f(ord: Ord(T), a: T, b: T) bool {
            return ord.lt(a, b);
        }
    }.f);
}

// ============ 预定义的 Ord 实例 ============

/// i32 的 Ord 实例
pub const ordI32 = defaultOrd(i32);

/// i64 的 Ord 实例
pub const ordI64 = defaultOrd(i64);

/// u8 的 Ord 实例
pub const ordU8 = defaultOrd(u8);

/// u32 的 Ord 实例
pub const ordU32 = defaultOrd(u32);

/// u64 的 Ord 实例
pub const ordU64 = defaultOrd(u64);

/// usize 的 Ord 实例
pub const ordUsize = defaultOrd(usize);

/// f32 的 Ord 实例
pub const ordF32 = defaultOrd(f32);

/// f64 的 Ord 实例
pub const ordF64 = defaultOrd(f64);

// ============ 测试 ============

test "Ordering operations" {
    try std.testing.expectEqual(Ordering.gt, Ordering.lt.reverse());
    try std.testing.expectEqual(Ordering.lt, Ordering.gt.reverse());
    try std.testing.expectEqual(Ordering.eq, Ordering.eq.reverse());

    try std.testing.expectEqual(Ordering.lt, Ordering.eq.then(.lt));
    try std.testing.expectEqual(Ordering.lt, Ordering.lt.then(.gt));

    try std.testing.expectEqual(@as(i2, -1), Ordering.lt.toInt());
    try std.testing.expectEqual(@as(i2, 0), Ordering.eq.toInt());
    try std.testing.expectEqual(@as(i2, 1), Ordering.gt.toInt());
}

test "Ord basic operations" {
    const intOrd = defaultOrd(i32);

    try std.testing.expect(intOrd.lt(1, 2));
    try std.testing.expect(!intOrd.lt(2, 1));
    try std.testing.expect(intOrd.le(1, 1));
    try std.testing.expect(intOrd.le(1, 2));
    try std.testing.expect(intOrd.gt(2, 1));
    try std.testing.expect(intOrd.ge(2, 2));
    try std.testing.expect(intOrd.eq(3, 3));
}

test "Ord reflexivity law" {
    const intOrd = defaultOrd(i32);
    const values = [_]i32{ -10, -1, 0, 1, 10 };

    for (values) |v| {
        try std.testing.expectEqual(Ordering.eq, intOrd.compare(v, v));
    }
}

test "Ord antisymmetry law" {
    const intOrd = defaultOrd(i32);

    try std.testing.expectEqual(Ordering.lt, intOrd.compare(1, 2));
    try std.testing.expectEqual(Ordering.gt, intOrd.compare(2, 1));
}

test "Ord min and max" {
    const intOrd = defaultOrd(i32);

    try std.testing.expectEqual(@as(i32, 3), intOrd.min(3, 5));
    try std.testing.expectEqual(@as(i32, 5), intOrd.max(3, 5));
    try std.testing.expectEqual(@as(i32, 3), intOrd.min(3, 3));
}

test "Ord clamp" {
    const intOrd = defaultOrd(i32);

    try std.testing.expectEqual(@as(i32, 5), intOrd.clamp(3, 5, 10));
    try std.testing.expectEqual(@as(i32, 10), intOrd.clamp(15, 5, 10));
    try std.testing.expectEqual(@as(i32, 7), intOrd.clamp(7, 5, 10));
}

test "Ord between" {
    const intOrd = defaultOrd(i32);

    try std.testing.expect(intOrd.between(5, 1, 10));
    try std.testing.expect(intOrd.between(1, 1, 10));
    try std.testing.expect(intOrd.between(10, 1, 10));
    try std.testing.expect(!intOrd.between(0, 1, 10));
    try std.testing.expect(!intOrd.between(11, 1, 10));
}

test "minimum and maximum" {
    const intOrd = defaultOrd(i32);
    const arr = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };

    try std.testing.expectEqual(@as(?i32, 1), minimum(i32, intOrd, &arr));
    try std.testing.expectEqual(@as(?i32, 9), maximum(i32, intOrd, &arr));

    const empty: []const i32 = &.{};
    try std.testing.expectEqual(@as(?i32, null), minimum(i32, intOrd, empty));
}

test "minimumBy and maximumBy" {
    const Person = struct { name: []const u8, age: u32 };

    const getAge = struct {
        fn f(p: Person) u32 {
            return p.age;
        }
    }.f;

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
        .{ .name = "Carol", .age = 35 },
    };

    const youngest = minimumBy(Person, u32, getAge, &people);
    try std.testing.expect(youngest != null);
    try std.testing.expectEqual(@as(u32, 25), youngest.?.age);

    const oldest = maximumBy(Person, u32, getAge, &people);
    try std.testing.expect(oldest != null);
    try std.testing.expectEqual(@as(u32, 35), oldest.?.age);
}

test "isSorted" {
    const intOrd = defaultOrd(i32);

    const sorted = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expect(isSorted(i32, intOrd, &sorted));

    const unsorted = [_]i32{ 1, 3, 2, 4, 5 };
    try std.testing.expect(!isSorted(i32, intOrd, &unsorted));

    const sortedDesc = [_]i32{ 5, 4, 3, 2, 1 };
    try std.testing.expect(isSortedDesc(i32, intOrd, &sortedDesc));
}

test "ordBy" {
    const Person = struct { name: []const u8, age: u32 };

    const getAge = struct {
        fn f(p: Person) u32 {
            return p.age;
        }
    }.f;

    const personOrdByAge = ordBy(Person, u32, getAge);

    const alice = Person{ .name = "Alice", .age = 30 };
    const bob = Person{ .name = "Bob", .age = 25 };

    try std.testing.expect(personOrdByAge.gt(alice, bob));
    try std.testing.expect(personOrdByAge.lt(bob, alice));
}

test "reverseOrd" {
    const revOrd = reverseOrd(i32, ordI32);

    try std.testing.expect(revOrd.gt(1, 2));
    try std.testing.expect(revOrd.lt(2, 1));
}

test "sortWith" {
    const intOrd = defaultOrd(i32);
    var arr = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };

    sortWith(i32, intOrd, &arr);

    try std.testing.expect(isSorted(i32, intOrd, &arr));
    try std.testing.expectEqual(@as(i32, 1), arr[0]);
    try std.testing.expectEqual(@as(i32, 9), arr[arr.len - 1]);
}
