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

    const a0 = try circuit.input(alloc, "a0");
    const b0 = try circuit.input(alloc, "b0");

    const cin = try circuit.input(alloc, "cin");

    const a0_and_b0 = try circuit.andGate(alloc, a0, b0);
    const a0_and_cin = try circuit.andGate(alloc, a0, cin);
    const b0_and_cin = try circuit.andGate(alloc, b0, cin);

    const as = try circuit.orGate(alloc, a0_and_b0, a0_and_cin);

    _ = try circuit.output(alloc, try circuit.orGate(alloc, as, b0_and_cin));

    const a_xor_b = try circuit.xorGate(alloc, a0, b0);
    _ = try circuit.output(alloc, try circuit.xorGate(alloc, a_xor_b, cin));

    const area = try CircuitEntity.translateToEntity(a_alloc, circuit);

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("rca.nbt", al.items);
}
