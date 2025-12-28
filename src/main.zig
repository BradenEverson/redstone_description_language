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
        std.debug.print("Opening `{s}`\n", .{file_path});
        const data = std.fs.cwd().readFileAlloc(alloc, file_path, 65536) catch {
            std.debug.print("Error: File does not exist!\n", .{});
            std.process.exit(1);
        };

        defer alloc.free(data);

        std.debug.print("Parsing VHDL\n", .{});

        var circuit = vhdl.parseToCircuit(alloc, data) catch |e| {
            std.debug.print("{any}\n", .{e});
            switch (e) {
                error.ArchitectureDefBeforeEntity => std.debug.print("Architecture statement before entity description, please define an entity before it's architecture\n", .{}),
                error.DuplicateEntityDefinitions => std.debug.print("Multiple definitions of the same entity, please only define an entity once\n", .{}),
                else => std.debug.print("Failed to Parse VHDL file\n", .{}),
            }
            std.process.exit(1);
        };
        defer circuit.deinit(alloc);

        std.debug.print("Generating Circuit Entity\n", .{});

        var entity = construction.CircuitEntity.translateToEntity(alloc, circuit) catch @panic("Failed to translate");
        defer entity.deinit(alloc);

        std.debug.print("Serializing to NBT Structure Format\n", .{});

        const nbt_ir = entity.toNbt(nbt_arena) catch @panic("Failed to create NBT IR");

        var bytes = std.ArrayList(u8){};
        defer bytes.deinit(alloc);

        nbt_ir.toBytes(alloc, &bytes, true, true) catch @panic("Failed to translate to bytes");

        const idx = std.mem.lastIndexOf(u8, file_path, "/");
        const name = if (idx) |i| file_path[i + 1 ..] else file_path;
        const buf = alloc.alloc(u8, name.len) catch @panic("Failed to alloc like 5 bytes come on man");
        defer alloc.free(buf);

        @memcpy(buf, name);

        buf[buf.len - 3] = 'n';
        buf[buf.len - 2] = 'b';
        buf[buf.len - 1] = 't';

        std.debug.print("Saving circuit entity to `{s}`\n", .{buf});

        nbt.zipNbt(buf, bytes.items) catch @panic("Failed to zip to NBT");
    } else {
        std.debug.print("Missing Input file!!!\nUsage: ./rhdl 'file.vhd' or whatever\n", .{});
    }
}

test {
    _ = @import("dl.zig");
    _ = @import("vhdl.zig");
    _ = @import("nbt.zig");
    _ = @import("nbt/node.zig");
    _ = @import("construction.zig");
}
