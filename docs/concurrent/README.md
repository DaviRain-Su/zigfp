# Concurrent 模块

并发工具，提供并行计算和性能测试能力。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| parallel.md | `seqMap`, `seqFilter`, `seqReduce` | 并行计算抽象 |
| benchmark.md | `Benchmark`, `BenchmarkResult` | 性能基准测试 |

## 导入方式

```zig
const concurrent = @import("zigfp").concurrent;

const seqMap = concurrent.seqMap;
const Benchmark = concurrent.Benchmark;
```

## 快速示例

### Parallel - 并行计算抽象

当前版本为顺序执行实现，保持与未来并行版本相同的 API 接口：

```zig
// 顺序映射（预留并行接口）
const doubled = try seqMap(i32, i32, allocator, slice, double);
defer allocator.free(doubled);

// 顺序过滤
const evens = try seqFilter(i32, allocator, slice, isEven);
defer allocator.free(evens);

// 顺序归约
const sum = seqReduce(i32, i32, slice, 0, add);
```

### Benchmark - 性能基准测试

```zig
var bench = Benchmark.init(allocator);

const result = try bench.runBenchmark("my_operation", 1000, struct {
    fn run() void {
        // 要测试的代码
        doSomething();
    }
}.run);

std.debug.print("Mean: {d:.2} ns\n", .{result.mean_duration});
std.debug.print("Std Dev: {d:.2} ns\n", .{result.std_deviation});
```

### 批处理操作

```zig
const config = BatchConfig{
    .batch_size = 100,
    .max_batches = 10,
};

const results = try batchMap(i32, i32, allocator, large_slice, transform, config);
defer allocator.free(results);
```

## 设计说明

> **注意**: Zig 的 async/await 功能目前正在重新设计中（0.11+ 已移除），
> 因此真正的并行实现标记为**未来实现**，待 Zig 官方稳定 async 支持后再行开发。

当前模块提供：
- 顺序执行的参考实现
- 与未来并行版本兼容的 API
- 批处理抽象
- 调度器接口定义（预留）
