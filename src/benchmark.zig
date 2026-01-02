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
            var result: i32 = 0;
            for (0..1000) |i| {
                result += @as(i32, @intCast(i));
            }
            // 避免未使用变量警告
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
    std.debug.print("Speedup: {d:.2}x\n", .{result1.mean_duration / result2.mean_duration});
}

// ============ 测试 ============

test "Benchmark basic functionality" {
    var bench = Benchmark.init(std.testing.allocator);

    const func = struct {
        fn testFunction() void {
            var result: i32 = 0;
            for (0..100) |i| {
                result += @as(i32, @intCast(i));
            }
            // 避免未使用变量警告
        }
    }.testFunction;

    const result = try bench.runBenchmark("sum loop", func, 100);
    var mutable_result = result;
    defer mutable_result.deinit(std.testing.allocator);

    try std.testing.expect(result.iterations == 100);
    try std.testing.expect(result.mean_duration > 0);
    try std.testing.expect(result.min_duration <= result.max_duration);
}
