//! Named Binary Tag Structure Definition

const std = @import("std");

const node = @import("nbt/node.zig");
const NbtNode = node.NbtNode;

pub fn unzipNbt(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    var file_stream = file.reader(&buf);

    var buffer: [65536]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&file_stream.interface, .gzip, &buffer);

    const data = try decomp.reader.allocRemaining(alloc, .unlimited);

    return data;
}

pub fn zipNbt(path: []const u8, data: []const u8) !void {
    const cwd = std.fs.cwd();

    var file = try cwd.createFile(path, .{});
    defer file.close();

    try file.writeAll(data);
}

pub fn loadUnzippedBytes(alloc: std.mem.Allocator, unzipped: []const u8) !*NbtNode {
    const result, _ = try NbtNode.parseSingular(alloc, unzipped, true, null);
    return result;
}

pub fn createNode(alloc: std.mem.Allocator, name: ?[]const u8, ty: node.NbtType) !*NbtNode {
    const n = try alloc.create(NbtNode);
    n.* = .{ .name = name, .ty = ty };
    return n;
}
