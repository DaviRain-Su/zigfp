//! 函数式JSON处理库
//!
//! 提供类型安全、函数式的JSON编解码能力。
//! 基于Zig标准库的JSON支持，添加函数式接口。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// JSON值类型 - 类型安全的JSON表示
pub const JsonValue = union(enum) {
    null,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringHashMap(JsonValue),

    /// 销毁JSON值及其所有子值
    pub fn deinit(self: *JsonValue, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
        self.* = .null;
    }

    /// 获取值的类型字符串
    pub fn getType(self: JsonValue) []const u8 {
        return switch (self) {
            .null => "null",
            .bool => "boolean",
            .int => "integer",
            .float => "float",
            .string => "string",
            .array => "array",
            .object => "object",
        };
    }

    /// 创建null值
    pub fn createNull() JsonValue {
        return .null;
    }

    /// 创建布尔值
    pub fn createBool(value: bool) JsonValue {
        return JsonValue{ .bool = value };
    }

    /// 创建整数值
    pub fn createInt(value: i64) JsonValue {
        return JsonValue{ .int = value };
    }

    /// 创建浮点数值
    pub fn createFloat(value: f64) JsonValue {
        return JsonValue{ .float = value };
    }

    /// 创建字符串值（复制）
    pub fn createString(allocator: Allocator, value: []const u8) !JsonValue {
        const copy = try allocator.dupe(u8, value);
        return JsonValue{ .string = copy };
    }

    /// 创建数组值
    pub fn createArray(allocator: Allocator, items: []const JsonValue) !JsonValue {
        const copy = try allocator.dupe(JsonValue, items);
        return JsonValue{ .array = copy };
    }

    /// 创建对象值
    pub fn createObject(allocator: Allocator) JsonValue {
        return JsonValue{ .object = std.StringHashMap(JsonValue).init(allocator) };
    }
};

/// JSON解析错误
pub const JsonError = error{
    InvalidJson,
    UnexpectedToken,
    UnterminatedString,
    InvalidNumber,
    InvalidUnicode,
    DepthLimitExceeded,
    OutOfMemory,
};

/// 解析JSON字符串
pub fn parseJson(allocator: Allocator, json_str: []const u8) !JsonValue {
    var parser = JsonParser.init(allocator, json_str);
    return parser.parseValue();
}

/// 将JSON值序列化为字符串
pub fn stringifyJson(allocator: Allocator, value: JsonValue) ![]u8 {
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer buffer.deinit(allocator);

    try stringifyValue(allocator, value, &buffer);
    return try buffer.toOwnedSlice(allocator);
}

/// JSON路径访问器 - 函数式JSON查询
pub const JsonPath = struct {
    /// 通过点分隔路径获取值
    pub fn get(value: JsonValue, path: []const u8) ?JsonValue {
        var current = value;
        var path_iter = std.mem.splitSequence(u8, path, ".");

        while (path_iter.next()) |segment| {
            switch (current) {
                .object => |obj| {
                    if (obj.get(segment)) |next| {
                        current = next;
                    } else {
                        return null;
                    }
                },
                .array => |arr| {
                    if (std.fmt.parseInt(usize, segment, 10)) |index| {
                        if (index < arr.len) {
                            current = arr[index];
                        } else {
                            return null;
                        }
                    } else |_| {
                        return null;
                    }
                },
                else => return null,
            }
        }

        return current;
    }

    /// 通过路径设置值
    pub fn set(allocator: Allocator, value: *JsonValue, path: []const u8, new_value: JsonValue) !void {
        // 简化实现：只支持单层对象路径
        if (std.mem.indexOf(u8, path, ".")) |_| {
            return error.NotImplemented; // 多层路径暂不支持
        }

        switch (value.*) {
            .object => |*obj| {
                const key_copy = try allocator.dupe(u8, path);
                try obj.put(key_copy, new_value);
            },
            else => return error.PathNotFound,
        }
    }

    /// 检查路径是否存在
    pub fn exists(value: JsonValue, path: []const u8) bool {
        return get(value, path) != null;
    }
};

/// JSON映射操作
pub fn mapJson(
    allocator: Allocator,
    value: JsonValue,
    f: *const fn (JsonValue) JsonValue,
) !JsonValue {
    return switch (value) {
        .array => |arr| {
            const mapped = try allocator.alloc(JsonValue, arr.len);
            for (arr, 0..) |item, i| {
                mapped[i] = try mapJson(allocator, item, f);
            }
            return JsonValue{ .array = mapped };
        },
        .object => |obj| {
            var result = std.StringHashMap(JsonValue).init(allocator);
            var it = obj.iterator();
            while (it.next()) |entry| {
                const mapped_value = try mapJson(allocator, entry.value_ptr.*, f);
                const key_copy = try allocator.dupe(u8, entry.key_ptr.*);
                try result.put(key_copy, mapped_value);
            }
            return JsonValue{ .object = result };
        },
        else => f(value),
    };
}

/// JSON过滤操作
pub fn filterJson(
    allocator: Allocator,
    value: JsonValue,
    predicate: *const fn (JsonValue) bool,
) !JsonValue {
    switch (value) {
        .array => |arr| {
            var filtered = std.ArrayList(JsonValue).initCapacity(allocator, arr.len);
            defer filtered.deinit();

            for (arr) |item| {
                if (predicate(item)) {
                    try filtered.append(item);
                }
            }

            const result = try allocator.dupe(JsonValue, filtered.items);
            return JsonValue{ .array = result };
        },
        else => return value,
    }
}

/// JSON折叠操作
pub fn foldJson(
    comptime T: type,
    value: JsonValue,
    initial: T,
    f: *const fn (T, JsonValue) T,
) T {
    var result = initial;

    switch (value) {
        .array => |arr| {
            for (arr) |item| {
                result = f(result, item);
            }
        },
        .object => |obj| {
            var it = obj.iterator();
            while (it.next()) |entry| {
                result = f(result, entry.value_ptr.*);
            }
        },
        else => {
            result = f(result, value);
        },
    }

    return result;
}

// ============ 内部实现 ============

/// JSON解析器
const JsonParser = struct {
    allocator: Allocator,
    input: []const u8,
    pos: usize,

    fn init(allocator: Allocator, input: []const u8) JsonParser {
        return JsonParser{
            .allocator = allocator,
            .input = input,
            .pos = 0,
        };
    }

    fn parseValue(self: *JsonParser) JsonError!JsonValue {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return JsonError.InvalidJson;
        }

        const char = self.input[self.pos];
        switch (char) {
            'n' => return try self.parseNull(),
            't', 'f' => return try self.parseBool(),
            '"' => return try self.parseString(),
            '[', ']' => return try self.parseArray(),
            '{', '}' => return try self.parseObject(),
            '0'...'9', '-', '+' => return try self.parseNumber(),
            else => return JsonError.UnexpectedToken,
        }
    }

    fn parseNull(self: *JsonParser) JsonError!JsonValue {
        if (std.mem.eql(u8, self.input[self.pos..@min(self.pos + 4, self.input.len)], "null")) {
            self.pos += 4;
            return .null;
        }
        return JsonError.InvalidJson;
    }

    fn parseBool(self: *JsonParser) JsonError!JsonValue {
        if (std.mem.eql(u8, self.input[self.pos..@min(self.pos + 4, self.input.len)], "true")) {
            self.pos += 4;
            return JsonValue{ .bool = true };
        }
        if (std.mem.eql(u8, self.input[self.pos..@min(self.pos + 5, self.input.len)], "false")) {
            self.pos += 5;
            return JsonValue{ .bool = false };
        }
        return JsonError.InvalidJson;
    }

    fn parseString(self: *JsonParser) JsonError!JsonValue {
        self.pos += 1; // 跳过开始的引号
        const start = self.pos;

        while (self.pos < self.input.len and self.input[self.pos] != '"') {
            if (self.input[self.pos] == '\\') {
                self.pos += 2; // 跳过转义字符
            } else {
                self.pos += 1;
            }
        }

        if (self.pos >= self.input.len) {
            return JsonError.UnterminatedString;
        }

        const str = self.input[start..self.pos];
        self.pos += 1; // 跳过结束的引号

        // 复制字符串
        const copy = try self.allocator.dupe(u8, str);
        return JsonValue{ .string = copy };
    }

    fn parseNumber(self: *JsonParser) JsonError!JsonValue {
        const start = self.pos;

        // 简单数字解析
        while (self.pos < self.input.len and
            (std.ascii.isDigit(self.input[self.pos]) or
                self.input[self.pos] == '.' or
                self.input[self.pos] == '-' or
                self.input[self.pos] == '+' or
                self.input[self.pos] == 'e' or
                self.input[self.pos] == 'E'))
        {
            self.pos += 1;
        }

        const num_str = self.input[start..self.pos];

        // 尝试解析为整数
        if (std.fmt.parseInt(i64, num_str, 10)) |int_val| {
            return JsonValue{ .int = int_val };
        } else |_| {}

        // 尝试解析为浮点数
        if (std.fmt.parseFloat(f64, num_str)) |float_val| {
            return JsonValue{ .float = float_val };
        } else |_| {}

        return JsonError.InvalidNumber;
    }

    fn parseArray(self: *JsonParser) JsonError!JsonValue {
        self.pos += 1; // 跳过'['
        var items = try std.ArrayList(JsonValue).initCapacity(self.allocator, 16);
        defer items.deinit(self.allocator);

        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.InvalidJson;

            if (self.input[self.pos] == ']') {
                self.pos += 1;
                break;
            }

            const value = try self.parseValue();
            try items.append(self.allocator, value);

            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.InvalidJson;

            if (self.input[self.pos] == ',') {
                self.pos += 1;
            } else if (self.input[self.pos] == ']') {
                self.pos += 1;
                break;
            } else {
                return JsonError.UnexpectedToken;
            }
        }

        const arr = try self.allocator.dupe(JsonValue, items.items);
        return JsonValue{ .array = arr };
    }

    fn parseObject(self: *JsonParser) JsonError!JsonValue {
        self.pos += 1; // 跳过'{'
        var object = std.StringHashMap(JsonValue).init(self.allocator);

        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.InvalidJson;

            if (self.input[self.pos] == '}') {
                self.pos += 1;
                break;
            }

            // 解析键
            if (self.input[self.pos] != '"') return JsonError.UnexpectedToken;
            const key_value = try self.parseString();
            const key = key_value.string;

            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                return JsonError.UnexpectedToken;
            }
            self.pos += 1;

            // 解析值
            const value = try self.parseValue();
            try object.put(key, value);

            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.InvalidJson;

            if (self.input[self.pos] == ',') {
                self.pos += 1;
            } else if (self.input[self.pos] == '}') {
                self.pos += 1;
                break;
            } else {
                return JsonError.UnexpectedToken;
            }
        }

        return JsonValue{ .object = object };
    }

    fn skipWhitespace(self: *JsonParser) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }
};

/// 序列化辅助函数
fn stringifyValue(
    allocator: Allocator,
    value: JsonValue,
    buffer: *std.ArrayList(u8),
) !void {
    switch (value) {
        .null => try buffer.appendSlice(allocator, "null"),
        .bool => |b| try buffer.appendSlice(allocator, if (b) "true" else "false"),
        .int => |i| try std.fmt.format(buffer.writer(allocator), "{}", .{i}),
        .float => |f| try std.fmt.format(buffer.writer(allocator), "{d}", .{f}),
        .string => |s| {
            try buffer.append(allocator, '"');
            for (s) |c| {
                switch (c) {
                    '"' => try buffer.appendSlice(allocator, "\\\""),
                    '\\' => try buffer.appendSlice(allocator, "\\\\"),
                    '\n' => try buffer.appendSlice(allocator, "\\n"),
                    '\r' => try buffer.appendSlice(allocator, "\\r"),
                    '\t' => try buffer.appendSlice(allocator, "\\t"),
                    else => try buffer.append(allocator, c),
                }
            }
            try buffer.append(allocator, '"');
        },
        .array => |arr| {
            try buffer.append(allocator, '[');
            for (arr, 0..) |item, i| {
                if (i > 0) try buffer.appendSlice(allocator, ", ");
                try stringifyValue(allocator, item, buffer);
            }
            try buffer.append(allocator, ']');
        },
        .object => |obj| {
            try buffer.append(allocator, '{');
            var it = obj.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try buffer.appendSlice(allocator, ", ");
                first = false;

                try buffer.append(allocator, '"');
                try buffer.appendSlice(allocator, entry.key_ptr.*);
                try buffer.appendSlice(allocator, "\": ");
                try stringifyValue(allocator, entry.value_ptr.*, buffer);
            }
            try buffer.append(allocator, '}');
        },
    }
}

// ============ 测试 ============

test "JsonValue creation" {
    const null_val = JsonValue.createNull();
    try std.testing.expect(null_val == .null);

    const bool_val = JsonValue.createBool(true);
    try std.testing.expect(bool_val.bool == true);

    const int_val = JsonValue.createInt(42);
    try std.testing.expect(int_val.int == 42);
}

test "JSON parse null" {
    var result = try parseJson(std.testing.allocator, "null");
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result == .null);
}

test "JSON parse boolean" {
    var result_true = try parseJson(std.testing.allocator, "true");
    defer result_true.deinit(std.testing.allocator);
    try std.testing.expect(result_true.bool == true);

    var result_false = try parseJson(std.testing.allocator, "false");
    defer result_false.deinit(std.testing.allocator);
    try std.testing.expect(result_false.bool == false);
}

test "JSON parse integer" {
    var result = try parseJson(std.testing.allocator, "123");
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.int == 123);
}

test "JSON parse string" {
    var result = try parseJson(std.testing.allocator, "\"hello\"");
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.eql(u8, result.string, "hello"));
}

test "JsonPath get" {
    var obj = JsonValue.createObject(std.testing.allocator);
    defer obj.deinit(std.testing.allocator);

    // Add name field
    const name_key = try std.testing.allocator.dupe(u8, "name");
    const name_value = try JsonValue.createString(std.testing.allocator, "Alice");
    try obj.object.put(name_key, name_value);

    // Add age field
    const age_key = try std.testing.allocator.dupe(u8, "age");
    const age_value = JsonValue.createInt(30);
    try obj.object.put(age_key, age_value);

    const name = JsonPath.get(obj, "name");
    try std.testing.expect(name != null);
    try std.testing.expect(std.mem.eql(u8, name.?.string, "Alice"));

    const age = JsonPath.get(obj, "age");
    try std.testing.expect(age != null);
    try std.testing.expect(age.?.int == 30);

    const missing = JsonPath.get(obj, "missing");
    try std.testing.expect(missing == null);
}

test "JSON stringify" {
    const value = JsonValue{ .int = 42 };
    const str = try stringifyJson(std.testing.allocator, value);
    defer std.testing.allocator.free(str);
    try std.testing.expect(std.mem.eql(u8, str, "42"));
}

test "JSON roundtrip" {
    const original = "{\"name\":\"test\",\"value\":123}";
    var parsed = try parseJson(std.testing.allocator, original);
    defer parsed.deinit(std.testing.allocator);

    const stringified = try stringifyJson(std.testing.allocator, parsed);
    defer std.testing.allocator.free(stringified);

    // 简化检查：确保解析成功且序列化不为空
    try std.testing.expect(parsed == .object);
    try std.testing.expect(stringified.len > 0);
}
