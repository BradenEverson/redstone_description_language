//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("structure/nbt.zig");
const tag = @import("structure/tag.zig");

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
        _ = val;

        // nbt.zip_nbt("test", data) catch @panic("zipping failed");
    }
}
