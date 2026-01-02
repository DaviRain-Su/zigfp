const std = @import("std");
const Allocator = std.mem.Allocator;
const tcp = @import("tcp.zig");
const udp = @import("udp.zig");

/// 网络效果系统
///
/// 提供函数式的网络操作抽象：
/// - 网络操作类型（NetworkOp）
/// - 网络效果（NetworkEffect）
/// - 效果处理器（NetworkHandler）
///
/// 示例:
/// ```zig
/// const effect = NetworkEffect.tcpConnect("127.0.0.1", 8080);
/// var handler = NetworkHandler.init(allocator);
/// defer handler.deinit();
///
/// const result = handler.run(effect);
/// ```
/// 网络操作类型
pub const NetworkOp = union(enum) {
    /// TCP 连接
    tcp_connect: TcpConnectOp,
    /// TCP 发送
    tcp_send: TcpSendOp,
    /// TCP 接收
    tcp_receive: TcpReceiveOp,
    /// TCP 断开
    tcp_disconnect: TcpDisconnectOp,
    /// UDP 绑定
    udp_bind: UdpBindOp,
    /// UDP 发送
    udp_send: UdpSendOp,
    /// UDP 接收
    udp_receive: UdpReceiveOp,
    /// DNS 解析
    dns_resolve: DnsResolveOp,

    pub const TcpConnectOp = struct {
        host: []const u8,
        port: u16,
        config: tcp.TcpConfig,
    };

    pub const TcpSendOp = struct {
        connection_id: u64,
        data: []const u8,
    };

    pub const TcpReceiveOp = struct {
        connection_id: u64,
        max_size: usize,
    };

    pub const TcpDisconnectOp = struct {
        connection_id: u64,
    };

    pub const UdpBindOp = struct {
        host: []const u8,
        port: u16,
        config: udp.UdpConfig,
    };

    pub const UdpSendOp = struct {
        socket_id: u64,
        data: []const u8,
        target_host: []const u8,
        target_port: u16,
    };

    pub const UdpReceiveOp = struct {
        socket_id: u64,
        max_size: usize,
    };

    pub const DnsResolveOp = struct {
        hostname: []const u8,
    };
};

/// 网络效果结果
pub const NetworkResult = union(enum) {
    /// TCP 连接成功
    tcp_connected: TcpConnectedResult,
    /// TCP 发送成功
    tcp_sent: TcpSentResult,
    /// TCP 接收成功
    tcp_received: TcpReceivedResult,
    /// TCP 断开成功
    tcp_disconnected: void,
    /// UDP 绑定成功
    udp_bound: UdpBoundResult,
    /// UDP 发送成功
    udp_sent: UdpSentResult,
    /// UDP 接收成功
    udp_received: UdpReceivedResult,
    /// DNS 解析成功
    dns_resolved: DnsResolvedResult,
    /// 操作失败
    err: NetworkError,

    pub const TcpConnectedResult = struct {
        connection_id: u64,
    };

    pub const TcpSentResult = struct {
        bytes_sent: usize,
    };

    pub const TcpReceivedResult = struct {
        data: []u8,
    };

    pub const UdpBoundResult = struct {
        socket_id: u64,
    };

    pub const UdpSentResult = struct {
        bytes_sent: usize,
    };

    pub const UdpReceivedResult = struct {
        data: []u8,
        from_host: []const u8,
        from_port: u16,
    };

    pub const DnsResolvedResult = struct {
        addresses: []const []const u8,
    };

    pub fn isSuccess(self: NetworkResult) bool {
        return self != .err;
    }

    pub fn isError(self: NetworkResult) bool {
        return self == .err;
    }
};

/// 网络错误
pub const NetworkError = error{
    ConnectionFailed,
    ConnectionClosed,
    ConnectionReset,
    Timeout,
    InvalidAddress,
    SendFailed,
    ReceiveFailed,
    BindFailed,
    DnsResolutionFailed,
    InvalidConnectionId,
    InvalidSocketId,
    OutOfMemory,
    Unexpected,
};

/// 网络效果
pub const NetworkEffect = struct {
    op: NetworkOp,

    const Self = @This();

    /// 创建 TCP 连接效果
    pub fn tcpConnect(host: []const u8, port: u16) Self {
        return .{
            .op = .{
                .tcp_connect = .{
                    .host = host,
                    .port = port,
                    .config = .{},
                },
            },
        };
    }

    /// 创建 TCP 连接效果（带配置）
    pub fn tcpConnectWithConfig(host: []const u8, port: u16, config: tcp.TcpConfig) Self {
        return .{
            .op = .{
                .tcp_connect = .{
                    .host = host,
                    .port = port,
                    .config = config,
                },
            },
        };
    }

    /// 创建 TCP 发送效果
    pub fn tcpSend(connection_id: u64, data: []const u8) Self {
        return .{
            .op = .{
                .tcp_send = .{
                    .connection_id = connection_id,
                    .data = data,
                },
            },
        };
    }

    /// 创建 TCP 接收效果
    pub fn tcpReceive(connection_id: u64, max_size: usize) Self {
        return .{
            .op = .{
                .tcp_receive = .{
                    .connection_id = connection_id,
                    .max_size = max_size,
                },
            },
        };
    }

    /// 创建 TCP 断开效果
    pub fn tcpDisconnect(connection_id: u64) Self {
        return .{
            .op = .{
                .tcp_disconnect = .{
                    .connection_id = connection_id,
                },
            },
        };
    }

    /// 创建 UDP 绑定效果
    pub fn udpBind(host: []const u8, port: u16) Self {
        return .{
            .op = .{
                .udp_bind = .{
                    .host = host,
                    .port = port,
                    .config = .{},
                },
            },
        };
    }

    /// 创建 UDP 发送效果
    pub fn udpSend(socket_id: u64, data: []const u8, target_host: []const u8, target_port: u16) Self {
        return .{
            .op = .{
                .udp_send = .{
                    .socket_id = socket_id,
                    .data = data,
                    .target_host = target_host,
                    .target_port = target_port,
                },
            },
        };
    }

    /// 创建 UDP 接收效果
    pub fn udpReceive(socket_id: u64, max_size: usize) Self {
        return .{
            .op = .{
                .udp_receive = .{
                    .socket_id = socket_id,
                    .max_size = max_size,
                },
            },
        };
    }

    /// 创建 DNS 解析效果
    pub fn dnsResolve(hostname: []const u8) Self {
        return .{
            .op = .{
                .dns_resolve = .{
                    .hostname = hostname,
                },
            },
        };
    }

    /// 获取操作类型名称
    pub fn getOpName(self: *const Self) []const u8 {
        return switch (self.op) {
            .tcp_connect => "tcp_connect",
            .tcp_send => "tcp_send",
            .tcp_receive => "tcp_receive",
            .tcp_disconnect => "tcp_disconnect",
            .udp_bind => "udp_bind",
            .udp_send => "udp_send",
            .udp_receive => "udp_receive",
            .dns_resolve => "dns_resolve",
        };
    }
};

/// 网络效果处理器
pub const NetworkHandler = struct {
    allocator: Allocator,
    tcp_connections: std.AutoHashMap(u64, tcp.TcpClient),
    udp_sockets: std.AutoHashMap(u64, udp.UdpSocket),
    next_connection_id: u64,
    next_socket_id: u64,

    const Self = @This();

    /// 初始化处理器
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .tcp_connections = std.AutoHashMap(u64, tcp.TcpClient).init(allocator),
            .udp_sockets = std.AutoHashMap(u64, udp.UdpSocket).init(allocator),
            .next_connection_id = 1,
            .next_socket_id = 1,
        };
    }

    /// 释放处理器
    pub fn deinit(self: *Self) void {
        // 关闭所有 TCP 连接
        var tcp_it = self.tcp_connections.valueIterator();
        while (tcp_it.next()) |client| {
            client.close();
        }
        self.tcp_connections.deinit();

        // 关闭所有 UDP 套接字
        var udp_it = self.udp_sockets.valueIterator();
        while (udp_it.next()) |socket| {
            socket.close();
        }
        self.udp_sockets.deinit();
    }

    /// 运行网络效果
    pub fn run(self: *Self, effect: NetworkEffect) NetworkResult {
        return switch (effect.op) {
            .tcp_connect => |op| self.handleTcpConnect(op),
            .tcp_send => |op| self.handleTcpSend(op),
            .tcp_receive => |op| self.handleTcpReceive(op),
            .tcp_disconnect => |op| self.handleTcpDisconnect(op),
            .udp_bind => |op| self.handleUdpBind(op),
            .udp_send => |op| self.handleUdpSend(op),
            .udp_receive => |op| self.handleUdpReceive(op),
            .dns_resolve => |op| self.handleDnsResolve(op),
        };
    }

    fn handleTcpConnect(self: *Self, op: NetworkOp.TcpConnectOp) NetworkResult {
        var client = tcp.TcpClient.connect(self.allocator, op.host, op.port, op.config) catch |err| {
            return .{ .err = mapTcpError(err) };
        };

        const id = self.next_connection_id;
        self.next_connection_id += 1;

        self.tcp_connections.put(id, client) catch {
            client.close();
            return .{ .err = NetworkError.OutOfMemory };
        };

        return .{ .tcp_connected = .{ .connection_id = id } };
    }

    fn handleTcpSend(self: *Self, op: NetworkOp.TcpSendOp) NetworkResult {
        const client = self.tcp_connections.getPtr(op.connection_id) orelse {
            return .{ .err = NetworkError.InvalidConnectionId };
        };

        const sent = client.send(op.data) catch |err| {
            return .{ .err = mapTcpError(err) };
        };

        return .{ .tcp_sent = .{ .bytes_sent = sent } };
    }

    fn handleTcpReceive(self: *Self, op: NetworkOp.TcpReceiveOp) NetworkResult {
        const client = self.tcp_connections.getPtr(op.connection_id) orelse {
            return .{ .err = NetworkError.InvalidConnectionId };
        };

        const data = client.receive(self.allocator) catch |err| {
            return .{ .err = mapTcpError(err) };
        };

        return .{ .tcp_received = .{ .data = data } };
    }

    fn handleTcpDisconnect(self: *Self, op: NetworkOp.TcpDisconnectOp) NetworkResult {
        if (self.tcp_connections.fetchRemove(op.connection_id)) |kv| {
            var client = kv.value;
            client.close();
            return .{ .tcp_disconnected = {} };
        }
        return .{ .err = NetworkError.InvalidConnectionId };
    }

    fn handleUdpBind(self: *Self, op: NetworkOp.UdpBindOp) NetworkResult {
        var socket = udp.UdpSocket.bind(self.allocator, op.host, op.port, op.config) catch |err| {
            return .{ .err = mapUdpError(err) };
        };

        const id = self.next_socket_id;
        self.next_socket_id += 1;

        self.udp_sockets.put(id, socket) catch {
            socket.close();
            return .{ .err = NetworkError.OutOfMemory };
        };

        return .{ .udp_bound = .{ .socket_id = id } };
    }

    fn handleUdpSend(self: *Self, op: NetworkOp.UdpSendOp) NetworkResult {
        const socket = self.udp_sockets.getPtr(op.socket_id) orelse {
            return .{ .err = NetworkError.InvalidSocketId };
        };

        const sent = socket.sendToAddress(op.data, op.target_host, op.target_port) catch |err| {
            return .{ .err = mapUdpError(err) };
        };

        return .{ .udp_sent = .{ .bytes_sent = sent } };
    }

    fn handleUdpReceive(self: *Self, op: NetworkOp.UdpReceiveOp) NetworkResult {
        const socket = self.udp_sockets.getPtr(op.socket_id) orelse {
            return .{ .err = NetworkError.InvalidSocketId };
        };

        const result = socket.receive(self.allocator) catch |err| {
            return .{ .err = mapUdpError(err) };
        };

        // 格式化地址
        var addr_buf: [64]u8 = undefined;
        const addr_str = std.fmt.bufPrint(&addr_buf, "{any}", .{result.address}) catch "unknown";
        _ = addr_str;

        return .{
            .udp_received = .{
                .data = result.data,
                .from_host = "0.0.0.0", // 简化，实际应解析地址
                .from_port = 0,
            },
        };
    }

    fn handleDnsResolve(self: *Self, op: NetworkOp.DnsResolveOp) NetworkResult {
        _ = self;
        _ = op;
        // DNS 解析简化实现
        return .{ .err = NetworkError.DnsResolutionFailed };
    }

    /// 获取活跃连接数
    pub fn getActiveConnectionCount(self: *const Self) usize {
        return self.tcp_connections.count();
    }

    /// 获取活跃套接字数
    pub fn getActiveSocketCount(self: *const Self) usize {
        return self.udp_sockets.count();
    }
};

/// 网络效果序列 - 用于组合多个网络操作
pub const NetworkSequence = struct {
    effects: std.ArrayList(NetworkEffect),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return .{
            .effects = try std.ArrayList(NetworkEffect).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.effects.deinit(self.allocator);
    }

    pub fn add(self: *Self, effect: NetworkEffect) !*Self {
        try self.effects.append(self.allocator, effect);
        return self;
    }

    pub fn tcpConnect(self: *Self, host: []const u8, port: u16) !*Self {
        return self.add(NetworkEffect.tcpConnect(host, port));
    }

    pub fn tcpSend(self: *Self, connection_id: u64, data: []const u8) !*Self {
        return self.add(NetworkEffect.tcpSend(connection_id, data));
    }

    pub fn tcpDisconnect(self: *Self, connection_id: u64) !*Self {
        return self.add(NetworkEffect.tcpDisconnect(connection_id));
    }

    pub fn runAll(self: *Self, handler: *NetworkHandler) ![]NetworkResult {
        var results = try std.ArrayList(NetworkResult).initCapacity(self.allocator, self.effects.items.len);
        errdefer results.deinit(self.allocator);

        for (self.effects.items) |effect| {
            try results.append(self.allocator, handler.run(effect));
        }

        return results.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// 错误映射辅助函数
// ============================================================================

fn mapTcpError(err: tcp.TcpError) NetworkError {
    return switch (err) {
        tcp.TcpError.ConnectionFailed => NetworkError.ConnectionFailed,
        tcp.TcpError.ConnectionClosed => NetworkError.ConnectionClosed,
        tcp.TcpError.ConnectionReset => NetworkError.ConnectionReset,
        tcp.TcpError.Timeout => NetworkError.Timeout,
        tcp.TcpError.InvalidAddress => NetworkError.InvalidAddress,
        tcp.TcpError.SendFailed => NetworkError.SendFailed,
        tcp.TcpError.ReceiveFailed => NetworkError.ReceiveFailed,
        tcp.TcpError.OutOfMemory => NetworkError.OutOfMemory,
        else => NetworkError.Unexpected,
    };
}

fn mapUdpError(err: udp.UdpError) NetworkError {
    return switch (err) {
        udp.UdpError.BindFailed => NetworkError.BindFailed,
        udp.UdpError.SendFailed => NetworkError.SendFailed,
        udp.UdpError.ReceiveFailed => NetworkError.ReceiveFailed,
        udp.UdpError.Timeout => NetworkError.Timeout,
        udp.UdpError.InvalidAddress => NetworkError.InvalidAddress,
        udp.UdpError.OutOfMemory => NetworkError.OutOfMemory,
        else => NetworkError.Unexpected,
    };
}

// ============================================================================
// 测试
// ============================================================================

test "NetworkEffect creation" {
    const effect1 = NetworkEffect.tcpConnect("127.0.0.1", 8080);
    try std.testing.expectEqualStrings("tcp_connect", effect1.getOpName());

    const effect2 = NetworkEffect.tcpSend(1, "hello");
    try std.testing.expectEqualStrings("tcp_send", effect2.getOpName());

    const effect3 = NetworkEffect.tcpReceive(1, 1024);
    try std.testing.expectEqualStrings("tcp_receive", effect3.getOpName());

    const effect4 = NetworkEffect.tcpDisconnect(1);
    try std.testing.expectEqualStrings("tcp_disconnect", effect4.getOpName());

    const effect5 = NetworkEffect.udpBind("0.0.0.0", 0);
    try std.testing.expectEqualStrings("udp_bind", effect5.getOpName());

    const effect6 = NetworkEffect.dnsResolve("example.com");
    try std.testing.expectEqualStrings("dns_resolve", effect6.getOpName());
}

test "NetworkHandler init and deinit" {
    const allocator = std.testing.allocator;

    var handler = NetworkHandler.init(allocator);
    defer handler.deinit();

    try std.testing.expectEqual(@as(usize, 0), handler.getActiveConnectionCount());
    try std.testing.expectEqual(@as(usize, 0), handler.getActiveSocketCount());
}

test "NetworkHandler invalid connection id" {
    const allocator = std.testing.allocator;

    var handler = NetworkHandler.init(allocator);
    defer handler.deinit();

    const effect = NetworkEffect.tcpSend(999, "hello");
    const result = handler.run(effect);

    try std.testing.expect(result.isError());
    try std.testing.expectEqual(NetworkError.InvalidConnectionId, result.err);
}

test "NetworkHandler invalid socket id" {
    const allocator = std.testing.allocator;

    var handler = NetworkHandler.init(allocator);
    defer handler.deinit();

    const effect = NetworkEffect.udpSend(999, "hello", "127.0.0.1", 8080);
    const result = handler.run(effect);

    try std.testing.expect(result.isError());
    try std.testing.expectEqual(NetworkError.InvalidSocketId, result.err);
}

test "NetworkResult success check" {
    const success: NetworkResult = .{ .tcp_connected = .{ .connection_id = 1 } };
    try std.testing.expect(success.isSuccess());
    try std.testing.expect(!success.isError());

    const failure: NetworkResult = .{ .err = NetworkError.ConnectionFailed };
    try std.testing.expect(!failure.isSuccess());
    try std.testing.expect(failure.isError());
}

test "NetworkSequence creation" {
    const allocator = std.testing.allocator;

    var seq = try NetworkSequence.init(allocator);
    defer seq.deinit();

    _ = try seq.tcpConnect("127.0.0.1", 8080);
    _ = try seq.tcpSend(1, "hello");
    _ = try seq.tcpDisconnect(1);

    try std.testing.expectEqual(@as(usize, 3), seq.effects.items.len);
}

test "NetworkEffect with config" {
    const config = tcp.TcpConfig{
        .connect_timeout_ms = 5000,
        .read_timeout_ms = 10000,
    };

    const effect = NetworkEffect.tcpConnectWithConfig("127.0.0.1", 8080, config);
    try std.testing.expectEqualStrings("tcp_connect", effect.getOpName());

    switch (effect.op) {
        .tcp_connect => |op| {
            try std.testing.expectEqual(@as(u32, 5000), op.config.connect_timeout_ms);
            try std.testing.expectEqual(@as(u32, 10000), op.config.read_timeout_ms);
        },
        else => unreachable,
    }
}
