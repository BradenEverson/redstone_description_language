//! Named Binary Tag Structure Definition

const std = @import("std");

pub fn unzip_nbt(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    var file_stream = file.reader(&buf);

    var buffer: [65536]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&file_stream.interface, .gzip, &buffer);

    const data = try decomp.reader.allocRemaining(alloc, .unlimited);

    return data;
}

pub fn zip_nbt(path: []const u8, data: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var file_buffer: [65536]u8 = undefined;
    var file_stream = file.writer(&file_buffer);
    const file_writer = &file_stream.interface;

    var comp_buffer: [65536]u8 = undefined;

    var comp = std.compress.flate.Compress.init(file_writer, &comp_buffer, .{ .container = .gzip });

    _ = try comp.writer.write(data);
    try comp.writer.flush();
    // try file_writer.flush();
}

pub const NamedBinaryTree = struct {
    entries: std.AutoHashMapUnmanaged([]const u8, NbtValue) = .{},

    pub fn load_unzipped_bytes(self: *NamedBinaryTree, alloc: std.mem.Allocator, unzipped: []const u8) !void {
        _ = self;
        _ = alloc;

        for (unzipped) |byte| {
            std.debug.print("{X:2}\n", .{byte});
        }
    }
};

pub const NbtValue = union(enum) {};
