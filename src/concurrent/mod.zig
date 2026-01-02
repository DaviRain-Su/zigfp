//! 并发模块
//!
//! 提供并发和性能相关功能：
//! - Parallel - 并行计算抽象
//! - Benchmark - 性能基准测试

const std = @import("std");

pub const parallel = @import("parallel.zig");
pub const benchmark = @import("benchmark.zig");

// ============ Parallel ============
pub const seqMap = parallel.seqMap;
pub const seqFilter = parallel.seqFilter;
pub const seqReduce = parallel.seqReduce;

// ============ Benchmark ============
pub const BenchmarkResult = benchmark.BenchmarkResult;
pub const Benchmark = benchmark.Benchmark;

test {
    std.testing.refAllDecls(@This());
}
