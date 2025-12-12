const std = @import("std");

const dl = @import("dl.zig");
const vhdl = @import("vhdl.zig");
const world = @import("structure.zig");

pub fn main() void {
    // const alloc = std.heap.page_allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file_path| {
        const data = std.fs.cwd().readFileAlloc(alloc, file_path, 65536) catch {
            std.debug.print("Error: File does not exist!\n", .{});
            std.process.exit(1);
        };

        defer alloc.free(data);

        std.debug.print("{s}\n", .{data});
    } else {
        std.debug.print("Missing Input file!!!\nUsage: ./redstone 'file.vhdl' or whatever\n", .{});
    }
}

test {
    _ = @import("dl.zig");
    _ = @import("vhdl.zig");
    _ = @import("structure/nbt.zig");
    _ = @import("structure/node.zig");
}
