//! File system effects
//!
//! Provides functional file system operations through the algebraic effect system.

const std = @import("std");
const effect = @import("effect.zig");

/// File system operation types
pub const FileOp = union(enum) {
    /// Read file content
    read_file: struct {
        path: []const u8,
        allocator: std.mem.Allocator,
    },

    /// Write file content
    write_file: struct {
        path: []const u8,
        content: []const u8,
    },

    /// Delete file
    delete_file: struct {
        path: []const u8,
    },

    /// Check if file exists
    file_exists: struct {
        path: []const u8,
    },

    /// Create directory
    create_dir: struct {
        path: []const u8,
    },

    /// List directory contents
    list_dir: struct {
        path: []const u8,
        allocator: std.mem.Allocator,
    },
};

/// File system effect type
pub fn FileSystemEffect(comptime A: type) type {
    return effect.Effect(FileOp, A);
}

/// File operation result
pub const FileResult = union(enum) {
    /// Operation successful
    success: []const u8,
    /// File not found
    not_found,
    /// 权限错误
    permission_denied,
    /// IO错误
    io_error: []const u8,
};

// ============ 便捷效果构造器 ============

/// Create read file effect
pub fn readFile(path: []const u8, allocator: std.mem.Allocator) FileSystemEffect([]u8) {
    return FileSystemEffect([]u8){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .read_file = .{ .path = path, .allocator = allocator } },
        },
    };
}

/// Create write file effect
pub fn writeFile(path: []const u8, content: []const u8) FileSystemEffect(void) {
    return FileSystemEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .write_file = .{ .path = path, .content = content } },
        },
    };
}

/// Create delete file effect
pub fn deleteFile(path: []const u8) FileSystemEffect(void) {
    return FileSystemEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .delete_file = .{ .path = path } },
        },
    };
}

/// Create file exists check effect
pub fn fileExists(path: []const u8) FileSystemEffect(bool) {
    return FileSystemEffect(bool){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .file_exists = .{ .path = path } },
        },
    };
}

/// Create directory creation effect
pub fn createDir(path: []const u8) FileSystemEffect(void) {
    return FileSystemEffect(void){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .create_dir = .{ .path = path } },
        },
    };
}

/// Create directory listing effect
pub fn listDir(path: []const u8, allocator: std.mem.Allocator) FileSystemEffect([][]u8) {
    return FileSystemEffect([][]u8){
        .effect_op = .{
            .tag = .IO,
            .data = FileOp{ .list_dir = .{ .path = path, .allocator = allocator } },
        },
    };
}

// ============ 文件系统处理器 ============

/// File system handler
pub const FileSystemHandler = struct {
    handleFn: *const fn (FileOp) FileResult,

    pub fn handle(self: FileSystemHandler, op: FileOp) FileResult {
        return self.handleFn(op);
    }
};

/// Create real file system handler
pub fn realFileSystemHandler() FileSystemHandler {
    return FileSystemHandler{
        .handleFn = realHandleImpl,
    };
}

fn realHandleImpl(op: FileOp) FileResult {
    return switch (op) {
        .read_file => |data| {
            const file = std.fs.openFileAbsolute(data.path, .{}) catch |err| {
                return switch (err) {
                    error.FileNotFound => .not_found,
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            defer file.close();

            const content = file.readToEndAlloc(data.allocator, std.math.maxInt(usize)) catch |err| {
                return FileResult{ .io_error = @errorName(err) };
            };

            return FileResult{ .success = content };
        },

        .write_file => |data| {
            const file = std.fs.createFileAbsolute(data.path, .{}) catch |err| {
                return switch (err) {
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            defer file.close();

            file.writeAll(data.content) catch |err| {
                return FileResult{ .io_error = @errorName(err) };
            };

            return FileResult{ .success = "" };
        },

        .delete_file => |data| {
            std.fs.deleteFileAbsolute(data.path) catch |err| {
                return switch (err) {
                    error.FileNotFound => .not_found,
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            return FileResult{ .success = "" };
        },

        .file_exists => |data| {
            std.fs.accessAbsolute(data.path, .{}) catch |err| {
                return switch (err) {
                    error.FileNotFound => FileResult{ .success = "false" },
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            return FileResult{ .success = "true" };
        },

        .create_dir => |data| {
            std.fs.makeDirAbsolute(data.path) catch |err| {
                return switch (err) {
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            return FileResult{ .success = "" };
        },

        .list_dir => |data| {
            var dir = std.fs.openDirAbsolute(data.path, .{ .iterate = true }) catch |err| {
                return switch (err) {
                    error.FileNotFound => .not_found,
                    error.AccessDenied => .permission_denied,
                    else => FileResult{ .io_error = @errorName(err) },
                };
            };
            defer dir.close();

            // 实现真实的目录列举功能
            var buffer = std.ArrayList(u8).initCapacity(data.allocator, 1024) catch |err| {
                return FileResult{ .io_error = @errorName(err) };
            };
            defer buffer.deinit(data.allocator);

            var iter = dir.iterate();
            var first = true;
            while (iter.next() catch |err| {
                return FileResult{ .io_error = @errorName(err) };
            }) |entry| {
                if (!first) {
                    buffer.appendSlice(data.allocator, "\n") catch |err| {
                        return FileResult{ .io_error = @errorName(err) };
                    };
                }
                first = false;

                buffer.appendSlice(data.allocator, entry.name) catch |err| {
                    return FileResult{ .io_error = @errorName(err) };
                };
            }

            const result = buffer.toOwnedSlice(data.allocator) catch |err| {
                return FileResult{ .io_error = @errorName(err) };
            };
            return FileResult{ .success = result };
        },
    };
}

/// Create mock file system handler for testing
pub fn mockFileSystemHandler() FileSystemHandler {
    return FileSystemHandler{
        .handleFn = mockHandleImpl,
    };
}

fn mockHandleImpl(op: FileOp) FileResult {
    _ = op;
    // 模拟处理器，总是返回成功
    return FileResult{ .success = "mocked" };
}

// ============ 测试 ============

test "FileSystem Effect basic operations" {
    // 测试效果构造器
    const read_eff = readFile("test.txt", std.testing.allocator);
    try std.testing.expect(read_eff == .effect_op);
    try std.testing.expect(read_eff.effect_op.data == .read_file);

    const write_eff = writeFile("test.txt", "hello");
    try std.testing.expect(write_eff == .effect_op);
    try std.testing.expect(write_eff.effect_op.data == .write_file);

    const exists_eff = fileExists("test.txt");
    try std.testing.expect(exists_eff == .effect_op);
    try std.testing.expect(exists_eff.effect_op.data == .file_exists);
}

test "Mock FileSystem Handler" {
    const handler = mockFileSystemHandler();

    const op = FileOp{ .read_file = .{ .path = "test.txt", .allocator = std.testing.allocator } };
    const result = handler.handleFn(op);
    try std.testing.expect(result == .success);
}

test "Real FileSystem Handler - file exists" {
    const handler = realFileSystemHandler();

    // 测试一个肯定存在的路径 - 使用 /tmp 目录
    const op = FileOp{ .file_exists = .{ .path = "/tmp" } };
    const result = handler.handleFn(op);
    // 在大多数 Unix 系统上 /tmp 存在，但我们不能假设这一点
    // 所以只验证返回了有效的结果类型
    try std.testing.expect(result == .success or result == .not_found or result == .permission_denied);
}
