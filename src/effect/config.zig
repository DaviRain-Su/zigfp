//! Config Effect - 配置效果
//!
//! 提供函数式的配置管理能力，通过代数效果系统实现。
//! 支持读取、设置、加载和保存配置。

const std = @import("std");
const builtin = @import("builtin");
const effect = @import("effect.zig");

// ============ 配置操作类型 ============

/// 配置值类型
pub const ConfigValue = union(enum) {
    string: []const u8,
    int: i64,
    float: f64,
    bool_val: bool,
    null_val: void,
    array: []const ConfigValue,
    object: std.StringHashMap(ConfigValue),

    const Self = @This();

    /// 创建字符串配置值
    pub fn string_(s: []const u8) Self {
        return Self{ .string = s };
    }

    /// 创建整数配置值
    pub fn int_(i: i64) Self {
        return Self{ .int = i };
    }

    /// 创建浮点数配置值
    pub fn float_(f: f64) Self {
        return Self{ .float = f };
    }

    /// 创建布尔配置值
    pub fn bool_(b: bool) Self {
        return Self{ .bool_val = b };
    }

    /// 创建空配置值
    pub fn null_() Self {
        return Self{ .null_val = {} };
    }

    /// 尝试获取字符串值
    pub fn asString(self: Self) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    /// 尝试获取整数值
    pub fn asInt(self: Self) ?i64 {
        return switch (self) {
            .int => |i| i,
            else => null,
        };
    }

    /// 尝试获取浮点数值
    pub fn asFloat(self: Self) ?f64 {
        return switch (self) {
            .float => |f| f,
            .int => |i| @floatFromInt(i),
            else => null,
        };
    }

    /// 尝试获取布尔值
    pub fn asBool(self: Self) ?bool {
        return switch (self) {
            .bool_val => |b| b,
            else => null,
        };
    }

    /// 检查是否为空
    pub fn isNull(self: Self) bool {
        return self == .null_val;
    }
};

/// 配置操作类型
pub const ConfigOp = union(enum) {
    /// 获取配置值
    get: struct {
        key: []const u8,
    },

    /// 设置配置值
    set: struct {
        key: []const u8,
        value: ConfigValue,
    },

    /// 删除配置值
    delete: struct {
        key: []const u8,
    },

    /// 检查配置是否存在
    has: struct {
        key: []const u8,
    },

    /// 获取所有配置键
    keys: void,

    /// 从文件加载配置
    load: struct {
        path: []const u8,
        format: ConfigFormat,
        allocator: std.mem.Allocator,
    },

    /// 保存配置到文件
    save: struct {
        path: []const u8,
        format: ConfigFormat,
    },

    /// 清空所有配置
    clear: void,

    /// 获取带默认值的配置
    get_or_default: struct {
        key: []const u8,
        default: ConfigValue,
    },
};

/// 配置文件格式
pub const ConfigFormat = enum {
    /// JSON 格式
    json,
    /// 环境变量格式 (KEY=VALUE)
    env,
    /// INI 格式
    ini,
    /// 简单键值对格式
    properties,
};

/// 配置效果类型
pub fn ConfigEffect(comptime A: type) type {
    return effect.Effect(ConfigOp, A);
}

/// 配置操作结果
pub const ConfigResult = union(enum) {
    value: ConfigValue,
    bool_result: bool,
    keys: []const []const u8,
    success: void,
    not_found: void,
    err: []const u8,
};

// ============ 效果构造器 ============

/// 获取配置值
pub fn getConfig(key: []const u8) ConfigEffect(?ConfigValue) {
    return ConfigEffect(?ConfigValue){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .get = .{ .key = key } },
        },
    };
}

/// 设置配置值
pub fn setConfig(key: []const u8, value: ConfigValue) ConfigEffect(void) {
    return ConfigEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .set = .{ .key = key, .value = value } },
        },
    };
}

/// 删除配置值
pub fn deleteConfig(key: []const u8) ConfigEffect(bool) {
    return ConfigEffect(bool){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .delete = .{ .key = key } },
        },
    };
}

/// 检查配置是否存在
pub fn hasConfig(key: []const u8) ConfigEffect(bool) {
    return ConfigEffect(bool){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .has = .{ .key = key } },
        },
    };
}

/// 获取所有配置键
pub fn configKeys() ConfigEffect([]const []const u8) {
    return ConfigEffect([]const []const u8){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .keys = {} },
        },
    };
}

/// 从文件加载配置
pub fn loadConfig(path: []const u8, format: ConfigFormat, allocator: std.mem.Allocator) ConfigEffect(void) {
    return ConfigEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .load = .{
                .path = path,
                .format = format,
                .allocator = allocator,
            } },
        },
    };
}

/// 保存配置到文件
pub fn saveConfig(path: []const u8, format: ConfigFormat) ConfigEffect(void) {
    return ConfigEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .save = .{
                .path = path,
                .format = format,
            } },
        },
    };
}

/// 清空所有配置
pub fn clearConfig() ConfigEffect(void) {
    return ConfigEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .clear = {} },
        },
    };
}

/// 获取配置值，如果不存在则返回默认值
pub fn getConfigOrDefault(key: []const u8, default: ConfigValue) ConfigEffect(ConfigValue) {
    return ConfigEffect(ConfigValue){
        .effect_op = .{
            .tag = .IO,
            .data = ConfigOp{ .get_or_default = .{
                .key = key,
                .default = default,
            } },
        },
    };
}

// ============ 配置处理器 ============

/// 内存配置处理器
pub const ConfigHandler = struct {
    allocator: std.mem.Allocator,
    store: std.StringHashMap(ConfigValue),

    const Self = @This();

    /// 创建配置处理器
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .store = std.StringHashMap(ConfigValue).init(allocator),
        };
    }

    /// 销毁配置处理器
    pub fn deinit(self: *Self) void {
        // 释放所有键的内存
        var it = self.store.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.store.deinit();
    }

    /// 处理配置操作
    pub fn handle(self: *Self, op: ConfigOp) ConfigResult {
        return switch (op) {
            .get => |data| {
                if (self.store.get(data.key)) |value| {
                    return ConfigResult{ .value = value };
                }
                return ConfigResult{ .not_found = {} };
            },

            .set => |data| {
                // 复制键
                const key_copy = self.allocator.dupe(u8, data.key) catch {
                    return ConfigResult{ .err = "allocation failed" };
                };

                // 如果键已存在，释放旧键
                if (self.store.fetchRemove(data.key)) |kv| {
                    self.allocator.free(kv.key);
                }

                self.store.put(key_copy, data.value) catch {
                    self.allocator.free(key_copy);
                    return ConfigResult{ .err = "allocation failed" };
                };
                return ConfigResult{ .success = {} };
            },

            .delete => |data| {
                if (self.store.fetchRemove(data.key)) |kv| {
                    self.allocator.free(kv.key);
                    return ConfigResult{ .bool_result = true };
                }
                return ConfigResult{ .bool_result = false };
            },

            .has => |data| {
                return ConfigResult{ .bool_result = self.store.contains(data.key) };
            },

            .keys => {
                var key_list = std.ArrayList([]const u8).initCapacity(self.allocator, self.store.count()) catch {
                    return ConfigResult{ .err = "allocation failed" };
                };
                var it = self.store.keyIterator();
                while (it.next()) |key| {
                    key_list.append(self.allocator, key.*) catch {
                        key_list.deinit(self.allocator);
                        return ConfigResult{ .err = "allocation failed" };
                    };
                }
                return ConfigResult{ .keys = key_list.toOwnedSlice(self.allocator) catch {
                    key_list.deinit(self.allocator);
                    return ConfigResult{ .err = "allocation failed" };
                } };
            },

            .load => |data| {
                self.loadFromFile(data.path, data.format, data.allocator) catch |err| {
                    return ConfigResult{ .err = @errorName(err) };
                };
                return ConfigResult{ .success = {} };
            },

            .save => |data| {
                self.saveToFile(data.path, data.format) catch |err| {
                    return ConfigResult{ .err = @errorName(err) };
                };
                return ConfigResult{ .success = {} };
            },

            .clear => {
                var it = self.store.keyIterator();
                while (it.next()) |key| {
                    self.allocator.free(key.*);
                }
                self.store.clearRetainingCapacity();
                return ConfigResult{ .success = {} };
            },

            .get_or_default => |data| {
                if (self.store.get(data.key)) |value| {
                    return ConfigResult{ .value = value };
                }
                return ConfigResult{ .value = data.default };
            },
        };
    }

    /// 从文件加载配置
    fn loadFromFile(self: *Self, path: []const u8, format: ConfigFormat, allocator: std.mem.Allocator) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        switch (format) {
            .env, .properties => {
                // 解析简单的 KEY=VALUE 格式
                var lines = std.mem.splitScalar(u8, content, '\n');
                while (lines.next()) |line| {
                    const trimmed = std.mem.trim(u8, line, " \t\r");
                    if (trimmed.len == 0 or trimmed[0] == '#') continue;

                    if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                        const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                        const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                        const key_copy = try self.allocator.dupe(u8, key);
                        errdefer self.allocator.free(key_copy);

                        try self.store.put(key_copy, ConfigValue.string_(value));
                    }
                }
            },
            else => return error.UnsupportedFormat,
        }
    }

    /// 保存配置到文件
    fn saveToFile(self: *Self, path: []const u8, format: ConfigFormat) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        switch (format) {
            .env, .properties => {
                var it = self.store.iterator();
                while (it.next()) |entry| {
                    switch (entry.value_ptr.*) {
                        .string => |s| {
                            const line = std.fmt.allocPrint(self.allocator, "{s}={s}\n", .{ entry.key_ptr.*, s }) catch continue;
                            defer self.allocator.free(line);
                            _ = file.write(line) catch continue;
                        },
                        .int => |i| {
                            const line = std.fmt.allocPrint(self.allocator, "{s}={d}\n", .{ entry.key_ptr.*, i }) catch continue;
                            defer self.allocator.free(line);
                            _ = file.write(line) catch continue;
                        },
                        .float => |f| {
                            const line = std.fmt.allocPrint(self.allocator, "{s}={d}\n", .{ entry.key_ptr.*, f }) catch continue;
                            defer self.allocator.free(line);
                            _ = file.write(line) catch continue;
                        },
                        .bool_val => |b| {
                            const line = std.fmt.allocPrint(self.allocator, "{s}={}\n", .{ entry.key_ptr.*, b }) catch continue;
                            defer self.allocator.free(line);
                            _ = file.write(line) catch continue;
                        },
                        else => {},
                    }
                }
            },
            else => return error.UnsupportedFormat,
        }
    }

    /// 便捷方法: 设置字符串配置
    pub fn setString(self: *Self, key: []const u8, value: []const u8) !void {
        const result = self.handle(ConfigOp{ .set = .{
            .key = key,
            .value = ConfigValue.string_(value),
        } });
        if (result == .err) return error.SetFailed;
    }

    /// 便捷方法: 设置整数配置
    pub fn setInt(self: *Self, key: []const u8, value: i64) !void {
        const result = self.handle(ConfigOp{ .set = .{
            .key = key,
            .value = ConfigValue.int_(value),
        } });
        if (result == .err) return error.SetFailed;
    }

    /// 便捷方法: 获取字符串配置
    pub fn getString(self: *Self, key: []const u8) ?[]const u8 {
        const result = self.handle(ConfigOp{ .get = .{ .key = key } });
        return switch (result) {
            .value => |v| v.asString(),
            else => null,
        };
    }

    /// 便捷方法: 获取整数配置
    pub fn getInt(self: *Self, key: []const u8) ?i64 {
        const result = self.handle(ConfigOp{ .get = .{ .key = key } });
        return switch (result) {
            .value => |v| v.asInt(),
            else => null,
        };
    }
};

/// 环境变量配置处理器
/// Note: On Windows, environment variable access requires allocation due to WTF-16 encoding.
/// Use EnvConfigHandlerAlloc for cross-platform support with allocator.
pub const EnvConfigHandler = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// 获取环境变量 (POSIX only, not available on Windows)
    pub const get = if (builtin.os.tag == .windows) getWindows else getPosix;

    fn getWindows(_: []const u8) ?[]const u8 {
        return null;
    }

    fn getPosix(key: []const u8) ?[]const u8 {
        return std.posix.getenv(key);
    }

    /// 处理配置操作 (只读)
    /// On Windows, always returns not_found since posix.getenv is unavailable
    pub const handle = if (builtin.os.tag == .windows) handleWindows else handlePosix;

    fn handleWindows(_: Self, op: ConfigOp) ConfigResult {
        return switch (op) {
            .get => ConfigResult{ .not_found = {} },
            .has => ConfigResult{ .bool_result = false },
            .get_or_default => |data| ConfigResult{ .value = data.default },
            else => ConfigResult{ .err = "operation not supported for env config" },
        };
    }

    fn handlePosix(_: Self, op: ConfigOp) ConfigResult {
        return switch (op) {
            .get => |data| {
                if (std.posix.getenv(data.key)) |value| {
                    return ConfigResult{ .value = ConfigValue.string_(value) };
                }
                return ConfigResult{ .not_found = {} };
            },

            .has => |data| {
                return ConfigResult{ .bool_result = std.posix.getenv(data.key) != null };
            },

            .get_or_default => |data| {
                if (std.posix.getenv(data.key)) |value| {
                    return ConfigResult{ .value = ConfigValue.string_(value) };
                }
                return ConfigResult{ .value = data.default };
            },

            else => ConfigResult{ .err = "operation not supported for env config" },
        };
    }
};

/// Cross-platform environment variable handler with allocator support
/// This handler works on all platforms including Windows
pub const EnvConfigHandlerAlloc = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// 获取环境变量 (cross-platform, caller must free result)
    pub fn get(self: Self, key: []const u8) ?[]const u8 {
        const result = std.process.getEnvVarOwned(self.allocator, key) catch return null;
        return result;
    }

    /// 释放由 get 返回的值
    pub fn free(self: Self, value: []const u8) void {
        self.allocator.free(value);
    }

    /// 检查环境变量是否存在
    pub fn has(self: Self, key: []const u8) bool {
        const result = std.process.getEnvVarOwned(self.allocator, key) catch return false;
        self.allocator.free(result);
        return true;
    }
};

// ============ 测试 ============

test "getConfig effect construction" {
    const eff = getConfig("test_key");
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .get);
}

test "setConfig effect construction" {
    const eff = setConfig("test_key", ConfigValue.string_("test_value"));
    try std.testing.expect(eff == .effect_op);
    try std.testing.expect(eff.effect_op.data == .set);
}

test "ConfigValue types" {
    const str = ConfigValue.string_("hello");
    try std.testing.expectEqualStrings("hello", str.asString().?);

    const int_val = ConfigValue.int_(42);
    try std.testing.expectEqual(@as(i64, 42), int_val.asInt().?);

    const float_val = ConfigValue.float_(3.14);
    try std.testing.expect(@abs(float_val.asFloat().? - 3.14) < 0.001);

    const bool_val = ConfigValue.bool_(true);
    try std.testing.expect(bool_val.asBool().?);

    const null_val = ConfigValue.null_();
    try std.testing.expect(null_val.isNull());
}

test "ConfigHandler basic operations" {
    var handler = ConfigHandler.init(std.testing.allocator);
    defer handler.deinit();

    // 设置配置
    const set_result = handler.handle(ConfigOp{ .set = .{
        .key = "test_key",
        .value = ConfigValue.string_("test_value"),
    } });
    try std.testing.expect(set_result == .success);

    // 获取配置
    const get_result = handler.handle(ConfigOp{ .get = .{ .key = "test_key" } });
    try std.testing.expect(get_result == .value);
    try std.testing.expectEqualStrings("test_value", get_result.value.asString().?);

    // 检查存在
    const has_result = handler.handle(ConfigOp{ .has = .{ .key = "test_key" } });
    try std.testing.expect(has_result.bool_result);

    // 获取不存在的键
    const not_found = handler.handle(ConfigOp{ .get = .{ .key = "nonexistent" } });
    try std.testing.expect(not_found == .not_found);

    // 删除配置
    const delete_result = handler.handle(ConfigOp{ .delete = .{ .key = "test_key" } });
    try std.testing.expect(delete_result.bool_result);

    // 再次检查存在
    const has_result2 = handler.handle(ConfigOp{ .has = .{ .key = "test_key" } });
    try std.testing.expect(!has_result2.bool_result);
}

test "ConfigHandler convenience methods" {
    var handler = ConfigHandler.init(std.testing.allocator);
    defer handler.deinit();

    try handler.setString("name", "zigFP");
    try std.testing.expectEqualStrings("zigFP", handler.getString("name").?);

    try handler.setInt("version", 8);
    try std.testing.expectEqual(@as(i64, 8), handler.getInt("version").?);
}

test "ConfigHandler get_or_default" {
    var handler = ConfigHandler.init(std.testing.allocator);
    defer handler.deinit();

    // 获取不存在的键，应返回默认值
    const result = handler.handle(ConfigOp{ .get_or_default = .{
        .key = "missing_key",
        .default = ConfigValue.string_("default_value"),
    } });
    try std.testing.expect(result == .value);
    try std.testing.expectEqualStrings("default_value", result.value.asString().?);
}

test "ConfigHandler clear" {
    var handler = ConfigHandler.init(std.testing.allocator);
    defer handler.deinit();

    try handler.setString("key1", "value1");
    try handler.setString("key2", "value2");

    const clear_result = handler.handle(ConfigOp{ .clear = {} });
    try std.testing.expect(clear_result == .success);

    try std.testing.expect(handler.getString("key1") == null);
    try std.testing.expect(handler.getString("key2") == null);
}

test "EnvConfigHandler" {
    const handler = EnvConfigHandler.init();

    // 测试 PATH 环境变量 (应该存在于大多数系统)
    const result = handler.handle(ConfigOp{ .has = .{ .key = "PATH" } });
    // PATH 在大多数系统上都存在，但我们不能保证，所以只测试返回类型
    try std.testing.expect(result == .bool_result);
}
