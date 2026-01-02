//! zigFP Monad 用法示例
//!
//! 本示例展示 Reader, Writer, State Monad 的使用方法

const std = @import("std");
const fp = @import("zigfp");

// ============ Reader Monad 示例 ============

/// 应用配置
const AppConfig = struct {
    app_name: []const u8,
    version: []const u8,
    debug_mode: bool,
};

/// 获取应用名称
fn getAppName() fp.Reader(AppConfig, []const u8) {
    return fp.asks(AppConfig, []const u8, struct {
        fn f(cfg: AppConfig) []const u8 {
            return cfg.app_name;
        }
    }.f);
}

/// 获取是否调试模式
fn isDebugMode() fp.Reader(AppConfig, bool) {
    return fp.asks(AppConfig, bool, struct {
        fn f(cfg: AppConfig) bool {
            return cfg.debug_mode;
        }
    }.f);
}

// ============ Writer Monad 示例 ============

/// 带日志的加法
fn addWithLog(a: i32, b: i32) fp.Writer([]const u8, i32) {
    return fp.Writer([]const u8, i32).init(a + b, "Adding two numbers; ");
}

/// 带日志的乘法
fn multiplyWithLog(a: i32, b: i32) fp.Writer([]const u8, i32) {
    return fp.Writer([]const u8, i32).init(a * b, "Multiplying two numbers; ");
}

// ============ State Monad 示例 ============

/// 计数器状态
const Counter = struct {
    count: i32,
    history: []const u8,
};

pub fn main() void {
    std.debug.print("=== zigFP Monad 用法示例 ===\n\n", .{});

    // ============ Reader Monad ============
    std.debug.print("--- Reader Monad ---\n", .{});

    const config = AppConfig{
        .app_name = "MyApp",
        .version = "1.0.0",
        .debug_mode = true,
    };

    const app_name = getAppName().run(config);
    const debug = isDebugMode().run(config);

    std.debug.print("App Name: {s}\n", .{app_name});
    std.debug.print("Debug Mode: {}\n", .{debug});

    // 使用 ask 获取整个配置
    const full_config = fp.ask(AppConfig).run(config);
    std.debug.print("Version: {s}\n", .{full_config.version});

    // ============ Writer Monad ============
    std.debug.print("\n--- Writer Monad ---\n", .{});

    const sum_result = addWithLog(10, 20);
    std.debug.print("Sum: {}, Log: {s}\n", .{ sum_result.value, sum_result.log });

    const product_result = multiplyWithLog(5, 6);
    std.debug.print("Product: {}, Log: {s}\n", .{ product_result.value, product_result.log });

    // 使用 tell 添加日志 (tell 返回 Writer(W, void))
    const logged = fp.tell([]const u8, "Important event; ");
    std.debug.print("Logged: {s}\n", .{logged.log});

    // ============ State Monad ============
    std.debug.print("\n--- State Monad ---\n", .{});

    // 简单的状态示例 - 使用 modify 修改状态
    const increment = fp.modify(i32, struct {
        fn f(s: i32) i32 {
            return s + 1;
        }
    }.f);

    // run 返回 tuple: { value, new_state }
    const state_result = increment.run(0);
    std.debug.print("Initial state: 0, After increment - state: {}\n", .{state_result[1]});

    // 获取当前状态
    const get_state = fp.get(i32);
    const get_result = get_state.run(100);
    std.debug.print("Get state: {} (state unchanged: {})\n", .{ get_result[0], get_result[1] });

    std.debug.print("\n=== Monad 示例完成 ===\n", .{});
}

test "Reader Monad" {
    const config = AppConfig{
        .app_name = "TestApp",
        .version = "0.1.0",
        .debug_mode = false,
    };

    const name = getAppName().run(config);
    try std.testing.expectEqualStrings("TestApp", name);

    const debug = isDebugMode().run(config);
    try std.testing.expect(!debug);
}

test "Writer Monad" {
    const result = addWithLog(5, 3);
    try std.testing.expectEqual(@as(i32, 8), result.value);
    try std.testing.expectEqualStrings("Adding two numbers; ", result.log);
}

test "State Monad" {
    const increment = fp.modify(i32, struct {
        fn f(s: i32) i32 {
            return s + 1;
        }
    }.f);

    const result = increment.run(10);
    try std.testing.expectEqual(@as(i32, 11), result[1]); // new state
}
