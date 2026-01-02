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

// ============ 编解码器组合 ============

/// 编解码器接口
pub fn Codec(comptime T: type) type {
    return struct {
        encodeFn: *const fn (Allocator, T) CodecError![]u8,
        decodeFn: *const fn (Allocator, []const u8) CodecError!T,

        const Self = @This();

        /// 编码
        pub fn encode(self: Self, allocator: Allocator, value: T) ![]u8 {
            return self.encodeFn(allocator, value);
        }

        /// 解码
        pub fn decode(self: Self, allocator: Allocator, data: []const u8) !T {
            return self.decodeFn(allocator, data);
        }

        /// 组合两个编解码器（编码后再编码）
        pub fn compose(self: Self, other: Codec([]u8)) Codec(T) {
            const S = struct {
                var inner: Self = undefined;
                var outer: Codec([]u8) = undefined;

                fn composedEncode(allocator: Allocator, value: T) CodecError![]u8 {
                    const intermediate = try inner.encode(allocator, value);
                    defer allocator.free(intermediate);
                    return outer.encode(allocator, intermediate);
                }

                fn composedDecode(allocator: Allocator, data: []const u8) CodecError!T {
                    const intermediate = try outer.decode(allocator, data);
                    defer allocator.free(intermediate);
                    return inner.decode(allocator, intermediate);
                }
            };
            S.inner = self;
            S.outer = other;
            return Codec(T){
                .encodeFn = S.composedEncode,
                .decodeFn = S.composedDecode,
            };
        }

        /// 转换编解码器（使用映射函数）
        pub fn contramap(
            self: Self,
            comptime U: type,
            from: *const fn (U) T,
            to: *const fn (T) U,
        ) Codec(U) {
            const S = struct {
                var base: Self = undefined;
                var fromFn: *const fn (U) T = undefined;
                var toFn: *const fn (T) U = undefined;

                fn encode(allocator: Allocator, value: U) CodecError![]u8 {
                    return base.encode(allocator, fromFn(value));
                }

                fn decode(allocator: Allocator, data: []const u8) CodecError!U {
                    const decoded = try base.decode(allocator, data);
                    return toFn(decoded);
                }
            };
            S.base = self;
            S.fromFn = from;
            S.toFn = to;
            return Codec(U){
                .encodeFn = S.encode,
                .decodeFn = S.decode,
            };
        }
    };
}

/// 自定义编解码器构建器
pub fn CustomCodec(comptime T: type) type {
    return struct {
        encoder: ?*const fn (Allocator, T) CodecError![]u8,
        decoder: ?*const fn (Allocator, []const u8) CodecError!T,

        const Self = @This();

        /// 创建空构建器
        pub fn init() Self {
            return Self{
                .encoder = null,
                .decoder = null,
            };
        }

        /// 设置编码器
        pub fn withEncoder(self: *Self, enc: *const fn (Allocator, T) CodecError![]u8) *Self {
            self.encoder = enc;
            return self;
        }

        /// 设置解码器
        pub fn withDecoder(self: *Self, dec: *const fn (Allocator, []const u8) CodecError!T) *Self {
            self.decoder = dec;
            return self;
        }

        /// 构建编解码器
        pub fn build(self: *Self) !Codec(T) {
            if (self.encoder == null or self.decoder == null) {
                return CodecError.UnsupportedType;
            }
            return Codec(T){
                .encodeFn = self.encoder.?,
                .decodeFn = self.decoder.?,
            };
        }
    };
}

/// Base64编解码器
pub const Base64Codec = struct {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// 创建Base64编解码器
    pub fn codec() Codec([]u8) {
        return Codec([]u8){
            .encodeFn = encode,
            .decodeFn = decode,
        };
    }

    fn encode(allocator: Allocator, data: []u8) CodecError![]u8 {
        const output_len = ((data.len + 2) / 3) * 4;
        const output = allocator.alloc(u8, output_len) catch return CodecError.OutOfMemory;

        var i: usize = 0;
        var o: usize = 0;
        while (i < data.len) : (o += 4) {
            const n = @min(3, data.len - i);
            var buf: [3]u8 = .{ 0, 0, 0 };
            @memcpy(buf[0..n], data[i .. i + n]);

            output[o] = alphabet[buf[0] >> 2];
            output[o + 1] = alphabet[((buf[0] & 0x03) << 4) | (buf[1] >> 4)];
            output[o + 2] = if (n > 1) alphabet[((buf[1] & 0x0f) << 2) | (buf[2] >> 6)] else '=';
            output[o + 3] = if (n > 2) alphabet[buf[2] & 0x3f] else '=';

            i += 3;
        }

        return output;
    }

    fn decode(allocator: Allocator, data: []const u8) CodecError![]u8 {
        if (data.len % 4 != 0) {
            return CodecError.InvalidData;
        }

        var padding: usize = 0;
        if (data.len > 0 and data[data.len - 1] == '=') padding += 1;
        if (data.len > 1 and data[data.len - 2] == '=') padding += 1;

        const output_len = (data.len / 4) * 3 - padding;
        const output = allocator.alloc(u8, output_len) catch return CodecError.OutOfMemory;

        var i: usize = 0;
        var o: usize = 0;
        while (i < data.len) : (i += 4) {
            const a = decodeChar(data[i]) catch return CodecError.InvalidData;
            const b = decodeChar(data[i + 1]) catch return CodecError.InvalidData;
            const c = if (data[i + 2] == '=') @as(u6, 0) else decodeChar(data[i + 2]) catch return CodecError.InvalidData;
            const d = if (data[i + 3] == '=') @as(u6, 0) else decodeChar(data[i + 3]) catch return CodecError.InvalidData;

            if (o < output_len) output[o] = (@as(u8, a) << 2) | (b >> 4);
            o += 1;
            if (o < output_len) output[o] = (@as(u8, b & 0x0f) << 4) | (c >> 2);
            o += 1;
            if (o < output_len) output[o] = (@as(u8, c & 0x03) << 6) | d;
            o += 1;
        }

        return output;
    }

    fn decodeChar(c: u8) !u6 {
        if (c >= 'A' and c <= 'Z') return @intCast(c - 'A');
        if (c >= 'a' and c <= 'z') return @intCast(c - 'a' + 26);
        if (c >= '0' and c <= '9') return @intCast(c - '0' + 52);
        if (c == '+') return 62;
        if (c == '/') return 63;
        return error.InvalidChar;
    }
};

/// Hex编解码器
pub const HexCodec = struct {
    const hex_chars = "0123456789abcdef";

    /// 创建Hex编解码器
    pub fn codec() Codec([]u8) {
        return Codec([]u8){
            .encodeFn = encode,
            .decodeFn = decode,
        };
    }

    fn encode(allocator: Allocator, data: []u8) CodecError![]u8 {
        const output = allocator.alloc(u8, data.len * 2) catch return CodecError.OutOfMemory;

        for (data, 0..) |byte, i| {
            output[i * 2] = hex_chars[byte >> 4];
            output[i * 2 + 1] = hex_chars[byte & 0x0f];
        }

        return output;
    }

    fn decode(allocator: Allocator, data: []const u8) CodecError![]u8 {
        if (data.len % 2 != 0) {
            return CodecError.InvalidData;
        }

        const output = allocator.alloc(u8, data.len / 2) catch return CodecError.OutOfMemory;

        var i: usize = 0;
        while (i < data.len) : (i += 2) {
            const high = hexValue(data[i]) catch return CodecError.InvalidData;
            const low = hexValue(data[i + 1]) catch return CodecError.InvalidData;
            output[i / 2] = (@as(u8, high) << 4) | low;
        }

        return output;
    }

    fn hexValue(c: u8) !u4 {
        if (c >= '0' and c <= '9') return @intCast(c - '0');
        if (c >= 'a' and c <= 'f') return @intCast(c - 'a' + 10);
        if (c >= 'A' and c <= 'F') return @intCast(c - 'A' + 10);
        return error.InvalidHex;
    }
};

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

test "HexCodec encode decode" {
    var data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex_codec = HexCodec.codec();

    const encoded = try hex_codec.encode(std.testing.allocator, &data);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.eql(u8, encoded, "deadbeef"));

    const decoded = try hex_codec.decode(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expect(std.mem.eql(u8, decoded, &data));
}

test "Base64Codec encode decode" {
    var data = [_]u8{ 'H', 'e', 'l', 'l', 'o' };
    const b64_codec = Base64Codec.codec();

    const encoded = try b64_codec.encode(std.testing.allocator, &data);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.eql(u8, encoded, "SGVsbG8="));

    const decoded = try b64_codec.decode(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expect(std.mem.eql(u8, decoded, &data));
}

test "CustomCodec builder" {
    const IntCodec = CustomCodec(i32);
    var builder = IntCodec.init();

    _ = builder.withEncoder(struct {
        fn enc(allocator: Allocator, value: i32) CodecError![]u8 {
            const result = allocator.alloc(u8, 4) catch return CodecError.OutOfMemory;
            const bytes = std.mem.asBytes(&value);
            @memcpy(result, bytes);
            return result;
        }
    }.enc);

    _ = builder.withDecoder(struct {
        fn dec(_: Allocator, data: []const u8) CodecError!i32 {
            if (data.len != 4) return CodecError.InvalidData;
            var result: i32 = undefined;
            const bytes = std.mem.asBytes(&result);
            @memcpy(bytes, data[0..4]);
            return result;
        }
    }.dec);

    const codec = try builder.build();

    const encoded = try codec.encode(std.testing.allocator, 42);
    defer std.testing.allocator.free(encoded);

    const decoded = try codec.decode(std.testing.allocator, encoded);
    try std.testing.expectEqual(@as(i32, 42), decoded);
}
