//! 弹性模式模块
//!
//! 提供系统弹性和故障处理模式：
//! - Retry - 重试策略
//! - CircuitBreaker - 断路器
//! - Bulkhead - 隔板模式
//! - Timeout - 超时控制
//! - Fallback - 降级策略

const std = @import("std");

pub const retry = @import("retry.zig");
pub const circuit_breaker = @import("circuit_breaker.zig");
pub const bulkhead = @import("bulkhead.zig");
pub const timeout = @import("timeout.zig");
pub const fallback = @import("fallback.zig");

// ============ Retry ============
pub const RetryStrategy = retry.RetryStrategy;
pub const RetryConfig = retry.RetryConfig;
pub const RetryResult = retry.RetryResult;
pub const RetryPolicy = retry.RetryPolicy;

// ============ CircuitBreaker ============
pub const CircuitState = circuit_breaker.CircuitState;
pub const CircuitBreakerError = circuit_breaker.CircuitBreakerError;
pub const CircuitBreakerConfig = circuit_breaker.CircuitBreakerConfig;
pub const CircuitBreaker = circuit_breaker.CircuitBreaker;

// ============ Bulkhead ============
pub const BulkheadError = bulkhead.BulkheadError;
pub const RejectionPolicy = bulkhead.RejectionPolicy;
pub const BulkheadConfig = bulkhead.BulkheadConfig;
pub const BulkheadStats = bulkhead.BulkheadStats;
pub const Bulkhead = bulkhead.Bulkhead;

// ============ Timeout ============
pub const TimeoutError = timeout.TimeoutError;
pub const TimeoutConfig = timeout.TimeoutConfig;
pub const TimeoutStats = timeout.TimeoutStats;
pub const Timeout = timeout.Timeout;
pub const Deadline = timeout.Deadline;

// ============ Fallback ============
pub const FallbackStrategy = fallback.FallbackStrategy;
pub const FallbackConfig = fallback.FallbackConfig;
pub const FallbackStats = fallback.FallbackStats;

test {
    std.testing.refAllDecls(@This());
}
