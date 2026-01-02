//! zigFP 基础用法示例
//!
//! 本示例展示 zigFP 库的基本使用方法

const std = @import("std");
const fp = @import("zigfp");

pub fn main() void {
    std.debug.print("=== zigFP 基础用法示例 ===\n\n", .{});

    // ============ Option 示例 ============
    std.debug.print("--- Option 示例 ---\n", .{});

    const some_value = fp.some(i32, 42);
    const no_value = fp.none(i32);

    std.debug.print("some_value.isSome(): {}\n", .{some_value.isSome()});
    std.debug.print("some_value.unwrap(): {}\n", .{some_value.unwrap()});
    std.debug.print("no_value.isNone(): {}\n", .{no_value.isNone()});
    std.debug.print("no_value.unwrapOr(0): {}\n", .{no_value.unwrapOr(0)});

    // Option map
    const doubled = some_value.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    std.debug.print("some_value.map(double): {}\n", .{doubled.unwrap()});

    // ============ Result 示例 ============
    std.debug.print("\n--- Result 示例 ---\n", .{});

    const Error = enum { NotFound, InvalidInput };

    const success = fp.ok(i32, Error, 100);
    const failure = fp.err(i32, Error, .NotFound);

    std.debug.print("success.isOk(): {}\n", .{success.isOk()});
    std.debug.print("success.unwrap(): {}\n", .{success.unwrap()});
    std.debug.print("failure.isErr(): {}\n", .{failure.isErr()});

    // Result map
    const mapped = success.map(i32, struct {
        fn f(x: i32) i32 {
            return x + 50;
        }
    }.f);
    std.debug.print("success.map(+50): {}\n", .{mapped.unwrap()});

    // ============ Pipe 示例 ============
    std.debug.print("\n--- Pipe 示例 ---\n", .{});

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

    const pipe_result = fp.Pipe(i32).init(5)
        .then(i32, addOne) // 6
        .then(i32, double) // 12
        .then(i32, addOne) // 13
        .unwrap();

    std.debug.print("Pipe(5).then(+1).then(*2).then(+1): {}\n", .{pipe_result});

    // ============ compose 示例 ============
    std.debug.print("\n--- compose 示例 ---\n", .{});

    const composed = fp.compose(i32, i32, i32, double, addOne);
    // compose(f, g)(x) = f(g(x)) = double(addOne(5)) = double(6) = 12
    std.debug.print("compose(double, addOne)(5): {}\n", .{composed(5)});

    // ============ Monoid 示例 ============
    std.debug.print("\n--- Monoid 示例 ---\n", .{});

    const numbers = [_]i64{ 1, 2, 3, 4, 5 };
    const sum = fp.sumMonoid.concat(&numbers);
    const product = fp.productMonoid.concat(&numbers);

    std.debug.print("sum([1,2,3,4,5]): {}\n", .{sum});
    std.debug.print("product([1,2,3,4,5]): {}\n", .{product});

    // ============ Lazy 示例 ============
    std.debug.print("\n--- Lazy 示例 ---\n", .{});

    var lazy_value = fp.Lazy(i32).init(struct {
        fn f() i32 {
            return 42;
        }
    }.f);

    std.debug.print("lazy_value (before eval): not evaluated\n", .{});
    const evaluated = lazy_value.force();
    std.debug.print("lazy_value.force(): {}\n", .{evaluated});

    std.debug.print("\n=== 示例完成 ===\n", .{});
}

test "basic usage examples" {
    // Option
    const opt = fp.some(i32, 42);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    // Result
    const Error = enum { TestError };
    const res = fp.ok(i32, Error, 100);
    try std.testing.expect(res.isOk());
    try std.testing.expectEqual(@as(i32, 100), res.unwrap());

    // Pipe
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = fp.Pipe(i32).init(5).then(i32, double).unwrap();
    try std.testing.expectEqual(@as(i32, 10), result);
}
