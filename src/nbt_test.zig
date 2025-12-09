//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("structure/nbt.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file_path| {
        const data = nbt.unzip_nbt(alloc, file_path) catch @panic("unzipping failed");
        defer alloc.free(data);
        var info = nbt.NamedBinaryTree{};
        info.load_unzipped_bytes(alloc, data) catch @panic("Failed to parse");

        // nbt.zip_nbt("test", data) catch @panic("zipping failed");
    }
}
