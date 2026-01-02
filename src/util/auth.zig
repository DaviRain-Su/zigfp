const std = @import("std");
const Allocator = std.mem.Allocator;
const base64 = std.base64;

/// HTTP 认证模块
///
/// 提供多种认证方式：
/// - BasicAuth - HTTP 基本认证
/// - BearerToken - Bearer Token 认证
/// - ApiKey - API Key 认证（Header 或 Query 参数）
///
/// 示例:
/// ```zig
/// // Basic Auth
/// const basic = BasicAuth.init("username", "password");
/// const header = try basic.toHeader(allocator);
/// defer allocator.free(header);
///
/// // Bearer Token
/// const bearer = BearerToken.init("my-access-token");
/// const auth_header = try bearer.toHeader(allocator);
///
/// // API Key
/// const apikey = ApiKey.init(.header, "X-API-Key", "secret-key");
/// ```
/// 认证类型
pub const AuthType = enum {
    basic,
    bearer,
    api_key_header,
    api_key_query,
    custom,
};

/// 认证凭证接口
pub const Credential = struct {
    auth_type: AuthType,
    /// 生成认证头部
    getHeaderFn: *const fn (*const Credential, Allocator) anyerror!?AuthHeader,
    /// 生成查询参数
    getQueryParamFn: *const fn (*const Credential) ?QueryParam,

    /// 认证头部
    pub const AuthHeader = struct {
        name: []const u8,
        value: []u8,
    };

    /// 查询参数
    pub const QueryParam = struct {
        name: []const u8,
        value: []const u8,
    };

    pub fn getHeader(self: *const Credential, allocator: Allocator) !?AuthHeader {
        return self.getHeaderFn(self, allocator);
    }

    pub fn getQueryParam(self: *const Credential) ?QueryParam {
        return self.getQueryParamFn(self);
    }
};

/// HTTP 基本认证
///
/// 使用 Base64 编码的用户名:密码
pub const BasicAuth = struct {
    username: []const u8,
    password: []const u8,

    const Self = @This();

    /// 创建基本认证
    pub fn init(username: []const u8, password: []const u8) Self {
        return .{
            .username = username,
            .password = password,
        };
    }

    /// 生成认证头部值
    pub fn toHeader(self: *const Self, allocator: Allocator) ![]u8 {
        // 构造 "username:password"
        const credentials = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ self.username, self.password });
        defer allocator.free(credentials);

        // Base64 编码
        const encoder = base64.standard;
        const encoded_len = encoder.Encoder.calcSize(credentials.len);
        const encoded = try allocator.alloc(u8, encoded_len);
        _ = encoder.Encoder.encode(encoded, credentials);

        // 构造 "Basic <encoded>"
        const header_value = try std.fmt.allocPrint(allocator, "Basic {s}", .{encoded});
        allocator.free(encoded);

        return header_value;
    }

    /// 验证凭证格式
    pub fn isValid(self: *const Self) bool {
        return self.username.len > 0;
    }

    /// 获取凭证接口（简化版本）
    pub fn asCredential(self: *const Self) struct { username: []const u8, password: []const u8 } {
        return .{ .username = self.username, .password = self.password };
    }
};

/// Bearer Token 认证
///
/// 用于 OAuth2 和 JWT 等场景
pub const BearerToken = struct {
    token: []const u8,

    const Self = @This();

    /// 创建 Bearer Token 认证
    pub fn init(token: []const u8) Self {
        return .{ .token = token };
    }

    /// 生成认证头部值
    pub fn toHeader(self: *const Self, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "Bearer {s}", .{self.token});
    }

    /// 验证 Token 格式
    pub fn isValid(self: *const Self) bool {
        return self.token.len > 0;
    }

    /// 检查是否是 JWT 格式
    pub fn isJwt(self: *const Self) bool {
        var count: usize = 0;
        for (self.token) |c| {
            if (c == '.') count += 1;
        }
        return count == 2;
    }
};

/// 名值对
pub const NameValuePair = struct {
    name: []const u8,
    value: []const u8,
};

/// API Key 认证
///
/// 支持 Header 和 Query 参数两种方式
pub const ApiKey = struct {
    location: Location,
    key_name: []const u8,
    key_value: []const u8,

    pub const Location = enum {
        header,
        query,
    };

    const Self = @This();

    /// 创建 API Key 认证
    pub fn init(location: Location, key_name: []const u8, key_value: []const u8) Self {
        return .{
            .location = location,
            .key_name = key_name,
            .key_value = key_value,
        };
    }

    /// 创建 Header 方式的 API Key
    pub fn header(key_name: []const u8, key_value: []const u8) Self {
        return init(.header, key_name, key_value);
    }

    /// 创建 Query 参数方式的 API Key
    pub fn query(key_name: []const u8, key_value: []const u8) Self {
        return init(.query, key_name, key_value);
    }

    /// 获取头部名称和值
    pub fn toHeader(self: *const Self) ?NameValuePair {
        if (self.location == .header) {
            return .{ .name = self.key_name, .value = self.key_value };
        }
        return null;
    }

    /// 获取查询参数
    pub fn toQueryParam(self: *const Self) ?NameValuePair {
        if (self.location == .query) {
            return .{ .name = self.key_name, .value = self.key_value };
        }
        return null;
    }

    /// 验证 API Key
    pub fn isValid(self: *const Self) bool {
        return self.key_name.len > 0 and self.key_value.len > 0;
    }
};

/// 自定义认证
pub const CustomAuth = struct {
    header_name: []const u8,
    header_value: []const u8,

    const Self = @This();

    pub fn init(header_name: []const u8, header_value: []const u8) Self {
        return .{
            .header_name = header_name,
            .header_value = header_value,
        };
    }

    pub fn toHeader(self: *const Self) struct { name: []const u8, value: []const u8 } {
        return .{ .name = self.header_name, .value = self.header_value };
    }
};

/// 认证中间件
///
/// 用于自动添加认证信息到请求
pub const AuthMiddleware = struct {
    auth_type: AuthType,
    basic: ?BasicAuth,
    bearer: ?BearerToken,
    api_key: ?ApiKey,
    custom: ?CustomAuth,

    const Self = @This();

    /// 从 BasicAuth 创建
    pub fn fromBasic(basic: BasicAuth) Self {
        return .{
            .auth_type = .basic,
            .basic = basic,
            .bearer = null,
            .api_key = null,
            .custom = null,
        };
    }

    /// 从 BearerToken 创建
    pub fn fromBearer(bearer: BearerToken) Self {
        return .{
            .auth_type = .bearer,
            .basic = null,
            .bearer = bearer,
            .api_key = null,
            .custom = null,
        };
    }

    /// 从 ApiKey 创建
    pub fn fromApiKey(api_key: ApiKey) Self {
        const auth_type: AuthType = if (api_key.location == .header) .api_key_header else .api_key_query;
        return .{
            .auth_type = auth_type,
            .basic = null,
            .bearer = null,
            .api_key = api_key,
            .custom = null,
        };
    }

    /// 从 CustomAuth 创建
    pub fn fromCustom(custom: CustomAuth) Self {
        return .{
            .auth_type = .custom,
            .basic = null,
            .bearer = null,
            .api_key = null,
            .custom = custom,
        };
    }

    /// 获取认证头部
    pub fn getAuthHeader(self: *const Self, allocator: Allocator) !?struct { name: []const u8, value: []u8, owned: bool } {
        switch (self.auth_type) {
            .basic => {
                if (self.basic) |basic| {
                    const value = try basic.toHeader(allocator);
                    return .{ .name = "Authorization", .value = value, .owned = true };
                }
            },
            .bearer => {
                if (self.bearer) |bearer| {
                    const value = try bearer.toHeader(allocator);
                    return .{ .name = "Authorization", .value = value, .owned = true };
                }
            },
            .api_key_header => {
                if (self.api_key) |api_key| {
                    if (api_key.toHeader()) |h| {
                        // 复制值以保持一致的所有权语义
                        const value = try allocator.dupe(u8, h.value);
                        return .{ .name = h.name, .value = value, .owned = true };
                    }
                }
            },
            .api_key_query => return null,
            .custom => {
                if (self.custom) |custom| {
                    const h = custom.toHeader();
                    const value = try allocator.dupe(u8, h.value);
                    return .{ .name = h.name, .value = value, .owned = true };
                }
            },
        }
        return null;
    }

    /// 获取查询参数
    pub fn getQueryParam(self: *const Self) ?NameValuePair {
        if (self.auth_type == .api_key_query) {
            if (self.api_key) |api_key| {
                return api_key.toQueryParam();
            }
        }
        return null;
    }

    /// 验证认证配置是否有效
    pub fn isValid(self: *const Self) bool {
        switch (self.auth_type) {
            .basic => return if (self.basic) |b| b.isValid() else false,
            .bearer => return if (self.bearer) |b| b.isValid() else false,
            .api_key_header, .api_key_query => return if (self.api_key) |a| a.isValid() else false,
            .custom => return self.custom != null,
        }
    }
};

/// 认证构建器 - 流畅 API
pub const AuthBuilder = struct {
    allocator: Allocator,
    middleware: ?AuthMiddleware,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .middleware = null,
        };
    }

    pub fn basic(self: *Self, username: []const u8, password: []const u8) *Self {
        self.middleware = AuthMiddleware.fromBasic(BasicAuth.init(username, password));
        return self;
    }

    pub fn bearer(self: *Self, token: []const u8) *Self {
        self.middleware = AuthMiddleware.fromBearer(BearerToken.init(token));
        return self;
    }

    pub fn apiKeyHeader(self: *Self, key_name: []const u8, key_value: []const u8) *Self {
        self.middleware = AuthMiddleware.fromApiKey(ApiKey.header(key_name, key_value));
        return self;
    }

    pub fn apiKeyQuery(self: *Self, key_name: []const u8, key_value: []const u8) *Self {
        self.middleware = AuthMiddleware.fromApiKey(ApiKey.query(key_name, key_value));
        return self;
    }

    pub fn custom(self: *Self, header_name: []const u8, header_value: []const u8) *Self {
        self.middleware = AuthMiddleware.fromCustom(CustomAuth.init(header_name, header_value));
        return self;
    }

    pub fn build(self: *Self) ?AuthMiddleware {
        return self.middleware;
    }
};

/// 创建认证构建器
pub fn auth(allocator: Allocator) AuthBuilder {
    return AuthBuilder.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "BasicAuth creates valid header" {
    const allocator = std.testing.allocator;

    const basic = BasicAuth.init("user", "pass");
    const header_value = try basic.toHeader(allocator);
    defer allocator.free(header_value);

    // "user:pass" base64 = "dXNlcjpwYXNz"
    try std.testing.expectEqualStrings("Basic dXNlcjpwYXNz", header_value);
}

test "BasicAuth validation" {
    const valid = BasicAuth.init("user", "pass");
    try std.testing.expect(valid.isValid());

    const invalid = BasicAuth.init("", "pass");
    try std.testing.expect(!invalid.isValid());
}

test "BearerToken creates valid header" {
    const allocator = std.testing.allocator;

    const bearer = BearerToken.init("my-token-123");
    const header_value = try bearer.toHeader(allocator);
    defer allocator.free(header_value);

    try std.testing.expectEqualStrings("Bearer my-token-123", header_value);
}

test "BearerToken JWT detection" {
    const jwt = BearerToken.init("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig");
    try std.testing.expect(jwt.isJwt());

    const not_jwt = BearerToken.init("simple-token");
    try std.testing.expect(!not_jwt.isJwt());
}

test "ApiKey header location" {
    const api_key = ApiKey.header("X-API-Key", "secret123");

    try std.testing.expectEqual(ApiKey.Location.header, api_key.location);

    const h = api_key.toHeader();
    try std.testing.expect(h != null);
    try std.testing.expectEqualStrings("X-API-Key", h.?.name);
    try std.testing.expectEqualStrings("secret123", h.?.value);

    try std.testing.expect(api_key.toQueryParam() == null);
}

test "ApiKey query location" {
    const api_key = ApiKey.query("api_key", "secret123");

    try std.testing.expectEqual(ApiKey.Location.query, api_key.location);

    const q = api_key.toQueryParam();
    try std.testing.expect(q != null);
    try std.testing.expectEqualStrings("api_key", q.?.name);
    try std.testing.expectEqualStrings("secret123", q.?.value);

    try std.testing.expect(api_key.toHeader() == null);
}

test "AuthMiddleware from basic" {
    const allocator = std.testing.allocator;

    const middleware = AuthMiddleware.fromBasic(BasicAuth.init("user", "pass"));
    try std.testing.expect(middleware.isValid());

    const header = try middleware.getAuthHeader(allocator);
    try std.testing.expect(header != null);
    try std.testing.expectEqualStrings("Authorization", header.?.name);
    if (header) |h| {
        if (h.owned) {
            allocator.free(h.value);
        }
    }
}

test "AuthMiddleware from bearer" {
    const allocator = std.testing.allocator;

    const middleware = AuthMiddleware.fromBearer(BearerToken.init("token123"));
    try std.testing.expect(middleware.isValid());

    const header = try middleware.getAuthHeader(allocator);
    try std.testing.expect(header != null);
    try std.testing.expectEqualStrings("Authorization", header.?.name);
    try std.testing.expectEqualStrings("Bearer token123", header.?.value);
    if (header) |h| {
        if (h.owned) {
            allocator.free(h.value);
        }
    }
}

test "AuthMiddleware from api key header" {
    const allocator = std.testing.allocator;

    const middleware = AuthMiddleware.fromApiKey(ApiKey.header("X-API-Key", "key123"));
    try std.testing.expect(middleware.isValid());

    const header = try middleware.getAuthHeader(allocator);
    try std.testing.expect(header != null);
    try std.testing.expectEqualStrings("X-API-Key", header.?.name);
    if (header) |h| {
        if (h.owned) {
            allocator.free(h.value);
        }
    }

    try std.testing.expect(middleware.getQueryParam() == null);
}

test "AuthMiddleware from api key query" {
    const allocator = std.testing.allocator;

    const middleware = AuthMiddleware.fromApiKey(ApiKey.query("api_key", "key123"));
    try std.testing.expect(middleware.isValid());

    const header = try middleware.getAuthHeader(allocator);
    try std.testing.expect(header == null);

    const query = middleware.getQueryParam();
    try std.testing.expect(query != null);
    try std.testing.expectEqualStrings("api_key", query.?.name);
}

test "AuthBuilder fluent api" {
    const allocator = std.testing.allocator;

    // Basic auth
    var builder1 = auth(allocator);
    const basic_middleware = builder1.basic("user", "pass").build();
    try std.testing.expect(basic_middleware != null);
    try std.testing.expectEqual(AuthType.basic, basic_middleware.?.auth_type);

    // Bearer token
    var builder2 = auth(allocator);
    const bearer_middleware = builder2.bearer("token").build();
    try std.testing.expect(bearer_middleware != null);
    try std.testing.expectEqual(AuthType.bearer, bearer_middleware.?.auth_type);

    // API Key header
    var builder3 = auth(allocator);
    const apikey_middleware = builder3.apiKeyHeader("X-Key", "val").build();
    try std.testing.expect(apikey_middleware != null);
    try std.testing.expectEqual(AuthType.api_key_header, apikey_middleware.?.auth_type);
}

test "CustomAuth header" {
    const custom = CustomAuth.init("X-Custom-Auth", "custom-value");
    const h = custom.toHeader();

    try std.testing.expectEqualStrings("X-Custom-Auth", h.name);
    try std.testing.expectEqualStrings("custom-value", h.value);
}
