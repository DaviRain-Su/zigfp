//! Bounded - 有界类型类
//!
//! Bounded 类型类定义了具有最小和最大边界的类型。
//! 适用于枚举类型和有限整数类型。

const std = @import("std");

/// Bounded 类型类 - 有界类型
pub fn Bounded(comptime T: type) type {
    return struct {
        const Self = @This();

        minBound: T,
        maxBound: T,

        /// 获取最小边界
        pub fn getMinBound(self: Self) T {
            return self.minBound;
        }

        /// 获取最大边界
        pub fn getMaxBound(self: Self) T {
            return self.maxBound;
        }

        /// 获取范围大小（对于整数类型）
        pub fn rangeSize(self: Self) usize {
            const info = @typeInfo(T);
            if (info == .int) {
                const max_val: i128 = @intCast(self.maxBound);
                const min_val: i128 = @intCast(self.minBound);
                return @intCast(max_val - min_val + 1);
            }
            return 0;
        }

        /// 检查值是否在边界内
        pub fn inBounds(self: Self, value: T) bool {
            return value >= self.minBound and value <= self.maxBound;
        }

        /// 将值限制在边界内
        pub fn clampToBounds(self: Self, value: T) T {
            if (value < self.minBound) return self.minBound;
            if (value > self.maxBound) return self.maxBound;
            return value;
        }
    };
}

/// 创建 Bounded 实例
pub fn makeBounded(comptime T: type, min: T, max: T) Bounded(T) {
    return .{
        .minBound = min,
        .maxBound = max,
    };
}

// ============ 预定义的整数 Bounded 实例 ============

/// u8 的 Bounded 实例
pub const boundedU8 = Bounded(u8){
    .minBound = 0,
    .maxBound = 255,
};

/// u16 的 Bounded 实例
pub const boundedU16 = Bounded(u16){
    .minBound = 0,
    .maxBound = 65535,
};

/// u32 的 Bounded 实例
pub const boundedU32 = Bounded(u32){
    .minBound = 0,
    .maxBound = 4294967295,
};

/// u64 的 Bounded 实例
pub const boundedU64 = Bounded(u64){
    .minBound = 0,
    .maxBound = 18446744073709551615,
};

/// i8 的 Bounded 实例
pub const boundedI8 = Bounded(i8){
    .minBound = -128,
    .maxBound = 127,
};

/// i16 的 Bounded 实例
pub const boundedI16 = Bounded(i16){
    .minBound = -32768,
    .maxBound = 32767,
};

/// i32 的 Bounded 实例
pub const boundedI32 = Bounded(i32){
    .minBound = -2147483648,
    .maxBound = 2147483647,
};

/// i64 的 Bounded 实例
pub const boundedI64 = Bounded(i64){
    .minBound = -9223372036854775808,
    .maxBound = 9223372036854775807,
};

/// bool 的 Bounded 实例
pub const boundedBool = Bounded(bool){
    .minBound = false,
    .maxBound = true,
};

/// 单位类型的 Bounded 实例
pub const boundedUnit = Bounded(void){
    .minBound = {},
    .maxBound = {},
};

// ============ 辅助函数 ============

/// 获取整数类型的默认 Bounded 实例
pub fn intBounded(comptime T: type) Bounded(T) {
    const info = @typeInfo(T);
    if (info != .int) @compileError("intBounded requires an integer type");

    return .{
        .minBound = std.math.minInt(T),
        .maxBound = std.math.maxInt(T),
    };
}

/// 枚举所有值（对于小范围整数）
pub fn enumerate(comptime T: type, bounded: Bounded(T), allocator: std.mem.Allocator) ![]T {
    const info = @typeInfo(T);
    if (info != .int) @compileError("enumerate requires an integer type");

    const size = bounded.rangeSize();
    if (size == 0 or size > 65536) return error.RangeTooLarge;

    const result = try allocator.alloc(T, size);
    errdefer allocator.free(result);

    var value: i128 = @intCast(bounded.minBound);
    for (result) |*slot| {
        slot.* = @intCast(value);
        value += 1;
    }

    return result;
}

/// 获取后继值（如果存在）
pub fn succ(comptime T: type, bounded: Bounded(T), value: T) ?T {
    if (value >= bounded.maxBound) return null;
    return value + 1;
}

/// 获取前驱值（如果存在）
pub fn pred(comptime T: type, bounded: Bounded(T), value: T) ?T {
    if (value <= bounded.minBound) return null;
    return value - 1;
}

/// 循环后继（到达最大值后回到最小值）
pub fn succWrap(comptime T: type, bounded: Bounded(T), value: T) T {
    if (value >= bounded.maxBound) return bounded.minBound;
    return value + 1;
}

/// 循环前驱（到达最小值后回到最大值）
pub fn predWrap(comptime T: type, bounded: Bounded(T), value: T) T {
    if (value <= bounded.minBound) return bounded.maxBound;
    return value - 1;
}

// ============ 测试 ============

test "Bounded basic operations" {
    const b = boundedU8;

    try std.testing.expectEqual(@as(u8, 0), b.getMinBound());
    try std.testing.expectEqual(@as(u8, 255), b.getMaxBound());
}

test "Bounded inBounds" {
    const b = boundedI8;

    try std.testing.expect(b.inBounds(0));
    try std.testing.expect(b.inBounds(-128));
    try std.testing.expect(b.inBounds(127));
}

test "Bounded clampToBounds" {
    const b = makeBounded(i32, -10, 10);

    try std.testing.expectEqual(@as(i32, 5), b.clampToBounds(5));
    try std.testing.expectEqual(@as(i32, -10), b.clampToBounds(-100));
    try std.testing.expectEqual(@as(i32, 10), b.clampToBounds(100));
}

test "Bounded rangeSize" {
    const b1 = makeBounded(i32, 0, 9);
    try std.testing.expectEqual(@as(usize, 10), b1.rangeSize());

    const b2 = makeBounded(i32, -5, 5);
    try std.testing.expectEqual(@as(usize, 11), b2.rangeSize());
}

test "intBounded" {
    const b = intBounded(u8);
    try std.testing.expectEqual(@as(u8, 0), b.minBound);
    try std.testing.expectEqual(@as(u8, 255), b.maxBound);

    const bSigned = intBounded(i8);
    try std.testing.expectEqual(@as(i8, -128), bSigned.minBound);
    try std.testing.expectEqual(@as(i8, 127), bSigned.maxBound);
}

test "enumerate" {
    const b = makeBounded(i32, 1, 5);
    const values = try enumerate(i32, b, std.testing.allocator);
    defer std.testing.allocator.free(values);

    try std.testing.expectEqual(@as(usize, 5), values.len);
    try std.testing.expectEqual(@as(i32, 1), values[0]);
    try std.testing.expectEqual(@as(i32, 5), values[4]);
}

test "succ and pred" {
    const b = makeBounded(i32, 0, 10);

    try std.testing.expectEqual(@as(?i32, 6), succ(i32, b, 5));
    try std.testing.expectEqual(@as(?i32, null), succ(i32, b, 10));

    try std.testing.expectEqual(@as(?i32, 4), pred(i32, b, 5));
    try std.testing.expectEqual(@as(?i32, null), pred(i32, b, 0));
}

test "succWrap and predWrap" {
    const b = makeBounded(i32, 0, 10);

    try std.testing.expectEqual(@as(i32, 0), succWrap(i32, b, 10));
    try std.testing.expectEqual(@as(i32, 6), succWrap(i32, b, 5));

    try std.testing.expectEqual(@as(i32, 10), predWrap(i32, b, 0));
    try std.testing.expectEqual(@as(i32, 4), predWrap(i32, b, 5));
}

test "boundedBool" {
    const b = boundedBool;
    try std.testing.expectEqual(false, b.minBound);
    try std.testing.expectEqual(true, b.maxBound);
}
