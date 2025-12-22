const std = @import("std");

const dl = @import("dl.zig");
const construction = @import("construction.zig");
const vhdl = @import("vhdl.zig");
const nbt = @import("nbt.zig");

pub fn main() void {
    // const alloc = std.heap.page_allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const nbt_arena = arena.allocator();

    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |file_path| {
        const data = std.fs.cwd().readFileAlloc(alloc, file_path, 65536) catch {
            std.debug.print("Error: File does not exist!\n", .{});
            std.process.exit(1);
        };

        defer alloc.free(data);

        const circuit = vhdl.parseToCircuit(alloc, data) catch {
            std.debug.print("Failed to Parse VHDL file\n", .{});
            std.process.exit(1);
        };

        const entity = construction.CircuitEntity.translateToEntity(alloc, circuit) catch @panic("Failed to translate");
        const nbt_ir = entity.toNbt(nbt_arena) catch @panic("Failed to create NBT IR");

        var bytes = std.ArrayList(u8){};

        nbt_ir.toBytes(alloc, &bytes, true, true) catch @panic("Failed to translate to bytes");
        nbt.zipNbt("out.nbt", bytes.items) catch @panic("Failed to zip to NBT");
    } else {
        std.debug.print("Missing Input file!!!\nUsage: ./redstone 'file.vhd' or whatever\n", .{});
    }
}

test {
    _ = @import("dl.zig");
    _ = @import("vhdl.zig");
    _ = @import("nbt.zig");
    _ = @import("nbt/node.zig");
    _ = @import("construction.zig");
}
