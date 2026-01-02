const std = @import("std");
const Allocator = std.mem.Allocator;

/// 函数式断路器模块
///
/// 实现断路器模式，防止级联故障：
/// - 三种状态：关闭（正常）、打开（熔断）、半开（恢复测试）
/// - 故障计数和阈值
/// - 自动恢复机制
/// - 状态变更回调
///
/// 示例:
/// ```zig
/// var breaker = CircuitBreaker.init(.{
///     .failure_threshold = 5,
///     .success_threshold = 3,
///     .timeout_ms = 30000,
/// });
///
/// const result = breaker.execute(fetchData, .{url}) catch |err| switch (err) {
///     error.CircuitOpen => handleFallback(),
///     else => return err,
/// };
/// ```
/// 断路器状态
pub const CircuitState = enum {
    /// 关闭状态 - 正常运行，请求正常通过
    closed,
    /// 打开状态 - 熔断，快速失败
    open,
    /// 半开状态 - 允许部分请求通过以测试恢复
    half_open,

    pub fn toString(self: CircuitState) []const u8 {
        return switch (self) {
            .closed => "CLOSED",
            .open => "OPEN",
            .half_open => "HALF_OPEN",
        };
    }
};

/// 断路器错误
pub const CircuitBreakerError = error{
    /// 断路器打开，拒绝请求
    CircuitOpen,
    /// 半开状态下请求失败
    HalfOpenFailed,
    /// 操作执行失败
    OperationFailed,
};

/// 断路器配置
pub const CircuitBreakerConfig = struct {
    /// 触发熔断的失败次数阈值
    failure_threshold: u32 = 5,
    /// 从半开恢复到关闭需要的成功次数
    success_threshold: u32 = 3,
    /// 熔断超时时间（毫秒），超时后进入半开状态
    timeout_ms: u64 = 30000,
    /// 半开状态允许的最大并发请求数
    half_open_max_calls: u32 = 1,
    /// 是否记录状态变更
    enable_logging: bool = false,
};

/// 断路器统计信息
pub const CircuitStats = struct {
    /// 总请求数
    total_requests: u64,
    /// 成功请求数
    successful_requests: u64,
    /// 失败请求数
    failed_requests: u64,
    /// 被拒绝的请求数（断路器打开时）
    rejected_requests: u64,
    /// 状态变更次数
    state_transitions: u64,
    /// 上次状态变更时间戳
    last_state_change_ns: i128,
    /// 上次失败时间戳
    last_failure_ns: i128,
    /// 连续成功次数
    consecutive_successes: u32,
    /// 连续失败次数
    consecutive_failures: u32,

    pub fn init() CircuitStats {
        return .{
            .total_requests = 0,
            .successful_requests = 0,
            .failed_requests = 0,
            .rejected_requests = 0,
            .state_transitions = 0,
            .last_state_change_ns = 0,
            .last_failure_ns = 0,
            .consecutive_successes = 0,
            .consecutive_failures = 0,
        };
    }

    /// 获取成功率（0.0 - 1.0）
    pub fn getSuccessRate(self: *const CircuitStats) f64 {
        if (self.total_requests == 0) return 1.0;
        return @as(f64, @floatFromInt(self.successful_requests)) / @as(f64, @floatFromInt(self.total_requests));
    }

    /// 获取失败率（0.0 - 1.0）
    pub fn getFailureRate(self: *const CircuitStats) f64 {
        return 1.0 - self.getSuccessRate();
    }
};

/// 状态变更事件
pub const StateChangeEvent = struct {
    from_state: CircuitState,
    to_state: CircuitState,
    timestamp_ns: i128,
    reason: []const u8,
};

/// 断路器
pub const CircuitBreaker = struct {
    config: CircuitBreakerConfig,
    state: CircuitState,
    stats: CircuitStats,
    open_timestamp_ns: i128,
    half_open_calls: u32,
    state_change_callback: ?*const fn (StateChangeEvent) void,
    mutex: std.Thread.Mutex,

    const Self = @This();

    /// 初始化断路器
    pub fn init(config: CircuitBreakerConfig) Self {
        return .{
            .config = config,
            .state = .closed,
            .stats = CircuitStats.init(),
            .open_timestamp_ns = 0,
            .half_open_calls = 0,
            .state_change_callback = null,
            .mutex = .{},
        };
    }

    /// 设置状态变更回调
    pub fn onStateChange(self: *Self, callback: *const fn (StateChangeEvent) void) void {
        self.state_change_callback = callback;
    }

    /// 获取当前状态
    pub fn getState(self: *Self) CircuitState {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.checkStateTransition();
        return self.state;
    }

    /// 检查断路器是否允许请求通过
    pub fn allowRequest(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.checkStateTransition();

        return switch (self.state) {
            .closed => true,
            .open => false,
            .half_open => self.half_open_calls < self.config.half_open_max_calls,
        };
    }

    /// 记录成功
    pub fn recordSuccess(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.total_requests += 1;
        self.stats.successful_requests += 1;
        self.stats.consecutive_successes += 1;
        self.stats.consecutive_failures = 0;

        switch (self.state) {
            .closed => {
                // 保持关闭状态
            },
            .half_open => {
                self.half_open_calls -|= 1;
                // 检查是否达到成功阈值
                if (self.stats.consecutive_successes >= self.config.success_threshold) {
                    self.transitionTo(.closed, "Recovery successful");
                }
            },
            .open => {
                // 不应该在打开状态收到成功（除非有并发问题）
            },
        }
    }

    /// 记录失败
    pub fn recordFailure(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.total_requests += 1;
        self.stats.failed_requests += 1;
        self.stats.consecutive_failures += 1;
        self.stats.consecutive_successes = 0;
        self.stats.last_failure_ns = std.time.nanoTimestamp();

        switch (self.state) {
            .closed => {
                // 检查是否达到失败阈值
                if (self.stats.consecutive_failures >= self.config.failure_threshold) {
                    self.transitionTo(.open, "Failure threshold exceeded");
                }
            },
            .half_open => {
                self.half_open_calls -|= 1;
                // 半开状态下失败，立即打开
                self.transitionTo(.open, "Half-open test failed");
            },
            .open => {
                // 不应该在打开状态收到失败
            },
        }
    }

    /// 检查状态转换（如超时后从打开变为半开）
    fn checkStateTransition(self: *Self) void {
        if (self.state == .open) {
            const now = std.time.nanoTimestamp();
            const elapsed_ms: u64 = @intCast(@divFloor(now - self.open_timestamp_ns, std.time.ns_per_ms));

            if (elapsed_ms >= self.config.timeout_ms) {
                self.transitionTo(.half_open, "Timeout expired");
            }
        }
    }

    /// 状态转换
    fn transitionTo(self: *Self, new_state: CircuitState, reason: []const u8) void {
        const old_state = self.state;
        if (old_state == new_state) return;

        self.state = new_state;
        self.stats.state_transitions += 1;
        self.stats.last_state_change_ns = std.time.nanoTimestamp();

        // 状态特定处理
        switch (new_state) {
            .open => {
                self.open_timestamp_ns = std.time.nanoTimestamp();
            },
            .half_open => {
                self.half_open_calls = 0;
                self.stats.consecutive_successes = 0;
            },
            .closed => {
                self.stats.consecutive_failures = 0;
            },
        }

        // 调用回调
        if (self.state_change_callback) |callback| {
            callback(.{
                .from_state = old_state,
                .to_state = new_state,
                .timestamp_ns = self.stats.last_state_change_ns,
                .reason = reason,
            });
        }
    }

    /// 执行操作（通过断路器保护）
    pub fn execute(
        self: *Self,
        comptime T: type,
        comptime E: type,
        operation: anytype,
        args: anytype,
    ) (E || CircuitBreakerError)!T {
        // 检查是否允许请求
        {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.checkStateTransition();

            switch (self.state) {
                .closed => {},
                .open => {
                    self.stats.rejected_requests += 1;
                    return CircuitBreakerError.CircuitOpen;
                },
                .half_open => {
                    if (self.half_open_calls >= self.config.half_open_max_calls) {
                        self.stats.rejected_requests += 1;
                        return CircuitBreakerError.CircuitOpen;
                    }
                    self.half_open_calls += 1;
                },
            }
        }

        // 执行操作
        if (@call(.auto, operation, args)) |result| {
            self.recordSuccess();
            return result;
        } else |err| {
            self.recordFailure();
            return err;
        }
    }

    /// 获取统计信息
    pub fn getStats(self: *Self) CircuitStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// 重置断路器
    pub fn reset(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.state = .closed;
        self.stats = CircuitStats.init();
        self.open_timestamp_ns = 0;
        self.half_open_calls = 0;
    }

    /// 强制打开断路器
    pub fn forceOpen(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.transitionTo(.open, "Forced open");
    }

    /// 强制关闭断路器
    pub fn forceClose(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.transitionTo(.closed, "Forced close");
    }
};

/// 断路器构建器
pub const CircuitBreakerBuilder = struct {
    config: CircuitBreakerConfig,

    const Self = @This();

    pub fn init() Self {
        return .{
            .config = .{},
        };
    }

    pub fn withFailureThreshold(self: *Self, threshold: u32) *Self {
        self.config.failure_threshold = threshold;
        return self;
    }

    pub fn withSuccessThreshold(self: *Self, threshold: u32) *Self {
        self.config.success_threshold = threshold;
        return self;
    }

    pub fn withTimeout(self: *Self, timeout_ms: u64) *Self {
        self.config.timeout_ms = timeout_ms;
        return self;
    }

    pub fn withHalfOpenMaxCalls(self: *Self, max_calls: u32) *Self {
        self.config.half_open_max_calls = max_calls;
        return self;
    }

    pub fn withLogging(self: *Self, enabled: bool) *Self {
        self.config.enable_logging = enabled;
        return self;
    }

    pub fn build(self: *const Self) CircuitBreaker {
        return CircuitBreaker.init(self.config);
    }
};

/// 创建断路器构建器
pub fn circuitBreaker() CircuitBreakerBuilder {
    return CircuitBreakerBuilder.init();
}

/// 断路器效果 - 用于函数式组合
pub const CircuitBreakerEffect = struct {
    breaker: *CircuitBreaker,
    operation_name: []const u8,

    const Self = @This();

    pub fn init(breaker: *CircuitBreaker, name: []const u8) Self {
        return .{
            .breaker = breaker,
            .operation_name = name,
        };
    }

    pub fn getState(self: *const Self) CircuitState {
        return self.breaker.getState();
    }

    pub fn isOpen(self: *const Self) bool {
        return self.breaker.getState() == .open;
    }

    pub fn isClosed(self: *const Self) bool {
        return self.breaker.getState() == .closed;
    }

    pub fn isHalfOpen(self: *const Self) bool {
        return self.breaker.getState() == .half_open;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "CircuitBreaker init" {
    var breaker = CircuitBreaker.init(.{});

    try std.testing.expectEqual(CircuitState.closed, breaker.getState());
    try std.testing.expect(breaker.allowRequest());
}

test "CircuitBreaker config" {
    const config = CircuitBreakerConfig{
        .failure_threshold = 10,
        .success_threshold = 5,
        .timeout_ms = 60000,
    };

    const breaker = CircuitBreaker.init(config);

    try std.testing.expectEqual(@as(u32, 10), breaker.config.failure_threshold);
    try std.testing.expectEqual(@as(u32, 5), breaker.config.success_threshold);
    try std.testing.expectEqual(@as(u64, 60000), breaker.config.timeout_ms);
}

test "CircuitBreaker recordSuccess" {
    var breaker = CircuitBreaker.init(.{});

    breaker.recordSuccess();
    breaker.recordSuccess();
    breaker.recordSuccess();

    const stats = breaker.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.successful_requests);
    try std.testing.expectEqual(@as(u64, 0), stats.failed_requests);
    try std.testing.expectEqual(@as(u32, 3), stats.consecutive_successes);
}

test "CircuitBreaker transition to open" {
    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 3,
    });

    // 记录3次失败，应该触发熔断
    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.closed, breaker.getState());

    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.closed, breaker.getState());

    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.open, breaker.getState());
    try std.testing.expect(!breaker.allowRequest());
}

test "CircuitBreaker rejected requests" {
    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 1,
    });

    // 触发熔断
    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.open, breaker.getState());

    // 请求应该被拒绝
    try std.testing.expect(!breaker.allowRequest());

    const stats = breaker.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.rejected_requests); // allowRequest 不增加计数
}

test "CircuitBreaker reset" {
    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 1,
    });

    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.open, breaker.getState());

    breaker.reset();
    try std.testing.expectEqual(CircuitState.closed, breaker.getState());
    try std.testing.expectEqual(@as(u64, 0), breaker.getStats().failed_requests);
}

test "CircuitBreaker forceOpen and forceClose" {
    var breaker = CircuitBreaker.init(.{});

    try std.testing.expectEqual(CircuitState.closed, breaker.getState());

    breaker.forceOpen();
    try std.testing.expectEqual(CircuitState.open, breaker.getState());

    breaker.forceClose();
    try std.testing.expectEqual(CircuitState.closed, breaker.getState());
}

test "CircuitStats success rate" {
    var stats = CircuitStats.init();

    // 初始状态，成功率为1.0
    try std.testing.expectEqual(@as(f64, 1.0), stats.getSuccessRate());

    stats.total_requests = 10;
    stats.successful_requests = 7;
    stats.failed_requests = 3;

    try std.testing.expectEqual(@as(f64, 0.7), stats.getSuccessRate());
    // 使用 approxEqAbs 来比较浮点数
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), stats.getFailureRate(), 0.0001);
}

test "CircuitState toString" {
    try std.testing.expectEqualStrings("CLOSED", CircuitState.closed.toString());
    try std.testing.expectEqualStrings("OPEN", CircuitState.open.toString());
    try std.testing.expectEqualStrings("HALF_OPEN", CircuitState.half_open.toString());
}

test "CircuitBreakerBuilder" {
    var builder = circuitBreaker();
    const breaker = builder
        .withFailureThreshold(10)
        .withSuccessThreshold(5)
        .withTimeout(60000)
        .withHalfOpenMaxCalls(3)
        .build();

    try std.testing.expectEqual(@as(u32, 10), breaker.config.failure_threshold);
    try std.testing.expectEqual(@as(u32, 5), breaker.config.success_threshold);
    try std.testing.expectEqual(@as(u64, 60000), breaker.config.timeout_ms);
    try std.testing.expectEqual(@as(u32, 3), breaker.config.half_open_max_calls);
}

test "CircuitBreaker execute success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    var breaker = CircuitBreaker.init(.{});

    const result = try breaker.execute(i32, TestError, successFn, .{});
    try std.testing.expectEqual(@as(i32, 42), result);

    const stats = breaker.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.successful_requests);
}

test "CircuitBreaker execute failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 5,
    });

    const result = breaker.execute(i32, TestError, failFn, .{});
    try std.testing.expectError(TestError.TestFailed, result);

    const stats = breaker.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.failed_requests);
}

test "CircuitBreaker execute rejected when open" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 1,
    });

    // 触发熔断
    breaker.recordFailure();
    try std.testing.expectEqual(CircuitState.open, breaker.getState());

    // 执行应该被拒绝
    const result = breaker.execute(i32, TestError, successFn, .{});
    try std.testing.expectError(CircuitBreakerError.CircuitOpen, result);
}

test "CircuitBreakerEffect" {
    var breaker = CircuitBreaker.init(.{});
    const effect = CircuitBreakerEffect.init(&breaker, "test_operation");

    try std.testing.expectEqualStrings("test_operation", effect.operation_name);
    try std.testing.expect(effect.isClosed());
    try std.testing.expect(!effect.isOpen());
    try std.testing.expect(!effect.isHalfOpen());
}

test "CircuitBreaker consecutive counters reset" {
    var breaker = CircuitBreaker.init(.{
        .failure_threshold = 5,
    });

    // 记录一些失败
    breaker.recordFailure();
    breaker.recordFailure();
    try std.testing.expectEqual(@as(u32, 2), breaker.getStats().consecutive_failures);

    // 成功应该重置连续失败计数
    breaker.recordSuccess();
    try std.testing.expectEqual(@as(u32, 0), breaker.getStats().consecutive_failures);
    try std.testing.expectEqual(@as(u32, 1), breaker.getStats().consecutive_successes);

    // 失败应该重置连续成功计数
    breaker.recordFailure();
    try std.testing.expectEqual(@as(u32, 0), breaker.getStats().consecutive_successes);
}
