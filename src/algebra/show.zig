//! Show 类型类
//!
//! 提供将值转换为可读字符串表示的类型类。
//! 类似于 Haskell 的 Show 或 Rust 的 Display trait。
//!
//! 示例:
//! ```zig
//! const show_i32 = showI32();
//! var buf: [32]u8 = undefined;
//! const str = show_i32.showBuf(42, &buf);  // "42"
//! ```

const std = @import("std");
const core = @import("../core/mod.zig");
const Option = core.Option;
const Result = core.Result;

/// Show 类型类
///
/// 将类型 T 的值转换为字符串表示。
/// 由于 Zig 没有垃圾回收，使用缓冲区方式避免分配。
pub fn Show(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 将值格式化到缓冲区
        showBufFn: *const fn (T, []u8) []const u8,

        /// 将值格式化到缓冲区
        pub fn showBuf(self: Self, value: T, buf: []u8) []const u8 {
            return self.showBufFn(value, buf);
        }

        /// 使用分配器将值转换为拥有的字符串
        pub fn showAlloc(self: Self, allocator: std.mem.Allocator, value: T) ![]u8 {
            var buf: [1024]u8 = undefined;
            const str = self.showBufFn(value, &buf);
            return allocator.dupe(u8, str);
        }
    };
}

// ============ 整数类型实例 ============

/// i32 的 Show 实例
pub fn showI32() Show(i32) {
    return .{
        .showBufFn = &struct {
            fn show(value: i32, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// i64 的 Show 实例
pub fn showI64() Show(i64) {
    return .{
        .showBufFn = &struct {
            fn show(value: i64, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// u8 的 Show 实例
pub fn showU8() Show(u8) {
    return .{
        .showBufFn = &struct {
            fn show(value: u8, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// u32 的 Show 实例
pub fn showU32() Show(u32) {
    return .{
        .showBufFn = &struct {
            fn show(value: u32, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// u64 的 Show 实例
pub fn showU64() Show(u64) {
    return .{
        .showBufFn = &struct {
            fn show(value: u64, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// usize 的 Show 实例
pub fn showUsize() Show(usize) {
    return .{
        .showBufFn = &struct {
            fn show(value: usize, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

// ============ 浮点类型实例 ============

/// f32 的 Show 实例
pub fn showF32() Show(f32) {
    return .{
        .showBufFn = &struct {
            fn show(value: f32, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

/// f64 的 Show 实例
pub fn showF64() Show(f64) {
    return .{
        .showBufFn = &struct {
            fn show(value: f64, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
            }
        }.show,
    };
}

// ============ 其他基本类型实例 ============

/// bool 的 Show 实例
pub fn showBool() Show(bool) {
    return .{
        .showBufFn = &struct {
            fn show(value: bool, buf: []u8) []const u8 {
                const str = if (value) "true" else "false";
                const len = @min(str.len, buf.len);
                @memcpy(buf[0..len], str[0..len]);
                return buf[0..len];
            }
        }.show,
    };
}

/// 字符串的 Show 实例（返回原字符串）
pub fn showString() Show([]const u8) {
    return .{
        .showBufFn = &struct {
            fn show(value: []const u8, buf: []u8) []const u8 {
                const len = @min(value.len, buf.len);
                @memcpy(buf[0..len], value[0..len]);
                return buf[0..len];
            }
        }.show,
    };
}

/// 字符串的 Show 实例（带引号）
pub fn showStringQuoted() Show([]const u8) {
    return .{
        .showBufFn = &struct {
            fn show(value: []const u8, buf: []u8) []const u8 {
                return std.fmt.bufPrint(buf, "\"{s}\"", .{value}) catch "?";
            }
        }.show,
    };
}

// ============ Option 类型实例 ============

/// Option(T) 的 Show 实例
pub fn showOption(comptime T: type, comptime innerShow: Show(T)) Show(Option(T)) {
    return .{
        .showBufFn = &struct {
            fn show(value: Option(T), buf: []u8) []const u8 {
                return switch (value) {
                    .some => |v| blk: {
                        var inner_buf: [512]u8 = undefined;
                        const inner_str = innerShow.showBuf(v, &inner_buf);
                        break :blk std.fmt.bufPrint(buf, "Some({s})", .{inner_str}) catch "?";
                    },
                    .none => blk: {
                        const str = "None";
                        const len = @min(str.len, buf.len);
                        @memcpy(buf[0..len], str[0..len]);
                        break :blk buf[0..len];
                    },
                };
            }
        }.show,
    };
}

// ============ Result 类型实例 ============

/// Result(T, E) 的 Show 实例
pub fn showResult(
    comptime T: type,
    comptime E: type,
    comptime okShow: Show(T),
    comptime errShow: Show(E),
) Show(Result(T, E)) {
    return .{
        .showBufFn = &struct {
            fn show(value: Result(T, E), buf: []u8) []const u8 {
                return switch (value) {
                    .ok => |v| blk: {
                        var inner_buf: [512]u8 = undefined;
                        const inner_str = okShow.showBuf(v, &inner_buf);
                        break :blk std.fmt.bufPrint(buf, "Ok({s})", .{inner_str}) catch "?";
                    },
                    .err => |e| blk: {
                        var inner_buf: [512]u8 = undefined;
                        const inner_str = errShow.showBuf(e, &inner_buf);
                        break :blk std.fmt.bufPrint(buf, "Err({s})", .{inner_str}) catch "?";
                    },
                };
            }
        }.show,
    };
}

// ============ 切片类型实例 ============

/// 切片的 Show 实例
pub fn showSlice(comptime T: type, comptime innerShow: Show(T)) Show([]const T) {
    return .{
        .showBufFn = &struct {
            fn show(value: []const T, buf: []u8) []const u8 {
                var pos: usize = 0;

                // 开始括号
                if (pos < buf.len) {
                    buf[pos] = '[';
                    pos += 1;
                }

                // 元素
                for (value, 0..) |item, i| {
                    if (i > 0) {
                        if (pos + 2 <= buf.len) {
                            buf[pos] = ',';
                            buf[pos + 1] = ' ';
                            pos += 2;
                        }
                    }

                    var inner_buf: [128]u8 = undefined;
                    const inner_str = innerShow.showBuf(item, &inner_buf);

                    const copy_len = @min(inner_str.len, buf.len - pos);
                    if (copy_len > 0) {
                        @memcpy(buf[pos .. pos + copy_len], inner_str[0..copy_len]);
                        pos += copy_len;
                    }
                }

                // 结束括号
                if (pos < buf.len) {
                    buf[pos] = ']';
                    pos += 1;
                }

                return buf[0..pos];
            }
        }.show,
    };
}

// ============ 通用辅助函数 ============

/// 使用 Show 实例将值写入 Writer
pub fn showToWriter(
    comptime T: type,
    show_instance: Show(T),
    value: T,
    writer: anytype,
) !void {
    var buf: [1024]u8 = undefined;
    const str = show_instance.showBuf(value, &buf);
    try writer.writeAll(str);
}

/// 快速整数显示（使用默认实例）
pub fn showInt(comptime T: type, value: T, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
}

/// 快速浮点显示（使用默认实例）
pub fn showFloat(comptime T: type, value: T, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
}

// ============ 测试 ============

test "Show i32" {
    const show = showI32();
    var buf: [32]u8 = undefined;

    try std.testing.expectEqualStrings("42", show.showBuf(42, &buf));
    try std.testing.expectEqualStrings("-123", show.showBuf(-123, &buf));
    try std.testing.expectEqualStrings("0", show.showBuf(0, &buf));
}

test "Show i64" {
    const show = showI64();
    var buf: [32]u8 = undefined;

    try std.testing.expectEqualStrings("9223372036854775807", show.showBuf(9223372036854775807, &buf));
    try std.testing.expectEqualStrings("-9223372036854775808", show.showBuf(-9223372036854775808, &buf));
}

test "Show u32" {
    const show = showU32();
    var buf: [32]u8 = undefined;

    try std.testing.expectEqualStrings("4294967295", show.showBuf(4294967295, &buf));
    try std.testing.expectEqualStrings("0", show.showBuf(0, &buf));
}

test "Show f64" {
    const show = showF64();
    var buf: [64]u8 = undefined;

    const result = show.showBuf(3.14159, &buf);
    // 浮点数格式化可能有精度差异，检查前几位
    try std.testing.expect(std.mem.startsWith(u8, result, "3.14"));
}

test "Show bool" {
    const show = showBool();
    var buf: [8]u8 = undefined;

    try std.testing.expectEqualStrings("true", show.showBuf(true, &buf));
    try std.testing.expectEqualStrings("false", show.showBuf(false, &buf));
}

test "Show string" {
    const show = showString();
    var buf: [64]u8 = undefined;

    try std.testing.expectEqualStrings("hello", show.showBuf("hello", &buf));
    try std.testing.expectEqualStrings("", show.showBuf("", &buf));
}

test "Show string quoted" {
    const show = showStringQuoted();
    var buf: [64]u8 = undefined;

    try std.testing.expectEqualStrings("\"hello\"", show.showBuf("hello", &buf));
}

test "Show Option" {
    const show = comptime showOption(i32, showI32());
    var buf: [64]u8 = undefined;

    try std.testing.expectEqualStrings("Some(42)", show.showBuf(Option(i32).Some(42), &buf));
    try std.testing.expectEqualStrings("None", show.showBuf(Option(i32).None(), &buf));
}

test "Show Result" {
    const show = comptime showResult(i32, []const u8, showI32(), showString());
    var buf: [64]u8 = undefined;

    try std.testing.expectEqualStrings("Ok(42)", show.showBuf(Result(i32, []const u8).Ok(42), &buf));
    try std.testing.expectEqualStrings("Err(failed)", show.showBuf(Result(i32, []const u8).Err("failed"), &buf));
}

test "Show slice" {
    const show = comptime showSlice(i32, showI32());
    var buf: [128]u8 = undefined;

    const arr = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("[1, 2, 3]", show.showBuf(&arr, &buf));

    const empty: []const i32 = &.{};
    try std.testing.expectEqualStrings("[]", show.showBuf(empty, &buf));
}

test "Show with allocator" {
    const allocator = std.testing.allocator;
    const show = showI32();

    const str = try show.showAlloc(allocator, 42);
    defer allocator.free(str);

    try std.testing.expectEqualStrings("42", str);
}

test "showToWriter" {
    const show = showI32();
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try showToWriter(i32, show, 12345, fbs.writer());
    try std.testing.expectEqualStrings("12345", fbs.getWritten());
}

test "showInt helper" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("42", showInt(i32, 42, &buf));
    try std.testing.expectEqualStrings("255", showInt(u8, 255, &buf));
}
