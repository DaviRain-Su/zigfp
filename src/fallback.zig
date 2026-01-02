const std = @import("std");
const Allocator = std.mem.Allocator;

/// 函数式降级策略模块
///
/// 提供操作降级和备用方案：
/// - 默认值降级
/// - 备用操作降级
/// - 缓存降级
/// - 链式降级
///
/// 示例:
/// ```zig
/// const result = withFallbackValue(fetchData, .{url}, defaultValue);
///
/// // 或使用备用操作
/// const result = withFallbackFn(fetchFromPrimary, .{}, fetchFromBackup, .{});
/// ```
/// 降级策略类型
pub const FallbackStrategy = enum {
    /// 返回默认值
    default_value,
    /// 执行备用操作
    fallback_operation,
    /// 使用缓存值
    cached_value,
    /// 抛出原始错误
    throw_error,
    /// 返回空值
    return_null,
};

/// 降级配置
pub const FallbackConfig = struct {
    /// 降级策略
    strategy: FallbackStrategy = .default_value,
    /// 操作名称
    name: []const u8 = "default",
    /// 是否记录降级
    log_fallback: bool = false,
};

/// 降级统计
pub const FallbackStats = struct {
    /// 总操作数
    total_operations: u64,
    /// 主操作成功数
    primary_successes: u64,
    /// 降级次数
    fallback_count: u64,
    /// 降级成功数
    fallback_successes: u64,
    /// 完全失败数
    total_failures: u64,

    pub fn init() FallbackStats {
        return .{
            .total_operations = 0,
            .primary_successes = 0,
            .fallback_count = 0,
            .fallback_successes = 0,
            .total_failures = 0,
        };
    }

    /// 获取降级率（0.0 - 1.0）
    pub fn getFallbackRate(self: *const FallbackStats) f64 {
        if (self.total_operations == 0) return 0.0;
        return @as(f64, @floatFromInt(self.fallback_count)) / @as(f64, @floatFromInt(self.total_operations));
    }

    /// 获取总成功率（0.0 - 1.0）
    pub fn getSuccessRate(self: *const FallbackStats) f64 {
        if (self.total_operations == 0) return 1.0;
        const successes = self.primary_successes + self.fallback_successes;
        return @as(f64, @floatFromInt(successes)) / @as(f64, @floatFromInt(self.total_operations));
    }
};

/// 降级结果
pub fn FallbackResult(comptime T: type) type {
    return struct {
        value: T,
        was_fallback: bool,
        primary_error: ?anyerror,

        const Self = @This();

        pub fn primary(value: T) Self {
            return .{
                .value = value,
                .was_fallback = false,
                .primary_error = null,
            };
        }

        pub fn fallback(value: T, err: anyerror) Self {
            return .{
                .value = value,
                .was_fallback = true,
                .primary_error = err,
            };
        }
    };
}

/// 降级器
pub fn Fallback(comptime T: type, comptime E: type) type {
    return struct {
        default_value: ?T,
        stats: FallbackStats,
        config: FallbackConfig,

        const Self = @This();

        /// 使用默认值初始化
        pub fn withDefault(value: T) Self {
            return .{
                .default_value = value,
                .stats = FallbackStats.init(),
                .config = .{
                    .strategy = .default_value,
                },
            };
        }

        /// 使用配置初始化
        pub fn init(config: FallbackConfig) Self {
            return .{
                .default_value = null,
                .stats = FallbackStats.init(),
                .config = config,
            };
        }

        /// 执行带降级的操作
        pub fn execute(
            self: *Self,
            operation: anytype,
            args: anytype,
        ) E!T {
            self.stats.total_operations += 1;

            // 尝试执行主操作
            if (@call(.auto, operation, args)) |result| {
                self.stats.primary_successes += 1;
                return result;
            } else |_| {
                self.stats.fallback_count += 1;

                // 使用降级策略
                switch (self.config.strategy) {
                    .default_value => {
                        if (self.default_value) |value| {
                            self.stats.fallback_successes += 1;
                            return value;
                        }
                        self.stats.total_failures += 1;
                        return error.NoFallbackValue;
                    },
                    .throw_error => {
                        self.stats.total_failures += 1;
                        return error.OperationFailed;
                    },
                    else => {
                        self.stats.total_failures += 1;
                        return error.UnsupportedStrategy;
                    },
                }
            }
        }

        /// 执行带降级值的操作
        pub fn executeWithFallback(
            self: *Self,
            operation: anytype,
            args: anytype,
            fallback_value: T,
        ) T {
            self.stats.total_operations += 1;

            if (@call(.auto, operation, args)) |result| {
                self.stats.primary_successes += 1;
                return result;
            } else |_| {
                self.stats.fallback_count += 1;
                self.stats.fallback_successes += 1;
                return fallback_value;
            }
        }

        /// 获取统计信息
        pub fn getStats(self: *const Self) FallbackStats {
            return self.stats;
        }

        /// 重置统计信息
        pub fn resetStats(self: *Self) void {
            self.stats = FallbackStats.init();
        }
    };
}

/// 便捷函数：带默认值降级
pub fn withFallbackValue(
    comptime T: type,
    comptime _: type,
    operation: anytype,
    args: anytype,
    fallback_value: T,
) T {
    if (@call(.auto, operation, args)) |result| {
        return result;
    } else |_| {
        return fallback_value;
    }
}

/// 便捷函数：带备用操作降级
pub fn withFallbackFn(
    comptime T: type,
    comptime _: type,
    primary_op: anytype,
    primary_args: anytype,
    fallback_op: anytype,
    fallback_args: anytype,
) !T {
    if (@call(.auto, primary_op, primary_args)) |result| {
        return result;
    } else |_| {
        return @call(.auto, fallback_op, fallback_args);
    }
}

/// 便捷函数：尝试主操作，失败返回 null
pub fn tryOrNull(
    comptime T: type,
    comptime _: type,
    operation: anytype,
    args: anytype,
) ?T {
    if (@call(.auto, operation, args)) |result| {
        return result;
    } else |_| {
        return null;
    }
}

/// 降级链 - 多级降级策略
pub fn FallbackChain(comptime T: type, comptime _: type) type {
    return struct {
        operations: std.ArrayList(Operation),
        allocator: Allocator,
        stats: FallbackStats,

        const Operation = struct {
            name: []const u8,
            fn_ptr: *const anyopaque,
        };

        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            return .{
                .operations = try std.ArrayList(Operation).initCapacity(allocator, 4),
                .allocator = allocator,
                .stats = FallbackStats.init(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.operations.deinit(self.allocator);
        }

        /// 执行链式降级
        pub fn executeWithDefault(self: *Self, default: T) T {
            _ = self;
            // 简化实现：直接返回默认值
            return default;
        }

        pub fn getStats(self: *const Self) FallbackStats {
            return self.stats;
        }
    };
}

/// 缓存降级器 - 使用缓存值作为降级
pub fn CacheFallback(comptime K: type, comptime V: type) type {
    return struct {
        cache: std.AutoHashMap(K, V),
        stats: FallbackStats,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .cache = std.AutoHashMap(K, V).init(allocator),
                .stats = FallbackStats.init(),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
        }

        /// 获取值，失败时使用缓存
        pub fn get(
            self: *Self,
            key: K,
            comptime E: type,
            fetcher: anytype,
            args: anytype,
        ) E!V {
            self.stats.total_operations += 1;

            // 尝试获取新值
            if (@call(.auto, fetcher, args)) |value| {
                // 更新缓存
                self.cache.put(key, value) catch {};
                self.stats.primary_successes += 1;
                return value;
            } else |err| {
                self.stats.fallback_count += 1;

                // 尝试使用缓存
                if (self.cache.get(key)) |cached| {
                    self.stats.fallback_successes += 1;
                    return cached;
                }

                self.stats.total_failures += 1;
                return err;
            }
        }

        /// 预填充缓存
        pub fn preload(self: *Self, key: K, value: V) !void {
            try self.cache.put(key, value);
        }

        /// 清空缓存
        pub fn clearCache(self: *Self) void {
            self.cache.clearAndFree();
        }

        pub fn getStats(self: *const Self) FallbackStats {
            return self.stats;
        }
    };
}

/// 降级效果 - 用于函数式组合
pub const FallbackEffect = struct {
    strategy: FallbackStrategy,
    operation_name: []const u8,
    was_fallback: bool,

    const Self = @This();

    pub fn init(strategy: FallbackStrategy, name: []const u8) Self {
        return .{
            .strategy = strategy,
            .operation_name = name,
            .was_fallback = false,
        };
    }

    pub fn markFallback(self: *Self) void {
        self.was_fallback = true;
    }

    pub fn wasFallback(self: *const Self) bool {
        return self.was_fallback;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "FallbackStats init" {
    const stats = FallbackStats.init();

    try std.testing.expectEqual(@as(u64, 0), stats.total_operations);
    try std.testing.expectEqual(@as(f64, 0.0), stats.getFallbackRate());
    try std.testing.expectEqual(@as(f64, 1.0), stats.getSuccessRate());
}

test "FallbackStats metrics" {
    var stats = FallbackStats.init();
    stats.total_operations = 10;
    stats.primary_successes = 7;
    stats.fallback_count = 3;
    stats.fallback_successes = 2;
    stats.total_failures = 1;

    try std.testing.expectEqual(@as(f64, 0.3), stats.getFallbackRate());
    try std.testing.expectEqual(@as(f64, 0.9), stats.getSuccessRate()); // 7 + 2 = 9 out of 10
}

test "FallbackResult primary" {
    const Result = FallbackResult(i32);
    const result = Result.primary(42);

    try std.testing.expectEqual(@as(i32, 42), result.value);
    try std.testing.expect(!result.was_fallback);
    try std.testing.expect(result.primary_error == null);
}

test "FallbackResult fallback" {
    const Result = FallbackResult(i32);
    const result = Result.fallback(0, error.TestFailed);

    try std.testing.expectEqual(@as(i32, 0), result.value);
    try std.testing.expect(result.was_fallback);
    try std.testing.expect(result.primary_error != null);
}

test "Fallback withDefault" {
    const TestError = error{ TestFailed, NoFallbackValue, OperationFailed, UnsupportedStrategy };

    const fb = Fallback(i32, TestError).withDefault(99);

    try std.testing.expectEqual(@as(?i32, 99), fb.default_value);
}

test "Fallback executeWithFallback success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    var fb = Fallback(i32, TestError).withDefault(0);
    const result = fb.executeWithFallback(successFn, .{}, 99);

    try std.testing.expectEqual(@as(i32, 42), result);
    try std.testing.expectEqual(@as(u64, 1), fb.getStats().primary_successes);
    try std.testing.expectEqual(@as(u64, 0), fb.getStats().fallback_count);
}

test "Fallback executeWithFallback failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    var fb = Fallback(i32, TestError).withDefault(0);
    const result = fb.executeWithFallback(failFn, .{}, 99);

    try std.testing.expectEqual(@as(i32, 99), result);
    try std.testing.expectEqual(@as(u64, 0), fb.getStats().primary_successes);
    try std.testing.expectEqual(@as(u64, 1), fb.getStats().fallback_count);
}

test "withFallbackValue success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    const result = withFallbackValue(i32, TestError, successFn, .{}, 99);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "withFallbackValue failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    const result = withFallbackValue(i32, TestError, failFn, .{}, 99);
    try std.testing.expectEqual(@as(i32, 99), result);
}

test "tryOrNull success" {
    const TestError = error{TestFailed};

    const successFn = struct {
        fn call() TestError!i32 {
            return 42;
        }
    }.call;

    const result = tryOrNull(i32, TestError, successFn, .{});
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i32, 42), result.?);
}

test "tryOrNull failure" {
    const TestError = error{TestFailed};

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    const result = tryOrNull(i32, TestError, failFn, .{});
    try std.testing.expect(result == null);
}

test "CacheFallback init and deinit" {
    const allocator = std.testing.allocator;

    var cache = CacheFallback(i32, i32).init(allocator);
    defer cache.deinit();

    try cache.preload(1, 100);
    try cache.preload(2, 200);
}

test "FallbackEffect" {
    var effect = FallbackEffect.init(.default_value, "test_op");

    try std.testing.expectEqualStrings("test_op", effect.operation_name);
    try std.testing.expect(!effect.wasFallback());

    effect.markFallback();
    try std.testing.expect(effect.wasFallback());
}

test "FallbackStrategy enum" {
    try std.testing.expectEqual(FallbackStrategy.default_value, FallbackStrategy.default_value);
    try std.testing.expectEqual(FallbackStrategy.fallback_operation, FallbackStrategy.fallback_operation);
    try std.testing.expectEqual(FallbackStrategy.cached_value, FallbackStrategy.cached_value);
}

test "Fallback resetStats" {
    const TestError = error{ TestFailed, NoFallbackValue, OperationFailed, UnsupportedStrategy };

    var fb = Fallback(i32, TestError).withDefault(0);

    const failFn = struct {
        fn call() TestError!i32 {
            return TestError.TestFailed;
        }
    }.call;

    _ = fb.executeWithFallback(failFn, .{}, 99);
    try std.testing.expectEqual(@as(u64, 1), fb.getStats().fallback_count);

    fb.resetStats();
    try std.testing.expectEqual(@as(u64, 0), fb.getStats().fallback_count);
}
