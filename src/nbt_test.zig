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

    var area = try CircuitEntity.construct_xor(alloc);
    defer area.deinit(alloc);

    var child = try CircuitEntity.construct_or(alloc);
    defer child.deinit(alloc);

    var not = try CircuitEntity.construct_not(alloc);
    defer not.deinit(alloc);

    try area.combine(alloc, child, 0, 0);

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("xor_combined_or.nbt", al.items);
}
