//! 通用编解码器框架
//!
//! 提供类型安全、函数式的序列化/反序列化能力。
//! 支持多种格式（JSON、二进制等），可扩展的编解码器系统。

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json.zig");

/// 编解码器错误
pub const CodecError = error{
    UnsupportedType,
    InvalidData,
    EncodingFailed,
    DecodingFailed,
    OutOfMemory,
};

/// 编解码器注册表
pub const CodecRegistry = struct {
    allocator: Allocator,
    json_encoder: JsonEncoder,
    json_decoder: JsonDecoder,
    binary_encoder: BinaryEncoder,
    binary_decoder: BinaryDecoder,

    /// 创建编解码器注册表
    pub fn init(allocator: Allocator) CodecRegistry {
        return CodecRegistry{
            .allocator = allocator,
            .json_encoder = JsonEncoder.init(),
            .json_decoder = JsonDecoder.init(),
            .binary_encoder = BinaryEncoder.init(),
            .binary_decoder = BinaryDecoder.init(),
        };
    }

    /// 销毁注册表
    pub fn deinit(self: *CodecRegistry) void {
        _ = self;
    }

    /// 编码值
    pub fn encode(self: *CodecRegistry, allocator: Allocator, format: []const u8, value: anytype) ![]u8 {
        if (std.mem.eql(u8, format, "json")) {
            return self.json_encoder.encode(allocator, value);
        } else if (std.mem.eql(u8, format, "binary")) {
            return self.binary_encoder.encode(allocator, value);
        } else {
            return CodecError.UnsupportedType;
        }
    }

    /// 解码数据
    pub fn decode(self: *CodecRegistry, allocator: Allocator, format: []const u8, data: []const u8, comptime T: type) !T {
        if (std.mem.eql(u8, format, "json")) {
            return self.json_decoder.decode(allocator, data, T);
        } else if (std.mem.eql(u8, format, "binary")) {
            return self.binary_decoder.decode(allocator, data, T);
        } else {
            return CodecError.UnsupportedType;
        }
    }
};

// ============ JSON 编解码器 ============

/// JSON编码器
pub const JsonEncoder = struct {
    /// 编码值
    pub fn encode(self: *const JsonEncoder, allocator: Allocator, value: anytype) ![]u8 {
        _ = self;
        // 使用现有的json模块进行编码
        var json_value = try jsonValueFromType(allocator, value);
        defer json_value.deinit(allocator);
        return json.stringifyJson(allocator, json_value);
    }

    /// 将Zig值转换为JsonValue
    fn jsonValueFromType(allocator: Allocator, value: anytype) !json.JsonValue {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .bool => return json.JsonValue.createBool(value),
            .int, .comptime_int => return json.JsonValue.createInt(@intCast(value)),
            .float, .comptime_float => return json.JsonValue.createFloat(@floatCast(value)),
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    // 字符串
                    return json.JsonValue.createString(allocator, value);
                } else {
                    return CodecError.UnsupportedType;
                }
            },
            .array => {
                var arr = try json.JsonValue.createArray(allocator, &[_]json.JsonValue{});
                for (value) |item| {
                    const json_item = try jsonValueFromType(allocator, item);
                    try arr.array.append(allocator, json_item);
                }
                return arr;
            },
            .@"struct" => |struct_info| {
                var obj = json.JsonValue.createObject(allocator);
                inline for (struct_info.fields) |field| {
                    const field_value = @field(value, field.name);
                    const json_field_value = try jsonValueFromType(allocator, field_value);
                    const field_name_copy = try allocator.dupe(u8, field.name);
                    try obj.object.put(field_name_copy, json_field_value);
                }
                return obj;
            },
            else => return CodecError.UnsupportedType,
        }
    }
};

/// JSON解码器
pub const JsonDecoder = struct {
    /// 解码数据
    pub fn decode(self: *const JsonDecoder, allocator: Allocator, data: []const u8, comptime T: type) !T {
        _ = self;
        var json_value = try json.parseJson(allocator, data);
        defer json_value.deinit(allocator);
        return try valueFromJsonValue(T, json_value);
    }

    /// 从JsonValue转换为Zig值
    fn valueFromJsonValue(comptime T: type, json_value: json.JsonValue) !T {
        switch (@typeInfo(T)) {
            .bool => {
                if (json_value == .bool) return json_value.bool;
                return CodecError.InvalidData;
            },
            .int => {
                if (json_value == .int) return @intCast(json_value.int);
                return CodecError.InvalidData;
            },
            .float => {
                if (json_value == .float) return @floatCast(json_value.float);
                return CodecError.InvalidData;
            },
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    if (json_value == .string) {
                        // 需要复制字符串，因为调用者期望拥有所有权
                        // 这里简化实现，实际应该传递allocator
                        return CodecError.UnsupportedType;
                    }
                    return CodecError.InvalidData;
                } else {
                    return CodecError.UnsupportedType;
                }
            },
            .array => |arr| {
                if (json_value == .array and json_value.array.len == arr.len) {
                    var result: T = undefined;
                    for (json_value.array, 0..) |item, i| {
                        result[i] = try valueFromJsonValue(arr.child, item);
                    }
                    return result;
                }
                return CodecError.InvalidData;
            },
            .@"struct" => |struct_info| {
                if (json_value != .object) return CodecError.InvalidData;
                var result: T = undefined;
                inline for (struct_info.fields) |field| {
                    if (json_value.object.get(field.name)) |field_value| {
                        @field(result, field.name) = try valueFromJsonValue(field.type, field_value);
                    } else {
                        return CodecError.InvalidData;
                    }
                }
                return result;
            },
            else => return CodecError.UnsupportedType,
        }
    }
};

// ============ 二进制编解码器 ============

/// 二进制编码器
pub const BinaryEncoder = struct {
    /// 编码值
    pub fn encode(self: *const BinaryEncoder, allocator: Allocator, value: anytype) ![]u8 {
        _ = self;
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 1024);
        defer buffer.deinit(allocator);

        try encodeValue(allocator, &buffer, value);
        return try buffer.toOwnedSlice(allocator);
    }

    /// 编码值到缓冲区
    fn encodeValue(allocator: Allocator, buffer: *std.ArrayList(u8), value: anytype) !void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .bool => {
                try buffer.append(allocator, if (value) 1 else 0);
            },
            .int => {
                const bytes = std.mem.asBytes(&value);
                try buffer.appendSlice(allocator, bytes);
            },
            .float => {
                const bytes = std.mem.asBytes(&value);
                try buffer.appendSlice(allocator, bytes);
            },
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    // 字符串：长度 + 数据
                    const len = @as(u32, @intCast(value.len));
                    const len_bytes = std.mem.asBytes(&len);
                    try buffer.appendSlice(allocator, len_bytes);
                    try buffer.appendSlice(allocator, value);
                } else {
                    return CodecError.UnsupportedType;
                }
            },
            .array => {
                for (value) |item| {
                    try encodeValue(allocator, buffer, item);
                }
            },
            .@"struct" => |struct_info| {
                inline for (struct_info.fields) |field| {
                    try encodeValue(allocator, buffer, @field(value, field.name));
                }
            },
            else => return CodecError.UnsupportedType,
        }
    }
};

/// 二进制解码器
pub const BinaryDecoder = struct {
    /// 解码数据
    pub fn decode(self: *const BinaryDecoder, allocator: Allocator, data: []const u8, comptime T: type) !T {
        _ = self;
        var stream = std.io.fixedBufferStream(data);
        var reader = stream.reader();
        return try decodeValue(allocator, &reader, T);
    }

    /// 从流中解码值
    fn decodeValue(allocator: Allocator, reader: anytype, comptime T: type) !T {
        switch (@typeInfo(T)) {
            .bool => {
                const byte = try reader.readByte();
                return byte != 0;
            },
            .int => {
                var result: T = undefined;
                const bytes = std.mem.asBytes(&result);
                _ = try reader.read(bytes);
                return result;
            },
            .float => {
                var result: T = undefined;
                const bytes = std.mem.asBytes(&result);
                _ = try reader.read(bytes);
                return result;
            },
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    var len: u32 = undefined;
                    const len_bytes = std.mem.asBytes(&len);
                    _ = try reader.read(len_bytes);
                    const result = try allocator.alloc(u8, len);
                    _ = try reader.read(result);
                    return result;
                } else {
                    return CodecError.UnsupportedType;
                }
            },
            .array => |arr| {
                var result: T = undefined;
                for (&result) |*item| {
                    item.* = try decodeValue(allocator, reader, arr.child);
                }
                return result;
            },
            .@"struct" => |struct_info| {
                var result: T = undefined;
                inline for (struct_info.fields) |field| {
                    @field(result, field.name) = try decodeValue(allocator, reader, field.type);
                }
                return result;
            },
            else => return CodecError.UnsupportedType,
        }
    }
};

// ============ 便捷函数 ============

/// 编码值到JSON格式
pub fn encodeJson(allocator: Allocator, value: anytype) ![]u8 {
    var encoder = JsonEncoder{};
    return encoder.encode(allocator, value);
}

/// 解码JSON数据为指定类型
pub fn decodeJson(allocator: Allocator, data: []const u8, comptime T: type) !T {
    var decoder = JsonDecoder{};
    return decoder.decode(allocator, data, T);
}

/// 编码值到二进制格式
pub fn encodeBinary(allocator: Allocator, value: anytype) ![]u8 {
    var encoder = BinaryEncoder{};
    return encoder.encode(allocator, value);
}

/// 解码二进制数据为指定类型
pub fn decodeBinary(allocator: Allocator, data: []const u8, comptime T: type) !T {
    var decoder = BinaryDecoder{};
    return decoder.decode(allocator, data, T);
}

// ============ 测试 ============

test "JSON codec basic types" {
    // 测试布尔值
    const encoded_bool = try encodeJson(std.testing.allocator, true);
    defer std.testing.allocator.free(encoded_bool);
    const decoded_bool = try decodeJson(std.testing.allocator, encoded_bool, bool);
    try std.testing.expect(decoded_bool == true);

    // 测试整数
    const encoded_int = try encodeJson(std.testing.allocator, @as(i32, 42));
    defer std.testing.allocator.free(encoded_int);
    const decoded_int = try decodeJson(std.testing.allocator, encoded_int, i32);
    try std.testing.expect(decoded_int == 42);
}

test "JSON codec struct" {
    const Person = struct {
        age: i32,
        active: bool,
    };

    const person = Person{
        .age = 30,
        .active = true,
    };

    const encoded = try encodeJson(std.testing.allocator, person);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeJson(std.testing.allocator, encoded, Person);
    try std.testing.expect(decoded.age == person.age);
    try std.testing.expect(decoded.active == person.active);
}

test "Binary codec basic types" {
    // 测试整数
    const encoded_int = try encodeBinary(std.testing.allocator, @as(i32, 12345));
    defer std.testing.allocator.free(encoded_int);
    const decoded_int = try decodeBinary(std.testing.allocator, encoded_int, i32);
    try std.testing.expect(decoded_int == 12345);

    // 测试浮点数
    const encoded_float = try encodeBinary(std.testing.allocator, @as(f32, 3.14));
    defer std.testing.allocator.free(encoded_float);
    const decoded_float = try decodeBinary(std.testing.allocator, encoded_float, f32);
    try std.testing.expect(decoded_float == 3.14);
}
