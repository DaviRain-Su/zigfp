const std = @import("std");
const Allocator = std.mem.Allocator;

/// 函数式超时控制模块
///
/// 提供操作超时保护：
/// - 超时配置
/// - 超时执行包装
/// - 统计信息
///
/// 示例:
/// ```zig
/// const result = try withTimeout(1000, fetchData, .{url});
/// ```
///
/// 注意：由于 Zig 同步执行特性，真正的超时需要线程支持。
/// 此模块提供超时抽象和时间跟踪功能。
/// 超时错误
pub const TimeoutError = error{
    /// 操作超时
    OperationTimeout,
    /// 操作被取消
    OperationCancelled,
};

/// 超时配置
pub const TimeoutConfig = struct {
    /// 超时时间（毫秒）
    timeout_ms: u64 = 30000,
    /// 操作名称
    name: []const u8 = "default",
    /// 是否记录超时
    log_timeout: bool = false,
};

/// 超时统计
pub const TimeoutStats = struct {
    /// 总操作数
    total_operations: u64,
    /// 成功操作数
    successful_operations: u64,
    /// 超时操作数
    timed_out_operations: u64,
    /// 失败操作数
    failed_operations: u64,
    /// 总执行时间（纳秒）
    total_execution_time_ns: u64,
    /// 最大执行时间（纳秒）
    max_execution_time_ns: u64,

    pub fn init() TimeoutStats {
        return .{
            .total_operations = 0,
            .successful_operations = 0,
            .timed_out_operations = 0,
            .failed_operations = 0,
            .total_execution_time_ns = 0,
            .max_execution_time_ns = 0,
        };
    }

    /// 获取平均执行时间（纳秒）
    pub fn getAverageExecutionTimeNs(self: *const TimeoutStats) u64 {
        if (self.total_operations == 0) return 0;
        return self.total_execution_time_ns / self.total_operations;
    }

    /// 获取平均执行时间（毫秒）
    pub fn getAverageExecutionTimeMs(self: *const TimeoutStats) u64 {
        return self.getAverageExecutionTimeNs() / std.time.ns_per_ms;
    }

    /// 获取超时率（0.0 - 1.0）
    pub fn getTimeoutRate(self: *const TimeoutStats) f64 {
        if (self.total_operations == 0) return 0.0;
        return @as(f64, @floatFromInt(self.timed_out_operations)) / @as(f64, @floatFromInt(self.total_operations));
    }
};

/// 超时结果
pub const TimeoutResult = union(enum) {
    /// 操作成功完成
    success: u64, // 执行时间（纳秒）
    /// 操作超时
    timeout: u64, // 已执行时间（纳秒）
    /// 操作失败
    failure: u64, // 执行时间（纳秒）
};

/// 超时器
pub const Timeout = struct {
    config: TimeoutConfig,
    stats: TimeoutStats,

    const Self = @This();

    /// 初始化超时器
    pub fn init(config: TimeoutConfig) Self {
        return .{
            .config = config,
            .stats = TimeoutStats.init(),
        };
    }

    /// 使用毫秒值创建超时器
    pub fn ms(timeout_ms: u64) Self {
        return init(.{
            .timeout_ms = timeout_ms,
        });
    }

    /// 使用秒值创建超时器
    pub fn seconds(timeout_seconds: u64) Self {
        return init(.{
            .timeout_ms = timeout_seconds * 1000,
        });
    }

    /// 执行带超时的操作
    /// 注意：由于 Zig 的同步特性，此方法检查执行时间但不能中断正在运行的操作
    pub fn execute(
        self: *Self,
        comptime T: type,
        comptime E: type,
        operation: anytype,
        args: anytype,
    ) (E || TimeoutError)!T {
        const start_time = std.time.nanoTimestamp();
        const timeout_ns: i128 = @as(i128, self.config.timeout_ms) * std.time.ns_per_ms;

        self.stats.total_operations += 1;

        // 执行操作
        if (@call(.auto, operation, args)) |result| {
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_u64: u64 = @intCast(@max(0, elapsed));

            self.stats.total_execution_time_ns += elapsed_u64;
            if (elapsed_u64 > self.stats.max_execution_time_ns) {
                self.stats.max_execution_time_ns = elapsed_u64;
            }

            // 检查是否超时（操作完成后检查）
            if (elapsed > timeout_ns) {
                self.stats.timed_out_operations += 1;
                return TimeoutError.OperationTimeout;
            }

            self.stats.successful_operations += 1;
            return result;
        } else |err| {
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_u64: u64 = @intCast(@max(0, elapsed));

            self.stats.total_execution_time_ns += elapsed_u64;
            if (elapsed_u64 > self.stats.max_execution_time_ns) {
                self.stats.max_execution_time_ns = elapsed_u64;
            }

            self.stats.failed_operations += 1;
            return err;
        }
    }

    /// 检查是否可能超时（预检查）
    pub fn willTimeout(self: *const Self, estimated_duration_ms: u64) bool {
        return estimated_duration_ms > self.config.timeout_ms;
    }

    /// 获取剩余时间（毫秒）
    pub fn getRemainingMs(self: *const Self, start_time_ns: i128) u64 {
        const now = std.time.nanoTimestamp();
        const elapsed_ms: u64 = @intCast(@divFloor(@max(0, now - start_time_ns), std.time.ns_per_ms));

        if (elapsed_ms >= self.config.timeout_ms) {
            return 0;
        }
        return self.config.timeout_ms - elapsed_ms;
    }

    /// 获取统计信息
    pub fn getStats(self: *const Self) TimeoutStats {
        return self.stats;
    }

    /// 重置统计信息
    pub fn resetStats(self: *Self) void {
        self.stats = TimeoutStats.init();
    }

    /// 获取超时时间（毫秒）
    pub fn getTimeoutMs(self: *const Self) u64 {
        return self.config.timeout_ms;
    }
};

/// 超时构建器
pub const TimeoutBuilder = struct {
    config: TimeoutConfig,

    const Self = @This();

    pub fn init() Self {
        return .{
            .config = .{},
        };
    }

    pub fn withTimeout(self: *Self, timeout_ms: u64) *Self {
        self.config.timeout_ms = timeout_ms;
        return self;
    }

    pub fn withTimeoutSeconds(self: *Self, seconds_val: u64) *Self {
        self.config.timeout_ms = seconds_val * 1000;
        return self;
    }

    pub fn withName(self: *Self, name: []const u8) *Self {
        self.config.name = name;
        return self;
    }

    pub fn withLogging(self: *Self, enabled: bool) *Self {
        self.config.log_timeout = enabled;
        return self;
    }

    pub fn build(self: *const Self) Timeout {
        return Timeout.init(self.config);
    }
};

/// 创建超时构建器
pub fn timeout() TimeoutBuilder {
    return TimeoutBuilder.init();
}

/// 便捷函数：带超时执行操作
pub fn withTimeout(
    comptime T: type,
    comptime E: type,
    timeout_ms: u64,
    operation: anytype,
    args: anytype,
) (E || TimeoutError)!T {
    var to = Timeout.ms(timeout_ms);
    return to.execute(T, E, operation, args);
}

/// 超时效果 - 用于函数式组合
pub const TimeoutEffect = struct {
    timeout_ptr: *Timeout,
    operation_name: []const u8,
    start_time_ns: i128,

    const Self = @This();

    pub fn init(to: *Timeout, name: []const u8) Self {
        return .{
            .timeout_ptr = to,
            .operation_name = name,
            .start_time_ns = std.time.nanoTimestamp(),
        };
    }

    pub fn getRemainingMs(self: *const Self) u64 {
        return self.timeout_ptr.getRemainingMs(self.start_time_ns);
    }

    pub fn isExpired(self: *const Self) bool {
        return self.getRemainingMs() == 0;
    }
};

/// 截止时间 - 绝对超时时间
pub const Deadline = struct {
    deadline_ns: i128,

    const Self = @This();

    /// 从现在起的超时时间（毫秒）
    pub fn fromNow(timeout_ms: u64) Self {
        const timeout_ns: i128 = @as(i128, timeout_ms) * std.time.ns_per_ms;
        return .{
            .deadline_ns = std.time.nanoTimestamp() + timeout_ns,
        };
    }

    /// 从现在起的超时时间（秒）
    pub fn fromNowSeconds(timeout_seconds: u64) Self {
        return fromNow(timeout_seconds * 1000);
    }

    /// 检查是否已过期
    pub fn isExpired(self: *const Self) bool {
        return std.time.nanoTimestamp() >= self.deadline_ns;
    }

    /// 获取剩余时间（毫秒）
    pub fn remainingMs(self: *const Self) u64 {
        const now = std.time.nanoTimestamp();
        if (now >= self.deadline_ns) {
            return 0;
        }
        return @intCast(@divFloor(self.deadline_ns - now, std.time.ns_per_ms));
    }

    /// 获取剩余时间（纳秒）
    pub fn remainingNs(self: *const Self) i128 {
        const now = std.time.nanoTimestamp();
        if (now >= self.deadline_ns) {
            return 0;
        }
        return self.deadline_ns - now;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Timeout init" {
    const to = Timeout.init(.{
        .timeout_ms = 5000,
    });

    try std.testing.expectEqual(@as(u64, 5000), to.getTimeoutMs());
}

test "Timeout.ms" {
    const to = Timeout.ms(1000);

    try std.testing.expectEqual(@as(u64, 1000), to.getTimeoutMs());
}

test "Timeout.seconds" {
    const to = Timeout.seconds(5);

    try std.testing.expectEqual(@as(u64, 5000), to.getTimeoutMs());
}

test "TimeoutStats init" {
    const stats = TimeoutStats.init();

    try std.testing.expectEqual(@as(u64, 0), stats.total_operations);
    try std.testing.expectEqual(@as(u64, 0), stats.getAverageExecutionTimeNs());
    try std.testing.expectEqual(@as(f64, 0.0), stats.getTimeoutRate());
}

test "TimeoutStats metrics" {
    var stats = TimeoutStats.init();
    stats.total_operations = 10;
    stats.timed_out_operations = 2;
    stats.total_execution_time_ns = 100_000_000; // 100ms

    try std.testing.expectEqual(@as(u64, 10_000_000), stats.getAverageExecutionTimeNs()); // 10ms
    try std.testing.expectEqual(@as(u64, 10), stats.getAverageExecutionTimeMs());
    try std.testing.expectEqual(@as(f64, 0.2), stats.getTimeoutRate());
}

test "Timeout execute success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    var to = Timeout.ms(5000);
    const result = try to.execute(i32, TestError, successFn, .{});

    try std.testing.expectEqual(@as(i32, 42), result);
    try std.testing.expectEqual(@as(u64, 1), to.getStats().successful_operations);
}

test "Timeout execute failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    var to = Timeout.ms(5000);
    const result = to.execute(i32, TestError, failFn, .{});

    try std.testing.expectError(TestError.TestFailed, result);
    try std.testing.expectEqual(@as(u64, 1), to.getStats().failed_operations);
}

test "Timeout willTimeout" {
    const to = Timeout.ms(1000);

    try std.testing.expect(!to.willTimeout(500));
    try std.testing.expect(!to.willTimeout(1000));
    try std.testing.expect(to.willTimeout(1001));
    try std.testing.expect(to.willTimeout(2000));
}

test "TimeoutBuilder" {
    var builder = timeout();
    const to = builder
        .withTimeout(5000)
        .withName("api_call")
        .withLogging(true)
        .build();

    try std.testing.expectEqual(@as(u64, 5000), to.config.timeout_ms);
    try std.testing.expectEqualStrings("api_call", to.config.name);
    try std.testing.expect(to.config.log_timeout);
}

test "TimeoutBuilder withTimeoutSeconds" {
    var builder = timeout();
    const to = builder
        .withTimeoutSeconds(30)
        .build();

    try std.testing.expectEqual(@as(u64, 30000), to.config.timeout_ms);
}

test "Deadline fromNow" {
    const deadline = Deadline.fromNow(1000);

    try std.testing.expect(!deadline.isExpired());
    try std.testing.expect(deadline.remainingMs() > 0);
    try std.testing.expect(deadline.remainingMs() <= 1000);
}

test "Deadline fromNowSeconds" {
    const deadline = Deadline.fromNowSeconds(1);

    try std.testing.expect(!deadline.isExpired());
    try std.testing.expect(deadline.remainingMs() > 0);
    try std.testing.expect(deadline.remainingMs() <= 1000);
}

test "TimeoutEffect" {
    var to = Timeout.ms(5000);
    const effect = TimeoutEffect.init(&to, "test_op");

    try std.testing.expectEqualStrings("test_op", effect.operation_name);
    try std.testing.expect(!effect.isExpired());
    try std.testing.expect(effect.getRemainingMs() > 0);
}

test "Timeout resetStats" {
    var to = Timeout.ms(5000);

    const TestError = error{TestFailed};
    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    _ = try to.execute(i32, TestError, successFn, .{});
    try std.testing.expectEqual(@as(u64, 1), to.getStats().total_operations);

    to.resetStats();
    try std.testing.expectEqual(@as(u64, 0), to.getStats().total_operations);
}
