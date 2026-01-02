//! 工具模块
//!
//! 提供常用工具功能：
//! - Auth - HTTP 认证
//! - I18n - 国际化支持
//! - Schema - JSON Schema 验证

const std = @import("std");

pub const auth = @import("auth.zig");
pub const i18n = @import("i18n.zig");
pub const schema = @import("schema.zig");

// ============ Auth ============
pub const AuthType = auth.AuthType;
pub const Credential = auth.Credential;
pub const BasicAuth = auth.BasicAuth;
pub const BearerToken = auth.BearerToken;
pub const ApiKey = auth.ApiKey;

// ============ I18n ============
pub const Locale = i18n.Locale;
pub const MessageBundle = i18n.MessageBundle;

// ============ Schema ============
pub const SchemaType = schema.SchemaType;
pub const ValidationError = schema.ValidationError;
pub const Schema = schema.Schema;

test {
    std.testing.refAllDecls(@This());
}
