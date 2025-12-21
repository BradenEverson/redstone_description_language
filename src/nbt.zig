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

fn create(alloc: std.mem.Allocator, name: ?[]const u8, ty: NbtType) !*NbtNode {
    const n = try alloc.create(NbtNode);
    n.* = .{ .name = name, .ty = ty };
    return n;
}

fn compound(alloc: std.mem.Allocator, name: ?[]const u8) !*NbtNode {
    return create(alloc, name, .{ .compound = .{} });
}

fn add(alloc: std.mem.Allocator, comp: *NbtNode, child: *NbtNode) !void {
    try comp.ty.compound.append(alloc, child);
}

fn int(alloc: std.mem.Allocator, name: ?[]const u8, value: u32) !*NbtNode {
    return create(alloc, name, .{ .int = value });
}

fn string(alloc: std.mem.Allocator, name: ?[]const u8, value: []const u8) !*NbtNode {
    return create(alloc, name, .{ .string = value });
}

fn list(alloc: std.mem.Allocator, name: ?[]const u8, items: []*NbtNode) !*NbtNode {
    return create(alloc, name, .{ .list = items });
}

pub fn createDiamondStructure(alloc: std.mem.Allocator) !*NbtNode {
    const root = try compound(alloc, "");

    const size_list = try alloc.alloc(*NbtNode, 3);
    size_list[0] = try int(alloc, null, 3);
    size_list[1] = try int(alloc, null, 2);
    size_list[2] = try int(alloc, null, 2);
    try add(alloc, root, try list(alloc, "size", size_list));

    const palette_list = try alloc.alloc(*NbtNode, 2);

    const air_tag = try compound(alloc, null);
    try add(alloc, air_tag, try string(alloc, "Name", "minecraft:air"));
    palette_list[0] = air_tag;

    const diamond_tag = try compound(alloc, null);
    try add(alloc, diamond_tag, try string(alloc, "Name", "minecraft:diamond_block"));
    palette_list[1] = diamond_tag;

    try add(alloc, root, try list(alloc, "palette", palette_list));

    const total_blocks = 3 * 2 * 2;
    const blocks_list = try alloc.alloc(*NbtNode, total_blocks);

    var idx: usize = 0;
    for (0..3) |x| {
        for (0..2) |y| {
            for (0..2) |z| {
                const b_entry = try compound(alloc, null);

                const pos_list = try alloc.alloc(*NbtNode, 3);
                pos_list[0] = try int(alloc, null, @intCast(x));
                pos_list[1] = try int(alloc, null, @intCast(y));
                pos_list[2] = try int(alloc, null, @intCast(z));
                try add(alloc, b_entry, try list(alloc, "pos", pos_list));

                const state: u32 = if (x == 1 and y == 1 and z == 1) 1 else 0;
                try add(alloc, b_entry, try int(alloc, "state", state));

                blocks_list[idx] = b_entry;
                idx += 1;
            }
        }
    }
    try add(alloc, root, try list(alloc, "blocks", blocks_list));

    return root;
}
