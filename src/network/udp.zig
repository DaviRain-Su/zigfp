const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const posix = std.posix;

/// 函数式 UDP 客户端模块
///
/// 提供类型安全的 UDP 网络操作：
/// - 无连接数据报传输
/// - sendTo/receiveFrom 操作
/// - 广播支持
/// - 超时配置
///
/// 示例:
/// ```zig
/// var socket = try UdpSocket.bind(allocator, "0.0.0.0", 0, .{});
/// defer socket.close();
///
/// const target = try net.Address.parseIp("127.0.0.1", 8080);
/// try socket.sendTo("Hello, UDP!", target);
///
/// var buffer: [1024]u8 = undefined;
/// const result = try socket.receiveFrom(&buffer);
/// ```
/// UDP 配置
pub const UdpConfig = struct {
    /// 接收超时（毫秒）
    receive_timeout_ms: u32 = 30000,
    /// 发送超时（毫秒）
    send_timeout_ms: u32 = 30000,
    /// 接收缓冲区大小
    receive_buffer_size: usize = 65535,
    /// 是否启用广播
    broadcast: bool = false,
    /// 是否允许地址重用
    reuse_address: bool = false,
};

/// UDP 错误类型
pub const UdpError = error{
    BindFailed,
    SendFailed,
    ReceiveFailed,
    Timeout,
    InvalidAddress,
    NotBound,
    AddressInUse,
    NetworkUnreachable,
    HostUnreachable,
    MessageTooLarge,
    OutOfMemory,
    Unexpected,
};

/// 接收结果
pub const ReceiveResult = struct {
    /// 接收到的数据长度
    len: usize,
    /// 发送方地址
    address: net.Address,
};

/// UDP 套接字
pub const UdpSocket = struct {
    allocator: Allocator,
    config: UdpConfig,
    socket: ?posix.socket_t,
    bound_address: ?net.Address,
    bytes_sent: u64,
    bytes_received: u64,
    packets_sent: u64,
    packets_received: u64,

    const Self = @This();

    /// 创建未绑定的套接字
    pub fn init(allocator: Allocator, config: UdpConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .socket = null,
            .bound_address = null,
            .bytes_sent = 0,
            .bytes_received = 0,
            .packets_sent = 0,
            .packets_received = 0,
        };
    }

    /// 绑定到指定地址
    pub fn bind(allocator: Allocator, host: []const u8, port: u16, config: UdpConfig) UdpError!Self {
        var socket = init(allocator, config);
        try socket.bindTo(host, port);
        return socket;
    }

    /// 绑定到地址
    pub fn bindTo(self: *Self, host: []const u8, port: u16) UdpError!void {
        // 解析地址
        const address = net.Address.parseIp(host, port) catch {
            return UdpError.InvalidAddress;
        };

        // 创建套接字
        const sock = posix.socket(
            address.any.family,
            posix.SOCK.DGRAM,
            0,
        ) catch {
            return UdpError.BindFailed;
        };
        errdefer posix.close(sock);

        // 配置套接字选项
        self.socket = sock;
        self.configureSocket() catch {};

        // 绑定地址
        posix.bind(sock, &address.any, address.getOsSockLen()) catch |err| {
            posix.close(sock);
            self.socket = null;
            return switch (err) {
                error.AddressInUse => UdpError.AddressInUse,
                else => UdpError.BindFailed,
            };
        };

        self.bound_address = address;
    }

    /// 配置套接字选项
    fn configureSocket(self: *Self) !void {
        const sock = self.socket orelse return;

        // SO_REUSEADDR
        if (self.config.reuse_address) {
            posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1))) catch {};
        }

        // SO_BROADCAST
        if (self.config.broadcast) {
            posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.BROADCAST, &std.mem.toBytes(@as(c_int, 1))) catch {};
        }

        // 接收超时
        if (self.config.receive_timeout_ms > 0) {
            const timeout = posix.timeval{
                .sec = @intCast(self.config.receive_timeout_ms / 1000),
                .usec = @intCast((self.config.receive_timeout_ms % 1000) * 1000),
            };
            posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout)) catch {};
        }

        // 发送超时
        if (self.config.send_timeout_ms > 0) {
            const timeout = posix.timeval{
                .sec = @intCast(self.config.send_timeout_ms / 1000),
                .usec = @intCast((self.config.send_timeout_ms % 1000) * 1000),
            };
            posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout)) catch {};
        }
    }

    /// 发送数据到指定地址
    pub fn sendTo(self: *Self, data: []const u8, address: net.Address) UdpError!usize {
        const sock = self.socket orelse return UdpError.NotBound;

        const sent = posix.sendto(
            sock,
            data,
            0,
            &address.any,
            address.getOsSockLen(),
        ) catch |err| {
            return mapSendError(err);
        };

        self.bytes_sent += sent;
        self.packets_sent += 1;
        return sent;
    }

    /// 发送数据到地址字符串
    pub fn sendToAddress(self: *Self, data: []const u8, host: []const u8, port: u16) UdpError!usize {
        const address = net.Address.parseIp(host, port) catch {
            return UdpError.InvalidAddress;
        };
        return self.sendTo(data, address);
    }

    /// 接收数据
    pub fn receiveFrom(self: *Self, buffer: []u8) UdpError!ReceiveResult {
        const sock = self.socket orelse return UdpError.NotBound;

        var src_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);

        const received = posix.recvfrom(
            sock,
            buffer,
            0,
            &src_addr,
            &addr_len,
        ) catch |err| {
            return mapReceiveError(err);
        };

        self.bytes_received += received;
        self.packets_received += 1;

        return .{
            .len = received,
            .address = net.Address{ .any = src_addr },
        };
    }

    /// 接收数据（分配内存）
    pub fn receive(self: *Self, allocator: Allocator) UdpError!struct { data: []u8, address: net.Address } {
        var buffer = allocator.alloc(u8, self.config.receive_buffer_size) catch {
            return UdpError.OutOfMemory;
        };
        errdefer allocator.free(buffer);

        const result = try self.receiveFrom(buffer);

        // 调整到实际大小
        const data = allocator.realloc(buffer, result.len) catch {
            return .{ .data = buffer[0..result.len], .address = result.address };
        };

        return .{ .data = data[0..result.len], .address = result.address };
    }

    /// 关闭套接字
    pub fn close(self: *Self) void {
        if (self.socket) |sock| {
            posix.close(sock);
            self.socket = null;
        }
        self.bound_address = null;
    }

    /// 检查是否已绑定
    pub fn isBound(self: *const Self) bool {
        return self.socket != null and self.bound_address != null;
    }

    /// 获取绑定地址字符串
    pub fn getBoundAddressString(self: *const Self, buffer: []u8) ?[]const u8 {
        if (self.bound_address) |addr| {
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
            .packets_sent = self.packets_sent,
            .packets_received = self.packets_received,
        };
    }

    /// 统计信息
    pub const Stats = struct {
        bytes_sent: u64,
        bytes_received: u64,
        packets_sent: u64,
        packets_received: u64,
    };
};

/// UDP 套接字构建器 - 流畅 API
pub const UdpSocketBuilder = struct {
    allocator: Allocator,
    config: UdpConfig,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .config = .{},
        };
    }

    pub fn receiveTimeout(self: *Self, timeout_ms: u32) *Self {
        self.config.receive_timeout_ms = timeout_ms;
        return self;
    }

    pub fn sendTimeout(self: *Self, timeout_ms: u32) *Self {
        self.config.send_timeout_ms = timeout_ms;
        return self;
    }

    pub fn bufferSize(self: *Self, size: usize) *Self {
        self.config.receive_buffer_size = size;
        return self;
    }

    pub fn broadcast(self: *Self, enabled: bool) *Self {
        self.config.broadcast = enabled;
        return self;
    }

    pub fn reuseAddress(self: *Self, enabled: bool) *Self {
        self.config.reuse_address = enabled;
        return self;
    }

    pub fn build(self: *Self) UdpSocket {
        return UdpSocket.init(self.allocator, self.config);
    }

    pub fn bind(self: *Self, host: []const u8, port: u16) UdpError!UdpSocket {
        return UdpSocket.bind(self.allocator, host, port, self.config);
    }
};

/// 创建 UDP 套接字构建器
pub fn udpSocket(allocator: Allocator) UdpSocketBuilder {
    return UdpSocketBuilder.init(allocator);
}

// ============================================================================
// 错误映射辅助函数
// ============================================================================

fn mapSendError(err: anyerror) UdpError {
    return switch (err) {
        error.NetworkUnreachable => UdpError.NetworkUnreachable,
        error.HostUnreachable => UdpError.HostUnreachable,
        error.MessageTooBig => UdpError.MessageTooLarge,
        error.WouldBlock => UdpError.Timeout,
        else => UdpError.SendFailed,
    };
}

fn mapReceiveError(err: anyerror) UdpError {
    return switch (err) {
        error.WouldBlock => UdpError.Timeout,
        else => UdpError.ReceiveFailed,
    };
}

// ============================================================================
// 测试
// ============================================================================

test "UdpSocket init" {
    const allocator = std.testing.allocator;

    const socket = UdpSocket.init(allocator, .{});
    try std.testing.expect(!socket.isBound());
    try std.testing.expectEqual(@as(u64, 0), socket.bytes_sent);
    try std.testing.expectEqual(@as(u64, 0), socket.bytes_received);
    try std.testing.expectEqual(@as(u64, 0), socket.packets_sent);
    try std.testing.expectEqual(@as(u64, 0), socket.packets_received);
}

test "UdpSocketBuilder configuration" {
    const allocator = std.testing.allocator;

    var builder = udpSocket(allocator);
    const socket = builder
        .receiveTimeout(5000)
        .sendTimeout(10000)
        .bufferSize(8192)
        .broadcast(true)
        .reuseAddress(true)
        .build();

    try std.testing.expectEqual(@as(u32, 5000), socket.config.receive_timeout_ms);
    try std.testing.expectEqual(@as(u32, 10000), socket.config.send_timeout_ms);
    try std.testing.expectEqual(@as(usize, 8192), socket.config.receive_buffer_size);
    try std.testing.expect(socket.config.broadcast);
    try std.testing.expect(socket.config.reuse_address);
}

test "UdpSocket send without bind" {
    const allocator = std.testing.allocator;

    var socket = UdpSocket.init(allocator, .{});
    const addr = net.Address.parseIp("127.0.0.1", 8080) catch unreachable;
    const result = socket.sendTo("test", addr);
    try std.testing.expectError(UdpError.NotBound, result);
}

test "UdpSocket receive without bind" {
    const allocator = std.testing.allocator;

    var socket = UdpSocket.init(allocator, .{});
    var buffer: [100]u8 = undefined;
    const result = socket.receiveFrom(&buffer);
    try std.testing.expectError(UdpError.NotBound, result);
}

test "UdpSocket stats" {
    const allocator = std.testing.allocator;

    var socket = UdpSocket.init(allocator, .{});
    socket.bytes_sent = 100;
    socket.bytes_received = 200;
    socket.packets_sent = 5;
    socket.packets_received = 10;

    const stats = socket.getStats();
    try std.testing.expectEqual(@as(u64, 100), stats.bytes_sent);
    try std.testing.expectEqual(@as(u64, 200), stats.bytes_received);
    try std.testing.expectEqual(@as(u64, 5), stats.packets_sent);
    try std.testing.expectEqual(@as(u64, 10), stats.packets_received);
}

test "UdpSocket close" {
    const allocator = std.testing.allocator;

    var socket = UdpSocket.init(allocator, .{});
    socket.close();
    try std.testing.expect(!socket.isBound());
}

test "UdpConfig defaults" {
    const config = UdpConfig{};

    try std.testing.expectEqual(@as(u32, 30000), config.receive_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.send_timeout_ms);
    try std.testing.expectEqual(@as(usize, 65535), config.receive_buffer_size);
    try std.testing.expect(!config.broadcast);
    try std.testing.expect(!config.reuse_address);
}

test "UdpSocket bind and close" {
    const allocator = std.testing.allocator;

    // 绑定到随机端口
    var socket = UdpSocket.bind(allocator, "127.0.0.1", 0, .{}) catch |err| {
        // 在某些环境下可能失败，跳过测试
        std.debug.print("Bind failed (expected in some environments): {}\n", .{err});
        return;
    };
    defer socket.close();

    try std.testing.expect(socket.isBound());
}
