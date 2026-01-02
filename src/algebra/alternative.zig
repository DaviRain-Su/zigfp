//! Alternative 模块
//!
//! Alternative 是 Applicative 的扩展，提供选择和重复操作。
//! 它是 MonadPlus 的替代，适用于那些支持"选择"和"空值"的类型。
//!
//! 核心操作:
//! - `empty` - 空值构造
//! - `or` - 选择操作 (<|>)
//! - `many` - 零或多个
//! - `some` - 一或多个
//! - `optional` - 可选的

const std = @import("std");
const option_mod = @import("../core/option.zig");
const Option = option_mod.Option;

/// Alternative 工具集合
/// 简化实现，为特定类型提供Alternative操作
pub const alternative = struct {
    /// Option Alternative 工具
    pub const option = struct {
        /// 空值构造
        pub fn empty(comptime A: type) Option(A) {
            return Option(A).None();
        }

        /// 选择操作 (<|>)
        pub fn orOp(comptime A: type, fa: Option(A), fb: Option(A)) Option(A) {
            if (fa.isSome()) return fa;
            return fb;
        }

        /// 零或多个 - many（简化实现）
        pub fn many(
            comptime A: type,
            allocator: std.mem.Allocator,
            fa: Option(A),
        ) ![]Option(A) {
            var result = try std.ArrayList(Option(A)).initCapacity(allocator, 1);
            errdefer result.deinit(allocator);

            if (fa.isSome()) {
                try result.append(allocator, fa);
            }

            return result.toOwnedSlice(allocator);
        }

        /// 一或多个 - some（简化实现）
        pub fn some(
            comptime A: type,
            allocator: std.mem.Allocator,
            fa: Option(A),
        ) ![]Option(A) {
            if (fa.isNone()) {
                return error.NoElements;
            }

            var result = try std.ArrayList(Option(A)).initCapacity(allocator, 1);
            errdefer result.deinit(allocator);

            try result.append(allocator, fa);
            return result.toOwnedSlice(allocator);
        }

        /// 可选的 - optional
        pub fn optional(comptime A: type, fa: Option(A)) Option(Option(A)) {
            return Option(Option(A)).Some(fa);
        }
    };
};

// ============ 便捷函数 ============

/// Option 的 empty
pub fn emptyOption(comptime A: type) Option(A) {
    return alternative.option.empty(A);
}

/// Option 的 or 操作
pub fn orOption(comptime A: type, fa: Option(A), fb: Option(A)) Option(A) {
    if (fa.isSome()) return fa;
    return fb;
}

/// Option 的 many 操作
pub fn manyOption(comptime A: type, allocator: std.mem.Allocator, fa: Option(A)) ![]Option(A) {
    return alternative.option.many(A, allocator, fa);
}

/// Option 的 some 操作
pub fn someOption(comptime A: type, allocator: std.mem.Allocator, fa: Option(A)) ![]Option(A) {
    return alternative.option.some(A, allocator, fa);
}

/// Option 的 optional 操作
pub fn optionalOption(comptime A: type, fa: Option(A)) Option(Option(A)) {
    return alternative.option.optional(A, fa);
}

// ============ 测试 ============

test "Option Alternative empty" {
    const empty_val = alternative.option.empty(i32);
    try std.testing.expect(empty_val.isNone());
}

test "Option Alternative or" {
    const a = Option(i32).Some(42);
    const b = Option(i32).Some(24);
    const none_val = Option(i32).None();

    // Some + Some = 第一个 Some
    const result1 = alternative.option.orOp(i32, a, b);
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(i32, 42), result1.unwrap());

    // None + Some = Some
    const result2 = alternative.option.orOp(i32, none_val, b);
    try std.testing.expect(result2.isSome());
    try std.testing.expectEqual(@as(i32, 24), result2.unwrap());

    // Some + None = Some
    const result3 = alternative.option.orOp(i32, a, none_val);
    try std.testing.expect(result3.isSome());
    try std.testing.expectEqual(@as(i32, 42), result3.unwrap());

    // None + None = None
    const result4 = alternative.option.orOp(i32, none_val, none_val);
    try std.testing.expect(result4.isNone());
}

test "Option Alternative many" {
    const allocator = std.testing.allocator;

    const opt = Option(i32).Some(42);
    const result = try alternative.option.many(i32, allocator, opt);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expect(result[0].isSome());
    try std.testing.expectEqual(@as(i32, 42), result[0].unwrap());

    // None 的 many 应该是空数组
    const none_opt = Option(i32).None();
    const result2 = try alternative.option.many(i32, allocator, none_opt);
    defer allocator.free(result2);

    try std.testing.expectEqual(@as(usize, 0), result2.len);
}

test "Option Alternative some" {
    const allocator = std.testing.allocator;

    const opt = Option(i32).Some(42);
    const result = try alternative.option.some(i32, allocator, opt);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expect(result[0].isSome());
    try std.testing.expectEqual(@as(i32, 42), result[0].unwrap());
}

test "Option Alternative optional" {
    const opt = Option(i32).Some(42);
    const result = alternative.option.optional(i32, opt);

    try std.testing.expect(result.isSome());
    const inner = result.unwrap();
    try std.testing.expect(inner.isSome());
    try std.testing.expectEqual(@as(i32, 42), inner.unwrap());
}

test "convenience functions" {
    const allocator = std.testing.allocator;

    const empty_val = emptyOption(i32);
    try std.testing.expect(empty_val.isNone());

    const a = Option(i32).Some(42);
    const b = Option(i32).Some(24);
    const result = orOption(i32, a, b);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    const many_result = try manyOption(i32, allocator, a);
    defer allocator.free(many_result);
    try std.testing.expectEqual(@as(usize, 1), many_result.len);
}
