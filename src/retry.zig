const std = @import("std");
const Allocator = std.mem.Allocator;

/// 函数式重试策略模块
///
/// 提供多种重试策略用于处理临时性故障：
/// - 固定间隔重试
/// - 指数退避重试
/// - 带抖动的指数退避
/// - 自定义重试条件
///
/// 示例:
/// ```zig
/// const policy = RetryPolicy.exponentialBackoff(.{
///     .initial_delay_ms = 100,
///     .max_delay_ms = 5000,
///     .max_retries = 5,
/// });
///
/// const result = try retry(policy, fetchData, .{url});
/// ```
/// 重试策略类型
pub const RetryStrategy = enum {
    /// 固定间隔重试
    fixed_delay,
    /// 指数退避
    exponential_backoff,
    /// 带抖动的指数退避
    exponential_backoff_with_jitter,
    /// 线性增长
    linear_backoff,
    /// 无延迟立即重试
    immediate,
};

/// 重试配置
pub const RetryConfig = struct {
    /// 最大重试次数（0 表示不重试）
    max_retries: u32 = 3,
    /// 初始延迟（毫秒）
    initial_delay_ms: u64 = 100,
    /// 最大延迟（毫秒）
    max_delay_ms: u64 = 30000,
    /// 指数退避的倍数
    multiplier: f64 = 2.0,
    /// 线性增长的步长（毫秒）
    linear_step_ms: u64 = 100,
    /// 抖动因子（0.0 - 1.0）
    jitter_factor: f64 = 0.1,
};

/// 重试结果
pub const RetryResult = enum {
    /// 操作成功
    success,
    /// 重试后成功
    success_after_retry,
    /// 重试次数耗尽
    exhausted,
    /// 遇到不可重试的错误
    non_retryable_error,
};

/// 重试统计信息
pub const RetryStats = struct {
    /// 尝试次数（包括初始尝试）
    attempts: u32,
    /// 成功与否
    succeeded: bool,
    /// 总耗时（纳秒）
    total_duration_ns: u64,
    /// 最后一次延迟（毫秒）
    last_delay_ms: u64,

    pub fn init() RetryStats {
        return .{
            .attempts = 0,
            .succeeded = false,
            .total_duration_ns = 0,
            .last_delay_ms = 0,
        };
    }
};

/// 重试策略
pub const RetryPolicy = struct {
    strategy: RetryStrategy,
    config: RetryConfig,

    const Self = @This();

    /// 创建固定间隔重试策略
    pub fn fixedDelay(delay_ms: u64, max_retries: u32) Self {
        return .{
            .strategy = .fixed_delay,
            .config = .{
                .max_retries = max_retries,
                .initial_delay_ms = delay_ms,
                .max_delay_ms = delay_ms,
            },
        };
    }

    /// 创建指数退避重试策略
    pub fn exponentialBackoff(config: RetryConfig) Self {
        return .{
            .strategy = .exponential_backoff,
            .config = config,
        };
    }

    /// 创建带抖动的指数退避重试策略
    pub fn exponentialBackoffWithJitter(config: RetryConfig) Self {
        return .{
            .strategy = .exponential_backoff_with_jitter,
            .config = config,
        };
    }

    /// 创建线性退避重试策略
    pub fn linearBackoff(config: RetryConfig) Self {
        return .{
            .strategy = .linear_backoff,
            .config = config,
        };
    }

    /// 创建立即重试策略（无延迟）
    pub fn immediate(max_retries: u32) Self {
        return .{
            .strategy = .immediate,
            .config = .{
                .max_retries = max_retries,
                .initial_delay_ms = 0,
                .max_delay_ms = 0,
            },
        };
    }

    /// 创建不重试策略
    pub fn noRetry() Self {
        return .{
            .strategy = .immediate,
            .config = .{
                .max_retries = 0,
            },
        };
    }

    /// 计算第 n 次重试的延迟（毫秒）
    pub fn calculateDelay(self: *const Self, attempt: u32) u64 {
        if (attempt == 0) return 0;

        const delay = switch (self.strategy) {
            .immediate => @as(u64, 0),
            .fixed_delay => self.config.initial_delay_ms,
            .linear_backoff => blk: {
                const linear_delay = self.config.initial_delay_ms + @as(u64, attempt - 1) * self.config.linear_step_ms;
                break :blk @min(linear_delay, self.config.max_delay_ms);
            },
            .exponential_backoff => blk: {
                const exp_factor = std.math.pow(f64, self.config.multiplier, @as(f64, @floatFromInt(attempt - 1)));
                const exp_delay: u64 = @intFromFloat(@as(f64, @floatFromInt(self.config.initial_delay_ms)) * exp_factor);
                break :blk @min(exp_delay, self.config.max_delay_ms);
            },
            .exponential_backoff_with_jitter => blk: {
                const exp_factor = std.math.pow(f64, self.config.multiplier, @as(f64, @floatFromInt(attempt - 1)));
                const base_delay: f64 = @as(f64, @floatFromInt(self.config.initial_delay_ms)) * exp_factor;

                // 添加抖动
                var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
                const random = prng.random();
                const jitter = (random.float(f64) * 2.0 - 1.0) * self.config.jitter_factor * base_delay;
                const jittered_delay = @max(0.0, base_delay + jitter);

                const result: u64 = @intFromFloat(jittered_delay);
                break :blk @min(result, self.config.max_delay_ms);
            },
        };

        return delay;
    }

    /// 检查是否应该重试
    pub fn shouldRetry(self: *const Self, attempt: u32) bool {
        return attempt < self.config.max_retries;
    }

    /// 获取最大重试次数
    pub fn getMaxRetries(self: *const Self) u32 {
        return self.config.max_retries;
    }
};

/// 重试构建器
pub const RetryPolicyBuilder = struct {
    config: RetryConfig,
    strategy: RetryStrategy,

    const Self = @This();

    pub fn init() Self {
        return .{
            .config = .{},
            .strategy = .exponential_backoff,
        };
    }

    pub fn withMaxRetries(self: *Self, max_retries: u32) *Self {
        self.config.max_retries = max_retries;
        return self;
    }

    pub fn withInitialDelay(self: *Self, delay_ms: u64) *Self {
        self.config.initial_delay_ms = delay_ms;
        return self;
    }

    pub fn withMaxDelay(self: *Self, delay_ms: u64) *Self {
        self.config.max_delay_ms = delay_ms;
        return self;
    }

    pub fn withMultiplier(self: *Self, multiplier: f64) *Self {
        self.config.multiplier = multiplier;
        return self;
    }

    pub fn withJitter(self: *Self, jitter_factor: f64) *Self {
        self.config.jitter_factor = jitter_factor;
        self.strategy = .exponential_backoff_with_jitter;
        return self;
    }

    pub fn withStrategy(self: *Self, strategy: RetryStrategy) *Self {
        self.strategy = strategy;
        return self;
    }

    pub fn build(self: *const Self) RetryPolicy {
        return .{
            .strategy = self.strategy,
            .config = self.config,
        };
    }
};

/// 创建重试策略构建器
pub fn retryPolicy() RetryPolicyBuilder {
    return RetryPolicyBuilder.init();
}

/// 重试器 - 用于执行带重试的操作
pub fn Retrier(comptime T: type, comptime E: type) type {
    return struct {
        policy: RetryPolicy,
        stats: RetryStats,

        const Self = @This();

        pub fn init(policy: RetryPolicy) Self {
            return .{
                .policy = policy,
                .stats = RetryStats.init(),
            };
        }

        /// 执行带重试的操作
        pub fn execute(self: *Self, operation: anytype, args: anytype) E!T {
            const start_time = std.time.nanoTimestamp();
            var attempt: u32 = 0;

            while (true) {
                self.stats.attempts = attempt + 1;

                // 尝试执行操作
                if (@call(.auto, operation, args)) |result| {
                    self.stats.succeeded = true;
                    self.stats.total_duration_ns = @intCast(std.time.nanoTimestamp() - start_time);
                    return result;
                } else |err| {
                    // 检查是否应该重试
                    if (!self.policy.shouldRetry(attempt + 1)) {
                        self.stats.succeeded = false;
                        self.stats.total_duration_ns = @intCast(std.time.nanoTimestamp() - start_time);
                        return err;
                    }

                    // 计算延迟
                    attempt += 1;
                    const delay_ms = self.policy.calculateDelay(attempt);
                    self.stats.last_delay_ms = delay_ms;

                    // 等待
                    if (delay_ms > 0) {
                        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
                    }
                }
            }
        }

        /// 获取统计信息
        pub fn getStats(self: *const Self) RetryStats {
            return self.stats;
        }

        /// 重置统计信息
        pub fn resetStats(self: *Self) void {
            self.stats = RetryStats.init();
        }
    };
}

/// 便捷函数：执行带重试的操作
pub fn retry(
    comptime T: type,
    comptime E: type,
    policy: RetryPolicy,
    operation: anytype,
    args: anytype,
) E!T {
    var retrier = Retrier(T, E).init(policy);
    return retrier.execute(operation, args);
}

/// 便捷函数：使用默认策略重试
pub fn retryWithDefaults(
    comptime T: type,
    comptime E: type,
    operation: anytype,
    args: anytype,
) E!T {
    const policy = RetryPolicy.exponentialBackoff(.{});
    return retry(T, E, policy, operation, args);
}

/// 条件重试 - 只在特定条件下重试
pub fn ConditionalRetrier(comptime T: type, comptime E: type) type {
    return struct {
        policy: RetryPolicy,
        should_retry_fn: *const fn (E) bool,
        stats: RetryStats,

        const Self = @This();

        pub fn init(policy: RetryPolicy, should_retry_fn: *const fn (E) bool) Self {
            return .{
                .policy = policy,
                .should_retry_fn = should_retry_fn,
                .stats = RetryStats.init(),
            };
        }

        /// 执行带条件重试的操作
        pub fn execute(self: *Self, operation: anytype, args: anytype) E!T {
            const start_time = std.time.nanoTimestamp();
            var attempt: u32 = 0;

            while (true) {
                self.stats.attempts = attempt + 1;

                // 尝试执行操作
                if (@call(.auto, operation, args)) |result| {
                    self.stats.succeeded = true;
                    self.stats.total_duration_ns = @intCast(std.time.nanoTimestamp() - start_time);
                    return result;
                } else |err| {
                    // 检查错误是否可重试
                    if (!self.should_retry_fn(err)) {
                        self.stats.succeeded = false;
                        self.stats.total_duration_ns = @intCast(std.time.nanoTimestamp() - start_time);
                        return err;
                    }

                    // 检查是否还有重试次数
                    if (!self.policy.shouldRetry(attempt + 1)) {
                        self.stats.succeeded = false;
                        self.stats.total_duration_ns = @intCast(std.time.nanoTimestamp() - start_time);
                        return err;
                    }

                    // 计算延迟并等待
                    attempt += 1;
                    const delay_ms = self.policy.calculateDelay(attempt);
                    self.stats.last_delay_ms = delay_ms;

                    if (delay_ms > 0) {
                        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
                    }
                }
            }
        }

        pub fn getStats(self: *const Self) RetryStats {
            return self.stats;
        }
    };
}

/// 重试效果 - 用于函数式组合
pub const RetryEffect = struct {
    policy: RetryPolicy,
    operation_name: []const u8,

    const Self = @This();

    pub fn init(policy: RetryPolicy, name: []const u8) Self {
        return .{
            .policy = policy,
            .operation_name = name,
        };
    }

    pub fn withPolicy(self: *Self, policy: RetryPolicy) *Self {
        self.policy = policy;
        return self;
    }

    pub fn getPolicy(self: *const Self) RetryPolicy {
        return self.policy;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "RetryPolicy.fixedDelay" {
    const policy = RetryPolicy.fixedDelay(100, 3);

    try std.testing.expectEqual(RetryStrategy.fixed_delay, policy.strategy);
    try std.testing.expectEqual(@as(u32, 3), policy.config.max_retries);
    try std.testing.expectEqual(@as(u64, 100), policy.config.initial_delay_ms);
}

test "RetryPolicy.exponentialBackoff" {
    const policy = RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 100,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .max_retries = 5,
    });

    try std.testing.expectEqual(RetryStrategy.exponential_backoff, policy.strategy);
    try std.testing.expectEqual(@as(u32, 5), policy.config.max_retries);
}

test "RetryPolicy.calculateDelay fixed" {
    const policy = RetryPolicy.fixedDelay(100, 3);

    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(0));
    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(1));
    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(2));
    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(3));
}

test "RetryPolicy.calculateDelay exponential" {
    const policy = RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 100,
        .max_delay_ms = 10000,
        .multiplier = 2.0,
        .max_retries = 5,
    });

    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(0));
    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(1)); // 100 * 2^0
    try std.testing.expectEqual(@as(u64, 200), policy.calculateDelay(2)); // 100 * 2^1
    try std.testing.expectEqual(@as(u64, 400), policy.calculateDelay(3)); // 100 * 2^2
    try std.testing.expectEqual(@as(u64, 800), policy.calculateDelay(4)); // 100 * 2^3
}

test "RetryPolicy.calculateDelay linear" {
    const policy = RetryPolicy.linearBackoff(.{
        .initial_delay_ms = 100,
        .linear_step_ms = 50,
        .max_delay_ms = 500,
        .max_retries = 10,
    });

    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(0));
    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(1)); // 100 + 0*50
    try std.testing.expectEqual(@as(u64, 150), policy.calculateDelay(2)); // 100 + 1*50
    try std.testing.expectEqual(@as(u64, 200), policy.calculateDelay(3)); // 100 + 2*50
    try std.testing.expectEqual(@as(u64, 500), policy.calculateDelay(10)); // capped at max
}

test "RetryPolicy.calculateDelay immediate" {
    const policy = RetryPolicy.immediate(5);

    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(0));
    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(1));
    try std.testing.expectEqual(@as(u64, 0), policy.calculateDelay(5));
}

test "RetryPolicy.shouldRetry" {
    const policy = RetryPolicy.fixedDelay(100, 3);

    try std.testing.expect(policy.shouldRetry(0));
    try std.testing.expect(policy.shouldRetry(1));
    try std.testing.expect(policy.shouldRetry(2));
    try std.testing.expect(!policy.shouldRetry(3));
    try std.testing.expect(!policy.shouldRetry(4));
}

test "RetryPolicy.noRetry" {
    const policy = RetryPolicy.noRetry();

    try std.testing.expectEqual(@as(u32, 0), policy.config.max_retries);
    try std.testing.expect(!policy.shouldRetry(0));
}

test "RetryPolicyBuilder" {
    var builder = retryPolicy();
    const policy = builder
        .withMaxRetries(5)
        .withInitialDelay(200)
        .withMaxDelay(10000)
        .withMultiplier(3.0)
        .build();

    try std.testing.expectEqual(@as(u32, 5), policy.config.max_retries);
    try std.testing.expectEqual(@as(u64, 200), policy.config.initial_delay_ms);
    try std.testing.expectEqual(@as(u64, 10000), policy.config.max_delay_ms);
    try std.testing.expectEqual(@as(f64, 3.0), policy.config.multiplier);
}

test "RetryStats init" {
    const stats = RetryStats.init();

    try std.testing.expectEqual(@as(u32, 0), stats.attempts);
    try std.testing.expect(!stats.succeeded);
    try std.testing.expectEqual(@as(u64, 0), stats.total_duration_ns);
}

test "Retrier successful first attempt" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    const policy = RetryPolicy.fixedDelay(10, 3);
    var retrier = Retrier(i32, TestError).init(policy);

    const result = try retrier.execute(successFn, .{});
    try std.testing.expectEqual(@as(i32, 42), result);
    try std.testing.expectEqual(@as(u32, 1), retrier.getStats().attempts);
    try std.testing.expect(retrier.getStats().succeeded);
}

test "Retrier with failures then success" {
    const TestError = error{TestFailed};

    var call_count: u32 = 0;
    const failThenSucceed = struct {
        fn call(count: *u32) TestError!i32 {
            count.* += 1;
            if (count.* < 3) {
                return TestError.TestFailed;
            }
            return 42;
        }
    }.call;

    const policy = RetryPolicy.immediate(5);
    var retrier = Retrier(i32, TestError).init(policy);

    const result = try retrier.execute(failThenSucceed, .{&call_count});
    try std.testing.expectEqual(@as(i32, 42), result);
    try std.testing.expectEqual(@as(u32, 3), call_count);
    try std.testing.expect(retrier.getStats().succeeded);
}

test "Retrier exhausted retries" {
    const TestError = error{TestFailed};

    const alwaysFail = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    const policy = RetryPolicy.immediate(2);
    var retrier = Retrier(i32, TestError).init(policy);

    const result = retrier.execute(alwaysFail, .{});
    try std.testing.expectError(TestError.TestFailed, result);
    try std.testing.expect(!retrier.getStats().succeeded);
}

test "RetryEffect creation" {
    const policy = RetryPolicy.fixedDelay(100, 3);
    const effect = RetryEffect.init(policy, "test_operation");

    try std.testing.expectEqualStrings("test_operation", effect.operation_name);
    try std.testing.expectEqual(@as(u32, 3), effect.getPolicy().config.max_retries);
}

test "exponentialBackoff max delay cap" {
    const policy = RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 1000,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .max_retries = 10,
    });

    // 第5次: 1000 * 2^4 = 16000, 应该被限制为 5000
    try std.testing.expectEqual(@as(u64, 5000), policy.calculateDelay(5));
    try std.testing.expectEqual(@as(u64, 5000), policy.calculateDelay(10));
}

test "jitter produces varying delays" {
    const policy = RetryPolicy.exponentialBackoffWithJitter(.{
        .initial_delay_ms = 1000,
        .max_delay_ms = 10000,
        .multiplier = 2.0,
        .jitter_factor = 0.5,
        .max_retries = 5,
    });

    // 由于抖动，延迟应该在一个范围内变化
    const delay1 = policy.calculateDelay(1);
    const delay2 = policy.calculateDelay(1);

    // 延迟应该在合理范围内（基础值 1000，抖动 ±50%）
    try std.testing.expect(delay1 >= 500 and delay1 <= 1500);
    try std.testing.expect(delay2 >= 500 and delay2 <= 1500);
}
