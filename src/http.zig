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
        const method = switch (request.method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
            .HEAD => .HEAD,
            .OPTIONS => .OPTIONS,
        };

        var req = self.client.request(method, uri, .{
            .extra_headers = &.{
                .{ .name = "User-Agent", .value = "zigFP/0.9.0" },
            },
        }) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // 添加自定义请求头
        for (request.headers.items) |header| {
            req.headers.add(header.name, header.value) catch {};
        }

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

        // 添加响应头
        var header_it = response.iterateHeaders();
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
