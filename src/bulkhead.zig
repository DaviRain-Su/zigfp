const std = @import("std");
const Allocator = std.mem.Allocator;

/// 函数式隔板模式模块
///
/// 实现隔板模式，限制并发访问以隔离故障：
/// - 最大并发数限制
/// - 等待队列（可选）
/// - 拒绝策略
/// - 资源使用统计
///
/// 示例:
/// ```zig
/// var bulkhead = Bulkhead.init(.{
///     .max_concurrent = 10,
///     .max_wait_ms = 1000,
/// });
///
/// const result = try bulkhead.execute(processRequest, .{request});
/// ```
/// 隔板错误
pub const BulkheadError = error{
    /// 隔板已满，拒绝请求
    BulkheadFull,
    /// 等待超时
    WaitTimeout,
    /// 操作失败
    OperationFailed,
};

/// 拒绝策略
pub const RejectionPolicy = enum {
    /// 立即拒绝
    fail_fast,
    /// 等待可用槽位
    wait,
    /// 丢弃最旧的等待请求
    discard_oldest,
};

/// 隔板配置
pub const BulkheadConfig = struct {
    /// 最大并发执行数
    max_concurrent: u32 = 10,
    /// 最大等待队列长度（0 表示不排队）
    max_waiting: u32 = 0,
    /// 最大等待时间（毫秒，0 表示无限等待）
    max_wait_ms: u64 = 0,
    /// 拒绝策略
    rejection_policy: RejectionPolicy = .fail_fast,
    /// 操作名称（用于日志）
    name: []const u8 = "default",
};

/// 隔板统计信息
pub const BulkheadStats = struct {
    /// 总请求数
    total_requests: u64,
    /// 成功执行数
    successful_executions: u64,
    /// 失败执行数
    failed_executions: u64,
    /// 拒绝请求数
    rejected_requests: u64,
    /// 当前并发执行数
    current_concurrent: u32,
    /// 当前等待数
    current_waiting: u32,
    /// 最大并发数（历史）
    max_concurrent_reached: u32,

    pub fn init() BulkheadStats {
        return .{
            .total_requests = 0,
            .successful_executions = 0,
            .failed_executions = 0,
            .rejected_requests = 0,
            .current_concurrent = 0,
            .current_waiting = 0,
            .max_concurrent_reached = 0,
        };
    }

    /// 获取利用率（0.0 - 1.0）
    pub fn getUtilization(self: *const BulkheadStats, max_concurrent: u32) f64 {
        if (max_concurrent == 0) return 0.0;
        return @as(f64, @floatFromInt(self.current_concurrent)) / @as(f64, @floatFromInt(max_concurrent));
    }
};

/// 隔板
pub const Bulkhead = struct {
    config: BulkheadConfig,
    stats: BulkheadStats,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,

    const Self = @This();

    /// 初始化隔板
    pub fn init(config: BulkheadConfig) Self {
        return .{
            .config = config,
            .stats = BulkheadStats.init(),
            .mutex = .{},
            .condition = .{},
        };
    }

    /// 尝试获取执行槽位
    pub fn tryAcquire(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.stats.current_concurrent < self.config.max_concurrent) {
            self.stats.current_concurrent += 1;
            if (self.stats.current_concurrent > self.stats.max_concurrent_reached) {
                self.stats.max_concurrent_reached = self.stats.current_concurrent;
            }
            return true;
        }
        return false;
    }

    /// 获取执行槽位（可能等待）
    pub fn acquire(self: *Self) BulkheadError!void {
        self.mutex.lock();

        // 如果有空闲槽位，立即获取
        if (self.stats.current_concurrent < self.config.max_concurrent) {
            self.stats.current_concurrent += 1;
            if (self.stats.current_concurrent > self.stats.max_concurrent_reached) {
                self.stats.max_concurrent_reached = self.stats.current_concurrent;
            }
            self.mutex.unlock();
            return;
        }

        // 根据拒绝策略处理
        switch (self.config.rejection_policy) {
            .fail_fast => {
                self.stats.rejected_requests += 1;
                self.mutex.unlock();
                return BulkheadError.BulkheadFull;
            },
            .wait => {
                // 检查等待队列是否已满
                if (self.config.max_waiting > 0 and self.stats.current_waiting >= self.config.max_waiting) {
                    self.stats.rejected_requests += 1;
                    self.mutex.unlock();
                    return BulkheadError.BulkheadFull;
                }

                self.stats.current_waiting += 1;

                // 等待可用槽位
                if (self.config.max_wait_ms > 0) {
                    const timeout_ns = self.config.max_wait_ms * std.time.ns_per_ms;
                    self.condition.timedWait(&self.mutex, timeout_ns) catch {
                        self.stats.current_waiting -= 1;
                        self.stats.rejected_requests += 1;
                        self.mutex.unlock();
                        return BulkheadError.WaitTimeout;
                    };
                } else {
                    self.condition.wait(&self.mutex);
                }

                self.stats.current_waiting -= 1;

                // 再次检查是否有槽位（可能被其他等待者抢占）
                if (self.stats.current_concurrent < self.config.max_concurrent) {
                    self.stats.current_concurrent += 1;
                    if (self.stats.current_concurrent > self.stats.max_concurrent_reached) {
                        self.stats.max_concurrent_reached = self.stats.current_concurrent;
                    }
                    self.mutex.unlock();
                    return;
                } else {
                    self.stats.rejected_requests += 1;
                    self.mutex.unlock();
                    return BulkheadError.BulkheadFull;
                }
            },
            .discard_oldest => {
                // 此策略需要队列支持，暂时按 fail_fast 处理
                self.stats.rejected_requests += 1;
                self.mutex.unlock();
                return BulkheadError.BulkheadFull;
            },
        }
    }

    /// 释放执行槽位
    pub fn release(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.stats.current_concurrent > 0) {
            self.stats.current_concurrent -= 1;
        }

        // 通知等待者
        self.condition.signal();
    }

    /// 执行操作（通过隔板保护）
    pub fn execute(
        self: *Self,
        comptime T: type,
        comptime E: type,
        operation: anytype,
        args: anytype,
    ) (E || BulkheadError)!T {
        self.stats.total_requests += 1;

        // 获取槽位
        try self.acquire();
        defer self.release();

        // 执行操作
        if (@call(.auto, operation, args)) |result| {
            self.mutex.lock();
            self.stats.successful_executions += 1;
            self.mutex.unlock();
            return result;
        } else |err| {
            self.mutex.lock();
            self.stats.failed_executions += 1;
            self.mutex.unlock();
            return err;
        }
    }

    /// 获取统计信息
    pub fn getStats(self: *Self) BulkheadStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// 获取当前并发数
    pub fn getCurrentConcurrent(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.current_concurrent;
    }

    /// 获取可用槽位数
    pub fn getAvailablePermits(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.stats.current_concurrent >= self.config.max_concurrent) {
            return 0;
        }
        return self.config.max_concurrent - self.stats.current_concurrent;
    }

    /// 检查是否已满
    pub fn isFull(self: *Self) bool {
        return self.getAvailablePermits() == 0;
    }

    /// 重置统计信息
    pub fn resetStats(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const current = self.stats.current_concurrent;
        self.stats = BulkheadStats.init();
        self.stats.current_concurrent = current;
    }
};

/// 隔板构建器
pub const BulkheadBuilder = struct {
    config: BulkheadConfig,

    const Self = @This();

    pub fn init() Self {
        return .{
            .config = .{},
        };
    }

    pub fn withMaxConcurrent(self: *Self, max: u32) *Self {
        self.config.max_concurrent = max;
        return self;
    }

    pub fn withMaxWaiting(self: *Self, max: u32) *Self {
        self.config.max_waiting = max;
        return self;
    }

    pub fn withMaxWaitTime(self: *Self, ms: u64) *Self {
        self.config.max_wait_ms = ms;
        return self;
    }

    pub fn withRejectionPolicy(self: *Self, policy: RejectionPolicy) *Self {
        self.config.rejection_policy = policy;
        return self;
    }

    pub fn withName(self: *Self, name: []const u8) *Self {
        self.config.name = name;
        return self;
    }

    pub fn build(self: *const Self) Bulkhead {
        return Bulkhead.init(self.config);
    }
};

/// 创建隔板构建器
pub fn bulkhead() BulkheadBuilder {
    return BulkheadBuilder.init();
}

/// 信号量 - 简化的并发控制
pub const Semaphore = struct {
    permits: u32,
    max_permits: u32,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,

    const Self = @This();

    pub fn init(permits: u32) Self {
        return .{
            .permits = permits,
            .max_permits = permits,
            .mutex = .{},
            .condition = .{},
        };
    }

    pub fn acquire(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.permits == 0) {
            self.condition.wait(&self.mutex);
        }
        self.permits -= 1;
    }

    pub fn tryAcquire(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.permits > 0) {
            self.permits -= 1;
            return true;
        }
        return false;
    }

    pub fn release(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.permits < self.max_permits) {
            self.permits += 1;
            self.condition.signal();
        }
    }

    pub fn availablePermits(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.permits;
    }
};

/// 隔板效果 - 用于函数式组合
pub const BulkheadEffect = struct {
    bulkhead_ptr: *Bulkhead,
    operation_name: []const u8,

    const Self = @This();

    pub fn init(bh: *Bulkhead, name: []const u8) Self {
        return .{
            .bulkhead_ptr = bh,
            .operation_name = name,
        };
    }

    pub fn isFull(self: *const Self) bool {
        return self.bulkhead_ptr.isFull();
    }

    pub fn getUtilization(self: *const Self) f64 {
        const stats = self.bulkhead_ptr.getStats();
        return stats.getUtilization(self.bulkhead_ptr.config.max_concurrent);
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Bulkhead init" {
    var bh = Bulkhead.init(.{});

    try std.testing.expectEqual(@as(u32, 10), bh.config.max_concurrent);
    try std.testing.expectEqual(@as(u32, 0), bh.getCurrentConcurrent());
    try std.testing.expect(!bh.isFull());
}

test "Bulkhead config" {
    const bh = Bulkhead.init(.{
        .max_concurrent = 5,
        .max_waiting = 10,
        .max_wait_ms = 1000,
        .rejection_policy = .wait,
        .name = "test",
    });

    try std.testing.expectEqual(@as(u32, 5), bh.config.max_concurrent);
    try std.testing.expectEqual(@as(u32, 10), bh.config.max_waiting);
    try std.testing.expectEqual(@as(u64, 1000), bh.config.max_wait_ms);
    try std.testing.expectEqual(RejectionPolicy.wait, bh.config.rejection_policy);
    try std.testing.expectEqualStrings("test", bh.config.name);
}

test "Bulkhead tryAcquire" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 2,
    });

    // 第一次获取应该成功
    try std.testing.expect(bh.tryAcquire());
    try std.testing.expectEqual(@as(u32, 1), bh.getCurrentConcurrent());

    // 第二次获取应该成功
    try std.testing.expect(bh.tryAcquire());
    try std.testing.expectEqual(@as(u32, 2), bh.getCurrentConcurrent());

    // 第三次获取应该失败（已满）
    try std.testing.expect(!bh.tryAcquire());
    try std.testing.expectEqual(@as(u32, 2), bh.getCurrentConcurrent());

    // 释放一个
    bh.release();
    try std.testing.expectEqual(@as(u32, 1), bh.getCurrentConcurrent());

    // 再次获取应该成功
    try std.testing.expect(bh.tryAcquire());
}

test "Bulkhead acquire fail_fast" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 1,
        .rejection_policy = .fail_fast,
    });

    // 第一次获取成功
    try bh.acquire();
    try std.testing.expectEqual(@as(u32, 1), bh.getCurrentConcurrent());

    // 第二次获取应该失败
    const result = bh.acquire();
    try std.testing.expectError(BulkheadError.BulkheadFull, result);

    bh.release();
}

test "Bulkhead getAvailablePermits" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 5,
    });

    try std.testing.expectEqual(@as(u32, 5), bh.getAvailablePermits());

    _ = bh.tryAcquire();
    try std.testing.expectEqual(@as(u32, 4), bh.getAvailablePermits());

    _ = bh.tryAcquire();
    _ = bh.tryAcquire();
    try std.testing.expectEqual(@as(u32, 2), bh.getAvailablePermits());

    bh.release();
    try std.testing.expectEqual(@as(u32, 3), bh.getAvailablePermits());
}

test "Bulkhead isFull" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 2,
    });

    try std.testing.expect(!bh.isFull());

    _ = bh.tryAcquire();
    try std.testing.expect(!bh.isFull());

    _ = bh.tryAcquire();
    try std.testing.expect(bh.isFull());

    bh.release();
    try std.testing.expect(!bh.isFull());
}

test "BulkheadStats utilization" {
    var stats = BulkheadStats.init();

    try std.testing.expectEqual(@as(f64, 0.0), stats.getUtilization(10));

    stats.current_concurrent = 5;
    try std.testing.expectEqual(@as(f64, 0.5), stats.getUtilization(10));

    stats.current_concurrent = 10;
    try std.testing.expectEqual(@as(f64, 1.0), stats.getUtilization(10));
}

test "BulkheadBuilder" {
    var builder = bulkhead();
    const bh = builder
        .withMaxConcurrent(20)
        .withMaxWaiting(50)
        .withMaxWaitTime(5000)
        .withRejectionPolicy(.wait)
        .withName("api_bulkhead")
        .build();

    try std.testing.expectEqual(@as(u32, 20), bh.config.max_concurrent);
    try std.testing.expectEqual(@as(u32, 50), bh.config.max_waiting);
    try std.testing.expectEqual(@as(u64, 5000), bh.config.max_wait_ms);
    try std.testing.expectEqual(RejectionPolicy.wait, bh.config.rejection_policy);
    try std.testing.expectEqualStrings("api_bulkhead", bh.config.name);
}

test "Bulkhead execute success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    var bh = Bulkhead.init(.{
        .max_concurrent = 5,
    });

    const result = try bh.execute(i32, TestError, successFn, .{});
    try std.testing.expectEqual(@as(i32, 42), result);

    const stats = bh.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.successful_executions);
    try std.testing.expectEqual(@as(u64, 0), stats.failed_executions);
}

test "Bulkhead execute failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    var bh = Bulkhead.init(.{
        .max_concurrent = 5,
    });

    const result = bh.execute(i32, TestError, failFn, .{});
    try std.testing.expectError(TestError.TestFailed, result);

    const stats = bh.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.successful_executions);
    try std.testing.expectEqual(@as(u64, 1), stats.failed_executions);
}

test "Semaphore basic operations" {
    var sem = Semaphore.init(3);

    try std.testing.expectEqual(@as(u32, 3), sem.availablePermits());

    try std.testing.expect(sem.tryAcquire());
    try std.testing.expectEqual(@as(u32, 2), sem.availablePermits());

    try std.testing.expect(sem.tryAcquire());
    try std.testing.expect(sem.tryAcquire());
    try std.testing.expectEqual(@as(u32, 0), sem.availablePermits());

    try std.testing.expect(!sem.tryAcquire());

    sem.release();
    try std.testing.expectEqual(@as(u32, 1), sem.availablePermits());
}

test "BulkheadEffect" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 10,
    });
    const effect = BulkheadEffect.init(&bh, "test_operation");

    try std.testing.expectEqualStrings("test_operation", effect.operation_name);
    try std.testing.expect(!effect.isFull());
    try std.testing.expectEqual(@as(f64, 0.0), effect.getUtilization());
}

test "Bulkhead resetStats" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 5,
    });

    _ = bh.tryAcquire();
    _ = bh.tryAcquire();

    var stats = bh.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.current_concurrent);

    bh.resetStats();

    stats = bh.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.current_concurrent); // 保持当前并发数
    try std.testing.expectEqual(@as(u64, 0), stats.total_requests); // 重置计数
}

test "Bulkhead max_concurrent_reached" {
    var bh = Bulkhead.init(.{
        .max_concurrent = 5,
    });

    _ = bh.tryAcquire();
    _ = bh.tryAcquire();
    _ = bh.tryAcquire();

    var stats = bh.getStats();
    try std.testing.expectEqual(@as(u32, 3), stats.max_concurrent_reached);

    bh.release();
    bh.release();

    stats = bh.getStats();
    try std.testing.expectEqual(@as(u32, 3), stats.max_concurrent_reached); // 历史最大值不变
    try std.testing.expectEqual(@as(u32, 1), stats.current_concurrent);
}
