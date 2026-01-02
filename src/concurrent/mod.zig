//! 并发模块
//!
//! 提供并发和性能相关功能：
//! - Parallel - 并行计算抽象
//! - Benchmark - 性能基准测试

const std = @import("std");

pub const parallel = @import("parallel.zig");
pub const benchmark = @import("benchmark.zig");

// ============ Parallel - Sequential ============
pub const seqMap = parallel.seqMap;
pub const seqFilter = parallel.seqFilter;
pub const seqReduce = parallel.seqReduce;
pub const seqFold = parallel.seqFold;
pub const seqFlatMap = parallel.seqFlatMap;
pub const seqZip = parallel.seqZip;

// ============ Parallel - Batch ============
pub const BatchConfig = parallel.BatchConfig;
pub const batchMap = parallel.batchMap;
pub const batchReduce = parallel.batchReduce;

// ============ Parallel - Par Monad ============
pub const Par = parallel.Par;
pub const parZip = parallel.parZip;
pub const parSequence = parallel.parSequence;
pub const parTraverse = parallel.parTraverse;
pub const parMap = parallel.parMap;
pub const parFilter = parallel.parFilter;

// ============ Parallel - Real Thread Pool ============
pub const RealThreadPoolConfig = parallel.RealThreadPoolConfig;
pub const RealThreadPool = parallel.RealThreadPool;
pub const realParMap = parallel.realParMap;
pub const realParFilter = parallel.realParFilter;
pub const realParReduce = parallel.realParReduce;

// ============ Parallel - Scheduler ============
pub const TaskStatus = parallel.TaskStatus;
pub const TaskPriority = parallel.TaskPriority;
pub const Task = parallel.Task;
pub const SchedulerConfig = parallel.SchedulerConfig;
pub const Scheduler = parallel.Scheduler;
pub const FixedThreadPool = parallel.FixedThreadPool;
pub const WorkStealingScheduler = parallel.WorkStealingScheduler;
pub const TaskQueue = parallel.TaskQueue;
pub const LoadBalanceStrategy = parallel.LoadBalanceStrategy;
pub const LoadBalancer = parallel.LoadBalancer;
pub const SplitStrategy = parallel.SplitStrategy;
pub const computeSplits = parallel.computeSplits;

// ============ Benchmark ============
pub const BenchmarkResult = benchmark.BenchmarkResult;
pub const Benchmark = benchmark.Benchmark;

test {
    std.testing.refAllDecls(@This());
}
