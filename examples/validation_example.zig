//! zigFP 验证框架示例
//!
//! 本示例展示如何使用函数式模式进行数据验证

const std = @import("std");
const fp = @import("zigfp");

pub fn main() void {
    std.debug.print("=== zigFP 验证模式示例 ===\n\n", .{});

    // ============ 使用 Option 进行验证 ============
    std.debug.print("--- Option 验证模式 ---\n", .{});

    // 验证非空
    const username = "alice";
    const validated_username = if (username.len > 0)
        fp.some([]const u8, username)
    else
        fp.none([]const u8);

    std.debug.print("Username '{s}' is valid: {}\n", .{ username, validated_username.isSome() });

    // 验证空字符串
    const empty_str = "";
    const validated_empty = if (empty_str.len > 0)
        fp.some([]const u8, empty_str)
    else
        fp.none([]const u8);

    std.debug.print("Empty string is valid: {}\n", .{validated_empty.isSome()});

    // ============ 使用 Result 进行验证 ============
    std.debug.print("\n--- Result 验证模式 ---\n", .{});

    const ValidationError = enum { Empty, TooShort, TooLong, InvalidFormat };

    // 验证函数
    const validateUsername = struct {
        fn validate(name: []const u8) fp.Result([]const u8, ValidationError) {
            if (name.len == 0) {
                return fp.err([]const u8, ValidationError, .Empty);
            }
            if (name.len < 3) {
                return fp.err([]const u8, ValidationError, .TooShort);
            }
            if (name.len > 20) {
                return fp.err([]const u8, ValidationError, .TooLong);
            }
            return fp.ok([]const u8, ValidationError, name);
        }
    }.validate;

    // 测试不同输入
    const inputs = [_][]const u8{ "ab", "alice", "a_very_long_username_that_exceeds_limit" };
    for (inputs) |input| {
        const result = validateUsername(input);
        if (result.isOk()) {
            std.debug.print("'{s}': VALID\n", .{input});
        } else {
            std.debug.print("'{s}': INVALID ({s})\n", .{ input, @tagName(result.unwrapErr()) });
        }
    }

    // ============ 组合验证 ============
    std.debug.print("\n--- 组合验证模式 ---\n", .{});

    // 验证用户注册
    const User = struct {
        username: []const u8,
        email: []const u8,
        age: i32,
    };

    const user = User{
        .username = "alice",
        .email = "alice@example.com",
        .age = 25,
    };

    // 分别验证每个字段
    const username_valid = user.username.len >= 3 and user.username.len <= 20;
    const email_valid = blk: {
        for (user.email) |c| {
            if (c == '@') break :blk true;
        }
        break :blk false;
    };
    const age_valid = user.age >= 18 and user.age <= 120;

    std.debug.print("User validation:\n", .{});
    std.debug.print("  - Username: {s}\n", .{if (username_valid) "valid" else "invalid"});
    std.debug.print("  - Email: {s}\n", .{if (email_valid) "valid" else "invalid"});
    std.debug.print("  - Age: {s}\n", .{if (age_valid) "valid" else "invalid"});
    std.debug.print("  - Overall: {s}\n", .{if (username_valid and email_valid and age_valid) "VALID" else "INVALID"});

    // ============ 使用 flatMap 链式验证 ============
    std.debug.print("\n--- 链式验证模式 ---\n", .{});

    // 解析并验证数字
    const parsePositive = struct {
        fn parse(input: []const u8) fp.Option(i32) {
            if (input.len == 0) return fp.none(i32);

            var result: i32 = 0;
            for (input) |c| {
                if (c < '0' or c > '9') return fp.none(i32);
                result = result * 10 + @as(i32, c - '0');
            }

            return if (result > 0) fp.some(i32, result) else fp.none(i32);
        }
    }.parse;

    const test_inputs = [_][]const u8{ "42", "0", "abc", "123" };
    for (test_inputs) |input| {
        const parsed = parsePositive(input);
        if (parsed.isSome()) {
            std.debug.print("'{s}' -> {}\n", .{ input, parsed.unwrap() });
        } else {
            std.debug.print("'{s}' -> invalid\n", .{input});
        }
    }

    std.debug.print("\n=== 验证示例完成 ===\n", .{});
}

test "Option validation" {
    const validateNonEmpty = struct {
        fn validate(s: []const u8) fp.Option([]const u8) {
            return if (s.len > 0) fp.some([]const u8, s) else fp.none([]const u8);
        }
    }.validate;

    try std.testing.expect(validateNonEmpty("hello").isSome());
    try std.testing.expect(validateNonEmpty("").isNone());
}

test "Result validation" {
    const Error = enum { Empty };

    const validate = struct {
        fn v(s: []const u8) fp.Result([]const u8, Error) {
            return if (s.len > 0)
                fp.ok([]const u8, Error, s)
            else
                fp.err([]const u8, Error, .Empty);
        }
    }.v;

    try std.testing.expect(validate("hello").isOk());
    try std.testing.expect(validate("").isErr());
}

test "Chain validation with flatMap" {
    const Error = enum { InvalidFormat };

    // Parse and validate in one step
    const result = fp.ok([]const u8, Error, "42")
        .flatMap(i32, struct {
        fn parse(s: []const u8) fp.Result(i32, Error) {
            var num: i32 = 0;
            for (s) |c| {
                if (c < '0' or c > '9') {
                    return fp.err(i32, Error, .InvalidFormat);
                }
                num = num * 10 + @as(i32, c - '0');
            }
            return fp.ok(i32, Error, num);
        }
    }.parse);

    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}
