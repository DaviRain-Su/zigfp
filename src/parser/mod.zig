//! 解析器模块
//!
//! 提供组合式解析器用于构建复杂解析逻辑：
//! - Parser - 组合式解析器
//! - Json - JSON 解析/序列化
//! - Codec - 通用编解码器

const std = @import("std");

pub const parser = @import("parser.zig");
pub const json = @import("json.zig");
pub const codec = @import("codec.zig");

// ============ Parser ============
pub const ParseResult = parser.ParseResult;
pub const ParseError = parser.ParseError;
pub const Parser = parser.Parser;

// ============ JSON ============
pub const JsonValue = json.JsonValue;
pub const JsonError = json.JsonError;
pub const parseJson = json.parseJson;
pub const stringifyJson = json.stringifyJson;

// ============ Codec ============
pub const CodecError = codec.CodecError;
pub const CodecRegistry = codec.CodecRegistry;
pub const JsonEncoder = codec.JsonEncoder;
pub const JsonDecoder = codec.JsonDecoder;
pub const BinaryEncoder = codec.BinaryEncoder;
pub const BinaryDecoder = codec.BinaryDecoder;

test {
    std.testing.refAllDecls(@This());
}
