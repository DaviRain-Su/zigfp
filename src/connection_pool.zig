const std = @import("std");
const Allocator = std.mem.Allocator;

/// HTTP 连接池 - 管理和复用 HTTP 连接
///
/// 功能:
/// - 连接复用，避免重复建立 TCP 连接
/// - 连接超时自动清理
/// - 最大连接数限制
/// - 按主机分组管理连接
///
/// 示例:
/// ```zig
/// var pool = try ConnectionPool.init(allocator, .{
///     .max_connections_per_host = 10,
///     .idle_timeout_ms = 60000,
/// });
/// defer pool.deinit();
///
/// const conn = try pool.acquire("example.com", 443);
/// defer pool.release(conn);
/// ```
pub const ConnectionPool = struct {
    allocator: Allocator,
    config: Config,
    hosts: std.StringHashMap(HostConnections),
    mutex: std.Thread.Mutex,
    total_connections: usize,

    /// 连接池配置
    pub const Config = struct {
        /// 每个主机的最大连接数
        max_connections_per_host: u32 = 10,
        /// 总最大连接数
        max_total_connections: u32 = 100,
        /// 空闲超时时间（毫秒）
        idle_timeout_ms: u64 = 60000,
        /// 连接超时时间（毫秒）
        connect_timeout_ms: u64 = 30000,
    };

    /// 连接状态
    pub const ConnectionState = enum {
        idle,
        in_use,
        closed,
    };

    /// 池化连接
    pub const PooledConnection = struct {
        host: []const u8,
        port: u16,
        state: ConnectionState,
        created_at: i64,
        last_used_at: i64,
        id: u64,

        /// 检查连接是否过期
        pub fn isExpired(self: *const PooledConnection, timeout_ms: u64) bool {
            const now = std.time.milliTimestamp();
            const idle_time: u64 = @intCast(now - self.last_used_at);
            return idle_time > timeout_ms;
        }

        /// 检查连接是否可用
        pub fn isAvailable(self: *const PooledConnection) bool {
            return self.state == .idle;
        }

        /// 标记为使用中
        pub fn markInUse(self: *PooledConnection) void {
            self.state = .in_use;
            self.last_used_at = std.time.milliTimestamp();
        }

        /// 标记为空闲
        pub fn markIdle(self: *PooledConnection) void {
            self.state = .idle;
            self.last_used_at = std.time.milliTimestamp();
        }

        /// 标记为关闭
        pub fn markClosed(self: *PooledConnection) void {
            self.state = .closed;
        }
    };

    /// 主机连接组
    const HostConnections = struct {
        connections: std.ArrayList(PooledConnection),
        host_key: []const u8,

        fn init(allocator: Allocator, host_key: []const u8) !HostConnections {
            return .{
                .connections = try std.ArrayList(PooledConnection).initCapacity(allocator, 4),
                .host_key = host_key,
            };
        }

        fn deinit(self: *HostConnections, allocator: Allocator) void {
            self.connections.deinit(allocator);
        }

        fn activeCount(self: *const HostConnections) usize {
            var count: usize = 0;
            for (self.connections.items) |conn| {
                if (conn.state != .closed) {
                    count += 1;
                }
            }
            return count;
        }

        fn findAvailable(self: *HostConnections) ?*PooledConnection {
            for (self.connections.items) |*conn| {
                if (conn.isAvailable()) {
                    return conn;
                }
            }
            return null;
        }
    };

    /// 连接池错误
    pub const Error = error{
        PoolExhausted,
        HostLimitReached,
        ConnectionTimeout,
        InvalidHost,
        OutOfMemory,
    };

    /// 连接池统计信息
    pub const Stats = struct {
        total_connections: usize,
        active_connections: usize,
        idle_connections: usize,
        hosts_count: usize,
    };

    /// 初始化连接池
    pub fn init(allocator: Allocator, config: Config) !ConnectionPool {
        return .{
            .allocator = allocator,
            .config = config,
            .hosts = std.StringHashMap(HostConnections).init(allocator),
            .mutex = .{},
            .total_connections = 0,
        };
    }

    /// 释放连接池
    pub fn deinit(self: *ConnectionPool) void {
        var it = self.hosts.valueIterator();
        while (it.next()) |host_conns| {
            host_conns.deinit(self.allocator);
        }
        // 释放所有 host key
        var key_it = self.hosts.keyIterator();
        while (key_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.hosts.deinit();
    }

    /// 获取连接
    ///
    /// 尝试从池中获取可用连接，如果没有则创建新连接
    pub fn acquire(self: *ConnectionPool, host: []const u8, port: u16) Error!*PooledConnection {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 创建主机键
        const host_key = self.makeHostKey(host, port) catch return Error.OutOfMemory;

        // 清理过期连接
        self.cleanupExpiredLocked(host_key);

        // 尝试获取现有连接
        if (self.hosts.getPtr(host_key)) |host_conns| {
            if (host_conns.findAvailable()) |conn| {
                conn.markInUse();
                self.allocator.free(host_key);
                return conn;
            }

            // 检查主机连接数限制
            if (host_conns.activeCount() >= self.config.max_connections_per_host) {
                self.allocator.free(host_key);
                return Error.HostLimitReached;
            }
        }

        // 检查总连接数限制
        if (self.total_connections >= self.config.max_total_connections) {
            self.allocator.free(host_key);
            return Error.PoolExhausted;
        }

        // 创建新连接
        return self.createConnectionLocked(host_key, host, port);
    }

    /// 释放连接回池
    pub fn release(self: *ConnectionPool, conn: *PooledConnection) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        conn.markIdle();
    }

    /// 关闭连接
    pub fn close(self: *ConnectionPool, conn: *PooledConnection) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        conn.markClosed();
        self.total_connections -|= 1;
    }

    /// 清理所有过期连接
    pub fn cleanup(self: *ConnectionPool) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        var cleaned: usize = 0;
        var it = self.hosts.iterator();
        while (it.next()) |entry| {
            cleaned += self.cleanupHostExpired(entry.value_ptr);
        }
        return cleaned;
    }

    /// 获取统计信息
    pub fn getStats(self: *ConnectionPool) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active: usize = 0;
        var idle: usize = 0;

        var it = self.hosts.valueIterator();
        while (it.next()) |host_conns| {
            for (host_conns.connections.items) |conn| {
                switch (conn.state) {
                    .in_use => active += 1,
                    .idle => idle += 1,
                    .closed => {},
                }
            }
        }

        return .{
            .total_connections = self.total_connections,
            .active_connections = active,
            .idle_connections = idle,
            .hosts_count = self.hosts.count(),
        };
    }

    /// 创建主机键
    fn makeHostKey(self: *ConnectionPool, host: []const u8, port: u16) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ host, port });
    }

    /// 创建新连接（内部，需持有锁）
    fn createConnectionLocked(self: *ConnectionPool, host_key: []const u8, host: []const u8, port: u16) Error!*PooledConnection {
        const now = std.time.milliTimestamp();

        const new_conn = PooledConnection{
            .host = host,
            .port = port,
            .state = .in_use,
            .created_at = now,
            .last_used_at = now,
            .id = self.generateConnectionId(),
        };

        // 获取或创建主机连接组
        const result = self.hosts.getOrPut(host_key) catch return Error.OutOfMemory;
        if (!result.found_existing) {
            result.value_ptr.* = HostConnections.init(self.allocator, host_key) catch return Error.OutOfMemory;
        } else {
            // 如果已存在，释放新创建的 key
            self.allocator.free(host_key);
        }

        result.value_ptr.connections.append(self.allocator, new_conn) catch return Error.OutOfMemory;
        self.total_connections += 1;

        // 返回最后添加的连接
        return &result.value_ptr.connections.items[result.value_ptr.connections.items.len - 1];
    }

    /// 清理指定主机键的过期连接（内部，需持有锁）
    fn cleanupExpiredLocked(self: *ConnectionPool, host_key: []const u8) void {
        if (self.hosts.getPtr(host_key)) |host_conns| {
            _ = self.cleanupHostExpired(host_conns);
        }
    }

    /// 清理主机的过期连接
    fn cleanupHostExpired(self: *ConnectionPool, host_conns: *HostConnections) usize {
        var cleaned: usize = 0;
        var i: usize = 0;
        while (i < host_conns.connections.items.len) {
            const conn = &host_conns.connections.items[i];
            if (conn.state == .idle and conn.isExpired(self.config.idle_timeout_ms)) {
                conn.markClosed();
                self.total_connections -|= 1;
                cleaned += 1;
            }
            i += 1;
        }
        return cleaned;
    }

    /// 生成连接 ID
    fn generateConnectionId(self: *ConnectionPool) u64 {
        _ = self;
        const S = struct {
            var counter: u64 = 0;
        };
        return @atomicRmw(u64, &S.counter, .Add, 1, .seq_cst);
    }
};

/// 连接池构建器 - 流畅 API
pub const ConnectionPoolBuilder = struct {
    config: ConnectionPool.Config,
    allocator: Allocator,

    pub fn init(allocator: Allocator) ConnectionPoolBuilder {
        return .{
            .allocator = allocator,
            .config = .{},
        };
    }

    pub fn maxConnectionsPerHost(self: *ConnectionPoolBuilder, max: u32) *ConnectionPoolBuilder {
        self.config.max_connections_per_host = max;
        return self;
    }

    pub fn maxTotalConnections(self: *ConnectionPoolBuilder, max: u32) *ConnectionPoolBuilder {
        self.config.max_total_connections = max;
        return self;
    }

    pub fn idleTimeout(self: *ConnectionPoolBuilder, timeout_ms: u64) *ConnectionPoolBuilder {
        self.config.idle_timeout_ms = timeout_ms;
        return self;
    }

    pub fn connectTimeout(self: *ConnectionPoolBuilder, timeout_ms: u64) *ConnectionPoolBuilder {
        self.config.connect_timeout_ms = timeout_ms;
        return self;
    }

    pub fn build(self: *ConnectionPoolBuilder) !ConnectionPool {
        return ConnectionPool.init(self.allocator, self.config);
    }
};

/// 创建连接池构建器
pub fn connectionPool(allocator: Allocator) ConnectionPoolBuilder {
    return ConnectionPoolBuilder.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "ConnectionPool basic acquire and release" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{
        .max_connections_per_host = 5,
        .max_total_connections = 10,
    });
    defer pool.deinit();

    // 获取连接
    const conn = try pool.acquire("example.com", 443);
    try std.testing.expectEqual(ConnectionPool.ConnectionState.in_use, conn.state);
    try std.testing.expectEqual(@as(u16, 443), conn.port);

    // 释放连接
    pool.release(conn);
    try std.testing.expectEqual(ConnectionPool.ConnectionState.idle, conn.state);

    // 再次获取应该复用
    const conn2 = try pool.acquire("example.com", 443);
    try std.testing.expectEqual(conn.id, conn2.id);
    pool.release(conn2);
}

test "ConnectionPool host limit" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{
        .max_connections_per_host = 2,
        .max_total_connections = 10,
    });
    defer pool.deinit();

    // 获取两个连接
    const conn1 = try pool.acquire("example.com", 443);
    const conn2 = try pool.acquire("example.com", 443);

    // 第三个应该失败
    const result = pool.acquire("example.com", 443);
    try std.testing.expectError(ConnectionPool.Error.HostLimitReached, result);

    pool.release(conn1);
    pool.release(conn2);
}

test "ConnectionPool total limit" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{
        .max_connections_per_host = 10,
        .max_total_connections = 3,
    });
    defer pool.deinit();

    // 获取三个连接到不同主机
    const conn1 = try pool.acquire("host1.com", 443);
    const conn2 = try pool.acquire("host2.com", 443);
    const conn3 = try pool.acquire("host3.com", 443);

    // 第四个应该失败
    const result = pool.acquire("host4.com", 443);
    try std.testing.expectError(ConnectionPool.Error.PoolExhausted, result);

    pool.release(conn1);
    pool.release(conn2);
    pool.release(conn3);
}

test "ConnectionPool stats" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{});
    defer pool.deinit();

    const conn1 = try pool.acquire("host1.com", 80);
    _ = try pool.acquire("host2.com", 80);
    _ = try pool.acquire("host1.com", 80);

    pool.release(conn1);

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_connections);
    try std.testing.expectEqual(@as(usize, 2), stats.active_connections);
    try std.testing.expectEqual(@as(usize, 1), stats.idle_connections);
    try std.testing.expectEqual(@as(usize, 2), stats.hosts_count);
}

test "ConnectionPool builder" {
    const allocator = std.testing.allocator;

    var builder = connectionPool(allocator);
    var pool = try builder
        .maxConnectionsPerHost(20)
        .maxTotalConnections(200)
        .idleTimeout(120000)
        .connectTimeout(60000)
        .build();
    defer pool.deinit();

    try std.testing.expectEqual(@as(u32, 20), pool.config.max_connections_per_host);
    try std.testing.expectEqual(@as(u32, 200), pool.config.max_total_connections);
    try std.testing.expectEqual(@as(u64, 120000), pool.config.idle_timeout_ms);
    try std.testing.expectEqual(@as(u64, 60000), pool.config.connect_timeout_ms);
}

test "PooledConnection expiration" {
    var conn = ConnectionPool.PooledConnection{
        .host = "test.com",
        .port = 443,
        .state = .idle,
        .created_at = std.time.milliTimestamp() - 100000,
        .last_used_at = std.time.milliTimestamp() - 100000,
        .id = 1,
    };

    // 100秒前创建，超时时间50秒，应该过期
    try std.testing.expect(conn.isExpired(50000));

    // 超时时间200秒，不应该过期
    try std.testing.expect(!conn.isExpired(200000));
}

test "ConnectionPool connection reuse" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{});
    defer pool.deinit();

    // 获取并释放
    const conn1 = try pool.acquire("reuse.com", 8080);
    const id1 = conn1.id;
    pool.release(conn1);

    // 再次获取应该是同一个连接
    const conn2 = try pool.acquire("reuse.com", 8080);
    try std.testing.expectEqual(id1, conn2.id);
    pool.release(conn2);
}

test "ConnectionPool close connection" {
    const allocator = std.testing.allocator;

    var pool = try ConnectionPool.init(allocator, .{});
    defer pool.deinit();

    const conn = try pool.acquire("close.com", 443);
    const initial_count = pool.total_connections;

    pool.close(conn);

    try std.testing.expectEqual(ConnectionPool.ConnectionState.closed, conn.state);
    try std.testing.expectEqual(initial_count - 1, pool.total_connections);
}
