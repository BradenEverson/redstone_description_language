//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("structure/nbt.zig");

pub fn main() void {
    // const alloc = std.heap.page_allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file_path| {
        nbt.parse_nbt(alloc, file_path) catch @panic("Failed to parse NBT file");
    }
}
