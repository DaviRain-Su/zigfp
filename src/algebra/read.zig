//! Read 类型类
//!
//! 提供将字符串解析为值的类型类。
//! 类似于 Haskell 的 Read 或 Rust 的 FromStr trait。
//! 是 Show 类型类的逆操作。
//!
//! 示例:
//! ```zig
//! const read_i32 = readI32();
//! const result = read_i32.read("42");  // Option(i32).some(42)
//! const invalid = read_i32.read("abc"); // Option(i32).none
//! ```

const std = @import("std");
const core = @import("../core/mod.zig");
const Option = core.Option;

/// Read 类型类
///
/// 将字符串解析为类型 T 的值。
/// 解析失败返回 None。
pub fn Read(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 解析函数
        readFn: *const fn ([]const u8) Option(T),

        /// 尝试从字符串解析值
        pub fn read(self: Self, str: []const u8) Option(T) {
            return self.readFn(str);
        }

        /// 解析，失败时返回默认值
        pub fn readOr(self: Self, str: []const u8, default: T) T {
            return switch (self.readFn(str)) {
                .some => |v| v,
                .none => default,
            };
        }

        /// 解析，失败时调用函数获取默认值
        pub fn readOrElse(self: Self, str: []const u8, comptime default_fn: fn () T) T {
            return switch (self.readFn(str)) {
                .some => |v| v,
                .none => default_fn(),
            };
        }
    };
}

// ============ 整数类型实例 ============

/// i8 的 Read 实例
pub fn readI8() Read(i8) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(i8) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(i8, trimmed, 10) catch return Option(i8).None();
                return Option(i8).Some(value);
            }
        }.read,
    };
}

/// i16 的 Read 实例
pub fn readI16() Read(i16) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(i16) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(i16, trimmed, 10) catch return Option(i16).None();
                return Option(i16).Some(value);
            }
        }.read,
    };
}

/// i32 的 Read 实例
pub fn readI32() Read(i32) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(i32) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(i32, trimmed, 10) catch return Option(i32).None();
                return Option(i32).Some(value);
            }
        }.read,
    };
}

/// i64 的 Read 实例
pub fn readI64() Read(i64) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(i64) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(i64, trimmed, 10) catch return Option(i64).None();
                return Option(i64).Some(value);
            }
        }.read,
    };
}

/// u8 的 Read 实例
pub fn readU8() Read(u8) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u8) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(u8, trimmed, 10) catch return Option(u8).None();
                return Option(u8).Some(value);
            }
        }.read,
    };
}

/// u16 的 Read 实例
pub fn readU16() Read(u16) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u16) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(u16, trimmed, 10) catch return Option(u16).None();
                return Option(u16).Some(value);
            }
        }.read,
    };
}

/// u32 的 Read 实例
pub fn readU32() Read(u32) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u32) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(u32, trimmed, 10) catch return Option(u32).None();
                return Option(u32).Some(value);
            }
        }.read,
    };
}

/// u64 的 Read 实例
pub fn readU64() Read(u64) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u64) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(u64, trimmed, 10) catch return Option(u64).None();
                return Option(u64).Some(value);
            }
        }.read,
    };
}

/// usize 的 Read 实例
pub fn readUsize() Read(usize) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(usize) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseInt(usize, trimmed, 10) catch return Option(usize).None();
                return Option(usize).Some(value);
            }
        }.read,
    };
}

// ============ 浮点类型实例 ============

/// f32 的 Read 实例
pub fn readF32() Read(f32) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(f32) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseFloat(f32, trimmed) catch return Option(f32).None();
                return Option(f32).Some(value);
            }
        }.read,
    };
}

/// f64 的 Read 实例
pub fn readF64() Read(f64) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(f64) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                const value = std.fmt.parseFloat(f64, trimmed) catch return Option(f64).None();
                return Option(f64).Some(value);
            }
        }.read,
    };
}

// ============ 其他基本类型实例 ============

/// bool 的 Read 实例
pub fn readBool() Read(bool) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(bool) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                if (std.mem.eql(u8, trimmed, "true") or std.mem.eql(u8, trimmed, "True") or std.mem.eql(u8, trimmed, "TRUE") or std.mem.eql(u8, trimmed, "1")) {
                    return Option(bool).Some(true);
                }
                if (std.mem.eql(u8, trimmed, "false") or std.mem.eql(u8, trimmed, "False") or std.mem.eql(u8, trimmed, "FALSE") or std.mem.eql(u8, trimmed, "0")) {
                    return Option(bool).Some(false);
                }
                return Option(bool).None();
            }
        }.read,
    };
}

/// 字符串的 Read 实例（简单返回输入）
/// 注意：不会复制字符串，返回的是对输入的引用
pub fn readString() Read([]const u8) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option([]const u8) {
                return Option([]const u8).Some(str);
            }
        }.read,
    };
}

/// 带引号字符串的 Read 实例
/// 解析 "..." 格式的字符串
pub fn readStringQuoted() Read([]const u8) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option([]const u8) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");
                if (trimmed.len < 2) return Option([]const u8).None();
                if (trimmed[0] != '"' or trimmed[trimmed.len - 1] != '"') {
                    return Option([]const u8).None();
                }
                return Option([]const u8).Some(trimmed[1 .. trimmed.len - 1]);
            }
        }.read,
    };
}

// ============ 十六进制整数解析 ============

/// 十六进制 u32 的 Read 实例
pub fn readHexU32() Read(u32) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u32) {
                var trimmed = std.mem.trim(u8, str, " \t\n\r");
                // 移除可选的 0x 或 0X 前缀
                if (trimmed.len >= 2 and (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X"))) {
                    trimmed = trimmed[2..];
                }
                const value = std.fmt.parseInt(u32, trimmed, 16) catch return Option(u32).None();
                return Option(u32).Some(value);
            }
        }.read,
    };
}

/// 十六进制 u64 的 Read 实例
pub fn readHexU64() Read(u64) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(u64) {
                var trimmed = std.mem.trim(u8, str, " \t\n\r");
                // 移除可选的 0x 或 0X 前缀
                if (trimmed.len >= 2 and (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X"))) {
                    trimmed = trimmed[2..];
                }
                const value = std.fmt.parseInt(u64, trimmed, 16) catch return Option(u64).None();
                return Option(u64).Some(value);
            }
        }.read,
    };
}

// ============ Option 类型实例 ============

/// Option(T) 的 Read 实例
/// 解析 "Some(value)" 或 "None" 格式
pub fn readOption(comptime T: type, comptime innerRead: Read(T)) Read(Option(T)) {
    return .{
        .readFn = &struct {
            fn read(str: []const u8) Option(Option(T)) {
                const trimmed = std.mem.trim(u8, str, " \t\n\r");

                // 检查 None
                if (std.mem.eql(u8, trimmed, "None")) {
                    return Option(Option(T)).Some(Option(T).None());
                }

                // 检查 Some(...)
                if (std.mem.startsWith(u8, trimmed, "Some(") and trimmed.len > 5 and trimmed[trimmed.len - 1] == ')') {
                    const inner_str = trimmed[5 .. trimmed.len - 1];
                    return switch (innerRead.read(inner_str)) {
                        .some => |v| Option(Option(T)).Some(Option(T).Some(v)),
                        .none => Option(Option(T)).None(),
                    };
                }

                return Option(Option(T)).None();
            }
        }.read,
    };
}

// ============ 通用辅助函数 ============

/// 快速整数解析
pub fn parseInt(comptime T: type, str: []const u8) Option(T) {
    const trimmed = std.mem.trim(u8, str, " \t\n\r");
    const value = std.fmt.parseInt(T, trimmed, 10) catch return Option(T).None();
    return Option(T).Some(value);
}

/// 快速浮点解析
pub fn parseFloat(comptime T: type, str: []const u8) Option(T) {
    const trimmed = std.mem.trim(u8, str, " \t\n\r");
    const value = std.fmt.parseFloat(T, trimmed) catch return Option(T).None();
    return Option(T).Some(value);
}

/// 从字符串列表批量解析
pub fn readMany(
    comptime T: type,
    read_instance: Read(T),
    strings: []const []const u8,
    allocator: std.mem.Allocator,
) ![]T {
    var results = try std.ArrayList(T).initCapacity(allocator, strings.len);
    errdefer results.deinit(allocator);

    for (strings) |str| {
        switch (read_instance.read(str)) {
            .some => |v| try results.append(allocator, v),
            .none => {}, // 跳过解析失败的
        }
    }

    return results.toOwnedSlice(allocator);
}

/// 从字符串列表批量解析（严格模式，任何失败都返回 None）
pub fn readManyStrict(
    comptime T: type,
    read_instance: Read(T),
    strings: []const []const u8,
    allocator: std.mem.Allocator,
) Option([]T) {
    var results = std.ArrayList(T).initCapacity(allocator, strings.len) catch return Option([]T).None();
    errdefer results.deinit(allocator);

    for (strings) |str| {
        switch (read_instance.read(str)) {
            .some => |v| results.append(allocator, v) catch return Option([]T).None(),
            .none => {
                results.deinit(allocator);
                return Option([]T).None();
            },
        }
    }

    const owned = results.toOwnedSlice(allocator) catch return Option([]T).None();
    return Option([]T).Some(owned);
}

// ============ 测试 ============

test "Read i32" {
    const read = readI32();

    // 正常情况
    var result = read.read("42");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    result = read.read("-123");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, -123), result.unwrap());

    result = read.read("0");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 0), result.unwrap());

    // 带空白
    result = read.read("  42  ");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    result = read.read("\t-1\n");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, -1), result.unwrap());

    // 无效输入
    try std.testing.expect(read.read("abc").isNone());
    try std.testing.expect(read.read("").isNone());
    try std.testing.expect(read.read("12.34").isNone());
}

test "Read i64" {
    const read = readI64();

    var result = read.read("9223372036854775807");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i64, 9223372036854775807), result.unwrap());

    result = read.read("-9223372036854775808");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i64, -9223372036854775808), result.unwrap());
}

test "Read u32" {
    const read = readU32();

    var result = read.read("4294967295");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 4294967295), result.unwrap());

    result = read.read("0");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 0), result.unwrap());

    try std.testing.expect(read.read("-1").isNone()); // u32 不能为负
}

test "Read f64" {
    const read = readF64();

    const result = read.read("3.14159");
    try std.testing.expect(result.isSome());
    const value = result.unwrap();
    try std.testing.expect(@abs(value - 3.14159) < 0.00001);

    try std.testing.expect(read.read("-2.5").isSome());
    try std.testing.expect(read.read("abc").isNone());
}

test "Read bool" {
    const read = readBool();

    // true variants
    var result = read.read("true");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(true, result.unwrap());

    result = read.read("True");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(true, result.unwrap());

    result = read.read("TRUE");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(true, result.unwrap());

    result = read.read("1");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(true, result.unwrap());

    // false variants
    result = read.read("false");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(false, result.unwrap());

    result = read.read("False");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(false, result.unwrap());

    result = read.read("FALSE");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(false, result.unwrap());

    result = read.read("0");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(false, result.unwrap());

    try std.testing.expect(read.read("yes").isNone());
    try std.testing.expect(read.read("no").isNone());
}

test "Read string" {
    const read = readString();

    const result = read.read("hello");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("hello", result.unwrap());
}

test "Read string quoted" {
    const read = readStringQuoted();

    const result = read.read("\"hello\"");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("hello", result.unwrap());

    try std.testing.expect(read.read("hello").isNone()); // 没有引号
    try std.testing.expect(read.read("\"").isNone()); // 不完整
}

test "Read hex" {
    const read = readHexU32();

    var result = read.read("FF");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 255), result.unwrap());

    result = read.read("0xFF");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 255), result.unwrap());

    result = read.read("0XFF");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 255), result.unwrap());

    result = read.read("DEADBEEF");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), result.unwrap());
}

test "Read Option" {
    const read = comptime readOption(i32, readI32());

    const some_result = read.read("Some(42)");
    try std.testing.expect(some_result.isSome());
    const inner_opt = some_result.unwrap();
    try std.testing.expect(inner_opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), inner_opt.unwrap());

    const none_result = read.read("None");
    try std.testing.expect(none_result.isSome());
    const none_inner = none_result.unwrap();
    try std.testing.expect(none_inner.isNone());

    try std.testing.expect(read.read("invalid").isNone());
}

test "readOr default value" {
    const read = readI32();

    try std.testing.expectEqual(@as(i32, 42), read.readOr("42", 0));
    try std.testing.expectEqual(@as(i32, 0), read.readOr("invalid", 0));
}

test "parseInt helper" {
    var result = parseInt(i32, "42");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    result = parseInt(i32, "abc");
    try std.testing.expect(result.isNone());

    const result_u64 = parseInt(u64, "9999999999");
    try std.testing.expect(result_u64.isSome());
    try std.testing.expectEqual(@as(u64, 9999999999), result_u64.unwrap());
}

test "parseFloat helper" {
    const result = parseFloat(f64, "3.14");
    try std.testing.expect(result.isSome());
}

test "readMany" {
    const allocator = std.testing.allocator;
    const read = readI32();

    const strings = [_][]const u8{ "1", "2", "invalid", "3" };
    const results = try readMany(i32, read, &strings, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 3), results.len);
    try std.testing.expectEqual(@as(i32, 1), results[0]);
    try std.testing.expectEqual(@as(i32, 2), results[1]);
    try std.testing.expectEqual(@as(i32, 3), results[2]);
}

test "readManyStrict" {
    const allocator = std.testing.allocator;
    const read = readI32();

    // 全部有效
    const valid_strings = [_][]const u8{ "1", "2", "3" };
    const valid_result = readManyStrict(i32, read, &valid_strings, allocator);
    try std.testing.expect(valid_result.isSome());
    const valid_values = valid_result.unwrap();
    defer allocator.free(valid_values);
    try std.testing.expectEqual(@as(usize, 3), valid_values.len);

    // 包含无效
    const invalid_strings = [_][]const u8{ "1", "invalid", "3" };
    const invalid_result = readManyStrict(i32, read, &invalid_strings, allocator);
    try std.testing.expect(invalid_result.isNone());
}
