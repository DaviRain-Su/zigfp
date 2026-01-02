//! zigFP 弹性模式示例
//!
//! 本示例展示 zigFP 库的弹性模式功能：
//! - RetryPolicy: 重试策略
//! - CircuitBreaker: 断路器
//! - Bulkhead: 隔板模式
//! - Timeout: 超时控制
//! - Fallback: 降级策略

const std = @import("std");
const fp = @import("zigfp");

pub fn main() !void {
    std.debug.print("=== zigFP 弹性模式示例 ===\n\n", .{});

    // ============ RetryPolicy 示例 ============
    std.debug.print("--- RetryPolicy 重试策略 ---\n", .{});

    // 1. 固定间隔重试
    const fixed_policy = fp.RetryPolicy.fixedDelay(100, 3);
    std.debug.print("固定间隔重试策略:\n", .{});
    std.debug.print("  - 最大重试次数: {}\n", .{fixed_policy.config.max_retries});
    std.debug.print("  - 每次延迟: {}ms\n\n", .{fixed_policy.config.initial_delay_ms});

    // 2. 指数退避重试
    const exp_policy = fp.RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 100,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .max_retries = 5,
    });
    std.debug.print("指数退避重试策略:\n", .{});
    std.debug.print("  - 初始延迟: {}ms\n", .{exp_policy.config.initial_delay_ms});
    std.debug.print("  - 最大延迟: {}ms\n", .{exp_policy.config.max_delay_ms});
    std.debug.print("  - 倍数: {d:.1}\n", .{exp_policy.config.multiplier});
    std.debug.print("  计算延迟序列:\n", .{});
    for (1..6) |i| {
        std.debug.print("    第 {} 次重试: {}ms\n", .{ i, exp_policy.calculateDelay(@intCast(i)) });
    }
    std.debug.print("\n", .{});

    // 3. 线性退避重试
    const linear_policy = fp.RetryPolicy.linearBackoff(.{
        .initial_delay_ms = 100,
        .linear_step_ms = 50,
        .max_delay_ms = 500,
        .max_retries = 10,
    });
    std.debug.print("线性退避重试策略:\n", .{});
    std.debug.print("  - 初始延迟: {}ms, 步长: {}ms\n", .{ linear_policy.config.initial_delay_ms, linear_policy.config.linear_step_ms });
    std.debug.print("  计算延迟序列: ", .{});
    for (1..6) |i| {
        std.debug.print("{}ms ", .{linear_policy.calculateDelay(@intCast(i))});
    }
    std.debug.print("...\n\n", .{});

    // 4. 使用构建器创建策略
    var builder = fp.retryPolicy();
    const custom_policy = builder
        .withMaxRetries(5)
        .withInitialDelay(200)
        .withMaxDelay(10000)
        .withMultiplier(3.0)
        .build();
    std.debug.print("构建器创建的策略:\n", .{});
    std.debug.print("  - 最大重试: {}, 初始延迟: {}ms, 倍数: {d:.1}\n\n", .{
        custom_policy.config.max_retries,
        custom_policy.config.initial_delay_ms,
        custom_policy.config.multiplier,
    });

    // ============ CircuitBreaker 示例 ============
    std.debug.print("--- CircuitBreaker 断路器 ---\n", .{});

    var breaker = fp.CircuitBreaker.init(.{
        .failure_threshold = 3, // 3 次失败后熔断
        .success_threshold = 2, // 半开状态下 2 次成功后恢复
        .timeout_ms = 5000, // 熔断 5 秒后尝试恢复
    });

    std.debug.print("断路器配置:\n", .{});
    std.debug.print("  - 失败阈值: {}\n", .{breaker.config.failure_threshold});
    std.debug.print("  - 成功阈值: {}\n", .{breaker.config.success_threshold});
    std.debug.print("  - 超时时间: {}ms\n\n", .{breaker.config.timeout_ms});

    // 模拟状态转换
    std.debug.print("模拟断路器状态转换:\n", .{});
    std.debug.print("  初始状态: {s}\n", .{breaker.getState().toString()});

    breaker.recordFailure();
    std.debug.print("  记录失败 #1, 状态: {s}\n", .{breaker.getState().toString()});

    breaker.recordFailure();
    std.debug.print("  记录失败 #2, 状态: {s}\n", .{breaker.getState().toString()});

    breaker.recordFailure();
    std.debug.print("  记录失败 #3, 状态: {s} (熔断!)\n", .{breaker.getState().toString()});

    std.debug.print("  allowRequest(): {}\n", .{breaker.allowRequest()});

    // 重置断路器
    breaker.reset();
    std.debug.print("  重置后状态: {s}\n\n", .{breaker.getState().toString()});

    // 使用构建器
    var cb_builder = fp.circuitBreaker();
    const custom_breaker = cb_builder
        .withFailureThreshold(10)
        .withSuccessThreshold(5)
        .withTimeout(60000)
        .build();
    std.debug.print("构建器创建的断路器:\n", .{});
    std.debug.print("  - 失败阈值: {}, 成功阈值: {}, 超时: {}ms\n\n", .{
        custom_breaker.config.failure_threshold,
        custom_breaker.config.success_threshold,
        custom_breaker.config.timeout_ms,
    });

    // ============ Bulkhead 示例 ============
    std.debug.print("--- Bulkhead 隔板模式 ---\n", .{});

    var bulkhead = fp.Bulkhead.init(.{
        .max_concurrent = 10, // 最大并发数
        .max_waiting = 5, // 最大等待数
        .max_wait_ms = 1000, // 最大等待时间
        .rejection_policy = .fail_fast, // 拒绝策略
        .name = "api_bulkhead",
    });

    std.debug.print("隔板配置:\n", .{});
    std.debug.print("  - 最大并发: {}\n", .{bulkhead.config.max_concurrent});
    std.debug.print("  - 最大等待: {}\n", .{bulkhead.config.max_waiting});
    std.debug.print("  - 等待超时: {}ms\n", .{bulkhead.config.max_wait_ms});
    std.debug.print("  - 拒绝策略: fail_fast\n\n", .{});

    // 模拟获取和释放槽位
    std.debug.print("模拟资源获取:\n", .{});
    const acquired1 = bulkhead.tryAcquire();
    std.debug.print("  获取槽位 #1: {}, 当前并发: {}\n", .{ acquired1, bulkhead.getStats().current_concurrent });

    const acquired2 = bulkhead.tryAcquire();
    std.debug.print("  获取槽位 #2: {}, 当前并发: {}\n", .{ acquired2, bulkhead.getStats().current_concurrent });

    bulkhead.release();
    std.debug.print("  释放一个槽位, 当前并发: {}\n\n", .{bulkhead.getStats().current_concurrent});

    // ============ Timeout 示例 ============
    std.debug.print("--- Timeout 超时控制 ---\n", .{});

    var timeout = fp.Timeout.init(.{
        .timeout_ms = 5000,
        .name = "api_timeout",
    });

    std.debug.print("超时配置:\n", .{});
    std.debug.print("  - 超时时间: {}ms\n", .{timeout.config.timeout_ms});

    // 便捷创建方式
    const timeout_ms = fp.Timeout.ms(1000);
    const timeout_sec = fp.Timeout.seconds(30);
    std.debug.print("  - Timeout.ms(1000): {}ms\n", .{timeout_ms.config.timeout_ms});
    std.debug.print("  - Timeout.seconds(30): {}ms\n\n", .{timeout_sec.config.timeout_ms});

    // 检查预估超时
    std.debug.print("预估超时检查:\n", .{});
    std.debug.print("  估计 3000ms 操作会超时? {}\n", .{timeout.willTimeout(3000)});
    std.debug.print("  估计 6000ms 操作会超时? {}\n\n", .{timeout.willTimeout(6000)});

    // ============ Fallback 示例 ============
    std.debug.print("--- Fallback 降级策略 ---\n", .{});

    const FallbackError = error{ OperationFailed, NoFallbackValue, UnsupportedStrategy };
    var fallback = fp.Fallback(i32, FallbackError).withDefault(42);

    std.debug.print("降级配置:\n", .{});
    std.debug.print("  - 策略: default_value\n", .{});
    std.debug.print("  - 默认值: 42\n\n", .{});

    // 模拟成功操作
    const success_result = fallback.executeWithFallback(successOperation, .{}, 0);
    std.debug.print("成功操作结果: {}\n", .{success_result});

    // 模拟失败操作使用降级
    const fallback_result = fallback.executeWithFallback(failOperation, .{}, 999);
    std.debug.print("失败操作降级结果: {}\n\n", .{fallback_result});

    // 统计信息
    const stats = fallback.getStats();
    std.debug.print("降级统计:\n", .{});
    std.debug.print("  - 总操作数: {}\n", .{stats.total_operations});
    std.debug.print("  - 主操作成功: {}\n", .{stats.primary_successes});
    std.debug.print("  - 降级次数: {}\n", .{stats.fallback_count});
    std.debug.print("  - 降级率: {d:.1}%\n\n", .{stats.getFallbackRate() * 100});

    // ============ 组合使用示例 ============
    std.debug.print("--- 组合使用模式 ---\n", .{});
    std.debug.print("典型的弹性模式组合:\n", .{});
    std.debug.print("  1. Timeout: 限制单次请求时间\n", .{});
    std.debug.print("  2. Retry: 临时故障时重试\n", .{});
    std.debug.print("  3. CircuitBreaker: 防止级联故障\n", .{});
    std.debug.print("  4. Bulkhead: 限制并发保护资源\n", .{});
    std.debug.print("  5. Fallback: 最终降级兜底\n\n", .{});

    std.debug.print("推荐的调用顺序:\n", .{});
    std.debug.print("  request\n", .{});
    std.debug.print("    -> Bulkhead (资源隔离)\n", .{});
    std.debug.print("      -> CircuitBreaker (熔断检查)\n", .{});
    std.debug.print("        -> Retry (重试逻辑)\n", .{});
    std.debug.print("          -> Timeout (超时控制)\n", .{});
    std.debug.print("            -> 实际操作\n", .{});
    std.debug.print("          <- Fallback (降级处理)\n\n", .{});

    std.debug.print("=== 示例完成 ===\n", .{});
}

// ============ 辅助函数 ============

fn successOperation() error{OperationFailed}!i32 {
    return 100;
}

fn failOperation() error{OperationFailed}!i32 {
    return error.OperationFailed;
}

// ============ 测试 ============

test "retry policy calculations" {
    const policy = fp.RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 100,
        .max_delay_ms = 10000,
        .multiplier = 2.0,
        .max_retries = 5,
    });

    try std.testing.expectEqual(@as(u64, 100), policy.calculateDelay(1));
    try std.testing.expectEqual(@as(u64, 200), policy.calculateDelay(2));
    try std.testing.expectEqual(@as(u64, 400), policy.calculateDelay(3));
}

test "circuit breaker state transitions" {
    var breaker = fp.CircuitBreaker.init(.{
        .failure_threshold = 2,
    });

    try std.testing.expectEqual(fp.CircuitState.closed, breaker.getState());

    breaker.recordFailure();
    try std.testing.expectEqual(fp.CircuitState.closed, breaker.getState());

    breaker.recordFailure();
    try std.testing.expectEqual(fp.CircuitState.open, breaker.getState());
}

test "bulkhead acquire and release" {
    var bulkhead = fp.Bulkhead.init(.{
        .max_concurrent = 2,
    });

    try std.testing.expect(bulkhead.tryAcquire());
    try std.testing.expect(bulkhead.tryAcquire());
    try std.testing.expect(!bulkhead.tryAcquire()); // 已满

    bulkhead.release();
    try std.testing.expect(bulkhead.tryAcquire()); // 释放后可以获取
}

test "timeout configuration" {
    const t1 = fp.Timeout.ms(1000);
    try std.testing.expectEqual(@as(u64, 1000), t1.config.timeout_ms);

    const t2 = fp.Timeout.seconds(5);
    try std.testing.expectEqual(@as(u64, 5000), t2.config.timeout_ms);
}

test "fallback with default value" {
    const FallbackError = error{ OperationFailed, NoFallbackValue, UnsupportedStrategy };
    var fallback = fp.Fallback(i32, FallbackError).withDefault(42);

    const result = fallback.executeWithFallback(failOperation, .{}, 999);
    try std.testing.expectEqual(@as(i32, 999), result);
}
