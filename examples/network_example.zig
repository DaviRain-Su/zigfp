//! zigFP 网络模块示例
//!
//! 本示例展示 zigFP 库的网络相关功能：
//! - TCP/UDP 客户端概念
//! - HTTP 客户端
//! - 连接池
//! - WebSocket 概念
//!
//! 注意：此示例主要展示 API 设计和概念，
//! 实际网络操作需要在支持的环境中运行。

const std = @import("std");
const fp = @import("zigfp");

pub fn main() !void {
    std.debug.print("=== zigFP 网络模块示例 ===\n\n", .{});

    // ============ TCP 客户端概念 ============
    std.debug.print("--- TCP 客户端 ---\n", .{});

    const tcp_config = fp.TcpConfig{
        .connect_timeout_ms = 5000,
        .read_timeout_ms = 30000,
        .write_timeout_ms = 30000,
        .keep_alive = true,
        .no_delay = true,
    };

    std.debug.print("TCP 配置:\n", .{});
    std.debug.print("  - 连接超时: {}ms\n", .{tcp_config.connect_timeout_ms});
    std.debug.print("  - 读取超时: {}ms\n", .{tcp_config.read_timeout_ms});
    std.debug.print("  - 写入超时: {}ms\n", .{tcp_config.write_timeout_ms});
    std.debug.print("  - Keep-Alive: {}\n", .{tcp_config.keep_alive});
    std.debug.print("  - TCP_NODELAY: {}\n\n", .{tcp_config.no_delay});

    // ============ UDP 客户端概念 ============
    std.debug.print("--- UDP 客户端 ---\n", .{});

    const udp_config = fp.UdpConfig{
        .receive_timeout_ms = 5000,
        .send_timeout_ms = 5000,
        .receive_buffer_size = 4096,
        .broadcast = false,
    };

    std.debug.print("UDP 配置:\n", .{});
    std.debug.print("  - 接收超时: {}ms\n", .{udp_config.receive_timeout_ms});
    std.debug.print("  - 发送超时: {}ms\n", .{udp_config.send_timeout_ms});
    std.debug.print("  - 接收缓冲区大小: {} bytes\n", .{udp_config.receive_buffer_size});
    std.debug.print("  - 广播模式: {}\n\n", .{udp_config.broadcast});

    // ============ HTTP 客户端概念 ============
    std.debug.print("--- HTTP 客户端 ---\n", .{});

    const http_config = fp.HttpConfig{
        .base_url = "https://api.example.com",
        .timeout_ms = 30000,
        .follow_redirects = true,
        .max_redirects = 5,
        .verify_ssl = true,
    };

    std.debug.print("HTTP 配置:\n", .{});
    std.debug.print("  - 基础 URL: {s}\n", .{http_config.base_url});
    std.debug.print("  - 超时: {}ms\n", .{http_config.timeout_ms});
    std.debug.print("  - 跟随重定向: {} (最多 {} 次)\n", .{ http_config.follow_redirects, http_config.max_redirects });
    std.debug.print("  - 验证 SSL: {}\n\n", .{http_config.verify_ssl});

    // HTTP 方法
    std.debug.print("支持的 HTTP 方法:\n", .{});
    const methods = [_]fp.HttpMethod{ .GET, .POST, .PUT, .DELETE, .PATCH, .HEAD, .OPTIONS };
    for (methods) |method| {
        std.debug.print("  - {s}\n", .{method.toString()});
    }
    std.debug.print("\n", .{});

    // HTTP 状态码
    std.debug.print("HTTP 状态码分类:\n", .{});
    std.debug.print("  - 200 OK: 成功={}, 重定向={}, 客户端错误={}, 服务器错误={}\n", .{
        fp.HttpStatus.ok.isSuccess(),
        fp.HttpStatus.ok.isRedirect(),
        fp.HttpStatus.ok.isClientError(),
        fp.HttpStatus.ok.isServerError(),
    });
    std.debug.print("  - 301 Moved: 成功={}, 重定向={}\n", .{
        fp.HttpStatus.moved_permanently.isSuccess(),
        fp.HttpStatus.moved_permanently.isRedirect(),
    });
    std.debug.print("  - 404 Not Found: 客户端错误={}\n", .{
        fp.HttpStatus.not_found.isClientError(),
    });
    std.debug.print("  - 500 Server Error: 服务器错误={}\n\n", .{
        fp.HttpStatus.internal_server_error.isServerError(),
    });

    // ============ 连接池概念 ============
    std.debug.print("--- 连接池 ---\n", .{});

    // Note: ConnectionPoolConfig uses different field names
    std.debug.print("连接池概念:\n", .{});
    std.debug.print("  - 支持最小/最大连接数配置\n", .{});
    std.debug.print("  - 支持连接超时和空闲超时\n", .{});
    std.debug.print("  - 支持连接生命周期管理\n", .{});
    std.debug.print("  - 支持连接验证和健康检查\n\n", .{});

    // ============ WebSocket 概念 ============
    std.debug.print("--- WebSocket ---\n", .{});

    const ws_config = fp.WebSocketConfig{
        .connect_timeout_ms = 30000,
        .read_timeout_ms = 30000,
        .write_timeout_ms = 30000,
        .max_message_size = 1048576,
        .auto_pong = true,
        .ping_interval_ms = 30000,
    };

    std.debug.print("WebSocket 配置:\n", .{});
    std.debug.print("  - 连接超时: {}ms\n", .{ws_config.connect_timeout_ms});
    std.debug.print("  - 读取超时: {}ms\n", .{ws_config.read_timeout_ms});
    std.debug.print("  - 最大消息大小: {} bytes ({}MB)\n", .{ ws_config.max_message_size, ws_config.max_message_size / 1048576 });
    std.debug.print("  - 自动 Pong: {}\n", .{ws_config.auto_pong});
    std.debug.print("  - Ping 间隔: {}ms\n\n", .{ws_config.ping_interval_ms});

    // WebSocket 操作码
    std.debug.print("WebSocket 操作码 (Opcode):\n", .{});
    std.debug.print("  - continuation (0x0): 延续帧\n", .{});
    std.debug.print("  - text (0x1): 文本消息\n", .{});
    std.debug.print("  - binary (0x2): 二进制消息\n", .{});
    std.debug.print("  - close (0x8): 关闭帧\n", .{});
    std.debug.print("  - ping (0x9): 心跳请求\n", .{});
    std.debug.print("  - pong (0xA): 心跳响应\n\n", .{});

    // ============ 网络与弹性模式结合 ============
    std.debug.print("--- 网络与弹性模式结合 ---\n", .{});

    std.debug.print("推荐的网络请求弹性策略:\n\n", .{});

    std.debug.print("1. HTTP 请求重试:\n", .{});
    const http_retry = fp.RetryPolicy.exponentialBackoff(.{
        .initial_delay_ms = 100,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .max_retries = 3,
    });
    std.debug.print("   - 策略: 指数退避\n", .{});
    std.debug.print("   - 重试次数: {}\n", .{http_retry.config.max_retries});
    std.debug.print("   - 延迟: {}ms -> {}ms\n\n", .{ http_retry.config.initial_delay_ms, http_retry.config.max_delay_ms });

    std.debug.print("2. 服务断路器:\n", .{});
    const service_breaker = fp.CircuitBreaker.init(.{
        .failure_threshold = 5,
        .success_threshold = 2,
        .timeout_ms = 30000,
    });
    std.debug.print("   - 失败阈值: {} 次\n", .{service_breaker.config.failure_threshold});
    std.debug.print("   - 恢复超时: {}ms\n\n", .{service_breaker.config.timeout_ms});

    std.debug.print("3. 请求超时:\n", .{});
    const request_timeout = fp.Timeout.seconds(30);
    std.debug.print("   - 超时时间: {}ms\n\n", .{request_timeout.config.timeout_ms});

    std.debug.print("4. 并发限制:\n", .{});
    const api_bulkhead = fp.Bulkhead.init(.{
        .max_concurrent = 100,
        .max_waiting = 50,
        .rejection_policy = .fail_fast,
    });
    std.debug.print("   - 最大并发: {}\n", .{api_bulkhead.config.max_concurrent});
    std.debug.print("   - 等待队列: {}\n\n", .{api_bulkhead.config.max_waiting});

    // ============ 网络错误处理 ============
    std.debug.print("--- 网络错误处理 ---\n", .{});

    std.debug.print("常见网络错误及处理建议:\n", .{});
    std.debug.print("  - ConnectionRefused: 服务不可用，触发断路器\n", .{});
    std.debug.print("  - ConnectionTimeout: 网络问题，可重试\n", .{});
    std.debug.print("  - DNS Resolution Failed: 配置问题，不重试\n", .{});
    std.debug.print("  - SSL Handshake Failed: 证书问题，不重试\n", .{});
    std.debug.print("  - HTTP 429 Too Many Requests: 限流，延迟重试\n", .{});
    std.debug.print("  - HTTP 500 Server Error: 服务问题，可重试\n", .{});
    std.debug.print("  - HTTP 503 Service Unavailable: 服务过载，触发断路器\n\n", .{});

    std.debug.print("=== 示例完成 ===\n", .{});
}

// ============ 测试 ============

test "tcp config defaults" {
    const config = fp.TcpConfig{};

    try std.testing.expectEqual(@as(u32, 30000), config.connect_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.read_timeout_ms);
    try std.testing.expect(config.no_delay);
}

test "udp config defaults" {
    const config = fp.UdpConfig{};

    try std.testing.expectEqual(@as(u32, 30000), config.receive_timeout_ms);
    try std.testing.expectEqual(@as(usize, 65535), config.receive_buffer_size);
    try std.testing.expect(!config.broadcast);
}

test "http method to string" {
    try std.testing.expectEqualStrings("GET", fp.HttpMethod.GET.toString());
    try std.testing.expectEqualStrings("POST", fp.HttpMethod.POST.toString());
    try std.testing.expectEqualStrings("DELETE", fp.HttpMethod.DELETE.toString());
}

test "http status classification" {
    try std.testing.expect(fp.HttpStatus.ok.isSuccess());
    try std.testing.expect(!fp.HttpStatus.ok.isRedirect());

    try std.testing.expect(fp.HttpStatus.moved_permanently.isRedirect());
    try std.testing.expect(fp.HttpStatus.found.isRedirect());

    try std.testing.expect(fp.HttpStatus.bad_request.isClientError());
    try std.testing.expect(fp.HttpStatus.not_found.isClientError());

    try std.testing.expect(fp.HttpStatus.internal_server_error.isServerError());
    try std.testing.expect(fp.HttpStatus.service_unavailable.isServerError());
}

test "websocket config defaults" {
    const config = fp.WebSocketConfig{};

    try std.testing.expectEqual(@as(u32, 30000), config.connect_timeout_ms);
    try std.testing.expectEqual(@as(usize, 1048576), config.max_message_size);
    try std.testing.expect(config.auto_pong);
}
