//! Random Effect - 随机数效果
//!
//! 提供函数式的随机数生成能力，通过代数效果系统实现。
//! 支持生成随机整数、浮点数、字节序列和数组打乱。

const std = @import("std");
const effect = @import("effect.zig");

// ============ 随机操作类型 ============

/// 随机数操作类型
pub const RandomOp = union(enum) {
    /// 生成随机整数 (在范围内)
    random_int: struct {
        min: i64,
        max: i64,
    },

    /// 生成随机无符号整数
    random_uint: struct {
        min: u64,
        max: u64,
    },

    /// 生成随机浮点数 [0, 1)
    random_float: void,

    /// 生成随机浮点数 (在范围内)
    random_float_range: struct {
        min: f64,
        max: f64,
    },

    /// 生成随机字节序列
    random_bytes: struct {
        len: usize,
        allocator: std.mem.Allocator,
    },

    /// 生成随机布尔值
    random_bool: void,

    /// 从数组中随机选择一个元素的索引
    random_choice: struct {
        len: usize,
    },
};

/// 随机数效果类型
pub fn RandomEffect(comptime A: type) type {
    return effect.Effect(RandomOp, A);
}

/// 随机数结果类型
pub const RandomResult = union(enum) {
    int_value: i64,
    uint_value: u64,
    float_value: f64,
    bytes_value: []u8,
    bool_value: bool,
    index_value: usize,
    err: []const u8,
};

// ============ 效果构造器 ============

/// 生成随机整数 (在 [min, max] 范围内)
pub fn randomInt(min: i64, max: i64) RandomEffect(i64) {
    return RandomEffect(i64){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_int = .{ .min = min, .max = max } },
        },
    };
}

/// 生成随机无符号整数 (在 [min, max] 范围内)
pub fn randomUint(min: u64, max: u64) RandomEffect(u64) {
    return RandomEffect(u64){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_uint = .{ .min = min, .max = max } },
        },
    };
}

/// 生成随机浮点数 [0, 1)
pub fn randomFloat() RandomEffect(f64) {
    return RandomEffect(f64){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_float = {} },
        },
    };
}

/// 生成随机浮点数 (在 [min, max) 范围内)
pub fn randomFloatRange(min: f64, max: f64) RandomEffect(f64) {
    return RandomEffect(f64){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_float_range = .{ .min = min, .max = max } },
        },
    };
}

/// 生成随机字节序列
pub fn randomBytes(len: usize, allocator: std.mem.Allocator) RandomEffect([]u8) {
    return RandomEffect([]u8){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_bytes = .{ .len = len, .allocator = allocator } },
        },
    };
}

/// 生成随机布尔值
pub fn randomBool() RandomEffect(bool) {
    return RandomEffect(bool){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_bool = {} },
        },
    };
}

/// 从给定长度的数组中随机选择一个索引
pub fn randomChoice(len: usize) RandomEffect(usize) {
    return RandomEffect(usize){
        .effect_op = .{
            .tag = .IO,
            .data = RandomOp{ .random_choice = .{ .len = len } },
        },
    };
}

// ============ 随机数处理器 ============

/// 随机数处理器
pub const RandomHandler = struct {
    prng_state: std.Random.DefaultPrng,

    const Self = @This();

    /// 创建真实的随机数处理器 (使用系统随机源)
    pub fn init() Self {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            // 如果系统随机源不可用，使用时间戳
            seed = @intCast(std.time.nanoTimestamp());
        };
        return Self{
            .prng_state = std.Random.DefaultPrng.init(seed),
        };
    }

    /// 创建带固定种子的随机数处理器 (用于测试)
    pub fn initWithSeed(seed: u64) Self {
        return Self{
            .prng_state = std.Random.DefaultPrng.init(seed),
        };
    }

    /// 获取随机数生成器
    fn getRandom(self: *Self) std.Random {
        return self.prng_state.random();
    }

    /// 处理随机数操作
    pub fn handle(self: *Self, op: RandomOp) RandomResult {
        var prng = self.prng_state.random();
        return switch (op) {
            .random_int => |data| {
                if (data.min > data.max) {
                    return RandomResult{ .err = "min > max" };
                }
                const range: u64 = @intCast(data.max - data.min + 1);
                const random_val = prng.uintLessThan(u64, range);
                return RandomResult{ .int_value = data.min + @as(i64, @intCast(random_val)) };
            },

            .random_uint => |data| {
                if (data.min > data.max) {
                    return RandomResult{ .err = "min > max" };
                }
                const range = data.max - data.min + 1;
                const random_val = prng.uintLessThan(u64, range);
                return RandomResult{ .uint_value = data.min + random_val };
            },

            .random_float => {
                return RandomResult{ .float_value = prng.float(f64) };
            },

            .random_float_range => |data| {
                if (data.min > data.max) {
                    return RandomResult{ .err = "min > max" };
                }
                const f = prng.float(f64);
                return RandomResult{ .float_value = data.min + f * (data.max - data.min) };
            },

            .random_bytes => |data| {
                const bytes = data.allocator.alloc(u8, data.len) catch {
                    return RandomResult{ .err = "allocation failed" };
                };
                prng.bytes(bytes);
                return RandomResult{ .bytes_value = bytes };
            },

            .random_bool => {
                return RandomResult{ .bool_value = prng.boolean() };
            },

            .random_choice => |data| {
                if (data.len == 0) {
                    return RandomResult{ .err = "empty array" };
                }
                return RandomResult{ .index_value = prng.uintLessThan(usize, data.len) };
            },
        };
    }
};

/// 创建模拟随机数处理器 (用于测试，返回固定值)
pub fn mockRandomHandler() MockRandomHandler {
    return MockRandomHandler{};
}

pub const MockRandomHandler = struct {
    int_value: i64 = 0,
    uint_value: u64 = 0,
    float_value: f64 = 0.5,
    bool_value: bool = true,
    index_value: usize = 0,

    const Self = @This();

    pub fn handle(self: Self, op: RandomOp) RandomResult {
        return switch (op) {
            .random_int => RandomResult{ .int_value = self.int_value },
            .random_uint => RandomResult{ .uint_value = self.uint_value },
            .random_float => RandomResult{ .float_value = self.float_value },
            .random_float_range => RandomResult{ .float_value = self.float_value },
            .random_bytes => |data| {
                const bytes = data.allocator.alloc(u8, data.len) catch {
                    return RandomResult{ .err = "allocation failed" };
                };
                @memset(bytes, 0);
                return RandomResult{ .bytes_value = bytes };
            },
            .random_bool => RandomResult{ .bool_value = self.bool_value },
            .random_choice => RandomResult{ .index_value = self.index_value },
        };
    }
};

// ============ 辅助函数 ============

/// 打乱数组 (原地修改)
pub fn shuffle(comptime T: type, slice: []T, handler: *RandomHandler) void {
    if (slice.len <= 1) return;

    var i: usize = slice.len - 1;
    while (i > 0) : (i -= 1) {
        const result = handler.handle(RandomOp{ .random_choice = .{ .len = i + 1 } });
        const j = result.index_value;
        const tmp = slice[i];
        slice[i] = slice[j];
        slice[j] = tmp;
    }
}

/// 从切片中随机采样 n 个元素
pub fn sample(comptime T: type, allocator: std.mem.Allocator, slice: []const T, n: usize, handler: *RandomHandler) ![]T {
    if (n > slice.len) return error.SampleSizeTooLarge;

    var result = try allocator.alloc(T, n);
    errdefer allocator.free(result);

    // 使用 reservoir sampling 算法
    for (0..n) |i| {
        result[i] = slice[i];
    }

    for (n..slice.len) |i| {
        const rand_result = handler.handle(RandomOp{ .random_choice = .{ .len = i + 1 } });
        const j = rand_result.index_value;
        if (j < n) {
            result[j] = slice[i];
        }
    }

    return result;
}

// ============ 测试 ============

test "randomInt effect construction" {
    const eff = randomInt(1, 100);
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .random_int);
}

test "randomFloat effect construction" {
    const eff = randomFloat();
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .random_float);
}

test "randomBool effect construction" {
    const eff = randomBool();
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .random_bool);
}

test "RandomHandler with seed" {
    var handler = RandomHandler.initWithSeed(12345);

    // 测试随机整数
    const int_result = handler.handle(RandomOp{ .random_int = .{ .min = 0, .max = 100 } });
    try std.testing.expect(int_result == .int_value);
    try std.testing.expect(int_result.int_value >= 0 and int_result.int_value <= 100);

    // 测试随机浮点数
    const float_result = handler.handle(RandomOp{ .random_float = {} });
    try std.testing.expect(float_result == .float_value);
    try std.testing.expect(float_result.float_value >= 0.0 and float_result.float_value < 1.0);

    // 测试随机布尔值
    const bool_result = handler.handle(RandomOp{ .random_bool = {} });
    try std.testing.expect(bool_result == .bool_value);
}

test "RandomHandler random bytes" {
    var handler = RandomHandler.initWithSeed(12345);

    const bytes_result = handler.handle(RandomOp{ .random_bytes = .{ .len = 16, .allocator = std.testing.allocator } });
    try std.testing.expect(bytes_result == .bytes_value);
    defer std.testing.allocator.free(bytes_result.bytes_value);

    try std.testing.expectEqual(@as(usize, 16), bytes_result.bytes_value.len);
}

test "MockRandomHandler" {
    var handler = mockRandomHandler();
    handler.int_value = 42;
    handler.float_value = 0.75;

    const int_result = handler.handle(RandomOp{ .random_int = .{ .min = 0, .max = 100 } });
    try std.testing.expectEqual(@as(i64, 42), int_result.int_value);

    const float_result = handler.handle(RandomOp{ .random_float = {} });
    try std.testing.expectEqual(@as(f64, 0.75), float_result.float_value);
}

test "shuffle" {
    var handler = RandomHandler.initWithSeed(12345);
    var arr = [_]i32{ 1, 2, 3, 4, 5 };

    shuffle(i32, &arr, &handler);

    // 验证打乱后元素仍然相同（只是顺序不同）
    var sum: i32 = 0;
    for (arr) |v| {
        sum += v;
    }
    try std.testing.expectEqual(@as(i32, 15), sum);
}

test "sample" {
    var handler = RandomHandler.initWithSeed(12345);
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const sampled = try sample(i32, std.testing.allocator, &arr, 3, &handler);
    defer std.testing.allocator.free(sampled);

    try std.testing.expectEqual(@as(usize, 3), sampled.len);
}

test "random_int range validation" {
    var handler = RandomHandler.initWithSeed(12345);

    // 测试无效范围
    const result = handler.handle(RandomOp{ .random_int = .{ .min = 100, .max = 0 } });
    try std.testing.expect(result == .err);
}
