# Resilience 模块

弹性模式，提供系统容错和故障恢复能力。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| retry.md | `RetryPolicy` | 重试策略 |
| circuit_breaker.md | `CircuitBreaker` | 断路器 |
| bulkhead.md | `Bulkhead` | 隔板模式 |
| timeout.md | `Timeout` | 超时控制 |
| fallback.md | `Fallback` | 降级策略 |

## 导入方式

```zig
const resilience = @import("zigfp").resilience;

const RetryPolicy = resilience.RetryPolicy;
const CircuitBreaker = resilience.CircuitBreaker;
const Bulkhead = resilience.Bulkhead;
```

## 快速示例

### Retry - 重试策略

```zig
const policy = RetryPolicy.exponentialBackoff(.{
    .initial_delay_ms = 100,
    .max_delay_ms = 5000,
    .max_retries = 5,
});

const result = try policy.execute(fetchData, .{url});
```

### CircuitBreaker - 断路器

```zig
var breaker = CircuitBreaker.init(.{
    .failure_threshold = 5,
    .success_threshold = 3,
    .timeout_ms = 30000,
});

const result = breaker.execute(fetchData, .{url}) catch |err| switch (err) {
    error.CircuitOpen => handleFallback(),
    else => return err,
};
```

### Bulkhead - 隔板模式

```zig
var bulkhead = Bulkhead.init(.{
    .max_concurrent = 10,
    .max_wait_ms = 1000,
});

const result = try bulkhead.execute(processRequest, .{request});
```

### Timeout - 超时控制

```zig
const result = try withTimeout(1000, fetchData, .{url});
```

### Fallback - 降级策略

```zig
// 使用默认值降级
const result = withFallbackValue(fetchData, .{url}, defaultValue);

// 使用备用操作降级
const result = withFallbackFn(fetchFromPrimary, .{}, fetchFromBackup, .{});
```

## 组合使用

弹性模式可以组合使用：

```zig
// 重试 + 断路器 + 超时
const result = try breaker.execute(struct {
    fn call() !Data {
        return policy.execute(struct {
            fn inner() !Data {
                return withTimeout(1000, fetchData, .{url});
            }
        }.inner, .{});
    }
}.call, .{});
```
