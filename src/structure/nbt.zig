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
    defer alloc.free(data);

    return data;
}

pub fn zip_nbt(alloc: std.mem.Allocator, path: []const u8, data: []u8) !void {
    _ = alloc;
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    const file_writer = file.writer(&buf);
    var out_file = file_writer.interface;

    var comp = std.compress.flate.Compress.init(&out_file, data, .{ .container = .gzip });

    var out: [65536]u8 = undefined;
    const len = try comp.writer.write(&out);

    try file.writeAll(out[0..len]);
    try comp.end();
    try out_file.flush();
}

pub const NamedBinaryTree = struct {
    pub fn from_unzipped_bytes(unzipped: []const u8) NamedBinaryTree {
        _ = unzipped;
        return NamedBinaryTree{};
    }
};
