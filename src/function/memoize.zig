//! Memoize - 函数记忆化
//!
//! `Memoized(F)` 包装一个函数，缓存其调用结果。
//! 对于相同的参数，直接返回缓存值而不重复计算。

const std = @import("std");

/// 通用记忆化包装器
/// 注意：由于 Zig 的类型系统限制，这里提供简化版本
pub fn Memoized(comptime K: type, comptime V: type) type {
    return struct {
        cache: std.AutoHashMap(K, V),
        compute: *const fn (K) V,
        hits: usize,
        misses: usize,

        const Self = @This();

        /// 创建记忆化函数
        pub fn init(allocator: std.mem.Allocator, compute: *const fn (K) V) Self {
            return .{
                .cache = std.AutoHashMap(K, V).init(allocator),
                .compute = compute,
                .hits = 0,
                .misses = 0,
            };
        }

        /// 释放资源
        pub fn deinit(self: *Self) void {
            self.cache.deinit();
        }

        /// 调用函数（使用缓存）
        pub fn call(self: *Self, key: K) V {
            if (self.cache.get(key)) |cached| {
                self.hits += 1;
                return cached;
            }

            self.misses += 1;
            const result = self.compute(key);
            self.cache.put(key, result) catch {};
            return result;
        }

        /// 获取缓存命中率
        pub fn hitRate(self: Self) f64 {
            const total = self.hits + self.misses;
            if (total == 0) return 0.0;
            return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
        }

        /// 获取统计信息
        pub fn stats(self: Self) Stats {
            return .{
                .hits = self.hits,
                .misses = self.misses,
                .cacheSize = self.cache.count(),
            };
        }

        /// 清除缓存
        pub fn clear(self: *Self) void {
            self.cache.clearRetainingCapacity();
            self.hits = 0;
            self.misses = 0;
        }

        pub const Stats = struct {
            hits: usize,
            misses: usize,
            cacheSize: usize,
        };
    };
}

/// 二元函数记忆化
pub fn Memoized2(comptime K1: type, comptime K2: type, comptime V: type) type {
    const Key = struct { K1, K2 };

    return struct {
        cache: std.AutoHashMap(Key, V),
        compute: *const fn (K1, K2) V,
        hits: usize,
        misses: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, compute: *const fn (K1, K2) V) Self {
            return .{
                .cache = std.AutoHashMap(Key, V).init(allocator),
                .compute = compute,
                .hits = 0,
                .misses = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
        }

        pub fn call(self: *Self, k1: K1, k2: K2) V {
            const key = Key{ k1, k2 };
            if (self.cache.get(key)) |cached| {
                self.hits += 1;
                return cached;
            }

            self.misses += 1;
            const result = self.compute(k1, k2);
            self.cache.put(key, result) catch {};
            return result;
        }

        pub fn hitRate(self: Self) f64 {
            const total = self.hits + self.misses;
            if (total == 0) return 0.0;
            return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
        }

        pub fn stats(self: Self) Stats {
            return .{
                .hits = self.hits,
                .misses = self.misses,
                .cacheSize = self.cache.count(),
            };
        }

        pub const Stats = struct {
            hits: usize,
            misses: usize,
            cacheSize: usize,
        };
    };
}

/// 便捷函数：创建一元记忆化
pub fn memoize(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    f: *const fn (K) V,
) Memoized(K, V) {
    return Memoized(K, V).init(allocator, f);
}

/// 便捷函数：创建二元记忆化
pub fn memoize2(
    comptime K1: type,
    comptime K2: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    f: *const fn (K1, K2) V,
) Memoized2(K1, K2, V) {
    return Memoized2(K1, K2, V).init(allocator, f);
}

// ============ 测试 ============

test "Memoized basic" {
    var memo = Memoized(i32, i32).init(std.testing.allocator, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer memo.deinit();

    try std.testing.expectEqual(@as(i32, 84), memo.call(42));
    try std.testing.expectEqual(@as(i32, 84), memo.call(42)); // 缓存
    try std.testing.expectEqual(@as(i32, 20), memo.call(10));
}

test "Memoized cache hits" {
    var memo = Memoized(i32, i32).init(std.testing.allocator, struct {
        fn f(x: i32) i32 {
            return x * x;
        }
    }.f);
    defer memo.deinit();

    _ = memo.call(5);
    _ = memo.call(5);
    _ = memo.call(5);
    _ = memo.call(10);
    _ = memo.call(10);

    const s = memo.stats();
    try std.testing.expectEqual(@as(usize, 3), s.hits); // 5 命中2次, 10 命中1次
    try std.testing.expectEqual(@as(usize, 2), s.misses); // 5 和 10 各 miss 1次
    try std.testing.expectEqual(@as(usize, 2), s.cacheSize);
}

test "Memoized hitRate" {
    var memo = Memoized(i32, i32).init(std.testing.allocator, struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f);
    defer memo.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), memo.hitRate());

    _ = memo.call(1);
    try std.testing.expectEqual(@as(f64, 0.0), memo.hitRate()); // 0/1

    _ = memo.call(1);
    try std.testing.expectEqual(@as(f64, 0.5), memo.hitRate()); // 1/2

    _ = memo.call(1);
    try std.testing.expect(memo.hitRate() > 0.6); // 2/3
}

test "Memoized clear" {
    var memo = Memoized(i32, i32).init(std.testing.allocator, struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f);
    defer memo.deinit();

    _ = memo.call(1);
    _ = memo.call(2);
    try std.testing.expectEqual(@as(usize, 2), memo.stats().cacheSize);

    memo.clear();
    try std.testing.expectEqual(@as(usize, 0), memo.stats().cacheSize);
    try std.testing.expectEqual(@as(usize, 0), memo.stats().hits);
}

test "Memoized2 basic" {
    var memo = Memoized2(i32, i32, i32).init(std.testing.allocator, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f);
    defer memo.deinit();

    try std.testing.expectEqual(@as(i32, 5), memo.call(2, 3));
    try std.testing.expectEqual(@as(i32, 5), memo.call(2, 3)); // 缓存
    try std.testing.expectEqual(@as(i32, 7), memo.call(3, 4));

    try std.testing.expectEqual(@as(usize, 1), memo.stats().hits);
    try std.testing.expectEqual(@as(usize, 2), memo.stats().misses);
}

test "memoize convenience function" {
    var memo = memoize(i32, i32, std.testing.allocator, struct {
        fn f(x: i32) i32 {
            return x * 10;
        }
    }.f);
    defer memo.deinit();

    try std.testing.expectEqual(@as(i32, 50), memo.call(5));
}

test "memoize2 convenience function" {
    var memo = memoize2(i32, i32, i32, std.testing.allocator, struct {
        fn f(a: i32, b: i32) i32 {
            return a * b;
        }
    }.f);
    defer memo.deinit();

    try std.testing.expectEqual(@as(i32, 15), memo.call(3, 5));
}
