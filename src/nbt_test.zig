//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("nbt.zig");
const node = @import("nbt/node.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file_path| {
        const data = nbt.unzipNbt(alloc, file_path) catch @panic("unzipping failed");
        defer alloc.free(data);
        const val = nbt.loadUnzippedBytes(a_alloc, data) catch @panic("Failed to parse NBT");
        std.debug.print("{f}\n", .{val});

        var al = std.ArrayList(u8){};
        defer al.deinit(alloc);

        val.toBytes(alloc, &al, true, true) catch @panic(":(");

        const val_2 = nbt.loadUnzippedBytes(a_alloc, al.items) catch @panic("Failed to parse NBT");
        std.debug.print("{f}\n", .{val_2});

        nbt.zipNbt("out.nbt", al.items) catch @panic("zipping failed");
    }
}
