//! 网络模块
//!
//! 提供类型安全的网络操作：
//! - TCP - TCP 客户端
//! - UDP - UDP 套接字
//! - WebSocket - WebSocket 客户端
//! - HTTP - HTTP 客户端
//! - ConnectionPool - 连接池
//! - Network - 统一网络抽象

const std = @import("std");

pub const tcp = @import("tcp.zig");
pub const udp = @import("udp.zig");
pub const websocket = @import("websocket.zig");
pub const http = @import("http.zig");
pub const connection_pool = @import("connection_pool.zig");
pub const network = @import("network.zig");

// ============ TCP ============
pub const TcpConfig = tcp.TcpConfig;
pub const TcpError = tcp.TcpError;
pub const TcpClient = tcp.TcpClient;
pub const TcpConnectionState = tcp.ConnectionState;

// ============ UDP ============
pub const UdpConfig = udp.UdpConfig;
pub const UdpError = udp.UdpError;
pub const UdpSocket = udp.UdpSocket;
pub const ReceiveResult = udp.ReceiveResult;

// ============ WebSocket ============
pub const WebSocketConfig = websocket.WebSocketConfig;
pub const WebSocketError = websocket.WebSocketError;
pub const WebSocketClient = websocket.WebSocketClient;
pub const WebSocketConnectionState = websocket.ConnectionState;
pub const Opcode = websocket.Opcode;

// ============ HTTP ============
pub const HttpMethod = http.HttpMethod;
pub const HttpHeader = http.HttpHeader;
pub const HttpRequest = http.HttpRequest;
pub const HttpResponse = http.HttpResponse;

// ============ Connection Pool ============
pub const ConnectionPool = connection_pool.ConnectionPool;
pub const PooledConnection = connection_pool.ConnectionPool.PooledConnection;
pub const ConnectionPoolConfig = connection_pool.ConnectionPool.Config;

// ============ Network ============
pub const NetworkEffect = network.NetworkEffect;
pub const NetworkOp = network.NetworkOp;
pub const NetworkResult = network.NetworkResult;
pub const NetworkError = network.NetworkError;

test {
    std.testing.refAllDecls(@This());
}
