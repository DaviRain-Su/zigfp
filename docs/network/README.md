# Network 模块

网络操作，提供类型安全的网络通信能力。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| tcp.md | `TcpClient` | TCP 客户端 |
| udp.md | `UdpSocket` | UDP 套接字 |
| websocket.md | `WebSocketClient` | WebSocket 客户端 |
| http.md | `HttpRequest`, `HttpResponse` | HTTP 客户端 |
| connection_pool.md | `ConnectionPool` | 连接池 |
| network.md | `NetworkEffect` | 网络效果系统 |

## 导入方式

```zig
const network = @import("zigfp").network;

const TcpClient = network.TcpClient;
const HttpRequest = network.HttpRequest;
const WebSocketClient = network.WebSocketClient;
```

## 快速示例

### TCP 客户端

```zig
var client = try TcpClient.connect(allocator, "127.0.0.1", 8080, .{});
defer client.close();

try client.send("Hello, Server!");
const response = try client.receive(allocator);
defer allocator.free(response);
```

### UDP 套接字

```zig
var socket = try UdpSocket.bind(allocator, "0.0.0.0", 0, .{});
defer socket.close();

const target = try net.Address.parseIp("127.0.0.1", 8080);
try socket.sendTo("Hello, UDP!", target);

var buffer: [1024]u8 = undefined;
const result = try socket.receiveFrom(&buffer);
```

### WebSocket 客户端

```zig
var client = try WebSocketClient.connect(allocator, "ws://127.0.0.1:8080/ws", .{});
defer client.close();

try client.sendText("Hello, WebSocket!");
const message = try client.receive(allocator);
defer message.deinit(allocator);
```

### HTTP 客户端

```zig
var request = try HttpRequest.get(allocator, "https://api.example.com/data");
defer request.deinit();

try request.withHeader("Authorization", "Bearer token");
const response = try request.send(allocator);
defer response.deinit();
```

### Connection Pool

```zig
var pool = try ConnectionPool.init(allocator, .{
    .max_connections_per_host = 10,
    .idle_timeout_ms = 60000,
});
defer pool.deinit();

const conn = try pool.acquire("example.com", 443);
defer pool.release(conn);
```
