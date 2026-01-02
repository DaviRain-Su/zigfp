//! Prelude 使用示例
//!
//! 这个文件演示了如何使用 zigFP 的 Prelude 模块

const std = @import("std");
const prelude = @import("../src/prelude.zig");

pub fn main() !void {
    std.debug.print("zigFP Prelude 使用示例\n", .{});

    // ============ 类型别名 ============
    std.debug.print("\n1. 类型别名:\n", .{});

    const maybe_num: prelude.Maybe(i32) = prelude.some(i32, 42);
    const maybe_none: prelude.Maybe(i32) = prelude.none(i32);

    std.debug.print("  Maybe: {}\n", .{maybe_num.isSome()});
    std.debug.print("  Maybe: {}\n", .{maybe_none.isNone()});

    const result_ok: prelude.Either(i32, []const u8) = prelude.ok(i32, []const u8, 42);
    const result_err: prelude.Either(i32, []const u8) = prelude.err(i32, []const u8, "error");

    std.debug.print("  Either OK: {}\n", .{result_ok.isOk()});
    std.debug.print("  Either Err: {}\n", .{result_err.isErr()});

    // ============ 核心函数 ============
    std.debug.print("\n2. 核心函数:\n", .{});

    // id 函数
    const id_fn = prelude.id(i32);
    std.debug.print("  id(42) = {}\n", .{id_fn(42)});

    // constant 函数
    const const_fn = prelude.constant(i32, []const u8, "hello");
    std.debug.print("  constant(42) = {s}\n", .{const_fn(42)});

    // compose2 函数
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const add_one = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const composed = prelude.compose2(i32, double, add_one);
    std.debug.print("  (double . add_one)(5) = {}\n", .{composed(5)}); // (5 + 1) * 2 = 12

    // ============ 条件函数 ============
    std.debug.print("\n3. 条件函数:\n", .{});

    const positive = prelude.when(i32, 5 > 0, 5, -5);
    const negative = prelude.when(i32, -3 > 0, -3, 0);

    std.debug.print("  when(5 > 0, 5, -5) = {}\n", .{positive});
    std.debug.print("  when(-3 > 0, -3, 0) = {}\n", .{negative});

    // ============ 布尔转换 ============
    std.debug.print("\n4. 布尔转换:\n", .{});

    const bool_true = prelude.boolToOption(i32, true, 100);
    const bool_false = prelude.boolToOption(i32, false, 200);

    std.debug.print("  boolToOption(true, 100) = {}\n", .{bool_true.isSome()});
    std.debug.print("  boolToOption(false, 200) = {}\n", .{bool_false.isNone()});

    // ============ 运算符常量 ============
    std.debug.print("\n5. 运算符常量:\n", .{});

    std.debug.print("  Functor map: {s}\n", .{prelude.fmap});
    std.debug.print("  Applicative apply: {s}\n", .{prelude.ap});
    std.debug.print("  Monad bind: {s}\n", .{prelude.bind});
    std.debug.print("  Semigroup combine: {s}\n", .{prelude.combine_op});

    // ============ 模块聚合 ============
    std.debug.print("\n6. 模块聚合:\n", .{});

    // 直接使用聚合的模块
    const opt = prelude.option.Some(i32, 42);
    std.debug.print("  option.Some(42) = {}\n", .{opt.isSome()});

    const res = prelude.result.Ok(i32, []const u8, 42);
    std.debug.print("  result.Ok(42) = {}\n", .{res.isOk()});

    std.debug.print("\nPrelude 示例完成!\n", .{});
}
