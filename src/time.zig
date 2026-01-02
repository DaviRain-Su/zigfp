//! Time Effect - 时间效果
//!
//! 提供函数式的时间操作能力，通过代数效果系统实现。
//! 支持获取当前时间、等待、超时控制和时间格式化。

const std = @import("std");
const effect = @import("effect.zig");

// ============ 时间操作类型 ============

/// 时间操作类型
pub const TimeOp = union(enum) {
    /// 获取当前时间戳 (纳秒)
    current_time: void,

    /// 获取当前时间戳 (毫秒)
    current_time_millis: void,

    /// 获取单调时钟时间 (用于测量时间间隔)
    monotonic_time: void,

    /// 等待指定时间 (纳秒)
    sleep_ns: u64,

    /// 等待指定时间 (毫秒)
    sleep_ms: u64,

    /// 获取格式化的时间字符串
    format_time: struct {
        timestamp_ns: i128,
        format: TimeFormat,
        allocator: std.mem.Allocator,
    },

    /// 解析时间字符串
    parse_time: struct {
        input: []const u8,
        format: TimeFormat,
    },
};

/// 时间格式
pub const TimeFormat = enum {
    /// ISO 8601 格式: 2024-01-02T15:04:05Z
    iso8601,
    /// RFC 2822 格式: Mon, 02 Jan 2024 15:04:05 +0000
    rfc2822,
    /// Unix 时间戳 (秒)
    unix_seconds,
    /// Unix 时间戳 (毫秒)
    unix_millis,
    /// 自定义格式
    custom,
};

/// 时间效果类型
pub fn TimeEffect(comptime A: type) type {
    return effect.Effect(TimeOp, A);
}

/// 时间结果类型
pub const TimeResult = union(enum) {
    timestamp_ns: i128,
    timestamp_ms: i64,
    formatted: []const u8,
    parsed: i128,
    success: void,
    err: []const u8,
};

/// 时间结构
pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    nanosecond: u32,

    /// 从纳秒时间戳创建 DateTime
    pub fn fromTimestamp(timestamp_ns: i128) DateTime {
        const seconds = @as(i64, @intCast(@divTrunc(timestamp_ns, std.time.ns_per_s)));
        const nanos = @as(u32, @intCast(@mod(timestamp_ns, std.time.ns_per_s)));

        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds) };
        const day_seconds = epoch_seconds.getDaySeconds();
        const year_day = epoch_seconds.getEpochDay().calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        return DateTime{
            .year = year_day.year,
            .month = @intFromEnum(month_day.month),
            .day = month_day.day_index + 1,
            .hour = day_seconds.getHoursIntoDay(),
            .minute = day_seconds.getMinutesIntoHour(),
            .second = day_seconds.getSecondsIntoMinute(),
            .nanosecond = nanos,
        };
    }

    /// 转换为纳秒时间戳
    pub fn toTimestamp(self: DateTime) i128 {
        // 简化实现：仅支持 1970 年后的日期
        const days = daysFromYearMonthDay(self.year, self.month, self.day);
        const seconds = @as(i64, days) * 86400 +
            @as(i64, self.hour) * 3600 +
            @as(i64, self.minute) * 60 +
            @as(i64, self.second);
        return @as(i128, seconds) * std.time.ns_per_s + @as(i128, self.nanosecond);
    }

    fn daysFromYearMonthDay(year: u16, month: u8, day: u8) i32 {
        // 简化的日期转天数计算
        var y = @as(i32, year);
        var m = @as(i32, month);
        const d = @as(i32, day);

        // 调整月份
        if (m <= 2) {
            y -= 1;
            m += 12;
        }

        // 计算从公历起点到指定日期的天数
        const a = @divTrunc(y, 4) - @divTrunc(y, 100) + @divTrunc(y, 400);
        const b = @divTrunc((m + 1) * 306, 10);
        const days_since_epoch = @as(i32, 365) * y + a + b + d - 719591;

        return days_since_epoch;
    }
};

/// Duration 类型 - 时间间隔
pub const Duration = struct {
    nanoseconds: i128,

    const Self = @This();

    /// 从纳秒创建
    pub fn fromNanos(ns: i128) Self {
        return Self{ .nanoseconds = ns };
    }

    /// 从微秒创建
    pub fn fromMicros(us: i64) Self {
        return Self{ .nanoseconds = @as(i128, us) * 1000 };
    }

    /// 从毫秒创建
    pub fn fromMillis(ms: i64) Self {
        return Self{ .nanoseconds = @as(i128, ms) * std.time.ns_per_ms };
    }

    /// 从秒创建
    pub fn fromSeconds(s: i64) Self {
        return Self{ .nanoseconds = @as(i128, s) * std.time.ns_per_s };
    }

    /// 从分钟创建
    pub fn fromMinutes(m: i64) Self {
        return Self{ .nanoseconds = @as(i128, m) * 60 * std.time.ns_per_s };
    }

    /// 从小时创建
    pub fn fromHours(h: i64) Self {
        return Self{ .nanoseconds = @as(i128, h) * 3600 * std.time.ns_per_s };
    }

    /// 转换为纳秒
    pub fn toNanos(self: Self) i128 {
        return self.nanoseconds;
    }

    /// 转换为微秒
    pub fn toMicros(self: Self) i64 {
        return @intCast(@divTrunc(self.nanoseconds, 1000));
    }

    /// 转换为毫秒
    pub fn toMillis(self: Self) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_ms));
    }

    /// 转换为秒
    pub fn toSeconds(self: Self) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_s));
    }

    /// 加法
    pub fn add(self: Self, other: Self) Self {
        return Self{ .nanoseconds = self.nanoseconds + other.nanoseconds };
    }

    /// 减法
    pub fn sub(self: Self, other: Self) Self {
        return Self{ .nanoseconds = self.nanoseconds - other.nanoseconds };
    }

    /// 乘法
    pub fn mul(self: Self, factor: i64) Self {
        return Self{ .nanoseconds = self.nanoseconds * @as(i128, factor) };
    }

    /// 比较
    pub fn compare(self: Self, other: Self) std.math.Order {
        if (self.nanoseconds < other.nanoseconds) return .lt;
        if (self.nanoseconds > other.nanoseconds) return .gt;
        return .eq;
    }

    /// 是否为零
    pub fn isZero(self: Self) bool {
        return self.nanoseconds == 0;
    }

    /// 是否为负
    pub fn isNegative(self: Self) bool {
        return self.nanoseconds < 0;
    }
};

// ============ 效果构造器 ============

/// 获取当前时间戳 (纳秒)
pub fn currentTime() TimeEffect(i128) {
    return TimeEffect(i128){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .current_time = {} },
        },
    };
}

/// 获取当前时间戳 (毫秒)
pub fn currentTimeMillis() TimeEffect(i64) {
    return TimeEffect(i64){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .current_time_millis = {} },
        },
    };
}

/// 获取单调时钟时间
pub fn monotonicTime() TimeEffect(i128) {
    return TimeEffect(i128){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .monotonic_time = {} },
        },
    };
}

/// 等待指定时间 (纳秒)
pub fn sleepNs(ns: u64) TimeEffect(void) {
    return TimeEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .sleep_ns = ns },
        },
    };
}

/// 等待指定时间 (毫秒)
pub fn sleepMs(ms: u64) TimeEffect(void) {
    return TimeEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .sleep_ms = ms },
        },
    };
}

/// 等待 Duration
pub fn sleep(duration: Duration) TimeEffect(void) {
    return sleepNs(@intCast(duration.toNanos()));
}

/// 格式化时间
pub fn formatTime(timestamp_ns: i128, format: TimeFormat, allocator: std.mem.Allocator) TimeEffect([]const u8) {
    return TimeEffect([]const u8){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .format_time = .{
                .timestamp_ns = timestamp_ns,
                .format = format,
                .allocator = allocator,
            } },
        },
    };
}

/// 解析时间
pub fn parseTime(input: []const u8, format: TimeFormat) TimeEffect(i128) {
    return TimeEffect(i128){
        .effect_op = .{
            .tag = .IO,
            .data = TimeOp{ .parse_time = .{
                .input = input,
                .format = format,
            } },
        },
    };
}

// ============ 时间处理器 ============

/// 真实时间处理器
pub const TimeHandler = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn handle(self: Self, op: TimeOp) TimeResult {
        _ = self;
        return switch (op) {
            .current_time => TimeResult{ .timestamp_ns = std.time.nanoTimestamp() },

            .current_time_millis => TimeResult{ .timestamp_ms = std.time.milliTimestamp() },

            .monotonic_time => TimeResult{ .timestamp_ns = std.time.nanoTimestamp() },

            .sleep_ns => |ns| {
                std.Thread.sleep(ns);
                return TimeResult{ .success = {} };
            },

            .sleep_ms => |ms| {
                std.Thread.sleep(ms * std.time.ns_per_ms);
                return TimeResult{ .success = {} };
            },

            .format_time => |data| {
                const dt = DateTime.fromTimestamp(data.timestamp_ns);
                const result = formatDateTime(dt, data.format, data.allocator) catch |err| {
                    return TimeResult{ .err = @errorName(err) };
                };
                return TimeResult{ .formatted = result };
            },

            .parse_time => |data| {
                const result = parseDateTime(data.input, data.format) catch |err| {
                    return TimeResult{ .err = @errorName(err) };
                };
                return TimeResult{ .parsed = result };
            },
        };
    }
};

/// 模拟时间处理器 (用于测试)
pub const MockTimeHandler = struct {
    current_timestamp: i128 = 0,
    sleep_callback: ?*const fn (u64) void = null,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn initWithTime(timestamp_ns: i128) Self {
        return Self{ .current_timestamp = timestamp_ns };
    }

    pub fn handle(self: *Self, op: TimeOp) TimeResult {
        return switch (op) {
            .current_time => TimeResult{ .timestamp_ns = self.current_timestamp },

            .current_time_millis => TimeResult{ .timestamp_ms = @intCast(@divTrunc(self.current_timestamp, std.time.ns_per_ms)) },

            .monotonic_time => TimeResult{ .timestamp_ns = self.current_timestamp },

            .sleep_ns => |ns| {
                if (self.sleep_callback) |cb| {
                    cb(ns);
                }
                self.current_timestamp += @intCast(ns);
                return TimeResult{ .success = {} };
            },

            .sleep_ms => |ms| {
                if (self.sleep_callback) |cb| {
                    cb(ms * std.time.ns_per_ms);
                }
                self.current_timestamp += @as(i128, ms) * std.time.ns_per_ms;
                return TimeResult{ .success = {} };
            },

            .format_time => |data| {
                const dt = DateTime.fromTimestamp(data.timestamp_ns);
                const result = formatDateTime(dt, data.format, data.allocator) catch |err| {
                    return TimeResult{ .err = @errorName(err) };
                };
                return TimeResult{ .formatted = result };
            },

            .parse_time => |data| {
                const result = parseDateTime(data.input, data.format) catch |err| {
                    return TimeResult{ .err = @errorName(err) };
                };
                return TimeResult{ .parsed = result };
            },
        };
    }

    /// 模拟时间前进
    pub fn advanceTime(self: *Self, duration: Duration) void {
        self.current_timestamp += duration.toNanos();
    }
};

// ============ 辅助函数 ============

fn formatDateTime(dt: DateTime, format: TimeFormat, allocator: std.mem.Allocator) ![]const u8 {
    return switch (format) {
        .iso8601 => try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            dt.year,
            dt.month,
            dt.day,
            dt.hour,
            dt.minute,
            dt.second,
        }),
        .unix_seconds => try std.fmt.allocPrint(allocator, "{d}", .{@divTrunc(dt.toTimestamp(), std.time.ns_per_s)}),
        .unix_millis => try std.fmt.allocPrint(allocator, "{d}", .{@divTrunc(dt.toTimestamp(), std.time.ns_per_ms)}),
        else => try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            dt.year,
            dt.month,
            dt.day,
            dt.hour,
            dt.minute,
            dt.second,
        }),
    };
}

fn parseDateTime(input: []const u8, format: TimeFormat) !i128 {
    return switch (format) {
        .unix_seconds => blk: {
            const seconds = std.fmt.parseInt(i64, input, 10) catch return error.InvalidFormat;
            break :blk @as(i128, seconds) * std.time.ns_per_s;
        },
        .unix_millis => blk: {
            const millis = std.fmt.parseInt(i64, input, 10) catch return error.InvalidFormat;
            break :blk @as(i128, millis) * std.time.ns_per_ms;
        },
        else => error.UnsupportedFormat,
    };
}

/// 测量代码块执行时间
pub fn measure(comptime func: fn () void) Duration {
    const start = std.time.nanoTimestamp();
    func();
    const end = std.time.nanoTimestamp();
    return Duration.fromNanos(end - start);
}

/// 测量带返回值的代码块执行时间
pub fn measureWithResult(comptime T: type, func: *const fn () T) struct { result: T, duration: Duration } {
    const start = std.time.nanoTimestamp();
    const result = func();
    const end = std.time.nanoTimestamp();
    return .{
        .result = result,
        .duration = Duration.fromNanos(end - start),
    };
}

// ============ 测试 ============

test "currentTime effect construction" {
    const eff = currentTime();
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .current_time);
}

test "sleepMs effect construction" {
    const eff = sleepMs(100);
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .sleep_ms);
}

test "Duration operations" {
    const d1 = Duration.fromSeconds(1);
    const d2 = Duration.fromMillis(500);

    try std.testing.expectEqual(@as(i64, 1000), d1.toMillis());
    try std.testing.expectEqual(@as(i64, 500), d2.toMillis());

    const sum = d1.add(d2);
    try std.testing.expectEqual(@as(i64, 1500), sum.toMillis());

    const diff = d1.sub(d2);
    try std.testing.expectEqual(@as(i64, 500), diff.toMillis());
}

test "Duration comparison" {
    const d1 = Duration.fromSeconds(1);
    const d2 = Duration.fromMillis(500);

    try std.testing.expect(d1.compare(d2) == .gt);
    try std.testing.expect(d2.compare(d1) == .lt);
    try std.testing.expect(d1.compare(d1) == .eq);
}

test "TimeHandler current time" {
    const handler = TimeHandler.init();
    const result = handler.handle(TimeOp{ .current_time = {} });
    try std.testing.expect(result == .timestamp_ns);
    try std.testing.expect(result.timestamp_ns > 0);
}

test "MockTimeHandler" {
    var handler = MockTimeHandler.initWithTime(1000000000); // 1 second in ns

    const result1 = handler.handle(TimeOp{ .current_time = {} });
    try std.testing.expectEqual(@as(i128, 1000000000), result1.timestamp_ns);

    // 模拟等待
    _ = handler.handle(TimeOp{ .sleep_ms = 100 });

    const result2 = handler.handle(TimeOp{ .current_time = {} });
    try std.testing.expectEqual(@as(i128, 1100000000), result2.timestamp_ns);
}

test "MockTimeHandler advanceTime" {
    var handler = MockTimeHandler.initWithTime(0);

    handler.advanceTime(Duration.fromSeconds(5));

    const result = handler.handle(TimeOp{ .current_time = {} });
    try std.testing.expectEqual(@as(i128, 5 * std.time.ns_per_s), result.timestamp_ns);
}

test "DateTime fromTimestamp" {
    // 测试 Unix epoch
    const dt = DateTime.fromTimestamp(0);
    try std.testing.expectEqual(@as(u16, 1970), dt.year);
    try std.testing.expectEqual(@as(u8, 1), dt.month);
    try std.testing.expectEqual(@as(u8, 1), dt.day);
}

test "formatDateTime iso8601" {
    const dt = DateTime{
        .year = 2024,
        .month = 1,
        .day = 2,
        .hour = 15,
        .minute = 4,
        .second = 5,
        .nanosecond = 0,
    };

    const formatted = try formatDateTime(dt, .iso8601, std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expectEqualStrings("2024-01-02T15:04:05Z", formatted);
}

test "parseDateTime unix_seconds" {
    const result = try parseDateTime("1704214445", .unix_seconds);
    try std.testing.expect(result > 0);
}
