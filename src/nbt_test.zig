//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("nbt.zig");
const node = @import("nbt/node.zig");
const construction = @import("construction.zig");
const Block = construction.Block;
const BlockType = construction.BlockType;
const CircuitEntity = construction.CircuitEntity;
const Point = construction.Point;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var area = CircuitEntity{};
    defer area.deinit(alloc);

    try area.setBlock(alloc, Block{
        .ty = .redstone_dust,
        .loc = .{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .metadata = 0,
    });

    try area.setBlock(alloc, Block{
        .ty = .redstone_dust,
        .loc = .{
            .x = 1,
            .y = 0,
            .z = 0,
        },
        .metadata = 0,
    });

    try area.setBlock(alloc, Block{
        .ty = .redstone_dust,
        .loc = .{
            .x = 2,
            .y = 0,
            .z = 0,
        },
        .metadata = 0,
    });

    try area.setBlock(alloc, Block{
        .ty = .redstone_dust,
        .loc = .{
            .x = 2,
            .y = 0,
            .z = 1,
        },
        .metadata = 0,
    });

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("construction.nbt", al.items);
}
