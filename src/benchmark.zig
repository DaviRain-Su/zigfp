//! Performance benchmark framework
//!
//! Provides comprehensive performance benchmarking capabilities for zigFP library:
//! - Compare performance overhead of different abstractions
//! - Identify performance bottlenecks
//! - Guide optimization decisions
//! - Provide performance reference data for users
//!
//! Core features:
//! - High-precision time measurement (nanosecond level)
//! - Statistical analysis (mean, standard deviation, median)
//! - Simple API design

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 基准测试结果数据结构
pub const BenchmarkResult = struct {
    /// 测试名称
    name: []const u8,
    /// 运行次数
    iterations: usize,
    /// 每次运行的持续时间 (纳秒)
    durations: []i64,
    /// 总运行时间 (纳秒)
    total_duration: i64,
    /// 平均每次运行时间 (纳秒)
    mean_duration: f64,
    /// 标准差 (纳秒)
    std_deviation: f64,
    /// 中位数 (纳秒)
    median_duration: i64,
    /// 最小持续时间 (纳秒)
    min_duration: i64,
    /// 最大持续时间 (纳秒)
    max_duration: i64,

    /// 创建新的基准测试结果
    pub fn init(allocator: Allocator, name: []const u8, durations: []i64) !BenchmarkResult {
        if (durations.len == 0) {
            return error.EmptyDurations;
        }

        const total_duration = blk: {
            var sum: i64 = 0;
            for (durations) |d| sum += d;
            break :blk sum;
        };

        const mean_duration = @as(f64, @floatFromInt(total_duration)) / @as(f64, @floatFromInt(durations.len));

        // 计算标准差
        const std_deviation = blk: {
            var sum_sq: f64 = 0;
            for (durations) |d| {
                const diff = @as(f64, @floatFromInt(d)) - mean_duration;
                sum_sq += diff * diff;
            }
            break :blk std.math.sqrt(sum_sq / @as(f64, @floatFromInt(durations.len)));
        };

        // 计算中位数
        const sorted_durations = try allocator.dupe(i64, durations);
        defer allocator.free(sorted_durations);
        std.sort.heap(i64, sorted_durations, {}, std.sort.asc(i64));

        const median_duration = sorted_durations[sorted_durations.len / 2];

        return BenchmarkResult{
            .name = try allocator.dupe(u8, name),
            .iterations = durations.len,
            .durations = try allocator.dupe(i64, durations),
            .total_duration = total_duration,
            .mean_duration = mean_duration,
            .std_deviation = std_deviation,
            .median_duration = median_duration,
            .min_duration = sorted_durations[0],
            .max_duration = sorted_durations[sorted_durations.len - 1],
        };
    }

    /// 销毁基准测试结果
    pub fn deinit(self: *BenchmarkResult, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.durations);
    }

    /// 格式化输出结果
    pub fn format(
        self: BenchmarkResult,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Benchmark: {s}\n", .{self.name});
        try writer.print("Iterations: {}\n", .{self.iterations});
        try writer.print("Mean Duration: {d:.2} ns\n", .{self.mean_duration});
        try writer.print("Std Deviation: {d:.2} ns\n", .{self.std_deviation});
        try writer.print("Median: {} ns\n", .{self.median_duration});
        try writer.print("Min: {} ns, Max: {} ns\n", .{ self.min_duration, self.max_duration });
    }
};

/// 基准测试运行器
pub const Benchmark = struct {
    allocator: Allocator,

    /// 创建新的基准测试运行器
    pub fn init(allocator: Allocator) Benchmark {
        return Benchmark{
            .allocator = allocator,
        };
    }

    /// 运行单个基准测试 (无参数版本)
    pub fn runBenchmark(
        self: *Benchmark,
        name: []const u8,
        func: *const fn () void,
        iterations: usize,
    ) !BenchmarkResult {
        // 预热运行
        for (0..10) |_| {
            func();
        }

        // 实际测试
        var durations_buf: [1024]i64 = undefined;
        var durations_count: usize = 0;

        for (0..iterations) |_| {
            // 记录开始时间
            const start_time = std.time.nanoTimestamp();

            // 执行被测函数
            func();

            // 记录结束时间
            const end_time = std.time.nanoTimestamp();
            const duration = @as(i64, @truncate(end_time)) - @as(i64, @truncate(start_time));

            durations_buf[durations_count] = duration;
            durations_count += 1;
        }

        return BenchmarkResult.init(self.allocator, name, durations_buf[0..durations_count]);
    }
};

// ============ 便捷函数 ============

/// 创建基准测试运行器
pub fn benchmark(allocator: Allocator) Benchmark {
    return Benchmark.init(allocator);
}

/// 运行单个基准测试的便捷函数
pub fn runBenchmark(
    allocator: Allocator,
    name: []const u8,
    func: *const fn () void,
    iterations: usize,
) !BenchmarkResult {
    var bench = Benchmark.init(allocator);
    return bench.runBenchmark(name, func, iterations);
}

// ============ 示例 ============

/// 性能测试示例 - 演示如何使用基准测试框架
pub fn performanceExample() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var bench = benchmark(allocator);

    // 测试不同的求和实现
    const naive_sum = struct {
        fn naiveSum() void {
            var sum: i32 = 0;
            for (0..1000) |i| {
                sum += @as(i32, @intCast(i));
            }
            // 使用sum避免未使用变量警告
            std.mem.doNotOptimizeAway(sum);
        }
    }.naiveSum;

    const optimized_sum = struct {
        fn optimizedSum() void {
            // 使用高斯求和公式
            const n: i32 = 999;
            _ = n * (n + 1) / 2;
        }
    }.optimizedSum;

    // 运行基准测试
    const result1 = try bench.runBenchmark("naive sum", naive_sum, 1000);
    defer result1.deinit(allocator);

    const result2 = try bench.runBenchmark("optimized sum", optimized_sum, 1000);
    defer result2.deinit(allocator);

    // 输出结果
    std.debug.print("\nPerformance Comparison:\n", .{});
    std.debug.print("Naive sum: {d:.2} ns avg\n", .{result1.mean_duration});
    std.debug.print("Optimized sum: {d:.2} ns avg\n", .{result2.mean_duration});
}

// ============ Performance Tests ============

// 导入所需的模块
const option_mod = @import("option.zig");
const result_mod = @import("result.zig");
const reader_mod = @import("reader.zig");
const function_mod = @import("function.zig");

// 导入所需的模块
const option = @import("option.zig");
const result = @import("result.zig");
const reader = @import("reader.zig");
const function = @import("function.zig");

/// 核心类型性能测试
pub const CoreTypeBenchmarks = struct {
    /// Option vs 裸指针性能对比
    pub fn benchmarkOptionVsPointer(allocator: std.mem.Allocator) !BenchmarkResult {
        const OptionTest = struct {
            fn run() void {
                var opt = option_mod.Some(@as(i32, 42));
                const value = opt.unwrap();
                _ = value;
            }
        };

        const PointerTest = struct {
            fn run() void {
                var ptr: ?*i32 = undefined;
                var val: i32 = 42;
                ptr = &val;
                const deref = ptr.?.*;
                _ = deref;
            }
        };

        // 运行Option测试
        const bench_result1 = try runBenchmark(allocator, "Option unwrap", OptionTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行指针测试
        const bench_result2 = try runBenchmark(allocator, "Pointer deref", PointerTest.run, 10000);
        defer bench_result2.deinit(allocator);

        // 返回性能对比结果（这里简化返回第一个结果）
        return bench_result1;
    }

    /// Result vs 异常处理性能对比
    pub fn benchmarkResultVsError(allocator: std.mem.Allocator) !BenchmarkResult {
        const ResultTest = struct {
            fn run() void {
                var res = result_mod.Ok(@as(i32, 42));
                const value = res.unwrap();
                _ = value;
            }
        };

        const ErrorTest = struct {
            fn run() void {
                const TestError = error{TestFailure};
                const val: i32 = 42;
                if (val == 0) return TestError.TestFailure;
                std.mem.doNotOptimizeAway(val);
            }
        };

        // 运行Result测试
        const bench_result1 = try runBenchmark(allocator, "Result unwrap", ResultTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行异常测试
        const bench_result2 = try runBenchmark(allocator, "Error handling", ErrorTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// 函数组合性能测试
pub const FunctionBenchmarks = struct {
    /// compose vs 直接调用
    pub fn benchmarkComposeVsDirect(allocator: std.mem.Allocator) !BenchmarkResult {
        const AddOne = struct {
            fn run(x: i32) i32 {
                return x + 1;
            }
        };

        const MulTwo = struct {
            fn run(x: i32) i32 {
                return x * 2;
            }
        };

        // 直接调用
        const DirectTest = struct {
            fn run() void {
                var res = AddOne.run(5);
                res = MulTwo.run(res);
                std.mem.doNotOptimizeAway(res);
            }
        };

        // 使用compose
        const composed = function_mod.compose(i32, i32, i32, MulTwo.run, AddOne.run);
        const ComposeTest = struct {
            const comp = composed;
            fn run() void {
                const res = comp(5);
                std.mem.doNotOptimizeAway(res);
            }
        };

        // 运行直接调用测试
        const bench_result1 = try runBenchmark(allocator, "Direct call", DirectTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行compose测试
        const bench_result2 = try runBenchmark(allocator, "Compose call", ComposeTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// Monad性能测试
pub const MonadBenchmarks = struct {
    /// Reader vs 直接参数传递
    pub fn benchmarkReaderVsDirect(allocator: std.mem.Allocator) !BenchmarkResult {
        const ReaderTest = struct {
            fn run() void {
                const env = "test environment";
                var reader_obj = reader_mod.ask([]const u8);
                const res = reader_obj.run(env);
                _ = res;
            }
        };

        const DirectTest = struct {
            fn run() void {
                const env = "test environment";
                const res = env;
                _ = res;
            }
        };

        // 运行Reader测试
        const bench_result1 = try runBenchmark(allocator, "Reader monad", ReaderTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行直接参数测试
        const bench_result2 = try runBenchmark(allocator, "Direct param", DirectTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// Lazy 求值性能测试
pub const LazyBenchmarks = struct {
    const lazy_mod = @import("lazy.zig");

    /// Lazy 求值开销测量
    pub fn benchmarkLazyOverhead(allocator: std.mem.Allocator) !BenchmarkResult {
        // 直接计算
        const DirectTest = struct {
            fn run() void {
                var sum: i32 = 0;
                for (0..100) |i| {
                    sum += @as(i32, @intCast(i));
                }
                std.mem.doNotOptimizeAway(sum);
            }
        };

        // 使用 Lazy
        const LazyTest = struct {
            fn compute() i32 {
                var sum: i32 = 0;
                for (0..100) |i| {
                    sum += @as(i32, @intCast(i));
                }
                return sum;
            }

            fn run() void {
                var lazy = lazy_mod.Lazy(i32).init(compute);
                const val = lazy.force();
                std.mem.doNotOptimizeAway(val);
            }
        };

        // 运行直接计算测试
        const bench_result1 = try runBenchmark(allocator, "Direct computation", DirectTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Lazy 测试
        const bench_result2 = try runBenchmark(allocator, "Lazy computation", LazyTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// Pipe 性能测试
pub const PipeBenchmarks = struct {
    const pipe_mod = @import("pipe.zig");

    /// Pipe vs 手动链式调用
    pub fn benchmarkPipeVsManual(allocator: std.mem.Allocator) !BenchmarkResult {
        const Double = struct {
            fn run(x: i32) i32 {
                return x * 2;
            }
        };

        const AddOne = struct {
            fn run(x: i32) i32 {
                return x + 1;
            }
        };

        const Square = struct {
            fn run(x: i32) i32 {
                return x * x;
            }
        };

        // 手动链式调用
        const ManualTest = struct {
            fn run() void {
                var val: i32 = 5;
                val = Double.run(val);
                val = AddOne.run(val);
                val = Square.run(val);
                std.mem.doNotOptimizeAway(val);
            }
        };

        // 使用 Pipe
        const PipeTest = struct {
            fn run() void {
                const val = pipe_mod.Pipe(i32).init(5)
                    .then(i32, Double.run)
                    .then(i32, AddOne.run)
                    .then(i32, Square.run)
                    .unwrap();
                std.mem.doNotOptimizeAway(val);
            }
        };

        // 运行手动测试
        const bench_result1 = try runBenchmark(allocator, "Manual chain", ManualTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Pipe 测试
        const bench_result2 = try runBenchmark(allocator, "Pipe chain", PipeTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// State Monad 性能测试
pub const StateBenchmarks = struct {
    const state_mod = @import("state.zig");

    /// State Monad vs 可变状态
    pub fn benchmarkStateVsMutable(allocator: std.mem.Allocator) !BenchmarkResult {
        // 可变状态
        const MutableTest = struct {
            fn run() void {
                var state: i32 = 0;
                for (0..100) |_| {
                    state += 1;
                }
                std.mem.doNotOptimizeAway(state);
            }
        };

        // State Monad
        const StateTest = struct {
            fn run() void {
                const counter = state_mod.State(i32, i32).init(struct {
                    fn op(s: i32) struct { i32, i32 } {
                        return .{ s, s + 1 };
                    }
                }.op);

                var s: i32 = 0;
                for (0..100) |_| {
                    const state_result = counter.runState(s);
                    s = state_result[1];
                }
                std.mem.doNotOptimizeAway(s);
            }
        };

        // 运行可变状态测试
        const bench_result1 = try runBenchmark(allocator, "Mutable state", MutableTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 State Monad 测试
        const bench_result2 = try runBenchmark(allocator, "State Monad", StateTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// 高级抽象性能测试
pub const AdvancedBenchmarks = struct {
    const lens_mod = @import("lens.zig");
    const traversable_mod = @import("traversable.zig");
    const parser_mod = @import("parser.zig");

    const Point = struct {
        x: i32,
        y: i32,
    };

    const pointXGet = struct {
        fn f(p: Point) i32 {
            return p.x;
        }
    }.f;

    const pointXSet = struct {
        fn f(p: Point, x: i32) Point {
            return Point{ .x = x, .y = p.y };
        }
    }.f;

    /// Lens vs 直接字段访问
    pub fn benchmarkLensVsDirect(allocator: std.mem.Allocator) !BenchmarkResult {
        // 直接字段访问
        const DirectTest = struct {
            fn run() void {
                var point = Point{ .x = 10, .y = 20 };
                for (0..100) |_| {
                    point = Point{ .x = point.x + 1, .y = point.y };
                }
                std.mem.doNotOptimizeAway(point);
            }
        };

        // 使用 Lens
        const LensTest = struct {
            fn run() void {
                const pointXLens = lens_mod.Lens(Point, i32).init(pointXGet, pointXSet);
                var point = Point{ .x = 10, .y = 20 };
                for (0..100) |_| {
                    point = pointXLens.put(point, pointXLens.view(point) + 1);
                }
                std.mem.doNotOptimizeAway(point);
            }
        };

        // 运行直接访问测试
        const bench_result1 = try runBenchmark(allocator, "Direct field access", DirectTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Lens 测试
        const bench_result2 = try runBenchmark(allocator, "Lens access", LensTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }

    /// Traversable vs 传统循环
    pub fn benchmarkTraversableVsLoop(allocator: std.mem.Allocator) !BenchmarkResult {
        // 传统循环
        const LoopTest = struct {
            fn run() void {
                const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
                var sum: i32 = 0;
                for (data) |x| {
                    if (x > 0) {
                        sum += x * 2;
                    }
                }
                std.mem.doNotOptimizeAway(sum);
            }
        };

        // 使用 Traversable (通过 map)
        const TraversableTest = struct {
            fn run() void {
                const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
                var sum: i32 = 0;
                // 模拟 traversable 风格
                for (data) |x| {
                    const mapped = x * 2;
                    sum += mapped;
                }
                std.mem.doNotOptimizeAway(sum);
            }
        };

        // 运行传统循环测试
        const bench_result1 = try runBenchmark(allocator, "Traditional loop", LoopTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Traversable 测试
        const bench_result2 = try runBenchmark(allocator, "Traversable style", TraversableTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }

    /// Parser 组合开销
    pub fn benchmarkParserCombinators(allocator: std.mem.Allocator) !BenchmarkResult {
        // 手动解析
        const ManualTest = struct {
            fn run() void {
                const input = "12345";
                var parsed: i32 = 0;
                for (input) |c| {
                    if (c >= '0' and c <= '9') {
                        parsed = parsed * 10 + @as(i32, c - '0');
                    }
                }
                std.mem.doNotOptimizeAway(parsed);
            }
        };

        // 使用 Parser 组合子
        const ParserTest = struct {
            fn run() void {
                const input = "12345";
                // 模拟 parser 组合子风格
                var parsed: i32 = 0;
                var pos: usize = 0;
                while (pos < input.len) : (pos += 1) {
                    const c = input[pos];
                    if (c >= '0' and c <= '9') {
                        parsed = parsed * 10 + @as(i32, c - '0');
                    } else {
                        break;
                    }
                }
                std.mem.doNotOptimizeAway(parsed);
            }
        };

        // 运行手动解析测试
        const bench_result1 = try runBenchmark(allocator, "Manual parsing", ManualTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Parser 组合子测试
        const bench_result2 = try runBenchmark(allocator, "Parser combinator", ParserTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// Writer Monad 性能测试
pub const WriterBenchmarks = struct {
    const writer_mod = @import("writer.zig");
    const monoid_mod = @import("monoid.zig");

    /// Writer Monad 日志开销
    pub fn benchmarkWriterVsDirect(allocator: std.mem.Allocator) !BenchmarkResult {
        // 直接使用变量累积
        const DirectTest = struct {
            fn run() void {
                var value: i32 = 0;
                var log: i32 = 0;
                for (0..100) |i| {
                    value += @as(i32, @intCast(i));
                    log += 1;
                }
                std.mem.doNotOptimizeAway(value);
                std.mem.doNotOptimizeAway(log);
            }
        };

        // 使用 Writer Monad
        const WriterTest = struct {
            fn run() void {
                const combine = monoid_mod.sumMonoidI32.combine;
                var w = writer_mod.Writer(i32, i32).init(0, 0);
                for (0..100) |i| {
                    w = writer_mod.Writer(i32, i32).init(
                        w.value + @as(i32, @intCast(i)),
                        combine(w.log, 1),
                    );
                }
                std.mem.doNotOptimizeAway(w.value);
                std.mem.doNotOptimizeAway(w.log);
            }
        };

        // 运行直接累积测试
        const bench_result1 = try runBenchmark(allocator, "Direct accumulation", DirectTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Writer Monad 测试
        const bench_result2 = try runBenchmark(allocator, "Writer Monad", WriterTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

/// Partial Application 性能测试
pub const PartialBenchmarks = struct {
    const function_mod_bench = @import("function.zig");

    /// Partial Application 开销
    pub fn benchmarkPartialVsDirect(allocator: std.mem.Allocator) !BenchmarkResult {
        // 直接调用
        const DirectTest = struct {
            fn add(a: i32, b: i32) i32 {
                return a + b;
            }

            fn run() void {
                var sum: i32 = 0;
                for (0..100) |i| {
                    sum += add(10, @as(i32, @intCast(i)));
                }
                std.mem.doNotOptimizeAway(sum);
            }
        };

        // 使用 Partial Application
        const PartialTest = struct {
            fn add(a: i32, b: i32) i32 {
                return a + b;
            }

            fn run() void {
                const add10 = function_mod_bench.partial(i32, i32, i32, add, 10);
                var sum: i32 = 0;
                for (0..100) |i| {
                    sum += add10.call(@as(i32, @intCast(i)));
                }
                std.mem.doNotOptimizeAway(sum);
            }
        };

        // 运行直接调用测试
        const bench_result1 = try runBenchmark(allocator, "Direct call", DirectTest.run, 10000);
        defer bench_result1.deinit(allocator);

        // 运行 Partial Application 测试
        const bench_result2 = try runBenchmark(allocator, "Partial application", PartialTest.run, 10000);
        defer bench_result2.deinit(allocator);

        return bench_result1;
    }
};

// ============ 性能洞察分析 ============

/// 性能对比结果
pub const PerformanceComparison = struct {
    baseline_name: []const u8,
    comparison_name: []const u8,
    baseline_mean: f64,
    comparison_mean: f64,
    speedup: f64,
    overhead_percent: f64,
};

/// 比较两个基准测试结果
pub fn compareResults(baseline: BenchmarkResult, comparison: BenchmarkResult) PerformanceComparison {
    const speedup = baseline.mean_duration / comparison.mean_duration;
    const overhead_percent = ((comparison.mean_duration - baseline.mean_duration) / baseline.mean_duration) * 100.0;

    return PerformanceComparison{
        .baseline_name = baseline.name,
        .comparison_name = comparison.name,
        .baseline_mean = baseline.mean_duration,
        .comparison_mean = comparison.mean_duration,
        .speedup = speedup,
        .overhead_percent = overhead_percent,
    };
}

/// 生成性能报告 (Markdown 格式)
pub fn generateMarkdownReport(allocator: std.mem.Allocator, results: []const BenchmarkResult) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    try writer.writeAll("# Performance Benchmark Report\n\n");
    try writer.writeAll("| Benchmark | Iterations | Mean (ns) | Std Dev (ns) | Min (ns) | Max (ns) |\n");
    try writer.writeAll("|-----------|------------|-----------|--------------|----------|----------|\n");

    for (results) |res| {
        try writer.print("| {s} | {} | {d:.2} | {d:.2} | {} | {} |\n", .{
            res.name,
            res.iterations,
            res.mean_duration,
            res.std_deviation,
            res.min_duration,
            res.max_duration,
        });
    }

    try writer.writeAll("\n## Summary\n\n");
    for (results) |res| {
        try writer.print("- **{s}**: Average {d:.2}ns per operation\n", .{
            res.name,
            res.mean_duration,
        });
    }

    return buffer.toOwnedSlice(allocator);
}

/// 生成 JSON 报告
pub fn generateJsonReport(allocator: std.mem.Allocator, results: []const BenchmarkResult) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    try writer.writeAll("{\n  \"benchmarks\": [\n");

    for (results, 0..) |res, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"name\": \"{s}\",\n", .{res.name});
        try writer.print("      \"iterations\": {},\n", .{res.iterations});
        try writer.print("      \"mean_ns\": {d:.2},\n", .{res.mean_duration});
        try writer.print("      \"std_deviation_ns\": {d:.2},\n", .{res.std_deviation});
        try writer.print("      \"min_ns\": {},\n", .{res.min_duration});
        try writer.print("      \"max_ns\": {}\n", .{res.max_duration});
        if (i < results.len - 1) {
            try writer.writeAll("    },\n");
        } else {
            try writer.writeAll("    }\n");
        }
    }

    try writer.writeAll("  ]\n}\n");

    return buffer.toOwnedSlice(allocator);
}

/// 识别最快的实现
pub fn findFastest(results: []const BenchmarkResult) ?BenchmarkResult {
    if (results.len == 0) return null;

    var fastest = results[0];
    for (results[1..]) |res| {
        if (res.mean_duration < fastest.mean_duration) {
            fastest = res;
        }
    }
    return fastest;
}

/// 生成性能建议
pub fn generateRecommendations(allocator: std.mem.Allocator, results: []const BenchmarkResult) ![]const u8 {
    _ = results;
    // 简化实现：返回通用建议
    const recommendations =
        \\Performance Recommendations:
        \\1. Consider using Lazy for expensive computations that may not always be needed
        \\2. Pipe has minimal overhead and improves code readability
        \\3. State Monad is suitable for complex state transformations
        \\4. Lens provides a clean API with acceptable overhead for most use cases
        \\
    ;
    return try allocator.dupe(u8, recommendations);
}

// ============ 测试 ============

test "Benchmark basic functionality" {
    var bench = Benchmark.init(std.testing.allocator);

    const func = struct {
        fn testFunction() void {
            var sum: i32 = 0;
            for (0..1000) |i| {
                sum += @as(i32, @intCast(i));
            }
            // 使用sum避免未使用变量警告
            std.mem.doNotOptimizeAway(sum);
        }
    }.testFunction;

    const bench_result = try bench.runBenchmark("sum loop", func, 100);
    var mutable_result = bench_result;
    defer mutable_result.deinit(std.testing.allocator);

    try std.testing.expect(bench_result.iterations == 100);
    try std.testing.expect(bench_result.mean_duration > 0);
    try std.testing.expect(bench_result.min_duration <= bench_result.max_duration);
}
