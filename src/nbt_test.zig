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

    // var area = try CircuitEntity.constructOrN(alloc, 3, 4);
    // defer area.deinit(alloc);
    //
    // try area.shift(alloc, 0, 0, 5);
    //
    // var child1 = try CircuitEntity.constructAnd(alloc);
    // defer child1.deinit(alloc);
    //
    // var child2 = try CircuitEntity.constructAnd(alloc);
    // defer child2.deinit(alloc);
    //
    // var child3 = try CircuitEntity.constructAnd(alloc);
    // defer child3.deinit(alloc);
    //
    // try area.connect(alloc, &child1, 0, 0);
    // try area.connect(alloc, &child2, 0, 0);
    // try area.connect(alloc, &child3, 0, 0);

    // var sum_bit = try CircuitEntity.constructXor(alloc);
    // defer sum_bit.deinit(alloc);
    //
    // var sum_bit_child = try CircuitEntity.constructXor(alloc);
    // defer sum_bit_child.deinit(alloc);
    //
    // try sum_bit.connect(alloc, &sum_bit_child, 0, 0);
    //
    // try area.combine(alloc, &sum_bit);

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");
    const c = try circuit.input(alloc, "c");
    const d = try circuit.input(alloc, "d");

    const a_or_b = try circuit.orGate(alloc, a, b);
    const c_or_d = try circuit.orGate(alloc, c, d);

    _ = try circuit.output(alloc, try circuit.orGate(alloc, a_or_b, c_or_d));

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const area = try CircuitEntity.translateToEntity(a_alloc, circuit);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("orororor.nbt", al.items);
}
