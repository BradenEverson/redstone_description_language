//! NBT Parser and Generator Testing
const std = @import("std");

const nbt = @import("nbt.zig");
const node = @import("nbt/node.zig");
const construction = @import("construction.zig");
const Block = construction.Block;
const BlockType = construction.BlockType;
const CircuitEntity = construction.CircuitEntity;
const Point = construction.Point;
const Circuit = @import("dl.zig").Circuit;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");
    const c = try circuit.input(alloc, "c");
    const not_c = try circuit.notGate(alloc, c);
    const d = try circuit.input(alloc, "d");

    const a_and_b = try circuit.andGate(alloc, a, b);
    const c_or_d = try circuit.orGate(alloc, not_c, d);

    _ = try circuit.output(alloc, try circuit.xorGate(alloc, a_and_b, c_or_d));

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const area = try CircuitEntity.translateToEntity(a_alloc, circuit);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("andornotxor.nbt", al.items);
}
