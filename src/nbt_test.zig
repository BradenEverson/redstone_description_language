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

    var area = try CircuitEntity.constructOrN(alloc, 3, 4);
    defer area.deinit(alloc);

    try area.shift(alloc, 0, 0, 5);

    var child1 = try CircuitEntity.constructAnd(alloc);
    defer child1.deinit(alloc);

    var child2 = try CircuitEntity.constructAnd(alloc);
    defer child2.deinit(alloc);

    var child3 = try CircuitEntity.constructAnd(alloc);
    defer child3.deinit(alloc);

    try area.combine(alloc, &child1, 0, 0);
    try area.combine(alloc, &child2, 0, 0);
    try area.combine(alloc, &child3, 0, 0);

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("cout.nbt", al.items);
}
