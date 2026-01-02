//! 序列工具模块
//!
//! 提供函数式风格的序列操作工具：
//! - zipWith - 使用函数合并两个序列
//! - zip3 - 合并三个序列
//! - unzip - 分解 Pair 序列
//! - intersperse - 在元素间插入分隔符
//! - intercalate - 使用分隔序列连接
//! - chunksOf - 分块
//! - sliding - 滑动窗口
//! - transpose - 转置

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============ zipWith ============

/// 使用函数合并两个序列
/// zipWith(f, [a, b, c], [x, y, z]) = [f(a, x), f(b, y), f(c, z)]
pub fn zipWith(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    allocator: Allocator,
    as: []const A,
    bs: []const B,
    f: *const fn (A, B) C,
) ![]C {
    const len = @min(as.len, bs.len);
    var result = try allocator.alloc(C, len);
    errdefer allocator.free(result);

    for (0..len) |i| {
        result[i] = f(as[i], bs[i]);
    }

    return result;
}

/// zipWith 的惰性版本 - 返回迭代器
pub fn ZipWithIterator(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        as: []const A,
        bs: []const B,
        f: *const fn (A, B) C,
        index: usize,

        const Self = @This();

        pub fn init(as: []const A, bs: []const B, f: *const fn (A, B) C) Self {
            return .{ .as = as, .bs = bs, .f = f, .index = 0 };
        }

        pub fn next(self: *Self) ?C {
            if (self.index >= self.as.len or self.index >= self.bs.len) {
                return null;
            }
            const result = self.f(self.as[self.index], self.bs[self.index]);
            self.index += 1;
            return result;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

pub fn zipWithIter(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    as: []const A,
    bs: []const B,
    f: *const fn (A, B) C,
) ZipWithIterator(A, B, C) {
    return ZipWithIterator(A, B, C).init(as, bs, f);
}

// ============ zip3 ============

/// 合并三个序列为三元组序列
pub fn zip3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    allocator: Allocator,
    as: []const A,
    bs: []const B,
    cs: []const C,
) ![]struct { A, B, C } {
    const len = @min(@min(as.len, bs.len), cs.len);
    var result = try allocator.alloc(struct { A, B, C }, len);
    errdefer allocator.free(result);

    for (0..len) |i| {
        result[i] = .{ as[i], bs[i], cs[i] };
    }

    return result;
}

/// zipWith3 - 使用函数合并三个序列
pub fn zipWith3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    allocator: Allocator,
    as: []const A,
    bs: []const B,
    cs: []const C,
    f: *const fn (A, B, C) D,
) ![]D {
    const len = @min(@min(as.len, bs.len), cs.len);
    var result = try allocator.alloc(D, len);
    errdefer allocator.free(result);

    for (0..len) |i| {
        result[i] = f(as[i], bs[i], cs[i]);
    }

    return result;
}

// ============ unzip ============

/// 分解 Pair 序列为两个序列
pub fn unzip(
    comptime A: type,
    comptime B: type,
    allocator: Allocator,
    pairs: []const struct { A, B },
) !struct { as: []A, bs: []B } {
    var as = try allocator.alloc(A, pairs.len);
    errdefer allocator.free(as);
    var bs = try allocator.alloc(B, pairs.len);
    errdefer allocator.free(bs);

    for (pairs, 0..) |pair, i| {
        as[i] = pair[0];
        bs[i] = pair[1];
    }

    return .{ .as = as, .bs = bs };
}

/// 分解三元组序列为三个序列
pub fn unzip3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    allocator: Allocator,
    triples: []const struct { A, B, C },
) !struct { as: []A, bs: []B, cs: []C } {
    var as = try allocator.alloc(A, triples.len);
    errdefer allocator.free(as);
    var bs = try allocator.alloc(B, triples.len);
    errdefer allocator.free(bs);
    var cs = try allocator.alloc(C, triples.len);
    errdefer allocator.free(cs);

    for (triples, 0..) |triple, i| {
        as[i] = triple[0];
        bs[i] = triple[1];
        cs[i] = triple[2];
    }

    return .{ .as = as, .bs = bs, .cs = cs };
}

// ============ intersperse ============

/// 在序列元素之间插入分隔符
/// intersperse(0, [1, 2, 3]) = [1, 0, 2, 0, 3]
pub fn intersperse(
    comptime T: type,
    allocator: Allocator,
    xs: []const T,
    sep: T,
) ![]T {
    if (xs.len == 0) {
        return try allocator.alloc(T, 0);
    }
    if (xs.len == 1) {
        var result = try allocator.alloc(T, 1);
        result[0] = xs[0];
        return result;
    }

    const result_len = xs.len * 2 - 1;
    var result = try allocator.alloc(T, result_len);
    errdefer allocator.free(result);

    for (xs, 0..) |x, i| {
        result[i * 2] = x;
        if (i < xs.len - 1) {
            result[i * 2 + 1] = sep;
        }
    }

    return result;
}

// ============ intercalate ============

/// 使用分隔序列连接多个序列
/// intercalate([0], [[1, 2], [3, 4], [5]]) = [1, 2, 0, 3, 4, 0, 5]
pub fn intercalate(
    comptime T: type,
    allocator: Allocator,
    sep: []const T,
    xss: []const []const T,
) ![]T {
    if (xss.len == 0) {
        return try allocator.alloc(T, 0);
    }

    // 计算结果长度
    var total_len: usize = 0;
    for (xss) |xs| {
        total_len += xs.len;
    }
    total_len += sep.len * (xss.len - 1);

    var result = try allocator.alloc(T, total_len);
    errdefer allocator.free(result);

    var pos: usize = 0;
    for (xss, 0..) |xs, i| {
        @memcpy(result[pos .. pos + xs.len], xs);
        pos += xs.len;
        if (i < xss.len - 1) {
            @memcpy(result[pos .. pos + sep.len], sep);
            pos += sep.len;
        }
    }

    return result;
}

// ============ chunksOf ============

/// 将序列分成固定大小的块
/// chunksOf(2, [1, 2, 3, 4, 5]) = [[1, 2], [3, 4], [5]]
pub fn chunksOf(
    comptime T: type,
    allocator: Allocator,
    xs: []const T,
    chunk_size: usize,
) ![][]const T {
    if (chunk_size == 0) {
        return error.InvalidChunkSize;
    }
    if (xs.len == 0) {
        return try allocator.alloc([]const T, 0);
    }

    const num_chunks = (xs.len + chunk_size - 1) / chunk_size;
    var result = try allocator.alloc([]const T, num_chunks);
    errdefer allocator.free(result);

    var pos: usize = 0;
    var chunk_idx: usize = 0;
    while (pos < xs.len) : (chunk_idx += 1) {
        const end = @min(pos + chunk_size, xs.len);
        result[chunk_idx] = xs[pos..end];
        pos = end;
    }

    return result;
}

// ============ sliding ============

/// 滑动窗口视图
/// sliding(2, [1, 2, 3, 4]) = [[1, 2], [2, 3], [3, 4]]
pub fn sliding(
    comptime T: type,
    allocator: Allocator,
    xs: []const T,
    window_size: usize,
) ![][]const T {
    if (window_size == 0 or window_size > xs.len) {
        return try allocator.alloc([]const T, 0);
    }

    const num_windows = xs.len - window_size + 1;
    var result = try allocator.alloc([]const T, num_windows);
    errdefer allocator.free(result);

    for (0..num_windows) |i| {
        result[i] = xs[i .. i + window_size];
    }

    return result;
}

// ============ transpose ============

/// 转置二维序列（假设所有行长度相同）
/// transpose([[1, 2], [3, 4], [5, 6]]) = [[1, 3, 5], [2, 4, 6]]
pub fn transpose(
    comptime T: type,
    allocator: Allocator,
    matrix: []const []const T,
) ![][]T {
    if (matrix.len == 0) {
        return try allocator.alloc([]T, 0);
    }

    const rows = matrix.len;
    const cols = matrix[0].len;

    // 验证所有行长度相同
    for (matrix) |row| {
        if (row.len != cols) {
            return error.UnequalRowLengths;
        }
    }

    var result = try allocator.alloc([]T, cols);
    errdefer {
        for (result) |row| {
            allocator.free(row);
        }
        allocator.free(result);
    }

    for (0..cols) |j| {
        result[j] = try allocator.alloc(T, rows);
        for (0..rows) |i| {
            result[j][i] = matrix[i][j];
        }
    }

    return result;
}

// ============ 辅助函数 ============

/// 重复元素 n 次
pub fn replicate(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    x: T,
) ![]T {
    const result = try allocator.alloc(T, n);
    for (result) |*slot| {
        slot.* = x;
    }
    return result;
}

/// 生成范围 [start, end)
pub fn range(
    allocator: Allocator,
    start: i32,
    end: i32,
) ![]i32 {
    if (end <= start) {
        return try allocator.alloc(i32, 0);
    }

    const len: usize = @intCast(end - start);
    var result = try allocator.alloc(i32, len);
    errdefer allocator.free(result);

    for (0..len) |i| {
        result[i] = start + @as(i32, @intCast(i));
    }

    return result;
}

/// 反转序列
pub fn reverse(
    comptime T: type,
    allocator: Allocator,
    xs: []const T,
) ![]T {
    var result = try allocator.alloc(T, xs.len);
    errdefer allocator.free(result);

    for (xs, 0..) |x, i| {
        result[xs.len - 1 - i] = x;
    }

    return result;
}

/// 获取序列的最后 n 个元素
pub fn takeLast(
    comptime T: type,
    xs: []const T,
    n: usize,
) []const T {
    if (n >= xs.len) {
        return xs;
    }
    return xs[xs.len - n ..];
}

/// 删除序列的最后 n 个元素
pub fn dropLast(
    comptime T: type,
    xs: []const T,
    n: usize,
) []const T {
    if (n >= xs.len) {
        return xs[0..0];
    }
    return xs[0 .. xs.len - n];
}

// ============ 错误类型 ============

pub const SequenceError = error{
    InvalidChunkSize,
    UnequalRowLengths,
    OutOfMemory,
};

// ============ 测试 ============

test "zipWith" {
    const allocator = std.testing.allocator;

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const as = [_]i32{ 1, 2, 3 };
    const bs = [_]i32{ 10, 20, 30 };

    const result = try zipWith(i32, i32, i32, allocator, &as, &bs, add);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
}

test "zipWith different lengths" {
    const allocator = std.testing.allocator;

    const mul = struct {
        fn f(a: i32, b: i32) i32 {
            return a * b;
        }
    }.f;

    const as = [_]i32{ 1, 2, 3, 4, 5 };
    const bs = [_]i32{ 10, 20 };

    const result = try zipWith(i32, i32, i32, allocator, &as, &bs, mul);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(i32, 10), result[0]);
    try std.testing.expectEqual(@as(i32, 40), result[1]);
}

test "zipWithIter" {
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const as = [_]i32{ 1, 2, 3 };
    const bs = [_]i32{ 10, 20, 30 };

    var iter = zipWithIter(i32, i32, i32, &as, &bs, add);

    try std.testing.expectEqual(@as(?i32, 11), iter.next());
    try std.testing.expectEqual(@as(?i32, 22), iter.next());
    try std.testing.expectEqual(@as(?i32, 33), iter.next());
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "zip3" {
    const allocator = std.testing.allocator;

    const as = [_]i32{ 1, 2, 3 };
    const bs = [_]u8{ 'a', 'b', 'c' };
    const cs = [_]bool{ true, false, true };

    const result = try zip3(i32, u8, bool, allocator, &as, &bs, &cs);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0][0]);
    try std.testing.expectEqual(@as(u8, 'a'), result[0][1]);
    try std.testing.expect(result[0][2]);
}

test "unzip" {
    const allocator = std.testing.allocator;

    const pairs = [_]struct { i32, u8 }{
        .{ 1, 'a' },
        .{ 2, 'b' },
        .{ 3, 'c' },
    };

    const result = try unzip(i32, u8, allocator, &pairs);
    defer allocator.free(result.as);
    defer allocator.free(result.bs);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, result.as);
    try std.testing.expectEqualSlices(u8, "abc", result.bs);
}

test "intersperse" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{ 1, 2, 3 };
    const result = try intersperse(i32, allocator, &xs, 0);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 0, 2, 0, 3 }, result);
}

test "intersperse empty" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{};
    const result = try intersperse(i32, allocator, &xs, 0);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "intersperse single" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{42};
    const result = try intersperse(i32, allocator, &xs, 0);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{42}, result);
}

test "intercalate" {
    const allocator = std.testing.allocator;

    const sep = [_]i32{0};
    const xss = [_][]const i32{
        &[_]i32{ 1, 2 },
        &[_]i32{ 3, 4 },
        &[_]i32{5},
    };

    const result = try intercalate(i32, allocator, &sep, &xss);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 0, 3, 4, 0, 5 }, result);
}

test "chunksOf" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try chunksOf(i32, allocator, &xs, 2);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2 }, result[0]);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 3, 4 }, result[1]);
    try std.testing.expectEqualSlices(i32, &[_]i32{5}, result[2]);
}

test "sliding" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{ 1, 2, 3, 4 };
    const result = try sliding(i32, allocator, &xs, 2);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2 }, result[0]);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 2, 3 }, result[1]);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 3, 4 }, result[2]);
}

test "transpose" {
    const allocator = std.testing.allocator;

    const matrix = [_][]const i32{
        &[_]i32{ 1, 2 },
        &[_]i32{ 3, 4 },
        &[_]i32{ 5, 6 },
    };

    const result = try transpose(i32, allocator, &matrix);
    defer {
        for (result) |row| {
            allocator.free(row);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 3, 5 }, result[0]);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 2, 4, 6 }, result[1]);
}

test "replicate" {
    const allocator = std.testing.allocator;

    const result = try replicate(i32, allocator, 5, 42);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 42, 42, 42, 42, 42 }, result);
}

test "range" {
    const allocator = std.testing.allocator;

    const result = try range(allocator, 1, 5);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4 }, result);
}

test "reverse" {
    const allocator = std.testing.allocator;

    const xs = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try reverse(i32, allocator, &xs);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 5, 4, 3, 2, 1 }, result);
}

test "takeLast" {
    const xs = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expectEqualSlices(i32, &[_]i32{ 4, 5 }, takeLast(i32, &xs, 2));
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4, 5 }, takeLast(i32, &xs, 10));
}

test "dropLast" {
    const xs = [_]i32{ 1, 2, 3, 4, 5 };

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, dropLast(i32, &xs, 2));
    try std.testing.expectEqualSlices(i32, &[_]i32{}, dropLast(i32, &xs, 10));
}
