//! 并行计算抽象
//!
//! 基础的并行计算支持。

const std = @import("std");

/// 并行映射数组
pub fn parMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
) ![]B {
    const result = try allocator.alloc(B, slice.len);
    for (slice, 0..) |item, i| {
        result[i] = f(item);
    }
    return result;
}

/// 并行过滤
pub fn parFilter(
    comptime A: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    predicate: *const fn (A) bool,
) ![]A {
    // 计算需要多少空间
    var count: usize = 0;
    for (slice) |item| {
        if (predicate(item)) {
            count += 1;
        }
    }

    const result = try allocator.alloc(A, count);
    var result_idx: usize = 0;
    for (slice) |item| {
        if (predicate(item)) {
            result[result_idx] = item;
            result_idx += 1;
        }
    }

    return result;
}

// ============ 测试 ============

test "parMap" {
    const allocator = std.testing.allocator;
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const result = try parMap(i32, i32, allocator, &nums, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 10), result[4]);
}

test "parFilter" {
    const allocator = std.testing.allocator;
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const result = try parFilter(i32, allocator, &nums, struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 4), result[1]);
}
