//! zigFP 并行计算示例
//!
//! 本示例展示 zigFP 库的真正并行计算功能：
//! - RealThreadPool: 真正的线程池
//! - realParMap: 并行映射
//! - realParFilter: 并行过滤
//! - realParReduce: 并行规约

const std = @import("std");
const fp = @import("zigfp");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== zigFP 并行计算示例 ===\n\n", .{});

    // ============ 创建线程池 ============
    std.debug.print("--- 创建线程池 ---\n", .{});

    const pool = try fp.RealThreadPool.init(allocator, .{
        .num_threads = 4, // 使用 4 个工作线程
        .max_queue_size = 1024,
    });
    defer pool.deinit();

    std.debug.print("线程池已创建，线程数: {}\n\n", .{pool.getThreadCount()});

    // ============ 准备测试数据 ============
    std.debug.print("--- 准备测试数据 ---\n", .{});

    var data: [100]i32 = undefined;
    for (&data, 0..) |*item, i| {
        item.* = @intCast(i + 1);
    }
    std.debug.print("测试数据: 1 到 100 的整数数组\n\n", .{});

    // ============ 并行 Map 示例 ============
    std.debug.print("--- 并行 Map 示例 ---\n", .{});
    std.debug.print("将每个数字平方: x -> x * x\n", .{});

    const squared = try fp.realParMap(i32, i32, allocator, &data, square, pool);
    defer allocator.free(squared);

    std.debug.print("前 10 个结果: ", .{});
    for (squared[0..10]) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("...\n", .{});
    std.debug.print("最后一个值 (100^2): {}\n\n", .{squared[99]});

    // ============ 并行 Filter 示例 ============
    std.debug.print("--- 并行 Filter 示例 ---\n", .{});
    std.debug.print("过滤偶数: x -> x %% 2 == 0\n", .{});

    const evens = try fp.realParFilter(i32, allocator, &data, isEven, pool);
    defer allocator.free(evens);

    std.debug.print("偶数数量: {}\n", .{evens.len});
    std.debug.print("前 10 个偶数: ", .{});
    for (evens[0..@min(10, evens.len)]) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("...\n\n", .{});

    // ============ 并行 Reduce 示例 ============
    std.debug.print("--- 并行 Reduce 示例 ---\n", .{});
    std.debug.print("计算总和: sum(1..100)\n", .{});

    const sum = try fp.realParReduce(i32, allocator, &data, 0, add, pool);

    std.debug.print("并行求和结果: {}\n", .{sum});
    std.debug.print("预期结果 (n*(n+1)/2): {}\n\n", .{@divExact(@as(i32, 100) * 101, 2)});

    // ============ 顺序操作对比 ============
    std.debug.print("--- 顺序操作对比 ---\n", .{});

    const seq_squared = try fp.seqMap(i32, i32, allocator, &data, square);
    defer allocator.free(seq_squared);

    const seq_evens = try fp.seqFilter(i32, allocator, &data, isEven);
    defer allocator.free(seq_evens);

    const seq_sum = fp.seqReduce(i32, &data, 0, add);

    std.debug.print("顺序 Map 结果数量: {}\n", .{seq_squared.len});
    std.debug.print("顺序 Filter 结果数量: {}\n", .{seq_evens.len});
    std.debug.print("顺序 Reduce 结果: {}\n\n", .{seq_sum});

    // ============ Par Monad 示例 ============
    std.debug.print("--- Par Monad 示例 ---\n", .{});

    const p1 = fp.Par(i32).pure(10);
    const p2 = p1.map(i32, double);
    const p3 = p2.map(i32, addTen);

    std.debug.print("Par(10).map(double).map(addTen) = {}\n", .{p3.run()});

    // parZip 组合两个并行计算
    const pa = fp.Par(i32).pure(100);
    const pb = fp.Par(i32).pure(200);
    const pc = fp.parZip(i32, i32, i32, pa, pb, add);

    std.debug.print("parZip(100, 200, add) = {}\n\n", .{pc.run()});

    // ============ 批处理示例 ============
    std.debug.print("--- 批处理示例 ---\n", .{});

    const batch_result = try fp.batchMap(i32, i32, allocator, &data, double, .{
        .batch_size = 16, // 每批处理 16 个元素
    });
    defer allocator.free(batch_result);

    std.debug.print("批处理 Map (batch_size=16)\n", .{});
    std.debug.print("前 5 个结果: ", .{});
    for (batch_result[0..5]) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("...\n\n", .{});

    std.debug.print("=== 示例完成 ===\n", .{});
}

// ============ 辅助函数 ============

fn square(x: i32) i32 {
    return x * x;
}

fn double(x: i32) i32 {
    return x * 2;
}

fn addTen(x: i32) i32 {
    return x + 10;
}

fn isEven(x: i32) bool {
    return @rem(x, 2) == 0;
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

// ============ 测试 ============

test "parallel example functions" {
    try std.testing.expectEqual(@as(i32, 4), square(2));
    try std.testing.expectEqual(@as(i32, 6), double(3));
    try std.testing.expectEqual(@as(i32, 15), addTen(5));
    try std.testing.expect(isEven(4));
    try std.testing.expect(!isEven(5));
    try std.testing.expectEqual(@as(i32, 7), add(3, 4));
}

test "parallel map with thread pool" {
    const allocator = std.testing.allocator;
    const pool = try fp.RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const data = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try fp.realParMap(i32, i32, allocator, &data, square, pool);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqual(@as(i32, 4), result[1]);
    try std.testing.expectEqual(@as(i32, 25), result[4]);
}

test "parallel filter with thread pool" {
    const allocator = std.testing.allocator;
    const pool = try fp.RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const data = [_]i32{ 1, 2, 3, 4, 5, 6 };
    const result = try fp.realParFilter(i32, allocator, &data, isEven, pool);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    // 验证所有结果都是偶数
    for (result) |val| {
        try std.testing.expect(@rem(val, 2) == 0);
    }
}

test "parallel reduce with thread pool" {
    const allocator = std.testing.allocator;
    const pool = try fp.RealThreadPool.init(allocator, .{ .num_threads = 2 });
    defer pool.deinit();

    const data = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try fp.realParReduce(i32, allocator, &data, 0, add, pool);

    try std.testing.expectEqual(@as(i32, 15), result);
}
