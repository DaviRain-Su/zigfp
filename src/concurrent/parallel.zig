//! 并行计算抽象
//!
//! 提供函数式的并行计算抽象，支持真正的多线程并行执行。
//!
//! 功能包括:
//! - 顺序/并行 map、filter、reduce
//! - 真正的线程池实现 (RealThreadPool)
//! - 批处理操作
//! - 工作分割策略
//! - 结果聚合
//!
//! ## 使用示例
//!
//! ```zig
//! const pool = try RealThreadPool.init(allocator, .{ .num_threads = 4 });
//! defer pool.deinit();
//!
//! const results = try realParMap(i32, i32, allocator, &data, square, &pool);
//! defer allocator.free(results);
//! ```

const std = @import("std");

// ============ 基础顺序操作 ============

/// 顺序映射数组（为未来并行实现预留接口）
pub fn seqMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
) ![]B {
    const mapped = try allocator.alloc(B, slice.len);
    for (slice, 0..) |item, i| {
        mapped[i] = f(item);
    }
    return mapped;
}

/// 顺序过滤（为未来并行实现预留接口）
pub fn seqFilter(
    comptime A: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    predicate: *const fn (A) bool,
) ![]A {
    // 计算需要多少空间
    var count: usize = 0;
    for (slice) |item| {
        if (predicate(item)) {
            count += 1;
        }
    }

    const filtered = try allocator.alloc(A, count);
    var result_idx: usize = 0;
    for (slice) |item| {
        if (predicate(item)) {
            filtered[result_idx] = item;
            result_idx += 1;
        }
    }

    return filtered;
}

/// 顺序规约
pub fn seqReduce(
    comptime A: type,
    slice: []const A,
    initial: A,
    f: *const fn (A, A) A,
) A {
    var acc = initial;
    for (slice) |item| {
        acc = f(acc, item);
    }
    return acc;
}

/// 顺序 fold (带不同类型累加器)
pub fn seqFold(
    comptime A: type,
    comptime B: type,
    slice: []const A,
    initial: B,
    f: *const fn (B, A) B,
) B {
    var acc = initial;
    for (slice) |item| {
        acc = f(acc, item);
    }
    return acc;
}

/// 顺序 flatMap
pub fn seqFlatMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A, std.mem.Allocator) error{OutOfMemory}![]B,
) ![]B {
    var total_len: usize = 0;
    var temp_results = try allocator.alloc([]B, slice.len);
    defer allocator.free(temp_results);

    for (slice, 0..) |item, i| {
        temp_results[i] = try f(item, allocator);
        total_len += temp_results[i].len;
    }

    const flat_result = try allocator.alloc(B, total_len);
    var offset: usize = 0;
    for (temp_results) |sub_slice| {
        @memcpy(flat_result[offset .. offset + sub_slice.len], sub_slice);
        offset += sub_slice.len;
        allocator.free(sub_slice);
    }

    return flat_result;
}

/// 顺序 zip
pub fn seqZip(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    allocator: std.mem.Allocator,
    slice_a: []const A,
    slice_b: []const B,
    f: *const fn (A, B) C,
) ![]C {
    const len = @min(slice_a.len, slice_b.len);
    const zipped = try allocator.alloc(C, len);
    for (0..len) |i| {
        zipped[i] = f(slice_a[i], slice_b[i]);
    }
    return zipped;
}

// ============ 批处理操作 ============

/// 批处理配置
pub const BatchConfig = struct {
    /// 批次大小
    batch_size: usize = 64,
    /// 是否并行执行批次（当前为 false，预留接口）
    parallel: bool = false,
};

/// 批量映射（将输入分成批次处理）
pub fn batchMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
    config: BatchConfig,
) ![]B {
    const mapped = try allocator.alloc(B, slice.len);
    var offset: usize = 0;

    while (offset < slice.len) {
        const end = @min(offset + config.batch_size, slice.len);
        const batch = slice[offset..end];

        for (batch, 0..) |item, i| {
            mapped[offset + i] = f(item);
        }

        offset = end;
    }

    return mapped;
}

/// 批量规约
pub fn batchReduce(
    comptime A: type,
    slice: []const A,
    initial: A,
    f: *const fn (A, A) A,
    config: BatchConfig,
) A {
    if (slice.len == 0) return initial;

    // 分批次计算部分结果
    var partial_results = std.ArrayList(A).init(std.heap.page_allocator);
    defer partial_results.deinit();

    var offset: usize = 0;
    while (offset < slice.len) {
        const end = @min(offset + config.batch_size, slice.len);
        const batch = slice[offset..end];

        var batch_acc = if (offset == 0) initial else batch[0];
        const start_idx: usize = if (offset == 0) 0 else 1;
        for (batch[start_idx..]) |item| {
            batch_acc = f(batch_acc, item);
        }

        partial_results.append(std.heap.page_allocator, batch_acc) catch {
            return initial;
        };

        offset = end;
    }

    // 合并部分结果
    var final_acc = initial;
    for (partial_results.items) |partial| {
        final_acc = f(final_acc, partial);
    }

    return final_acc;
}

// ============ 工作分割策略 ============

/// 工作分割策略
pub const SplitStrategy = enum {
    /// 均匀分割
    even,
    /// 基于工作量的动态分割
    dynamic,
    /// 自适应分割
    adaptive,
};

/// 计算分割点
pub fn computeSplits(total_len: usize, num_chunks: usize, strategy: SplitStrategy) []const usize {
    _ = strategy; // 当前只实现均匀分割
    var splits: [64]usize = undefined;
    const chunk_size = total_len / num_chunks;
    const remainder = total_len % num_chunks;

    var offset: usize = 0;
    for (0..num_chunks) |i| {
        splits[i] = offset;
        offset += chunk_size + (if (i < remainder) @as(usize, 1) else @as(usize, 0));
    }

    return splits[0..num_chunks];
}

// ============ Par Monad 接口（预留） ============

/// Par Monad - 并行计算的 Monad 抽象
/// 当前为顺序实现，保持 API 接口一致
pub fn Par(comptime A: type) type {
    return struct {
        value: A,

        const Self = @This();

        /// 将值提升到并行上下文
        pub fn pure(value: A) Self {
            return Self{ .value = value };
        }

        /// 运行并行计算（当前为同步执行）
        pub fn run(self: Self) A {
            return self.value;
        }

        /// 映射函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) Par(B) {
            return Par(B).pure(f(self.value));
        }

        /// flatMap (顺序执行)
        pub fn flatMap(self: Self, comptime B: type, f: *const fn (A) Par(B)) Par(B) {
            return f(self.value);
        }
    };
}

/// 并行组合两个计算
pub fn parZip(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    par_a: Par(A),
    par_b: Par(B),
    f: *const fn (A, B) C,
) Par(C) {
    // 当前顺序执行
    return Par(C).pure(f(par_a.run(), par_b.run()));
}

/// 并行执行多个计算
pub fn parSequence(
    comptime A: type,
    allocator: std.mem.Allocator,
    pars: []const Par(A),
) ![]A {
    const results = try allocator.alloc(A, pars.len);
    for (pars, 0..) |p, i| {
        results[i] = p.run();
    }
    return results;
}

// ============ 并行 Traversable（预留接口） ============

/// 并行遍历数组
pub fn parTraverse(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
) ![]B {
    // 当前使用顺序实现
    return seqMap(A, B, allocator, slice, f);
}

/// 并行映射
pub fn parMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
) ![]B {
    // 当前使用顺序实现
    return seqMap(A, B, allocator, slice, f);
}

/// 并行过滤
pub fn parFilter(
    comptime A: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    predicate: *const fn (A) bool,
) ![]A {
    // 当前使用顺序实现
    return seqFilter(A, allocator, slice, predicate);
}

// ============ 调度器接口（预留） ============

/// 任务状态
pub const TaskStatus = enum {
    pending,
    running,
    completed,
    failed,
    cancelled,
};

/// 任务优先级
pub const TaskPriority = enum {
    low,
    normal,
    high,
    critical,
};

/// 任务描述
pub const Task = struct {
    id: usize,
    priority: TaskPriority,
    status: TaskStatus,

    pub fn init(id: usize) Task {
        return Task{
            .id = id,
            .priority = .normal,
            .status = .pending,
        };
    }
};

/// 调度器配置
pub const SchedulerConfig = struct {
    /// 工作线程数量（0 表示自动检测）
    num_threads: usize = 0,
    /// 任务队列大小
    queue_size: usize = 1024,
    /// 是否启用工作窃取
    work_stealing: bool = true,
    /// 空闲超时（毫秒，0 表示不超时）
    idle_timeout_ms: u64 = 0,
};

/// 调度器接口 - 抽象基类
/// 注意：当前为接口定义，真正的实现需要线程支持
pub const Scheduler = struct {
    /// 虚函数表
    vtable: *const VTable,

    pub const VTable = struct {
        submit: *const fn (*Scheduler, Task) SchedulerError!void,
        shutdown: *const fn (*Scheduler) void,
        isShutdown: *const fn (*const Scheduler) bool,
    };

    pub const SchedulerError = error{
        QueueFull,
        ShutdownInProgress,
        InvalidTask,
    };

    /// 提交任务
    pub fn submit(self: *Scheduler, task: Task) SchedulerError!void {
        return self.vtable.submit(self, task);
    }

    /// 优雅关闭
    pub fn shutdown(self: *Scheduler) void {
        self.vtable.shutdown(self);
    }

    /// 检查是否已关闭
    pub fn isShutdown(self: *const Scheduler) bool {
        return self.vtable.isShutdown(self);
    }
};

/// 固定大小线程池（接口预留）
/// 注意：当前为顺序执行的模拟实现，真正的并行需要 Zig 线程支持
pub const FixedThreadPool = struct {
    config: SchedulerConfig,
    is_shutdown: bool,
    task_count: usize,

    const Self = @This();

    /// 创建固定大小线程池
    pub fn init(config: SchedulerConfig) Self {
        return Self{
            .config = config,
            .is_shutdown = false,
            .task_count = 0,
        };
    }

    /// 获取线程数
    pub fn getThreadCount(self: *const Self) usize {
        if (self.config.num_threads == 0) {
            // 自动检测：返回 CPU 核心数（模拟）
            return 4; // 默认值
        }
        return self.config.num_threads;
    }

    /// 提交任务（当前为同步执行）
    pub fn submit(self: *Self, task: Task) Scheduler.SchedulerError!void {
        if (self.is_shutdown) {
            return Scheduler.SchedulerError.ShutdownInProgress;
        }
        // 当前为同步执行，未来实现真正的并行
        self.task_count += 1;
        _ = task;
    }

    /// 优雅关闭
    pub fn shutdown(self: *Self) void {
        self.is_shutdown = true;
    }

    /// 检查是否已关闭
    pub fn isShutdown(self: *const Self) bool {
        return self.is_shutdown;
    }

    /// 等待所有任务完成
    pub fn awaitTermination(self: *Self) void {
        // 当前为同步执行，无需等待
        _ = self;
    }
};

/// 工作窃取调度器（接口预留）
/// 注意：当前为顺序执行的模拟实现，真正的工作窃取需要 Zig 线程支持
pub const WorkStealingScheduler = struct {
    config: SchedulerConfig,
    is_shutdown: bool,
    task_count: usize,

    const Self = @This();

    /// 创建工作窃取调度器
    pub fn init(config: SchedulerConfig) Self {
        return Self{
            .config = config,
            .is_shutdown = false,
            .task_count = 0,
        };
    }

    /// 获取工作线程数
    pub fn getWorkerCount(self: *const Self) usize {
        if (self.config.num_threads == 0) {
            return 4; // 默认值
        }
        return self.config.num_threads;
    }

    /// 提交任务（当前为同步执行）
    pub fn submit(self: *Self, task: Task) Scheduler.SchedulerError!void {
        if (self.is_shutdown) {
            return Scheduler.SchedulerError.ShutdownInProgress;
        }
        self.task_count += 1;
        _ = task;
    }

    /// 尝试窃取任务（当前返回 null）
    pub fn trySteal(self: *Self) ?Task {
        _ = self;
        // 当前为顺序执行，无任务可窃取
        return null;
    }

    /// 优雅关闭
    pub fn shutdown(self: *Self) void {
        self.is_shutdown = true;
    }

    /// 检查是否已关闭
    pub fn isShutdown(self: *const Self) bool {
        return self.is_shutdown;
    }

    /// 等待所有任务完成
    pub fn awaitTermination(self: *Self) void {
        _ = self;
    }
};

/// 任务队列（接口预留）
pub const TaskQueue = struct {
    capacity: usize,
    count: usize,

    const Self = @This();

    pub fn init(capacity: usize) Self {
        return Self{
            .capacity = capacity,
            .count = 0,
        };
    }

    /// 入队
    pub fn enqueue(self: *Self, task: Task) !void {
        if (self.count >= self.capacity) {
            return error.QueueFull;
        }
        self.count += 1;
        _ = task;
    }

    /// 出队
    pub fn dequeue(self: *Self) ?Task {
        if (self.count == 0) {
            return null;
        }
        self.count -= 1;
        return Task.init(0);
    }

    /// 队列是否为空
    pub fn isEmpty(self: *const Self) bool {
        return self.count == 0;
    }

    /// 队列是否已满
    pub fn isFull(self: *const Self) bool {
        return self.count >= self.capacity;
    }
};

/// 负载均衡策略
pub const LoadBalanceStrategy = enum {
    /// 轮询
    round_robin,
    /// 最少任务优先
    least_tasks,
    /// 随机分配
    random,
    /// 基于亲和性
    affinity,
};

/// 负载均衡器（接口预留）
pub const LoadBalancer = struct {
    strategy: LoadBalanceStrategy,
    worker_count: usize,
    current_worker: usize,

    const Self = @This();

    pub fn init(strategy: LoadBalanceStrategy, worker_count: usize) Self {
        return Self{
            .strategy = strategy,
            .worker_count = worker_count,
            .current_worker = 0,
        };
    }

    /// 选择下一个工作线程
    pub fn selectWorker(self: *Self) usize {
        switch (self.strategy) {
            .round_robin => {
                const worker = self.current_worker;
                self.current_worker = (self.current_worker + 1) % self.worker_count;
                return worker;
            },
            .least_tasks => {
                // 简化实现：返回第一个
                return 0;
            },
            .random => {
                // 简化实现：轮询
                const worker = self.current_worker;
                self.current_worker = (self.current_worker + 1) % self.worker_count;
                return worker;
            },
            .affinity => {
                // 简化实现：返回第一个
                return 0;
            },
        }
    }
};

// ============ 真正的线程池实现 ============

/// 真正的线程池配置
pub const RealThreadPoolConfig = struct {
    /// 工作线程数量（0 表示使用 CPU 核心数）
    num_threads: usize = 0,
    /// 任务队列最大容量
    max_queue_size: usize = 1024,
};

/// 工作项 - 用于线程间传递任务
const WorkItem = struct {
    /// 任务函数指针
    func: *const fn (*anyopaque) void,
    /// 任务参数
    arg: *anyopaque,
};

/// 真正的线程池 - 使用 Zig 原生线程
pub const RealThreadPool = struct {
    allocator: std.mem.Allocator,
    threads: []std.Thread,
    work_queue: std.ArrayList(WorkItem),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    shutdown: bool,
    active_tasks: usize,

    const Self = @This();

    /// 初始化线程池
    pub fn init(allocator: std.mem.Allocator, config: RealThreadPoolConfig) !*Self {
        const num_threads = if (config.num_threads == 0)
            std.Thread.getCpuCount() catch 4
        else
            config.num_threads;

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = Self{
            .allocator = allocator,
            .threads = try allocator.alloc(std.Thread, num_threads),
            .work_queue = .{},
            .mutex = .{},
            .condition = .{},
            .shutdown = false,
            .active_tasks = 0,
        };

        // 启动工作线程
        for (self.threads, 0..) |*thread, i| {
            thread.* = std.Thread.spawn(.{}, workerThread, .{self}) catch |err| {
                // 清理已创建的线程
                for (self.threads[0..i]) |t| {
                    t.join();
                }
                allocator.free(self.threads);
                self.work_queue.deinit(allocator);
                allocator.destroy(self);
                return err;
            };
        }

        return self;
    }

    /// 销毁线程池
    pub fn deinit(self: *Self) void {
        // 设置关闭标志
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.shutdown = true;
        }

        // 唤醒所有等待的线程
        self.condition.broadcast();

        // 等待所有线程结束
        for (self.threads) |thread| {
            thread.join();
        }

        self.allocator.free(self.threads);
        self.work_queue.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// 提交任务到线程池
    pub fn submit(self: *Self, func: *const fn (*anyopaque) void, arg: *anyopaque) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.shutdown) {
            return error.PoolShutdown;
        }

        try self.work_queue.append(self.allocator, WorkItem{
            .func = func,
            .arg = arg,
        });

        self.condition.signal();
    }

    /// 等待所有任务完成
    pub fn waitAll(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.work_queue.items.len > 0 or self.active_tasks > 0) {
            self.condition.wait(&self.mutex);
        }
    }

    /// 获取线程数
    pub fn getThreadCount(self: *const Self) usize {
        return self.threads.len;
    }

    /// 工作线程函数
    fn workerThread(self: *Self) void {
        while (true) {
            var work_item: ?WorkItem = null;

            {
                self.mutex.lock();
                defer self.mutex.unlock();

                // 等待任务或关闭信号
                while (self.work_queue.items.len == 0 and !self.shutdown) {
                    self.condition.wait(&self.mutex);
                }

                if (self.shutdown and self.work_queue.items.len == 0) {
                    return;
                }

                if (self.work_queue.items.len > 0) {
                    work_item = self.work_queue.orderedRemove(0);
                    self.active_tasks += 1;
                }
            }

            // 执行任务
            if (work_item) |item| {
                item.func(item.arg);

                self.mutex.lock();
                self.active_tasks -= 1;
                self.condition.broadcast();
                self.mutex.unlock();
            }
        }
    }
};

/// 并行 Map 任务上下文
fn ParMapContext(comptime A: type, comptime B: type) type {
    return struct {
        input: []const A,
        output: []B,
        f: *const fn (A) B,
        start_idx: usize,
        end_idx: usize,
        completed: *std.atomic.Value(usize),
    };
}

/// 真正并行的 map 操作
pub fn realParMap(
    comptime A: type,
    comptime B: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    f: *const fn (A) B,
    pool: *RealThreadPool,
) ![]B {
    if (slice.len == 0) {
        return try allocator.alloc(B, 0);
    }

    const output = try allocator.alloc(B, slice.len);
    errdefer allocator.free(output);

    const num_threads = pool.getThreadCount();
    const chunk_size = (slice.len + num_threads - 1) / num_threads;

    var completed = std.atomic.Value(usize).init(0);
    const Context = ParMapContext(A, B);
    var contexts = try allocator.alloc(Context, num_threads);
    defer allocator.free(contexts);

    var actual_chunks: usize = 0;
    var offset: usize = 0;
    while (offset < slice.len) : (actual_chunks += 1) {
        const end = @min(offset + chunk_size, slice.len);
        contexts[actual_chunks] = Context{
            .input = slice,
            .output = output,
            .f = f,
            .start_idx = offset,
            .end_idx = end,
            .completed = &completed,
        };
        offset = end;
    }

    // 提交所有任务
    for (contexts[0..actual_chunks]) |*ctx| {
        try pool.submit(struct {
            fn work(arg: *anyopaque) void {
                const context: *Context = @ptrCast(@alignCast(arg));
                for (context.start_idx..context.end_idx) |i| {
                    context.output[i] = context.f(context.input[i]);
                }
                _ = context.completed.fetchAdd(1, .release);
            }
        }.work, @ptrCast(ctx));
    }

    // 等待所有任务完成
    pool.waitAll();

    return output;
}

/// 并行 Filter 任务上下文
fn ParFilterContext(comptime A: type) type {
    return struct {
        input: []const A,
        predicate: *const fn (A) bool,
        start_idx: usize,
        end_idx: usize,
        results: []A,
        count: usize,
        done: bool,
    };
}

/// 真正并行的 filter 操作
pub fn realParFilter(
    comptime A: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    predicate: *const fn (A) bool,
    pool: *RealThreadPool,
) ![]A {
    if (slice.len == 0) {
        return try allocator.alloc(A, 0);
    }

    const num_threads = pool.getThreadCount();
    const chunk_size = (slice.len + num_threads - 1) / num_threads;

    const Context = ParFilterContext(A);
    var contexts = try allocator.alloc(Context, num_threads);
    defer allocator.free(contexts);

    // 为每个 chunk 分配临时结果缓冲区
    var temp_buffers = try allocator.alloc([]A, num_threads);
    defer {
        for (temp_buffers[0..contexts.len]) |buf| {
            if (buf.len > 0) {
                allocator.free(buf);
            }
        }
        allocator.free(temp_buffers);
    }

    var actual_chunks: usize = 0;
    var offset: usize = 0;
    while (offset < slice.len) : (actual_chunks += 1) {
        const end = @min(offset + chunk_size, slice.len);
        const chunk_len = end - offset;

        temp_buffers[actual_chunks] = try allocator.alloc(A, chunk_len);

        contexts[actual_chunks] = Context{
            .input = slice,
            .predicate = predicate,
            .start_idx = offset,
            .end_idx = end,
            .results = temp_buffers[actual_chunks],
            .count = 0,
            .done = false,
        };
        offset = end;
    }

    // 提交所有任务
    for (contexts[0..actual_chunks]) |*ctx| {
        try pool.submit(struct {
            fn work(arg: *anyopaque) void {
                const context: *Context = @ptrCast(@alignCast(arg));
                var count: usize = 0;
                for (context.input[context.start_idx..context.end_idx]) |item| {
                    if (context.predicate(item)) {
                        context.results[count] = item;
                        count += 1;
                    }
                }
                context.count = count;
                context.done = true;
            }
        }.work, @ptrCast(ctx));
    }

    // 等待所有任务完成
    pool.waitAll();

    // 计算总结果数量
    var total_count: usize = 0;
    for (contexts[0..actual_chunks]) |ctx| {
        total_count += ctx.count;
    }

    // 合并结果
    const final_result = try allocator.alloc(A, total_count);
    var result_offset: usize = 0;
    for (contexts[0..actual_chunks]) |ctx| {
        @memcpy(final_result[result_offset .. result_offset + ctx.count], ctx.results[0..ctx.count]);
        result_offset += ctx.count;
    }

    return final_result;
}

/// 并行 Reduce 任务上下文
fn ParReduceContext(comptime A: type) type {
    return struct {
        slice: []const A,
        f: *const fn (A, A) A,
        start_idx: usize,
        end_idx: usize,
        result: A,
        done: bool,
    };
}

/// 真正并行的 reduce 操作
pub fn realParReduce(
    comptime A: type,
    allocator: std.mem.Allocator,
    slice: []const A,
    initial: A,
    f: *const fn (A, A) A,
    pool: *RealThreadPool,
) !A {
    if (slice.len == 0) {
        return initial;
    }

    const num_threads = pool.getThreadCount();
    const chunk_size = (slice.len + num_threads - 1) / num_threads;

    const Context = ParReduceContext(A);
    var contexts = try allocator.alloc(Context, num_threads);
    defer allocator.free(contexts);

    var actual_chunks: usize = 0;
    var offset: usize = 0;
    while (offset < slice.len) : (actual_chunks += 1) {
        const end = @min(offset + chunk_size, slice.len);
        contexts[actual_chunks] = Context{
            .slice = slice,
            .f = f,
            .start_idx = offset,
            .end_idx = end,
            .result = initial,
            .done = false,
        };
        offset = end;
    }

    // 提交所有任务
    for (contexts[0..actual_chunks]) |*ctx| {
        try pool.submit(struct {
            fn work(arg: *anyopaque) void {
                const context: *Context = @ptrCast(@alignCast(arg));
                var acc = context.slice[context.start_idx];
                for (context.slice[context.start_idx + 1 .. context.end_idx]) |item| {
                    acc = context.f(acc, item);
                }
                context.result = acc;
                context.done = true;
            }
        }.work, @ptrCast(ctx));
    }

    // 等待所有任务完成
    pool.waitAll();

    // 合并部分结果
    var final_result = initial;
    for (contexts[0..actual_chunks]) |ctx| {
        final_result = f(final_result, ctx.result);
    }

    return final_result;
}

// ============ 测试 ============

test "seqMap" {
    const allocator = std.testing.allocator;
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const mapped = try seqMap(i32, i32, allocator, &nums, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer allocator.free(mapped);

    try std.testing.expectEqual(@as(usize, 5), mapped.len);
    try std.testing.expectEqual(@as(i32, 2), mapped[0]);
    try std.testing.expectEqual(@as(i32, 10), mapped[4]);
}

test "seqFilter" {
    const allocator = std.testing.allocator;
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const filtered = try seqFilter(i32, allocator, &nums, struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqual(@as(i32, 2), filtered[0]);
    try std.testing.expectEqual(@as(i32, 4), filtered[1]);
}

test "seqReduce" {
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const sum = seqReduce(i32, &nums, 0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), sum);
}

test "seqFold" {
    const nums = [_]i32{ 1, 2, 3, 4, 5 };

    const count = seqFold(i32, usize, &nums, 0, struct {
        fn countEven(acc: usize, x: i32) usize {
            return if (@rem(x, 2) == 0) acc + 1 else acc;
        }
    }.countEven);

    try std.testing.expectEqual(@as(usize, 2), count);
}

test "seqZip" {
    const allocator = std.testing.allocator;
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20, 30 };

    const zipped = try seqZip(i32, i32, i32, allocator, &a, &b, struct {
        fn add(x: i32, y: i32) i32 {
            return x + y;
        }
    }.add);
    defer allocator.free(zipped);

    try std.testing.expectEqual(@as(usize, 3), zipped.len);
    try std.testing.expectEqual(@as(i32, 11), zipped[0]);
    try std.testing.expectEqual(@as(i32, 22), zipped[1]);
    try std.testing.expectEqual(@as(i32, 33), zipped[2]);
}

test "batchMap" {
    const allocator = std.testing.allocator;
    const nums = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const mapped = try batchMap(i32, i32, allocator, &nums, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double, .{ .batch_size = 3 });
    defer allocator.free(mapped);

    try std.testing.expectEqual(@as(usize, 10), mapped.len);
    try std.testing.expectEqual(@as(i32, 2), mapped[0]);
    try std.testing.expectEqual(@as(i32, 20), mapped[9]);
}

test "Par monad" {
    const p1 = Par(i32).pure(10);
    const p2 = p1.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 20), p2.run());
}

test "parZip" {
    const p1 = Par(i32).pure(10);
    const p2 = Par(i32).pure(20);

    const p3 = parZip(i32, i32, i32, p1, p2, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 30), p3.run());
}

test "parSequence" {
    const allocator = std.testing.allocator;
    const pars = [_]Par(i32){
        Par(i32).pure(1),
        Par(i32).pure(2),
        Par(i32).pure(3),
    };

    const results = try parSequence(i32, allocator, &pars);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 3), results.len);
    try std.testing.expectEqual(@as(i32, 1), results[0]);
    try std.testing.expectEqual(@as(i32, 2), results[1]);
    try std.testing.expectEqual(@as(i32, 3), results[2]);
}

test "Task init" {
    const task = Task.init(42);
    try std.testing.expectEqual(@as(usize, 42), task.id);
    try std.testing.expectEqual(TaskPriority.normal, task.priority);
    try std.testing.expectEqual(TaskStatus.pending, task.status);
}

test "FixedThreadPool basic" {
    var pool = FixedThreadPool.init(.{ .num_threads = 4 });

    try std.testing.expectEqual(@as(usize, 4), pool.getThreadCount());
    try std.testing.expect(!pool.isShutdown());

    const task = Task.init(1);
    try pool.submit(task);
    try std.testing.expectEqual(@as(usize, 1), pool.task_count);

    pool.shutdown();
    try std.testing.expect(pool.isShutdown());

    // 关闭后不能提交任务
    const result = pool.submit(Task.init(2));
    try std.testing.expectError(Scheduler.SchedulerError.ShutdownInProgress, result);
}

test "WorkStealingScheduler basic" {
    var scheduler = WorkStealingScheduler.init(.{ .num_threads = 8 });

    try std.testing.expectEqual(@as(usize, 8), scheduler.getWorkerCount());
    try std.testing.expect(!scheduler.isShutdown());

    const task = Task.init(1);
    try scheduler.submit(task);

    // 当前没有任务可窃取
    try std.testing.expect(scheduler.trySteal() == null);

    scheduler.shutdown();
    try std.testing.expect(scheduler.isShutdown());
}

test "TaskQueue basic" {
    var queue = TaskQueue.init(10);

    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(!queue.isFull());

    try queue.enqueue(Task.init(1));
    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.count);

    const task = queue.dequeue();
    try std.testing.expect(task != null);
    try std.testing.expect(queue.isEmpty());
}

test "LoadBalancer round_robin" {
    var balancer = LoadBalancer.init(.round_robin, 4);

    try std.testing.expectEqual(@as(usize, 0), balancer.selectWorker());
    try std.testing.expectEqual(@as(usize, 1), balancer.selectWorker());
    try std.testing.expectEqual(@as(usize, 2), balancer.selectWorker());
    try std.testing.expectEqual(@as(usize, 3), balancer.selectWorker());
    try std.testing.expectEqual(@as(usize, 0), balancer.selectWorker()); // 循环
}

test "RealThreadPool init and deinit" {
    const allocator = std.testing.allocator;
    const pool = try RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 2), pool.getThreadCount());
}

test "RealThreadPool submit and wait" {
    const allocator = std.testing.allocator;
    const pool = try RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    var counter = std.atomic.Value(usize).init(0);

    const Context = struct {
        counter: *std.atomic.Value(usize),
    };

    var ctx = Context{ .counter = &counter };

    try pool.submit(struct {
        fn work(arg: *anyopaque) void {
            const c: *Context = @ptrCast(@alignCast(arg));
            _ = c.counter.fetchAdd(1, .release);
        }
    }.work, @ptrCast(&ctx));

    pool.waitAll();

    try std.testing.expectEqual(@as(usize, 1), counter.load(.acquire));
}

test "realParMap basic" {
    const allocator = std.testing.allocator;
    const pool = try RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const nums = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const mapped = try realParMap(i32, i32, allocator, &nums, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double, pool);
    defer allocator.free(mapped);

    try std.testing.expectEqual(@as(usize, 8), mapped.len);
    try std.testing.expectEqual(@as(i32, 2), mapped[0]);
    try std.testing.expectEqual(@as(i32, 4), mapped[1]);
    try std.testing.expectEqual(@as(i32, 16), mapped[7]);
}

test "realParReduce basic" {
    const allocator = std.testing.allocator;
    const pool = try RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const nums = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const sum = try realParReduce(i32, allocator, &nums, 0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add, pool);

    try std.testing.expectEqual(@as(i32, 36), sum);
}

test "realParFilter basic" {
    const allocator = std.testing.allocator;
    const pool = try RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const nums = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const filtered = try realParFilter(i32, allocator, &nums, struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven, pool);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 4), filtered.len);
    // 注意：并行结果可能顺序不同，但应包含所有偶数
    var sum: i32 = 0;
    for (filtered) |n| {
        sum += n;
    }
    try std.testing.expectEqual(@as(i32, 20), sum); // 2+4+6+8=20
}
