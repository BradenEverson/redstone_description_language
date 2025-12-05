const std = @import("std");

pub fn main() void {
    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file| {
        std.debug.print("Compiling {s}\n", .{file});
    } else {
        std.debug.print("Missing Input file!!!\nUsage: ./redstone 'file.vhdl' or whatever\n", .{});
    }
}
