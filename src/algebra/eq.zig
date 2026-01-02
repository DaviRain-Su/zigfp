//! Eq - 等价性类型类
//!
//! Eq 类型类定义了等价性比较操作。
//! 所有实现必须满足以下法则：
//! - 自反性: eq(x, x) = true
//! - 对称性: eq(x, y) = eq(y, x)
//! - 传递性: 如果 eq(x, y) 且 eq(y, z)，则 eq(x, z)

const std = @import("std");

/// Eq 类型类 - 等价性比较
pub fn Eq(comptime T: type) type {
    return struct {
        const Self = @This();

        eqFn: *const fn (T, T) bool,

        /// 比较两个值是否相等
        pub fn eq(self: Self, a: T, b: T) bool {
            return self.eqFn(a, b);
        }

        /// 比较两个值是否不相等
        pub fn neq(self: Self, a: T, b: T) bool {
            return !self.eq(a, b);
        }
    };
}

/// 创建默认的 Eq 实例（使用 == 操作符）
pub fn defaultEq(comptime T: type) Eq(T) {
    return .{
        .eqFn = &struct {
            fn f(a: T, b: T) bool {
                return a == b;
            }
        }.f,
    };
}

/// 使用自定义函数创建 Eq 实例
pub fn eqBy(comptime T: type, comptime B: type, comptime f: *const fn (T) B) Eq(T) {
    return .{
        .eqFn = &struct {
            fn compare(a: T, b: T) bool {
                return f(a) == f(b);
            }
        }.compare,
    };
}

/// 检查切片中所有元素是否相等
pub fn allEq(comptime T: type, eqInstance: Eq(T), slice: []const T) bool {
    if (slice.len <= 1) return true;
    const first = slice[0];
    for (slice[1..]) |item| {
        if (!eqInstance.eq(first, item)) return false;
    }
    return true;
}

/// 检查切片中是否存在指定元素
pub fn elem(comptime T: type, eqInstance: Eq(T), needle: T, haystack: []const T) bool {
    for (haystack) |item| {
        if (eqInstance.eq(needle, item)) return true;
    }
    return false;
}

/// 检查切片中是否不存在指定元素
pub fn notElem(comptime T: type, eqInstance: Eq(T), needle: T, haystack: []const T) bool {
    return !elem(T, eqInstance, needle, haystack);
}

/// 查找元素在切片中的索引
pub fn findIndex(comptime T: type, eqInstance: Eq(T), needle: T, haystack: []const T) ?usize {
    for (haystack, 0..) |item, i| {
        if (eqInstance.eq(needle, item)) return i;
    }
    return null;
}

/// 计算元素在切片中出现的次数
pub fn count(comptime T: type, eqInstance: Eq(T), needle: T, haystack: []const T) usize {
    var c: usize = 0;
    for (haystack) |item| {
        if (eqInstance.eq(needle, item)) c += 1;
    }
    return c;
}

/// 去除切片中的重复元素（需要分配内存）
pub fn nub(comptime T: type, eqInstance: Eq(T), allocator: std.mem.Allocator, slice: []const T) ![]T {
    var result = try std.ArrayList(T).initCapacity(allocator, slice.len);
    errdefer result.deinit(allocator);

    for (slice) |item| {
        if (!elem(T, eqInstance, item, result.items)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// 按函数去重
pub fn nubBy(
    comptime T: type,
    comptime B: type,
    comptime f: *const fn (T) B,
    allocator: std.mem.Allocator,
    slice: []const T,
) ![]T {
    const bEq = defaultEq(B);
    var result = try std.ArrayList(T).initCapacity(allocator, slice.len);
    var seen = try std.ArrayList(B).initCapacity(allocator, slice.len);
    errdefer result.deinit(allocator);
    defer seen.deinit(allocator);

    for (slice) |item| {
        const key = f(item);
        if (!elem(B, bEq, key, seen.items)) {
            try result.append(allocator, item);
            try seen.append(allocator, key);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// 分组相邻的相等元素
pub fn group(comptime T: type, eqInstance: Eq(T), allocator: std.mem.Allocator, slice: []const T) ![][]const T {
    if (slice.len == 0) return &[_][]const T{};

    var groups = try std.ArrayList([]const T).initCapacity(allocator, 8);
    errdefer groups.deinit(allocator);

    var start: usize = 0;
    var i: usize = 1;

    while (i < slice.len) : (i += 1) {
        if (!eqInstance.eq(slice[i - 1], slice[i])) {
            try groups.append(allocator, slice[start..i]);
            start = i;
        }
    }
    try groups.append(allocator, slice[start..]);

    return try groups.toOwnedSlice(allocator);
}

// ============ 预定义的 Eq 实例 ============

/// i32 的 Eq 实例
pub const eqI32 = defaultEq(i32);

/// i64 的 Eq 实例
pub const eqI64 = defaultEq(i64);

/// u8 的 Eq 实例
pub const eqU8 = defaultEq(u8);

/// u32 的 Eq 实例
pub const eqU32 = defaultEq(u32);

/// u64 的 Eq 实例
pub const eqU64 = defaultEq(u64);

/// usize 的 Eq 实例
pub const eqUsize = defaultEq(usize);

/// bool 的 Eq 实例
pub const eqBool = defaultEq(bool);

/// 字符串切片的 Eq 实例
pub fn eqString() Eq([]const u8) {
    return .{
        .eqFn = &struct {
            fn f(a: []const u8, b: []const u8) bool {
                return std.mem.eql(u8, a, b);
            }
        }.f,
    };
}

// ============ 测试 ============

test "Eq basic operations" {
    const intEq = defaultEq(i32);

    try std.testing.expect(intEq.eq(1, 1));
    try std.testing.expect(!intEq.eq(1, 2));
    try std.testing.expect(intEq.neq(1, 2));
    try std.testing.expect(!intEq.neq(1, 1));
}

test "Eq reflexivity law" {
    const intEq = defaultEq(i32);
    const values = [_]i32{ -10, -1, 0, 1, 10, 100 };

    for (values) |v| {
        try std.testing.expect(intEq.eq(v, v));
    }
}

test "Eq symmetry law" {
    const intEq = defaultEq(i32);

    try std.testing.expect(intEq.eq(1, 1) == intEq.eq(1, 1));
    try std.testing.expect(intEq.eq(1, 2) == intEq.eq(2, 1));
}

test "allEq" {
    const intEq = defaultEq(i32);

    const allSame = [_]i32{ 5, 5, 5, 5 };
    try std.testing.expect(allEq(i32, intEq, &allSame));

    const different = [_]i32{ 5, 5, 6, 5 };
    try std.testing.expect(!allEq(i32, intEq, &different));

    const empty: []const i32 = &.{};
    try std.testing.expect(allEq(i32, intEq, empty));

    const single = [_]i32{42};
    try std.testing.expect(allEq(i32, intEq, &single));
}

test "elem and notElem" {
    const intEq = defaultEq(i32);
    const arr = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expect(elem(i32, intEq, 3, &arr));
    try std.testing.expect(!elem(i32, intEq, 10, &arr));
    try std.testing.expect(notElem(i32, intEq, 10, &arr));
    try std.testing.expect(!notElem(i32, intEq, 3, &arr));
}

test "findIndex" {
    const intEq = defaultEq(i32);
    const arr = [_]i32{ 10, 20, 30, 40, 50 };

    try std.testing.expectEqual(@as(?usize, 2), findIndex(i32, intEq, 30, &arr));
    try std.testing.expectEqual(@as(?usize, 0), findIndex(i32, intEq, 10, &arr));
    try std.testing.expectEqual(@as(?usize, null), findIndex(i32, intEq, 100, &arr));
}

test "count" {
    const intEq = defaultEq(i32);
    const arr = [_]i32{ 1, 2, 1, 3, 1, 4, 1 };

    try std.testing.expectEqual(@as(usize, 4), count(i32, intEq, 1, &arr));
    try std.testing.expectEqual(@as(usize, 1), count(i32, intEq, 2, &arr));
    try std.testing.expectEqual(@as(usize, 0), count(i32, intEq, 10, &arr));
}

test "nub" {
    const intEq = defaultEq(i32);
    const arr = [_]i32{ 1, 2, 1, 3, 2, 4, 1 };

    const unique = try nub(i32, intEq, std.testing.allocator, &arr);
    defer std.testing.allocator.free(unique);

    try std.testing.expectEqual(@as(usize, 4), unique.len);
    try std.testing.expectEqual(@as(i32, 1), unique[0]);
    try std.testing.expectEqual(@as(i32, 2), unique[1]);
    try std.testing.expectEqual(@as(i32, 3), unique[2]);
    try std.testing.expectEqual(@as(i32, 4), unique[3]);
}

test "nubBy" {
    const abs = struct {
        fn f(x: i32) u32 {
            return if (x < 0) @intCast(-x) else @intCast(x);
        }
    }.f;

    const arr = [_]i32{ 1, -1, 2, -2, 3 };
    const unique = try nubBy(i32, u32, abs, std.testing.allocator, &arr);
    defer std.testing.allocator.free(unique);

    try std.testing.expectEqual(@as(usize, 3), unique.len);
    try std.testing.expectEqual(@as(i32, 1), unique[0]);
    try std.testing.expectEqual(@as(i32, 2), unique[1]);
    try std.testing.expectEqual(@as(i32, 3), unique[2]);
}

test "group" {
    const intEq = defaultEq(i32);
    const arr = [_]i32{ 1, 1, 2, 2, 2, 3, 1, 1 };

    const groups = try group(i32, intEq, std.testing.allocator, &arr);
    defer std.testing.allocator.free(groups);

    try std.testing.expectEqual(@as(usize, 4), groups.len);
    try std.testing.expectEqual(@as(usize, 2), groups[0].len);
    try std.testing.expectEqual(@as(usize, 3), groups[1].len);
    try std.testing.expectEqual(@as(usize, 1), groups[2].len);
    try std.testing.expectEqual(@as(usize, 2), groups[3].len);
}

test "eqString" {
    const strEq = eqString();

    try std.testing.expect(strEq.eq("hello", "hello"));
    try std.testing.expect(!strEq.eq("hello", "world"));
    try std.testing.expect(strEq.neq("hello", "world"));
}

test "eqBy" {
    const Person = struct { name: []const u8, age: u32 };

    const getAge = struct {
        fn f(p: Person) u32 {
            return p.age;
        }
    }.f;

    const personEqByAge = eqBy(Person, u32, getAge);

    const alice = Person{ .name = "Alice", .age = 30 };
    const bob = Person{ .name = "Bob", .age = 30 };
    const carol = Person{ .name = "Carol", .age = 25 };

    try std.testing.expect(personEqByAge.eq(alice, bob));
    try std.testing.expect(!personEqByAge.eq(alice, carol));
}
