const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const posix = std.posix;

/// 函数式 TCP 客户端模块
///
/// 提供类型安全的 TCP 网络操作：
/// - 连接管理（connect/disconnect）
/// - 数据收发（send/receive）
/// - 超时配置
/// - 错误处理
///
/// 示例:
/// ```zig
/// var client = try TcpClient.connect(allocator, "127.0.0.1", 8080, .{});
/// defer client.close();
///
/// try client.send("Hello, Server!");
/// const response = try client.receive(allocator);
/// defer allocator.free(response);
/// ```
/// TCP 客户端配置
pub const TcpConfig = struct {
    /// 连接超时（毫秒）
    connect_timeout_ms: u32 = 30000,
    /// 读取超时（毫秒）
    read_timeout_ms: u32 = 30000,
    /// 写入超时（毫秒）
    write_timeout_ms: u32 = 30000,
    /// 接收缓冲区大小
    receive_buffer_size: usize = 4096,
    /// 是否启用 TCP_NODELAY
    no_delay: bool = true,
    /// 是否启用 keep-alive
    keep_alive: bool = false,
};

/// TCP 错误类型
pub const TcpError = error{
    ConnectionFailed,
    ConnectionClosed,
    ConnectionReset,
    Timeout,
    InvalidAddress,
    SendFailed,
    ReceiveFailed,
    AlreadyConnected,
    NotConnected,
    OutOfMemory,
    AddressInUse,
    NetworkUnreachable,
    HostUnreachable,
    Unexpected,
};

/// TCP 连接状态
pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    closing,
    closed,
};

/// TCP 客户端
pub const TcpClient = struct {
    allocator: Allocator,
    config: TcpConfig,
    stream: ?net.Stream,
    state: ConnectionState,
    remote_address: ?net.Address,
    local_address: ?net.Address,
    bytes_sent: u64,
    bytes_received: u64,

    const Self = @This();

    /// 创建未连接的客户端
    pub fn init(allocator: Allocator, config: TcpConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .stream = null,
            .state = .disconnected,
            .remote_address = null,
            .local_address = null,
            .bytes_sent = 0,
            .bytes_received = 0,
        };
    }

    /// 连接到服务器
    pub fn connect(allocator: Allocator, host: []const u8, port: u16, config: TcpConfig) TcpError!Self {
        var client = init(allocator, config);
        try client.connectTo(host, port);
        return client;
    }

    /// 连接到指定地址
    pub fn connectTo(self: *Self, host: []const u8, port: u16) TcpError!void {
        if (self.state == .connected) {
            return TcpError.AlreadyConnected;
        }

        self.state = .connecting;

        // 解析地址
        const address = net.Address.parseIp(host, port) catch |err| {
            self.state = .disconnected;
            return switch (err) {
                else => TcpError.InvalidAddress,
            };
        };

        // 建立连接
        self.stream = net.tcpConnectToAddress(address) catch |err| {
            self.state = .disconnected;
            return mapConnectError(err);
        };

        self.remote_address = address;
        self.state = .connected;

        // 配置套接字选项
        if (self.stream) |stream| {
            self.configureSocket(stream) catch {};
        }
    }

    /// 配置套接字选项
    fn configureSocket(self: *Self, stream: net.Stream) !void {
        const fd = stream.handle;

        // TCP_NODELAY
        if (self.config.no_delay) {
            posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.NODELAY, &std.mem.toBytes(@as(c_int, 1))) catch {};
        }

        // SO_KEEPALIVE
        if (self.config.keep_alive) {
            posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.KEEPALIVE, &std.mem.toBytes(@as(c_int, 1))) catch {};
        }

        // 读取超时
        if (self.config.read_timeout_ms > 0) {
            const timeout = posix.timeval{
                .sec = @intCast(self.config.read_timeout_ms / 1000),
                .usec = @intCast((self.config.read_timeout_ms % 1000) * 1000),
            };
            posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout)) catch {};
        }

        // 写入超时
        if (self.config.write_timeout_ms > 0) {
            const timeout = posix.timeval{
                .sec = @intCast(self.config.write_timeout_ms / 1000),
                .usec = @intCast((self.config.write_timeout_ms % 1000) * 1000),
            };
            posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout)) catch {};
        }
    }

    /// 发送数据
    pub fn send(self: *Self, data: []const u8) TcpError!usize {
        if (self.state != .connected) {
            return TcpError.NotConnected;
        }

        const stream = self.stream orelse return TcpError.NotConnected;

        const sent = stream.write(data) catch |err| {
            return mapWriteError(err);
        };

        self.bytes_sent += sent;
        return sent;
    }

    /// 发送所有数据
    pub fn sendAll(self: *Self, data: []const u8) TcpError!void {
        if (self.state != .connected) {
            return TcpError.NotConnected;
        }

        const stream = self.stream orelse return TcpError.NotConnected;

        stream.writeAll(data) catch |err| {
            return mapWriteError(err);
        };

        self.bytes_sent += data.len;
    }

    /// 接收数据到缓冲区
    pub fn receiveInto(self: *Self, buffer: []u8) TcpError!usize {
        if (self.state != .connected) {
            return TcpError.NotConnected;
        }

        const stream = self.stream orelse return TcpError.NotConnected;

        const received = stream.read(buffer) catch |err| {
            return mapReadError(err);
        };

        if (received == 0) {
            self.state = .closed;
            return TcpError.ConnectionClosed;
        }

        self.bytes_received += received;
        return received;
    }

    /// 接收数据（分配内存）
    pub fn receive(self: *Self, allocator: Allocator) TcpError![]u8 {
        var buffer = allocator.alloc(u8, self.config.receive_buffer_size) catch {
            return TcpError.OutOfMemory;
        };
        errdefer allocator.free(buffer);

        const received = try self.receiveInto(buffer);

        // 调整到实际大小
        const result = allocator.realloc(buffer, received) catch {
            return buffer[0..received];
        };
        return result[0..received];
    }

    /// 接收指定长度的数据
    pub fn receiveExact(self: *Self, buffer: []u8) TcpError!void {
        if (self.state != .connected) {
            return TcpError.NotConnected;
        }

        const stream = self.stream orelse return TcpError.NotConnected;

        var total_received: usize = 0;
        while (total_received < buffer.len) {
            const received = stream.read(buffer[total_received..]) catch |err| {
                return mapReadError(err);
            };

            if (received == 0) {
                self.state = .closed;
                return TcpError.ConnectionClosed;
            }

            total_received += received;
        }

        self.bytes_received += total_received;
    }

    /// 关闭连接
    pub fn close(self: *Self) void {
        if (self.stream) |stream| {
            self.state = .closing;
            stream.close();
            self.stream = null;
            self.state = .closed;
        } else {
            self.state = .disconnected;
        }
    }

    /// 检查是否已连接
    pub fn isConnected(self: *const Self) bool {
        return self.state == .connected and self.stream != null;
    }

    /// 获取远程地址字符串
    pub fn getRemoteAddressString(self: *const Self, buffer: []u8) ?[]const u8 {
        if (self.remote_address) |addr| {
            const result = std.fmt.bufPrint(buffer, "{}", .{addr}) catch return null;
            return result;
        }
        return null;
    }

    /// 获取统计信息
    pub fn getStats(self: *const Self) Stats {
        return .{
            .bytes_sent = self.bytes_sent,
            .bytes_received = self.bytes_received,
            .state = self.state,
        };
    }

    /// 统计信息
    pub const Stats = struct {
        bytes_sent: u64,
        bytes_received: u64,
        state: ConnectionState,
    };
};

/// TCP 连接构建器 - 流畅 API
pub const TcpClientBuilder = struct {
    allocator: Allocator,
    config: TcpConfig,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .config = .{},
        };
    }

    pub fn connectTimeout(self: *Self, timeout_ms: u32) *Self {
        self.config.connect_timeout_ms = timeout_ms;
        return self;
    }

    pub fn readTimeout(self: *Self, timeout_ms: u32) *Self {
        self.config.read_timeout_ms = timeout_ms;
        return self;
    }

    pub fn writeTimeout(self: *Self, timeout_ms: u32) *Self {
        self.config.write_timeout_ms = timeout_ms;
        return self;
    }

    pub fn bufferSize(self: *Self, size: usize) *Self {
        self.config.receive_buffer_size = size;
        return self;
    }

    pub fn noDelay(self: *Self, enabled: bool) *Self {
        self.config.no_delay = enabled;
        return self;
    }

    pub fn keepAlive(self: *Self, enabled: bool) *Self {
        self.config.keep_alive = enabled;
        return self;
    }

    pub fn build(self: *Self) TcpClient {
        return TcpClient.init(self.allocator, self.config);
    }

    pub fn connect(self: *Self, host: []const u8, port: u16) TcpError!TcpClient {
        return TcpClient.connect(self.allocator, host, port, self.config);
    }
};

/// 创建 TCP 客户端构建器
pub fn tcpClient(allocator: Allocator) TcpClientBuilder {
    return TcpClientBuilder.init(allocator);
}

/// 简单的请求-响应模式
pub fn requestResponse(
    allocator: Allocator,
    host: []const u8,
    port: u16,
    request: []const u8,
    config: TcpConfig,
) TcpError![]u8 {
    var client = try TcpClient.connect(allocator, host, port, config);
    defer client.close();

    try client.sendAll(request);
    return client.receive(allocator);
}

// ============================================================================
// 错误映射辅助函数
// ============================================================================

fn mapConnectError(err: anyerror) TcpError {
    return switch (err) {
        error.ConnectionRefused => TcpError.ConnectionFailed,
        error.NetworkUnreachable => TcpError.NetworkUnreachable,
        error.HostUnreachable => TcpError.HostUnreachable,
        error.ConnectionTimedOut => TcpError.Timeout,
        error.AddressInUse => TcpError.AddressInUse,
        else => TcpError.ConnectionFailed,
    };
}

fn mapWriteError(err: anyerror) TcpError {
    return switch (err) {
        error.BrokenPipe => TcpError.ConnectionClosed,
        error.ConnectionResetByPeer => TcpError.ConnectionReset,
        error.WouldBlock => TcpError.Timeout,
        else => TcpError.SendFailed,
    };
}

fn mapReadError(err: anyerror) TcpError {
    return switch (err) {
        error.ConnectionResetByPeer => TcpError.ConnectionReset,
        error.WouldBlock => TcpError.Timeout,
        else => TcpError.ReceiveFailed,
    };
}

// ============================================================================
// 测试
// ============================================================================

test "TcpClient init" {
    const allocator = std.testing.allocator;

    const client = TcpClient.init(allocator, .{});
    try std.testing.expectEqual(ConnectionState.disconnected, client.state);
    try std.testing.expect(!client.isConnected());
    try std.testing.expectEqual(@as(u64, 0), client.bytes_sent);
    try std.testing.expectEqual(@as(u64, 0), client.bytes_received);
}

test "TcpClientBuilder configuration" {
    const allocator = std.testing.allocator;

    var builder = tcpClient(allocator);
    const client = builder
        .connectTimeout(5000)
        .readTimeout(10000)
        .writeTimeout(10000)
        .bufferSize(8192)
        .noDelay(true)
        .keepAlive(true)
        .build();

    try std.testing.expectEqual(@as(u32, 5000), client.config.connect_timeout_ms);
    try std.testing.expectEqual(@as(u32, 10000), client.config.read_timeout_ms);
    try std.testing.expectEqual(@as(u32, 10000), client.config.write_timeout_ms);
    try std.testing.expectEqual(@as(usize, 8192), client.config.receive_buffer_size);
    try std.testing.expect(client.config.no_delay);
    try std.testing.expect(client.config.keep_alive);
}

test "TcpClient send without connection" {
    const allocator = std.testing.allocator;

    var client = TcpClient.init(allocator, .{});
    const result = client.send("test");
    try std.testing.expectError(TcpError.NotConnected, result);
}

test "TcpClient receive without connection" {
    const allocator = std.testing.allocator;

    var client = TcpClient.init(allocator, .{});
    const result = client.receive(allocator);
    try std.testing.expectError(TcpError.NotConnected, result);
}

test "TcpClient double connect error" {
    const allocator = std.testing.allocator;

    var client = TcpClient.init(allocator, .{});
    // 模拟已连接状态
    client.state = .connected;

    const result = client.connectTo("127.0.0.1", 8080);
    try std.testing.expectError(TcpError.AlreadyConnected, result);
}

test "TcpClient stats" {
    const allocator = std.testing.allocator;

    var client = TcpClient.init(allocator, .{});
    client.bytes_sent = 100;
    client.bytes_received = 200;
    client.state = .connected;

    const stats = client.getStats();
    try std.testing.expectEqual(@as(u64, 100), stats.bytes_sent);
    try std.testing.expectEqual(@as(u64, 200), stats.bytes_received);
    try std.testing.expectEqual(ConnectionState.connected, stats.state);
}

test "TcpClient close" {
    const allocator = std.testing.allocator;

    var client = TcpClient.init(allocator, .{});
    client.state = .connected;

    client.close();
    try std.testing.expectEqual(ConnectionState.disconnected, client.state);
}

test "TcpConfig defaults" {
    const config = TcpConfig{};

    try std.testing.expectEqual(@as(u32, 30000), config.connect_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.read_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.write_timeout_ms);
    try std.testing.expectEqual(@as(usize, 4096), config.receive_buffer_size);
    try std.testing.expect(config.no_delay);
    try std.testing.expect(!config.keep_alive);
}
