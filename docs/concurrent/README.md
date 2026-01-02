# Concurrent 模块

并发工具，提供真正的并行计算和性能测试能力。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| parallel.zig | `RealThreadPool`, `realParMap`, `realParFilter`, `realParReduce` | 真正的并行计算 |
| parallel.zig | `seqMap`, `seqFilter`, `seqReduce` | 顺序操作（对比/回退） |
| benchmark.zig | `Benchmark`, `BenchmarkResult` | 性能基准测试 |

## 导入方式

```zig
const fp = @import("zigfp");

// 真正的并行操作
const RealThreadPool = fp.RealThreadPool;
const realParMap = fp.realParMap;
const realParFilter = fp.realParFilter;
const realParReduce = fp.realParReduce;

// 顺序操作
const seqMap = fp.seqMap;
const seqFilter = fp.seqFilter;
const seqReduce = fp.seqReduce;

// 基准测试
const Benchmark = fp.concurrent.Benchmark;
```

## 快速示例

### RealThreadPool - 真正的线程池 (v1.5.0+)

基于 Zig 原生线程的真正多线程并行执行：

```zig
const std = @import("std");
const fp = @import("zigfp");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 创建线程池（4 个工作线程）
    const pool = try fp.RealThreadPool.init(allocator, .{
        .num_threads = 4,
        .max_queue_size = 1024,
    });
    defer pool.deinit();

    std.debug.print("线程数: {}\n", .{pool.getThreadCount()});

    // 准备数据
    var data: [1000]i32 = undefined;
    for (&data, 0..) |*item, i| {
        item.* = @intCast(i + 1);
    }

    // 并行 map: 每个元素平方
    const squared = try fp.realParMap(i32, i32, allocator, &data, square, pool);
    defer allocator.free(squared);

    // 并行 filter: 过滤偶数
    const evens = try fp.realParFilter(i32, allocator, &data, isEven, pool);
    defer allocator.free(evens);

    // 并行 reduce: 求和
    const sum = try fp.realParReduce(i32, allocator, &data, 0, add, pool);
    std.debug.print("Sum: {}\n", .{sum}); // 500500
}

fn square(x: i32) i32 { return x * x; }
fn isEven(x: i32) bool { return @rem(x, 2) == 0; }
fn add(a: i32, b: i32) i32 { return a + b; }
```

### RealThreadPoolConfig - 线程池配置

```zig
const config = fp.RealThreadPoolConfig{
    // 工作线程数量（0 表示使用 CPU 核心数）
    .num_threads = 4,
    // 任务队列最大容量
    .max_queue_size = 1024,
};
```

### 顺序操作 - 对比和回退

顺序版本用于对比性能或作为回退方案：

```zig
// 顺序映射
const doubled = try fp.seqMap(i32, i32, allocator, slice, double);
defer allocator.free(doubled);

// 顺序过滤
const evens = try fp.seqFilter(i32, allocator, slice, isEven);
defer allocator.free(evens);

// 顺序归约
const sum = fp.seqReduce(i32, slice, 0, add);

// 顺序 fold (带不同类型累加器)
const count = fp.seqFold(i32, usize, slice, 0, countEven);

// 顺序 zip
const zipped = try fp.seqZip(i32, i32, i32, allocator, a, b, add);
```

### Par Monad - 并行计算抽象

提供函数式的并行计算接口：

```zig
// 创建并行计算
const p1 = fp.Par(i32).pure(10);

// 映射
const p2 = p1.map(i32, double);

// 运行获取结果
const result = p2.run(); // 20

// 组合两个并行计算
const pa = fp.Par(i32).pure(100);
const pb = fp.Par(i32).pure(200);
const pc = fp.parZip(i32, i32, i32, pa, pb, add);
const combined = pc.run(); // 300

// 并行执行多个计算
const pars = [_]fp.Par(i32){ fp.Par(i32).pure(1), fp.Par(i32).pure(2) };
const results = try fp.parSequence(i32, allocator, &pars);
defer allocator.free(results);
```

### 批处理操作

将大数据分批处理：

```zig
const config = fp.BatchConfig{
    .batch_size = 64,    // 每批处理 64 个元素
    .parallel = false,   // 当前批次顺序执行
};

const results = try fp.batchMap(i32, i32, allocator, large_slice, transform, config);
defer allocator.free(results);

// 批量归约
const sum = fp.batchReduce(i32, slice, 0, add, config);
```

### Benchmark - 性能基准测试

```zig
var bench = fp.concurrent.Benchmark.init(allocator);

const result = try bench.runBenchmark("my_operation", 1000, struct {
    fn run() void {
        // 要测试的代码
        doSomething();
    }
}.run);

std.debug.print("Mean: {d:.2} ns\n", .{result.mean_duration});
std.debug.print("Std Dev: {d:.2} ns\n", .{result.std_deviation});
std.debug.print("Min: {} ns\n", .{result.min_duration});
std.debug.print("Max: {} ns\n", .{result.max_duration});
```

## API 参考

### RealThreadPool

| 方法 | 签名 | 说明 |
|------|------|------|
| `init` | `(allocator, config) !*RealThreadPool` | 创建线程池 |
| `deinit` | `() void` | 销毁线程池 |
| `submit` | `(func, arg) !void` | 提交任务 |
| `waitAll` | `() void` | 等待所有任务完成 |
| `getThreadCount` | `() usize` | 获取线程数 |

### 并行操作函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `realParMap` | `(A, B, allocator, slice, f, pool) ![]B` | 并行映射 |
| `realParFilter` | `(A, allocator, slice, pred, pool) ![]A` | 并行过滤 |
| `realParReduce` | `(A, allocator, slice, init, f, pool) !A` | 并行归约 |

### 顺序操作函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `seqMap` | `(A, B, allocator, slice, f) ![]B` | 顺序映射 |
| `seqFilter` | `(A, allocator, slice, pred) ![]A` | 顺序过滤 |
| `seqReduce` | `(A, slice, init, f) A` | 顺序归约 |
| `seqFold` | `(A, B, slice, init, f) B` | 顺序折叠 |
| `seqZip` | `(A, B, C, allocator, a, b, f) ![]C` | 顺序合并 |

## 性能建议

1. **选择合适的线程数**: 通常使用 CPU 核心数，I/O 密集型任务可以更多
2. **数据大小**: 小数据集可能顺序执行更快（避免线程开销）
3. **任务粒度**: 每个任务不要太小，否则线程开销会抵消并行收益
4. **内存分配**: 预分配结果缓冲区，减少运行时分配

```zig
// 推荐：大数据集使用并行
if (data.len > 1000) {
    return try realParMap(i32, i32, allocator, data, f, pool);
} else {
    return try seqMap(i32, i32, allocator, data, f);
}
```

## 版本历史

- **v1.5.0**: 添加 `RealThreadPool` 和真正的并行操作
- **v0.5.0**: 初始顺序实现和 API 设计
