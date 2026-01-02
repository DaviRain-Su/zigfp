const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const posix = std.posix;

/// 函数式 WebSocket 客户端模块
///
/// 提供类型安全的 WebSocket 网络操作：
/// - 连接管理（connect/close）
/// - 文本/二进制消息收发
/// - Ping/Pong 心跳
/// - 帧解析和构建
///
/// 示例:
/// ```zig
/// var client = try WebSocketClient.connect(allocator, "ws://127.0.0.1:8080/ws", .{});
/// defer client.close();
///
/// try client.sendText("Hello, Server!");
/// const message = try client.receive(allocator);
/// defer message.deinit(allocator);
/// ```
/// WebSocket 配置
pub const WebSocketConfig = struct {
    /// 连接超时（毫秒）
    connect_timeout_ms: u32 = 30000,
    /// 读取超时（毫秒）
    read_timeout_ms: u32 = 30000,
    /// 写入超时（毫秒）
    write_timeout_ms: u32 = 30000,
    /// 最大帧大小
    max_frame_size: usize = 65536,
    /// 最大消息大小
    max_message_size: usize = 1048576,
    /// 是否自动响应 Ping
    auto_pong: bool = true,
    /// Ping 间隔（毫秒，0 表示禁用）
    ping_interval_ms: u32 = 0,
};

/// WebSocket 错误类型
pub const WebSocketError = error{
    ConnectionFailed,
    ConnectionClosed,
    HandshakeFailed,
    InvalidFrame,
    InvalidOpcode,
    InvalidPayloadLength,
    MessageTooLarge,
    ProtocolError,
    Timeout,
    InvalidAddress,
    InvalidUrl,
    SendFailed,
    ReceiveFailed,
    NotConnected,
    OutOfMemory,
    Unexpected,
};

/// WebSocket 连接状态
pub const ConnectionState = enum {
    disconnected,
    connecting,
    handshaking,
    connected,
    closing,
    closed,
};

/// WebSocket 帧操作码
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,

    pub fn isControl(self: Opcode) bool {
        return @intFromEnum(self) >= 0x8;
    }

    pub fn isData(self: Opcode) bool {
        return @intFromEnum(self) <= 0x2;
    }
};

/// WebSocket 关闭状态码
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    no_status = 1005,
    abnormal = 1006,
    invalid_payload = 1007,
    policy_violation = 1008,
    message_too_big = 1009,
    mandatory_extension = 1010,
    internal_error = 1011,
    service_restart = 1012,
    try_again_later = 1013,
    bad_gateway = 1014,
    tls_handshake = 1015,
    _,
};

/// WebSocket 消息
pub const Message = struct {
    opcode: Opcode,
    data: []u8,
    is_final: bool,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.data.len > 0) {
            allocator.free(self.data);
        }
        self.data = &[_]u8{};
    }

    pub fn isText(self: *const Self) bool {
        return self.opcode == .text;
    }

    pub fn isBinary(self: *const Self) bool {
        return self.opcode == .binary;
    }

    pub fn isClose(self: *const Self) bool {
        return self.opcode == .close;
    }

    pub fn isPing(self: *const Self) bool {
        return self.opcode == .ping;
    }

    pub fn isPong(self: *const Self) bool {
        return self.opcode == .pong;
    }

    pub fn getText(self: *const Self) ?[]const u8 {
        if (self.opcode == .text) {
            return self.data;
        }
        return null;
    }
};

/// WebSocket 帧
pub const Frame = struct {
    fin: bool,
    rsv1: bool,
    rsv2: bool,
    rsv3: bool,
    opcode: Opcode,
    masked: bool,
    payload_length: u64,
    mask_key: [4]u8,
    payload: []u8,

    const Self = @This();

    /// 创建文本帧
    pub fn text(data: []const u8, allocator: Allocator) !Self {
        const payload = try allocator.dupe(u8, data);
        return .{
            .fin = true,
            .rsv1 = false,
            .rsv2 = false,
            .rsv3 = false,
            .opcode = .text,
            .masked = true,
            .payload_length = data.len,
            .mask_key = generateMaskKey(),
            .payload = payload,
        };
    }

    /// 创建二进制帧
    pub fn binary(data: []const u8, allocator: Allocator) !Self {
        const payload = try allocator.dupe(u8, data);
        return .{
            .fin = true,
            .rsv1 = false,
            .rsv2 = false,
            .rsv3 = false,
            .opcode = .binary,
            .masked = true,
            .payload_length = data.len,
            .mask_key = generateMaskKey(),
            .payload = payload,
        };
    }

    /// 创建 Ping 帧
    pub fn ping(data: []const u8, allocator: Allocator) !Self {
        const payload = try allocator.dupe(u8, data);
        return .{
            .fin = true,
            .rsv1 = false,
            .rsv2 = false,
            .rsv3 = false,
            .opcode = .ping,
            .masked = true,
            .payload_length = data.len,
            .mask_key = generateMaskKey(),
            .payload = payload,
        };
    }

    /// 创建 Pong 帧
    pub fn pong(data: []const u8, allocator: Allocator) !Self {
        const payload = try allocator.dupe(u8, data);
        return .{
            .fin = true,
            .rsv1 = false,
            .rsv2 = false,
            .rsv3 = false,
            .opcode = .pong,
            .masked = true,
            .payload_length = data.len,
            .mask_key = generateMaskKey(),
            .payload = payload,
        };
    }

    /// 创建关闭帧
    pub fn close(code: CloseCode, reason: []const u8, allocator: Allocator) !Self {
        const code_u16 = @intFromEnum(code);
        const payload_len = 2 + reason.len;
        const payload = try allocator.alloc(u8, payload_len);

        payload[0] = @intCast((code_u16 >> 8) & 0xFF);
        payload[1] = @intCast(code_u16 & 0xFF);
        if (reason.len > 0) {
            @memcpy(payload[2..], reason);
        }

        return .{
            .fin = true,
            .rsv1 = false,
            .rsv2 = false,
            .rsv3 = false,
            .opcode = .close,
            .masked = true,
            .payload_length = payload_len,
            .mask_key = generateMaskKey(),
            .payload = payload,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.payload.len > 0) {
            allocator.free(self.payload);
        }
        self.payload = &[_]u8{};
    }

    /// 编码帧为字节
    pub fn encode(self: *const Self, allocator: Allocator) ![]u8 {
        // 计算帧大小
        var frame_size: usize = 2; // 最小头部
        if (self.payload_length <= 125) {
            // 使用 1 字节长度
        } else if (self.payload_length <= 65535) {
            frame_size += 2; // 额外 2 字节
        } else {
            frame_size += 8; // 额外 8 字节
        }
        if (self.masked) {
            frame_size += 4; // mask key
        }
        frame_size += @intCast(self.payload_length);

        const buffer = try allocator.alloc(u8, frame_size);
        errdefer allocator.free(buffer);

        var offset: usize = 0;

        // 第一字节: FIN + RSV + Opcode
        var byte0: u8 = 0;
        if (self.fin) byte0 |= 0x80;
        if (self.rsv1) byte0 |= 0x40;
        if (self.rsv2) byte0 |= 0x20;
        if (self.rsv3) byte0 |= 0x10;
        byte0 |= @intFromEnum(self.opcode);
        buffer[offset] = byte0;
        offset += 1;

        // 第二字节: MASK + Payload length
        var byte1: u8 = 0;
        if (self.masked) byte1 |= 0x80;

        if (self.payload_length <= 125) {
            byte1 |= @intCast(self.payload_length);
            buffer[offset] = byte1;
            offset += 1;
        } else if (self.payload_length <= 65535) {
            byte1 |= 126;
            buffer[offset] = byte1;
            offset += 1;
            buffer[offset] = @intCast((self.payload_length >> 8) & 0xFF);
            offset += 1;
            buffer[offset] = @intCast(self.payload_length & 0xFF);
            offset += 1;
        } else {
            byte1 |= 127;
            buffer[offset] = byte1;
            offset += 1;
            // 8 字节长度
            inline for (0..8) |i| {
                buffer[offset] = @intCast((self.payload_length >> @intCast(56 - i * 8)) & 0xFF);
                offset += 1;
            }
        }

        // Mask key
        if (self.masked) {
            @memcpy(buffer[offset .. offset + 4], &self.mask_key);
            offset += 4;
        }

        // Payload (masked if needed)
        if (self.masked) {
            for (self.payload, 0..) |byte, i| {
                buffer[offset + i] = byte ^ self.mask_key[i % 4];
            }
        } else {
            @memcpy(buffer[offset..], self.payload);
        }

        return buffer;
    }

    /// 从字节解码帧
    pub fn decode(data: []const u8, allocator: Allocator) !struct { frame: Self, bytes_consumed: usize } {
        if (data.len < 2) {
            return WebSocketError.InvalidFrame;
        }

        var offset: usize = 0;

        // 解析第一字节
        const byte0 = data[offset];
        offset += 1;
        const fin = (byte0 & 0x80) != 0;
        const rsv1 = (byte0 & 0x40) != 0;
        const rsv2 = (byte0 & 0x20) != 0;
        const rsv3 = (byte0 & 0x10) != 0;
        const opcode_raw = byte0 & 0x0F;
        const opcode = std.meta.intToEnum(Opcode, @as(u4, @intCast(opcode_raw))) catch {
            return WebSocketError.InvalidOpcode;
        };

        // 解析第二字节
        const byte1 = data[offset];
        offset += 1;
        const masked = (byte1 & 0x80) != 0;
        var payload_length: u64 = byte1 & 0x7F;

        // 扩展长度
        if (payload_length == 126) {
            if (data.len < offset + 2) {
                return WebSocketError.InvalidFrame;
            }
            payload_length = (@as(u64, data[offset]) << 8) | @as(u64, data[offset + 1]);
            offset += 2;
        } else if (payload_length == 127) {
            if (data.len < offset + 8) {
                return WebSocketError.InvalidFrame;
            }
            payload_length = 0;
            inline for (0..8) |i| {
                payload_length |= @as(u64, data[offset + i]) << @intCast(56 - i * 8);
            }
            offset += 8;
        }

        // Mask key
        var mask_key: [4]u8 = .{ 0, 0, 0, 0 };
        if (masked) {
            if (data.len < offset + 4) {
                return WebSocketError.InvalidFrame;
            }
            @memcpy(&mask_key, data[offset .. offset + 4]);
            offset += 4;
        }

        // Payload
        const payload_len_usize: usize = @intCast(payload_length);
        if (data.len < offset + payload_len_usize) {
            return WebSocketError.InvalidFrame;
        }

        const payload = try allocator.alloc(u8, payload_len_usize);
        errdefer allocator.free(payload);

        if (masked) {
            for (0..payload_len_usize) |i| {
                payload[i] = data[offset + i] ^ mask_key[i % 4];
            }
        } else {
            @memcpy(payload, data[offset .. offset + payload_len_usize]);
        }
        offset += payload_len_usize;

        return .{
            .frame = .{
                .fin = fin,
                .rsv1 = rsv1,
                .rsv2 = rsv2,
                .rsv3 = rsv3,
                .opcode = opcode,
                .masked = masked,
                .payload_length = payload_length,
                .mask_key = mask_key,
                .payload = payload,
            },
            .bytes_consumed = offset,
        };
    }
};

/// 生成随机 mask key
fn generateMaskKey() [4]u8 {
    var key: [4]u8 = undefined;
    std.crypto.random.bytes(&key);
    return key;
}

/// WebSocket URL 解析结果
pub const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
    is_secure: bool,
};

/// 解析 WebSocket URL
pub fn parseUrl(url: []const u8) WebSocketError!ParsedUrl {
    var is_secure = false;
    var remaining = url;

    // 检查协议
    if (std.mem.startsWith(u8, remaining, "wss://")) {
        is_secure = true;
        remaining = remaining[6..];
    } else if (std.mem.startsWith(u8, remaining, "ws://")) {
        remaining = remaining[5..];
    } else {
        return WebSocketError.InvalidUrl;
    }

    // 解析主机和端口
    const host_end = std.mem.indexOf(u8, remaining, "/") orelse remaining.len;
    const host_port = remaining[0..host_end];
    const path = if (host_end < remaining.len) remaining[host_end..] else "/";

    // 解析端口
    var host: []const u8 = undefined;
    var port: u16 = undefined;

    if (std.mem.indexOf(u8, host_port, ":")) |colon_idx| {
        host = host_port[0..colon_idx];
        port = std.fmt.parseInt(u16, host_port[colon_idx + 1 ..], 10) catch {
            return WebSocketError.InvalidUrl;
        };
    } else {
        host = host_port;
        port = if (is_secure) 443 else 80;
    }

    return .{
        .host = host,
        .port = port,
        .path = path,
        .is_secure = is_secure,
    };
}

/// WebSocket 客户端
pub const WebSocketClient = struct {
    allocator: Allocator,
    config: WebSocketConfig,
    stream: ?net.Stream,
    state: ConnectionState,
    host: []const u8,
    port: u16,
    path: []const u8,
    is_secure: bool,
    bytes_sent: u64,
    bytes_received: u64,
    messages_sent: u64,
    messages_received: u64,

    const Self = @This();

    /// 创建未连接的客户端
    pub fn init(allocator: Allocator, config: WebSocketConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .stream = null,
            .state = .disconnected,
            .host = "",
            .port = 0,
            .path = "/",
            .is_secure = false,
            .bytes_sent = 0,
            .bytes_received = 0,
            .messages_sent = 0,
            .messages_received = 0,
        };
    }

    /// 连接到 WebSocket 服务器
    pub fn connect(allocator: Allocator, url: []const u8, config: WebSocketConfig) WebSocketError!Self {
        var client = init(allocator, config);
        try client.connectTo(url);
        return client;
    }

    /// 连接到指定 URL
    pub fn connectTo(self: *Self, url: []const u8) WebSocketError!void {
        if (self.state != .disconnected) {
            return WebSocketError.ConnectionFailed;
        }

        // 解析 URL
        const parsed = try parseUrl(url);
        self.host = parsed.host;
        self.port = parsed.port;
        self.path = parsed.path;
        self.is_secure = parsed.is_secure;

        // TODO: 安全连接需要 TLS 支持
        if (self.is_secure) {
            return WebSocketError.ConnectionFailed;
        }

        self.state = .connecting;

        // TCP 连接
        const address = net.Address.parseIp(self.host, self.port) catch {
            self.state = .disconnected;
            return WebSocketError.InvalidAddress;
        };

        const stream = net.tcpConnectToAddress(address) catch {
            self.state = .disconnected;
            return WebSocketError.ConnectionFailed;
        };
        self.stream = stream;

        self.state = .handshaking;

        // WebSocket 握手
        self.performHandshake() catch |err| {
            self.stream.?.close();
            self.stream = null;
            self.state = .disconnected;
            return err;
        };

        self.state = .connected;
    }

    /// 执行 WebSocket 握手
    fn performHandshake(self: *Self) WebSocketError!void {
        const stream = self.stream orelse return WebSocketError.NotConnected;

        // 生成 Sec-WebSocket-Key
        var key_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&key_bytes);
        const sec_key = std.base64.standard.Encoder.encode(&key_bytes, &key_bytes);
        _ = sec_key;

        // 构建握手请求
        var request_buf: [1024]u8 = undefined;
        const request = std.fmt.bufPrint(&request_buf, "GET {s} HTTP/1.1\r\nHost: {s}:{d}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n", .{ self.path, self.host, self.port }) catch {
            return WebSocketError.HandshakeFailed;
        };

        // 发送握手请求
        _ = stream.write(request) catch {
            return WebSocketError.SendFailed;
        };

        // 读取握手响应
        var response_buf: [1024]u8 = undefined;
        const bytes_read = stream.read(&response_buf) catch {
            return WebSocketError.ReceiveFailed;
        };

        if (bytes_read == 0) {
            return WebSocketError.ConnectionClosed;
        }

        const response = response_buf[0..bytes_read];

        // 验证响应（简化版本）
        if (!std.mem.startsWith(u8, response, "HTTP/1.1 101")) {
            return WebSocketError.HandshakeFailed;
        }

        if (std.mem.indexOf(u8, response, "Upgrade: websocket") == null and
            std.mem.indexOf(u8, response, "upgrade: websocket") == null)
        {
            return WebSocketError.HandshakeFailed;
        }
    }

    /// 发送文本消息
    pub fn sendText(self: *Self, text: []const u8) WebSocketError!void {
        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        var frame = Frame.text(text, self.allocator) catch {
            return WebSocketError.OutOfMemory;
        };
        defer frame.deinit(self.allocator);

        try self.sendFrame(&frame);
        self.messages_sent += 1;
    }

    /// 发送二进制消息
    pub fn sendBinary(self: *Self, data: []const u8) WebSocketError!void {
        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        var frame = Frame.binary(data, self.allocator) catch {
            return WebSocketError.OutOfMemory;
        };
        defer frame.deinit(self.allocator);

        try self.sendFrame(&frame);
        self.messages_sent += 1;
    }

    /// 发送 Ping
    pub fn sendPing(self: *Self, data: []const u8) WebSocketError!void {
        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        var frame = Frame.ping(data, self.allocator) catch {
            return WebSocketError.OutOfMemory;
        };
        defer frame.deinit(self.allocator);

        try self.sendFrame(&frame);
    }

    /// 发送 Pong
    pub fn sendPong(self: *Self, data: []const u8) WebSocketError!void {
        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        var frame = Frame.pong(data, self.allocator) catch {
            return WebSocketError.OutOfMemory;
        };
        defer frame.deinit(self.allocator);

        try self.sendFrame(&frame);
    }

    /// 发送帧
    fn sendFrame(self: *Self, frame: *const Frame) WebSocketError!void {
        const stream = self.stream orelse return WebSocketError.NotConnected;

        const encoded = frame.encode(self.allocator) catch {
            return WebSocketError.OutOfMemory;
        };
        defer self.allocator.free(encoded);

        _ = stream.write(encoded) catch {
            return WebSocketError.SendFailed;
        };

        self.bytes_sent += encoded.len;
    }

    /// 接收消息
    pub fn receive(self: *Self) WebSocketError!Message {
        if (self.state != .connected) {
            return WebSocketError.NotConnected;
        }

        const stream = self.stream orelse return WebSocketError.NotConnected;

        // 读取数据
        var buffer: [65536]u8 = undefined;
        const bytes_read = stream.read(&buffer) catch {
            return WebSocketError.ReceiveFailed;
        };

        if (bytes_read == 0) {
            return WebSocketError.ConnectionClosed;
        }

        self.bytes_received += bytes_read;

        // 解析帧
        const result = Frame.decode(buffer[0..bytes_read], self.allocator) catch {
            return WebSocketError.InvalidFrame;
        };
        var frame = result.frame;

        // 处理控制帧
        if (frame.opcode.isControl()) {
            if (frame.opcode == .ping and self.config.auto_pong) {
                self.sendPong(frame.payload) catch {};
            }
            if (frame.opcode == .close) {
                self.state = .closing;
            }
        }

        self.messages_received += 1;

        return .{
            .opcode = frame.opcode,
            .data = frame.payload,
            .is_final = frame.fin,
        };
    }

    /// 发送关闭帧并关闭连接
    pub fn closeWithCode(self: *Self, code: CloseCode, reason: []const u8) void {
        if (self.state == .connected) {
            self.state = .closing;

            var frame = Frame.close(code, reason, self.allocator) catch {
                self.forceClose();
                return;
            };
            defer frame.deinit(self.allocator);

            self.sendFrame(&frame) catch {};
        }

        self.forceClose();
    }

    /// 关闭连接
    pub fn close(self: *Self) void {
        self.closeWithCode(.normal, "");
    }

    /// 强制关闭
    fn forceClose(self: *Self) void {
        if (self.stream) |stream| {
            stream.close();
        }
        self.stream = null;
        self.state = .closed;
    }

    /// 获取连接状态
    pub fn getState(self: *const Self) ConnectionState {
        return self.state;
    }

    /// 检查是否已连接
    pub fn isConnected(self: *const Self) bool {
        return self.state == .connected;
    }

    /// 获取统计信息
    pub fn getStats(self: *const Self) struct {
        bytes_sent: u64,
        bytes_received: u64,
        messages_sent: u64,
        messages_received: u64,
    } {
        return .{
            .bytes_sent = self.bytes_sent,
            .bytes_received = self.bytes_received,
            .messages_sent = self.messages_sent,
            .messages_received = self.messages_received,
        };
    }
};

/// WebSocket 客户端构建器
pub const WebSocketClientBuilder = struct {
    allocator: Allocator,
    config: WebSocketConfig,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .config = .{},
        };
    }

    pub fn connectTimeout(self: *Self, ms: u32) *Self {
        self.config.connect_timeout_ms = ms;
        return self;
    }

    pub fn readTimeout(self: *Self, ms: u32) *Self {
        self.config.read_timeout_ms = ms;
        return self;
    }

    pub fn writeTimeout(self: *Self, ms: u32) *Self {
        self.config.write_timeout_ms = ms;
        return self;
    }

    pub fn maxFrameSize(self: *Self, size: usize) *Self {
        self.config.max_frame_size = size;
        return self;
    }

    pub fn maxMessageSize(self: *Self, size: usize) *Self {
        self.config.max_message_size = size;
        return self;
    }

    pub fn autoPong(self: *Self, enabled: bool) *Self {
        self.config.auto_pong = enabled;
        return self;
    }

    pub fn pingInterval(self: *Self, ms: u32) *Self {
        self.config.ping_interval_ms = ms;
        return self;
    }

    pub fn connect(self: *Self, url: []const u8) WebSocketError!WebSocketClient {
        return WebSocketClient.connect(self.allocator, url, self.config);
    }

    pub fn build(self: *Self) WebSocketClient {
        return WebSocketClient.init(self.allocator, self.config);
    }
};

/// 创建 WebSocket 客户端构建器
pub fn webSocketClient(allocator: Allocator) WebSocketClientBuilder {
    return WebSocketClientBuilder.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "WebSocketConfig defaults" {
    const config = WebSocketConfig{};
    try std.testing.expectEqual(@as(u32, 30000), config.connect_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.read_timeout_ms);
    try std.testing.expectEqual(@as(usize, 65536), config.max_frame_size);
    try std.testing.expect(config.auto_pong);
}

test "Opcode classification" {
    try std.testing.expect(Opcode.text.isData());
    try std.testing.expect(Opcode.binary.isData());
    try std.testing.expect(Opcode.continuation.isData());

    try std.testing.expect(Opcode.ping.isControl());
    try std.testing.expect(Opcode.pong.isControl());
    try std.testing.expect(Opcode.close.isControl());
}

test "parseUrl basic" {
    const result1 = try parseUrl("ws://localhost:8080/ws");
    try std.testing.expectEqualStrings("localhost", result1.host);
    try std.testing.expectEqual(@as(u16, 8080), result1.port);
    try std.testing.expectEqualStrings("/ws", result1.path);
    try std.testing.expect(!result1.is_secure);

    const result2 = try parseUrl("wss://example.com/chat");
    try std.testing.expectEqualStrings("example.com", result2.host);
    try std.testing.expectEqual(@as(u16, 443), result2.port);
    try std.testing.expectEqualStrings("/chat", result2.path);
    try std.testing.expect(result2.is_secure);
}

test "parseUrl default port" {
    const result1 = try parseUrl("ws://localhost/");
    try std.testing.expectEqual(@as(u16, 80), result1.port);

    const result2 = try parseUrl("wss://localhost/");
    try std.testing.expectEqual(@as(u16, 443), result2.port);
}

test "parseUrl invalid" {
    const result = parseUrl("http://localhost:8080/");
    try std.testing.expectError(WebSocketError.InvalidUrl, result);
}

test "Frame text creation" {
    const allocator = std.testing.allocator;

    var frame = try Frame.text("hello", allocator);
    defer frame.deinit(allocator);

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.text, frame.opcode);
    try std.testing.expect(frame.masked);
    try std.testing.expectEqual(@as(u64, 5), frame.payload_length);
    try std.testing.expectEqualStrings("hello", frame.payload);
}

test "Frame encode and decode" {
    const allocator = std.testing.allocator;

    var frame = try Frame.text("test message", allocator);
    defer frame.deinit(allocator);

    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    const decoded = try Frame.decode(encoded, allocator);
    var decoded_frame = decoded.frame;
    defer decoded_frame.deinit(allocator);

    try std.testing.expectEqual(frame.opcode, decoded_frame.opcode);
    try std.testing.expectEqual(frame.fin, decoded_frame.fin);
    try std.testing.expectEqualStrings("test message", decoded_frame.payload);
}

test "Frame ping creation" {
    const allocator = std.testing.allocator;

    var frame = try Frame.ping("ping data", allocator);
    defer frame.deinit(allocator);

    try std.testing.expectEqual(Opcode.ping, frame.opcode);
    try std.testing.expect(frame.opcode.isControl());
}

test "Frame close creation" {
    const allocator = std.testing.allocator;

    var frame = try Frame.close(.normal, "goodbye", allocator);
    defer frame.deinit(allocator);

    try std.testing.expectEqual(Opcode.close, frame.opcode);
    try std.testing.expectEqual(@as(u64, 9), frame.payload_length); // 2 bytes code + 7 bytes reason
}

test "WebSocketClient init" {
    const allocator = std.testing.allocator;

    var client = WebSocketClient.init(allocator, .{});
    try std.testing.expectEqual(ConnectionState.disconnected, client.getState());
    try std.testing.expect(!client.isConnected());
}

test "WebSocketClientBuilder configuration" {
    const allocator = std.testing.allocator;

    var builder = webSocketClient(allocator);
    _ = builder.connectTimeout(5000).readTimeout(10000).autoPong(false).pingInterval(30000);

    try std.testing.expectEqual(@as(u32, 5000), builder.config.connect_timeout_ms);
    try std.testing.expectEqual(@as(u32, 10000), builder.config.read_timeout_ms);
    try std.testing.expect(!builder.config.auto_pong);
    try std.testing.expectEqual(@as(u32, 30000), builder.config.ping_interval_ms);
}

test "WebSocketClient stats" {
    const allocator = std.testing.allocator;

    const client = WebSocketClient.init(allocator, .{});
    const stats = client.getStats();

    try std.testing.expectEqual(@as(u64, 0), stats.bytes_sent);
    try std.testing.expectEqual(@as(u64, 0), stats.bytes_received);
    try std.testing.expectEqual(@as(u64, 0), stats.messages_sent);
    try std.testing.expectEqual(@as(u64, 0), stats.messages_received);
}

test "WebSocketClient send without connection" {
    const allocator = std.testing.allocator;

    var client = WebSocketClient.init(allocator, .{});
    const result = client.sendText("hello");
    try std.testing.expectError(WebSocketError.NotConnected, result);
}

test "Message type checks" {
    const allocator = std.testing.allocator;
    var text_msg = Message{ .opcode = .text, .data = try allocator.dupe(u8, "hello"), .is_final = true };
    defer text_msg.deinit(allocator);

    try std.testing.expect(text_msg.isText());
    try std.testing.expect(!text_msg.isBinary());
    try std.testing.expect(!text_msg.isClose());

    const text_content = text_msg.getText();
    try std.testing.expect(text_content != null);
    try std.testing.expectEqualStrings("hello", text_content.?);
}

test "CloseCode values" {
    try std.testing.expectEqual(@as(u16, 1000), @intFromEnum(CloseCode.normal));
    try std.testing.expectEqual(@as(u16, 1001), @intFromEnum(CloseCode.going_away));
    try std.testing.expectEqual(@as(u16, 1002), @intFromEnum(CloseCode.protocol_error));
}
