//! 函数式HTTP客户端库
//!
//! 提供类型安全、函数式的HTTP请求/响应处理能力。
//! 基于Zig标准库的HTTP支持，添加函数式接口和效果系统集成。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// HTTP方法枚举
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    /// 转换为字符串
    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

/// HTTP 状态码枚举
pub const HttpStatus = enum(u16) {
    // 2xx Success
    ok = 200,
    created = 201,
    accepted = 202,
    no_content = 204,

    // 3xx Redirection
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    not_modified = 304,
    temporary_redirect = 307,
    permanent_redirect = 308,

    // 4xx Client Error
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    gone = 410,
    unprocessable_entity = 422,
    too_many_requests = 429,

    // 5xx Server Error
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,

    /// 检查是否为成功状态 (2xx)
    pub fn isSuccess(self: HttpStatus) bool {
        const status_code = @intFromEnum(self);
        return status_code >= 200 and status_code < 300;
    }

    /// 检查是否为重定向状态 (3xx)
    pub fn isRedirect(self: HttpStatus) bool {
        const status_code = @intFromEnum(self);
        return status_code >= 300 and status_code < 400;
    }

    /// 检查是否为客户端错误 (4xx)
    pub fn isClientError(self: HttpStatus) bool {
        const status_code = @intFromEnum(self);
        return status_code >= 400 and status_code < 500;
    }

    /// 检查是否为服务器错误 (5xx)
    pub fn isServerError(self: HttpStatus) bool {
        const status_code = @intFromEnum(self);
        return status_code >= 500 and status_code < 600;
    }

    /// 获取数值状态码
    pub fn toCode(self: HttpStatus) u16 {
        return @intFromEnum(self);
    }
};

/// HTTP 客户端配置
pub const HttpConfig = struct {
    /// 基础 URL
    base_url: []const u8 = "",
    /// 超时时间（毫秒）
    timeout_ms: u64 = 30000,
    /// 是否跟随重定向
    follow_redirects: bool = true,
    /// 最大重定向次数
    max_redirects: u8 = 5,
    /// 是否验证 SSL 证书
    verify_ssl: bool = true,
    /// 用户代理
    user_agent: []const u8 = "zigFP/1.0",
    /// 默认请求头
    default_headers: []const HttpHeader = &.{},
};

/// HTTP请求头
pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,

    /// 创建请求头
    pub fn init(name: []const u8, value: []const u8) HttpHeader {
        return HttpHeader{
            .name = name,
            .value = value,
        };
    }
};

/// HTTP请求
pub const HttpRequest = struct {
    allocator: Allocator,
    method: HttpMethod,
    url: []const u8,
    headers: std.ArrayList(HttpHeader),
    body: ?[]const u8,

    /// 创建GET请求
    pub fn get(allocator: Allocator, url: []const u8) !HttpRequest {
        return HttpRequest{
            .allocator = allocator,
            .method = .GET,
            .url = try allocator.dupe(u8, url),
            .headers = try std.ArrayList(HttpHeader).initCapacity(allocator, 8),
            .body = null,
        };
    }

    /// 创建POST请求
    pub fn post(allocator: Allocator, url: []const u8, body: []const u8) !HttpRequest {
        return HttpRequest{
            .allocator = allocator,
            .method = .POST,
            .url = try allocator.dupe(u8, url),
            .headers = try std.ArrayList(HttpHeader).initCapacity(allocator, 8),
            .body = try allocator.dupe(u8, body),
        };
    }

    /// 添加请求头
    pub fn withHeader(self: *HttpRequest, name: []const u8, value: []const u8) !void {
        try self.headers.append(self.allocator, HttpHeader.init(
            try self.allocator.dupe(u8, name),
            try self.allocator.dupe(u8, value),
        ));
    }

    /// 设置Content-Type为JSON
    pub fn withJsonContentType(self: *HttpRequest) !void {
        try self.withHeader("Content-Type", "application/json");
    }

    /// 设置Content-Type为表单
    pub fn withFormContentType(self: *HttpRequest) !void {
        try self.withHeader("Content-Type", "application/x-www-form-urlencoded");
    }

    /// 销毁请求及其所有资源
    pub fn deinit(self: *HttpRequest) void {
        self.allocator.free(self.url);
        for (self.headers.items) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.headers.deinit(self.allocator);
        if (self.body) |body| {
            self.allocator.free(body);
        }
        self.* = undefined;
    }
};

/// HTTP响应
pub const HttpResponse = struct {
    allocator: Allocator,
    status_code: u16,
    status_text: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []u8,

    /// 创建响应
    pub fn init(allocator: Allocator, status_code: u16, status_text: []const u8, body: []u8) !HttpResponse {
        return HttpResponse{
            .allocator = allocator,
            .status_code = status_code,
            .status_text = try allocator.dupe(u8, status_text),
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = body,
        };
    }

    /// 添加响应头
    pub fn addHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.headers.put(name_copy, value_copy);
    }

    /// 获取响应头
    pub fn getHeader(self: HttpResponse, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    /// 检查响应是否成功 (2xx状态码)
    pub fn isSuccess(self: HttpResponse) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    /// 销毁响应及其所有资源
    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.status_text);
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        self.allocator.free(self.body);
        self.* = undefined;
    }
};

/// HTTP错误
pub const HttpError = error{
    InvalidUrl,
    ConnectionFailed,
    Timeout,
    InvalidResponse,
    OutOfMemory,
    UnsupportedMethod,
};

/// HTTP客户端
pub const HttpClient = struct {
    allocator: Allocator,
    client: std.http.Client,

    /// 创建HTTP客户端
    pub fn init(allocator: Allocator) HttpClient {
        return HttpClient{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    /// 销毁客户端
    pub fn deinit(self: *HttpClient) void {
        self.client.deinit();
    }

    /// 发送HTTP请求
    pub fn send(self: *HttpClient, request: HttpRequest) !HttpResponse {
        // 解析URL
        const uri = std.Uri.parse(request.url) catch return HttpError.InvalidUrl;

        // 创建HTTP请求
        const method: std.http.Method = switch (request.method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
            .HEAD => .HEAD,
            .OPTIONS => .OPTIONS,
        };

        // 构建 extra_headers
        var extra_headers_buf: [32]std.http.Header = undefined;
        var extra_header_count: usize = 1; // 预留 User-Agent

        extra_headers_buf[0] = .{ .name = "User-Agent", .value = "zigFP/0.9.0" };

        // 添加自定义请求头
        for (request.headers.items) |header| {
            if (extra_header_count < extra_headers_buf.len) {
                extra_headers_buf[extra_header_count] = .{ .name = header.name, .value = header.value };
                extra_header_count += 1;
            }
        }

        var req = self.client.request(method, uri, .{
            .extra_headers = extra_headers_buf[0..extra_header_count],
        }) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // 发送请求体（如果有）
        if (request.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
            var body_writer = req.sendBodyUnflushed(&.{}) catch return HttpError.ConnectionFailed;
            body_writer.writer.writeAll(body) catch return HttpError.ConnectionFailed;
            body_writer.end() catch return HttpError.ConnectionFailed;
            if (req.connection) |conn| {
                conn.flush() catch {};
            }
        } else {
            req.sendBodiless() catch return HttpError.ConnectionFailed;
        }

        // 接收响应头
        var response = req.receiveHead(&.{}) catch return HttpError.InvalidResponse;

        // 检查状态码
        if (response.head.status != .ok) {
            // 对于非200响应，我们仍然读取body以便返回完整的响应
        }

        // 读取响应体
        var reader = response.reader(&.{});
        const body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return HttpError.InvalidResponse;

        // 创建响应对象
        var http_response = try HttpResponse.init(self.allocator, @intFromEnum(response.head.status), "", body);

        // 添加响应头 (Zig 0.15: iterateHeaders 在 head 上)
        var header_it = response.head.iterateHeaders();
        while (header_it.next()) |header| {
            try http_response.addHeader(header.name, header.value);
        }

        // 设置状态文本
        const status_text = switch (response.head.status) {
            .ok => "OK",
            .created => "Created",
            .accepted => "Accepted",
            .no_content => "No Content",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .not_modified => "Not Modified",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .internal_server_error => "Internal Server Error",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
            else => "Unknown",
        };
        self.allocator.free(http_response.status_text);
        http_response.status_text = try self.allocator.dupe(u8, status_text);

        return http_response;
    }
};

// ============ 便捷函数 ============

/// 发送GET请求
pub fn get(allocator: Allocator, url: []const u8) !HttpResponse {
    var client = HttpClient.init(allocator);
    defer client.deinit();

    var request = try HttpRequest.get(allocator, url);
    defer request.deinit();

    return client.send(request);
}

/// 发送POST请求
pub fn post(allocator: Allocator, url: []const u8, body: []const u8) !HttpResponse {
    var client = HttpClient.init(allocator);
    defer client.deinit();

    var request = try HttpRequest.post(allocator, url, body);
    defer request.deinit();

    return client.send(request);
}

/// 发送JSON POST请求
pub fn postJson(allocator: Allocator, url: []const u8, json_body: []const u8) !HttpResponse {
    var client = HttpClient.init(allocator);
    defer client.deinit();

    var request = try HttpRequest.post(allocator, url, json_body);
    defer request.deinit();

    try request.withJsonContentType();

    return client.send(request);
}

// ============ HTTP Effect ============

/// HTTP效果类型
pub const HttpEffect = struct {
    request: HttpRequest,

    const Self = @This();

    /// 创建GET效果
    pub fn get(allocator: Allocator, url: []const u8) !Self {
        return Self{
            .request = try HttpRequest.get(allocator, url),
        };
    }

    /// 创建POST效果
    pub fn post(allocator: Allocator, url: []const u8, body: []const u8) !Self {
        return Self{
            .request = try HttpRequest.post(allocator, url, body),
        };
    }

    /// 添加请求头
    pub fn withHeader(self: *Self, name: []const u8, value: []const u8) !*Self {
        try self.request.withHeader(name, value);
        return self;
    }

    /// 设置超时（毫秒）- 存储在请求元数据中
    pub fn withTimeout(self: *Self, timeout_ms: u64) *Self {
        // 注意：Zig std.http.Client 不直接支持超时
        // 这里我们可以存储超时值用于将来的实现
        _ = timeout_ms;
        return self;
    }

    /// 执行HTTP效果
    pub fn run(self: *Self, allocator: Allocator) !HttpResponse {
        var client = HttpClient.init(allocator);
        defer client.deinit();
        return client.send(self.request);
    }

    /// 销毁效果
    pub fn deinit(self: *Self) void {
        self.request.deinit();
    }
};

/// 重试配置
pub const RetryConfig = struct {
    /// 最大重试次数
    max_retries: u32 = 3,
    /// 初始延迟（毫秒）
    initial_delay_ms: u64 = 100,
    /// 延迟倍数（指数退避）
    backoff_multiplier: f32 = 2.0,
    /// 最大延迟（毫秒）
    max_delay_ms: u64 = 10000,
    /// 可重试的状态码
    retryable_status_codes: []const u16 = &[_]u16{ 429, 500, 502, 503, 504 },
};

/// 带重试的HTTP请求执行器
pub const RetryableHttpClient = struct {
    allocator: Allocator,
    config: RetryConfig,

    const Self = @This();

    /// 创建可重试客户端
    pub fn init(allocator: Allocator, config: RetryConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// 执行带重试的请求
    pub fn execute(self: *Self, request: HttpRequest) !HttpResponse {
        var client = HttpClient.init(self.allocator);
        defer client.deinit();

        var attempts: u32 = 0;
        var delay_ms: u64 = self.config.initial_delay_ms;

        while (attempts <= self.config.max_retries) {
            const response = client.send(request) catch |err| {
                attempts += 1;
                if (attempts > self.config.max_retries) {
                    return err;
                }
                // 等待后重试
                std.time.sleep(delay_ms * std.time.ns_per_ms);
                delay_ms = @min(
                    @as(u64, @intFromFloat(@as(f32, @floatFromInt(delay_ms)) * self.config.backoff_multiplier)),
                    self.config.max_delay_ms,
                );
                continue;
            };

            // 检查是否需要重试
            var should_retry = false;
            for (self.config.retryable_status_codes) |code| {
                if (response.status_code == code) {
                    should_retry = true;
                    break;
                }
            }

            if (should_retry and attempts < self.config.max_retries) {
                attempts += 1;
                std.time.sleep(delay_ms * std.time.ns_per_ms);
                delay_ms = @min(
                    @as(u64, @intFromFloat(@as(f32, @floatFromInt(delay_ms)) * self.config.backoff_multiplier)),
                    self.config.max_delay_ms,
                );
                continue;
            }

            return response;
        }

        return HttpError.ConnectionFailed;
    }
};

/// 解析JSON响应为JsonValue
pub fn parseJsonResponse(allocator: Allocator, response: HttpResponse) !@import("../parser/json.zig").JsonValue {
    const json = @import("../parser/json.zig");

    if (!response.isSuccess()) {
        return HttpError.InvalidResponse;
    }

    return json.parseJson(allocator, response.body);
}

/// 请求构建器 - 链式API
pub const RequestBuilder = struct {
    allocator: Allocator,
    method: HttpMethod,
    url: []const u8,
    headers: std.ArrayList(HttpHeader),
    body: ?[]const u8,
    timeout_ms: ?u64,

    const Self = @This();

    /// 创建构建器
    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .method = .GET,
            .url = "",
            .headers = try std.ArrayList(HttpHeader).initCapacity(allocator, 8),
            .body = null,
            .timeout_ms = null,
        };
    }

    /// 销毁构建器
    pub fn deinit(self: *Self) void {
        for (self.headers.items) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.headers.deinit(self.allocator);
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
        if (self.body) |body| {
            self.allocator.free(body);
        }
    }

    /// 设置方法
    pub fn setMethod(self: *Self, method: HttpMethod) *Self {
        self.method = method;
        return self;
    }

    /// 设置URL
    pub fn setUrl(self: *Self, url: []const u8) !*Self {
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
        self.url = try self.allocator.dupe(u8, url);
        return self;
    }

    /// 添加请求头
    pub fn addHeader(self: *Self, name: []const u8, value: []const u8) !*Self {
        try self.headers.append(self.allocator, HttpHeader.init(
            try self.allocator.dupe(u8, name),
            try self.allocator.dupe(u8, value),
        ));
        return self;
    }

    /// 设置JSON Content-Type
    pub fn json(self: *Self) !*Self {
        return self.addHeader("Content-Type", "application/json");
    }

    /// 设置请求体
    pub fn setBody(self: *Self, body: []const u8) !*Self {
        if (self.body) |old_body| {
            self.allocator.free(old_body);
        }
        self.body = try self.allocator.dupe(u8, body);
        return self;
    }

    /// 设置超时
    pub fn setTimeout(self: *Self, timeout_ms: u64) *Self {
        self.timeout_ms = timeout_ms;
        return self;
    }

    /// 构建请求
    pub fn build(self: *Self) !HttpRequest {
        var request = HttpRequest{
            .allocator = self.allocator,
            .method = self.method,
            .url = try self.allocator.dupe(u8, self.url),
            .headers = try std.ArrayList(HttpHeader).initCapacity(self.allocator, self.headers.items.len),
            .body = if (self.body) |b| try self.allocator.dupe(u8, b) else null,
        };

        for (self.headers.items) |header| {
            try request.headers.append(self.allocator, HttpHeader.init(
                try self.allocator.dupe(u8, header.name),
                try self.allocator.dupe(u8, header.value),
            ));
        }

        return request;
    }
};

/// HTTP中间件类型
pub const Middleware = *const fn (*HttpRequest) HttpError!void;

/// 中间件链
pub const MiddlewareChain = struct {
    middlewares: std.ArrayList(Middleware),
    allocator: Allocator,

    const Self = @This();

    /// 创建中间件链
    pub fn init(allocator: Allocator) !Self {
        return Self{
            .middlewares = try std.ArrayList(Middleware).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    /// 销毁中间件链
    pub fn deinit(self: *Self) void {
        self.middlewares.deinit(self.allocator);
    }

    /// 添加中间件
    pub fn use(self: *Self, middleware: Middleware) !*Self {
        try self.middlewares.append(self.allocator, middleware);
        return self;
    }

    /// 执行中间件链
    pub fn execute(self: *Self, request: *HttpRequest) !void {
        for (self.middlewares.items) |middleware| {
            try middleware(request);
        }
    }
};

/// 常用中间件 - 添加认证头
pub fn authMiddleware(token: []const u8) Middleware {
    const S = struct {
        var stored_token: []const u8 = undefined;

        fn apply(request: *HttpRequest) HttpError!void {
            request.withHeader("Authorization", stored_token) catch return HttpError.OutOfMemory;
        }
    };
    S.stored_token = token;
    return S.apply;
}

// ============ 测试 ============

test "HttpRequest creation" {
    var request = try HttpRequest.get(std.testing.allocator, "https://httpbin.org/get");
    defer request.deinit();

    try std.testing.expect(request.method == .GET);
    try std.testing.expect(std.mem.eql(u8, request.url, "https://httpbin.org/get"));
    try std.testing.expect(request.body == null);
}

test "HttpRequest with headers" {
    var request = try HttpRequest.get(std.testing.allocator, "https://httpbin.org/get");
    defer request.deinit();

    try request.withHeader("Accept", "application/json");
    try std.testing.expect(request.headers.items.len == 1);
    try std.testing.expect(std.mem.eql(u8, request.headers.items[0].name, "Accept"));
    try std.testing.expect(std.mem.eql(u8, request.headers.items[0].value, "application/json"));
}

test "HttpResponse creation" {
    var response = try HttpResponse.init(std.testing.allocator, 200, "OK", try std.testing.allocator.dupe(u8, "test response"));
    defer response.deinit();

    try std.testing.expect(response.status_code == 200);
    try std.testing.expect(std.mem.eql(u8, response.status_text, "OK"));
    try std.testing.expect(std.mem.eql(u8, response.body, "test response"));
    try std.testing.expect(response.isSuccess());
}

test "HttpMethod to string" {
    try std.testing.expect(std.mem.eql(u8, HttpMethod.GET.toString(), "GET"));
    try std.testing.expect(std.mem.eql(u8, HttpMethod.POST.toString(), "POST"));
    try std.testing.expect(std.mem.eql(u8, HttpMethod.PUT.toString(), "PUT"));
    try std.testing.expect(std.mem.eql(u8, HttpMethod.DELETE.toString(), "DELETE"));
}

test "RequestBuilder" {
    var builder = try RequestBuilder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.setUrl("https://example.com/api");
    _ = builder.setMethod(.POST);
    _ = try builder.addHeader("Accept", "application/json");
    _ = try builder.json();
    _ = try builder.setBody("{\"key\": \"value\"}");
    _ = builder.setTimeout(5000);

    var request = try builder.build();
    defer request.deinit();

    try std.testing.expect(request.method == .POST);
    try std.testing.expect(std.mem.eql(u8, request.url, "https://example.com/api"));
    try std.testing.expect(request.headers.items.len == 2);
    try std.testing.expect(request.body != null);
}

test "HttpEffect creation" {
    var effect = try HttpEffect.get(std.testing.allocator, "https://example.com");
    defer effect.deinit();

    try std.testing.expect(effect.request.method == .GET);
}

test "RetryConfig default" {
    const config = RetryConfig{};
    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(@as(u64, 100), config.initial_delay_ms);
}

test "MiddlewareChain" {
    var chain = try MiddlewareChain.init(std.testing.allocator);
    defer chain.deinit();

    // 添加一个简单的中间件
    const add_header = struct {
        fn apply(request: *HttpRequest) HttpError!void {
            try request.withHeader("X-Test", "test-value");
        }
    }.apply;

    _ = try chain.use(add_header);
    try std.testing.expectEqual(@as(usize, 1), chain.middlewares.items.len);
}
