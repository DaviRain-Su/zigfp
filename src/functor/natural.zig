//! Natural Transformation - 自然变换
//!
//! 自然变换是函子之间的态射，提供在不同容器类型间转换值的方式。
//!
//! 在函数式编程中，自然变换 `η: F ~> G` 将 F[A] 转换为 G[A]，
//! 满足自然性条件：对于任何 f: A -> B，η_B ∘ F(f) = G(f) ∘ η_A

const std = @import("std");
const Option = @import("../core/option.zig").Option;
const Result = @import("../core/result.zig").Result;

// ============ Option <-> Result 转换 ============

/// Option -> Result
/// 将 Option 转换为 Result，None 变为指定的错误
pub fn optionToResult(
    comptime T: type,
    comptime E: type,
    opt: Option(T),
    err_value: E,
) Result(T, E) {
    if (opt.isSome()) {
        return Result(T, E).Ok(opt.unwrap());
    } else {
        return Result(T, E).Err(err_value);
    }
}

/// Result -> Option
/// 将 Result 转换为 Option，Err 变为 None
pub fn resultToOption(comptime T: type, comptime E: type, res: Result(T, E)) Option(T) {
    if (res.isOk()) {
        return Option(T).Some(res.unwrap());
    } else {
        return Option(T).None();
    }
}

/// Result Err -> Option
/// 将 Result 的错误部分转换为 Option
pub fn resultErrToOption(comptime T: type, comptime E: type, res: Result(T, E)) Option(E) {
    if (res.isErr()) {
        return Option(E).Some(res.unwrapErr());
    } else {
        return Option(E).None();
    }
}

// ============ Option <-> 切片 转换 ============

/// Option -> 切片
/// 将 Option 转换为单元素切片或空切片
pub fn optionToSlice(comptime T: type, opt: Option(T), buffer: *[1]T) []T {
    if (opt.isSome()) {
        buffer[0] = opt.unwrap();
        return buffer[0..1];
    } else {
        return buffer[0..0];
    }
}

/// 切片头部 -> Option
/// 获取切片的第一个元素作为 Option
pub fn sliceHeadOption(comptime T: type, slice: []const T) Option(T) {
    if (slice.len > 0) {
        return Option(T).Some(slice[0]);
    } else {
        return Option(T).None();
    }
}

/// 切片尾部 -> Option
/// 获取切片的最后一个元素作为 Option
pub fn sliceLastOption(comptime T: type, slice: []const T) Option(T) {
    if (slice.len > 0) {
        return Option(T).Some(slice[slice.len - 1]);
    } else {
        return Option(T).None();
    }
}

/// 切片索引 -> Option
/// 安全地获取切片指定索引的元素
pub fn sliceAtOption(comptime T: type, slice: []const T, index: usize) Option(T) {
    if (index < slice.len) {
        return Option(T).Some(slice[index]);
    } else {
        return Option(T).None();
    }
}

// ============ Option 嵌套处理 ============

/// 展平嵌套的 Option
/// Option(Option(T)) -> Option(T)
pub fn flattenOption(comptime T: type, opt: Option(Option(T))) Option(T) {
    if (opt.isSome()) {
        return opt.unwrap();
    } else {
        return Option(T).None();
    }
}

/// 展平嵌套的 Result
/// Result(Result(T, E), E) -> Result(T, E)
pub fn flattenResult(comptime T: type, comptime E: type, res: Result(Result(T, E), E)) Result(T, E) {
    if (res.isOk()) {
        return res.unwrap();
    } else {
        return Result(T, E).Err(res.unwrapErr());
    }
}

// ============ 类型转换工具 ============

/// 安全的整数类型转换
pub fn safeCast(comptime From: type, comptime To: type, value: From) Option(To) {
    const result = std.math.cast(To, value);
    if (result) |v| {
        return Option(To).Some(v);
    } else {
        return Option(To).None();
    }
}

/// 将可空指针转为 Option
pub fn fromNullable(comptime T: type, nullable: ?T) Option(T) {
    if (nullable) |v| {
        return Option(T).Some(v);
    } else {
        return Option(T).None();
    }
}

/// 将 Option 转为可空值
pub fn toNullable(comptime T: type, opt: Option(T)) ?T {
    if (opt.isSome()) {
        return opt.unwrap();
    } else {
        return null;
    }
}

// ============ 组合工具 ============

/// 组合两个自然变换
/// 如果 f: F ~> G 且 g: G ~> H，则 compose(g, f): F ~> H
pub fn composeNat(
    comptime F: fn (type) type,
    comptime G: fn (type) type,
    comptime H: fn (type) type,
    comptime T: type,
    f: fn (F(T)) G(T),
    g: fn (G(T)) H(T),
) fn (F(T)) H(T) {
    return struct {
        fn composed(fa: F(T)) H(T) {
            return g(f(fa));
        }
    }.composed;
}

// ============ 测试 ============

test "optionToResult" {
    const some = Option(i32).Some(42);
    const res1 = optionToResult(i32, []const u8, some, "error");
    try std.testing.expect(res1.isOk());
    try std.testing.expectEqual(@as(i32, 42), res1.unwrap());

    const none_ = Option(i32).None();
    const res2 = optionToResult(i32, []const u8, none_, "error");
    try std.testing.expect(res2.isErr());
    try std.testing.expectEqualStrings("error", res2.unwrapErr());
}

test "resultToOption" {
    const ok = Result(i32, []const u8).Ok(42);
    const opt1 = resultToOption(i32, []const u8, ok);
    try std.testing.expect(opt1.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt1.unwrap());

    const err_ = Result(i32, []const u8).Err("error");
    const opt2 = resultToOption(i32, []const u8, err_);
    try std.testing.expect(opt2.isNone());
}

test "resultErrToOption" {
    const ok = Result(i32, []const u8).Ok(42);
    const opt1 = resultErrToOption(i32, []const u8, ok);
    try std.testing.expect(opt1.isNone());

    const err_ = Result(i32, []const u8).Err("error");
    const opt2 = resultErrToOption(i32, []const u8, err_);
    try std.testing.expect(opt2.isSome());
    try std.testing.expectEqualStrings("error", opt2.unwrap());
}

test "sliceHeadOption" {
    const arr = [_]i32{ 1, 2, 3 };
    const head = sliceHeadOption(i32, &arr);
    try std.testing.expect(head.isSome());
    try std.testing.expectEqual(@as(i32, 1), head.unwrap());

    const empty: []const i32 = &.{};
    const noHead = sliceHeadOption(i32, empty);
    try std.testing.expect(noHead.isNone());
}

test "sliceLastOption" {
    const arr = [_]i32{ 1, 2, 3 };
    const last = sliceLastOption(i32, &arr);
    try std.testing.expect(last.isSome());
    try std.testing.expectEqual(@as(i32, 3), last.unwrap());

    const empty: []const i32 = &.{};
    const noLast = sliceLastOption(i32, empty);
    try std.testing.expect(noLast.isNone());
}

test "sliceAtOption" {
    const arr = [_]i32{ 10, 20, 30 };
    const at1 = sliceAtOption(i32, &arr, 1);
    try std.testing.expect(at1.isSome());
    try std.testing.expectEqual(@as(i32, 20), at1.unwrap());

    const at_oob = sliceAtOption(i32, &arr, 10);
    try std.testing.expect(at_oob.isNone());
}

test "flattenOption" {
    const nested_some = Option(Option(i32)).Some(Option(i32).Some(42));
    const flat1 = flattenOption(i32, nested_some);
    try std.testing.expect(flat1.isSome());
    try std.testing.expectEqual(@as(i32, 42), flat1.unwrap());

    const nested_none = Option(Option(i32)).Some(Option(i32).None());
    const flat2 = flattenOption(i32, nested_none);
    try std.testing.expect(flat2.isNone());

    const outer_none = Option(Option(i32)).None();
    const flat3 = flattenOption(i32, outer_none);
    try std.testing.expect(flat3.isNone());
}

test "flattenResult" {
    const nested_ok = Result(Result(i32, []const u8), []const u8).Ok(
        Result(i32, []const u8).Ok(42),
    );
    const flat1 = flattenResult(i32, []const u8, nested_ok);
    try std.testing.expect(flat1.isOk());
    try std.testing.expectEqual(@as(i32, 42), flat1.unwrap());

    const nested_err_inner = Result(Result(i32, []const u8), []const u8).Ok(
        Result(i32, []const u8).Err("inner error"),
    );
    const flat2 = flattenResult(i32, []const u8, nested_err_inner);
    try std.testing.expect(flat2.isErr());

    const nested_err_outer = Result(Result(i32, []const u8), []const u8).Err("outer error");
    const flat3 = flattenResult(i32, []const u8, nested_err_outer);
    try std.testing.expect(flat3.isErr());
}

test "safeCast" {
    const result1 = safeCast(i32, u8, 100);
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(u8, 100), result1.unwrap());

    const result2 = safeCast(i32, u8, 300);
    try std.testing.expect(result2.isNone());

    const result3 = safeCast(i32, u8, -1);
    try std.testing.expect(result3.isNone());
}

test "fromNullable and toNullable" {
    const some: ?i32 = 42;
    const opt1 = fromNullable(i32, some);
    try std.testing.expect(opt1.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt1.unwrap());

    const none_val: ?i32 = null;
    const opt2 = fromNullable(i32, none_val);
    try std.testing.expect(opt2.isNone());

    const back1 = toNullable(i32, opt1);
    try std.testing.expectEqual(@as(?i32, 42), back1);

    const back2 = toNullable(i32, opt2);
    try std.testing.expect(back2 == null);
}

test "optionToSlice" {
    var buffer: [1]i32 = undefined;

    const some = Option(i32).Some(42);
    const slice1 = optionToSlice(i32, some, &buffer);
    try std.testing.expectEqual(@as(usize, 1), slice1.len);
    try std.testing.expectEqual(@as(i32, 42), slice1[0]);

    const none_ = Option(i32).None();
    const slice2 = optionToSlice(i32, none_, &buffer);
    try std.testing.expectEqual(@as(usize, 0), slice2.len);
}
