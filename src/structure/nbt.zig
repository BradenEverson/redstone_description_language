//! Named Binary Tag Structure Definition

const std = @import("std");

pub fn parse_nbt(alloc: std.mem.Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    var file_stream = file.reader(&buf);

    var buffer: [65536]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&file_stream.interface, .gzip, &buffer);

    const data = try decomp.reader.allocRemaining(alloc, .unlimited);
    defer alloc.free(data);

    for (data) |byte| {
        std.debug.print("0x{X:02}\n", .{byte});
    }
}
