//! Named Binary Tag Structure Definition

const std = @import("std");

const node = @import("nbt/node.zig");
const NbtNode = node.NbtNode;
const NbtType = node.NbtType;

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

pub fn create(alloc: std.mem.Allocator, name: ?[]const u8, ty: NbtType) !*NbtNode {
    const n = try alloc.create(NbtNode);
    n.* = .{ .name = name, .ty = ty };
    return n;
}

pub fn compound(alloc: std.mem.Allocator, name: ?[]const u8) !*NbtNode {
    return create(alloc, name, .{ .compound = .{} });
}

pub fn add(alloc: std.mem.Allocator, comp: *NbtNode, child: *NbtNode) !void {
    try comp.ty.compound.append(alloc, child);
}

pub fn int(alloc: std.mem.Allocator, name: ?[]const u8, value: u32) !*NbtNode {
    return create(alloc, name, .{ .int = value });
}

pub fn string(alloc: std.mem.Allocator, name: ?[]const u8, value: []const u8) !*NbtNode {
    return create(alloc, name, .{ .string = value });
}

pub fn list(alloc: std.mem.Allocator, name: ?[]const u8, items: []*NbtNode) !*NbtNode {
    return create(alloc, name, .{ .list = items });
}
