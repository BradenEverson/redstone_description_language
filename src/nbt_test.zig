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

    // Carry Lookahead Circuit
    //
    // const a0 = try circuit.input(alloc, "a0");
    // const a1 = try circuit.input(alloc, "a1");
    // const b0 = try circuit.input(alloc, "b0");
    // const b1 = try circuit.input(alloc, "b1");
    // const cin = try circuit.input(alloc, "cin");
    //
    // const g0 = try circuit.andGate(alloc, a0, b0);
    // const p0 = try circuit.orGate(alloc, a0, b0);
    //
    // const g1 = try circuit.andGate(alloc, a1, b1);
    // const p1 = try circuit.orGate(alloc, a1, b1);
    //
    // const c1 = try circuit.orGate(alloc, g0, try circuit.andGate(alloc, p0, cin));
    //
    // const p1_and_g0 = try circuit.andGate(alloc, p1, g0);
    // const p1_and_p0 = try circuit.andGate(alloc, p1, p0);
    // const p1_and_p0_and_c1 = try circuit.andGate(alloc, p1_and_p0, c1);
    //
    // const g1_or_p1_and_g0 = try circuit.orGate(alloc, g1, p1_and_g0);
    //
    // _ = try circuit.output(alloc, try circuit.orGate(alloc, g1_or_p1_and_g0, p1_and_p0_and_c1));

    // 2-bit rca
    const a0 = try circuit.input(alloc, "a0");
    const a1 = try circuit.input(alloc, "a1");
    const b0 = try circuit.input(alloc, "b0");
    const b1 = try circuit.input(alloc, "b1");

    const cin = try circuit.input(alloc, "cin");

    const a0_and_b0 = try circuit.andGate(alloc, a0, b0);
    const a0_and_cin = try circuit.andGate(alloc, a0, cin);
    const b0_and_cin = try circuit.andGate(alloc, b0, cin);

    const a0_xor_b0 = try circuit.xorGate(alloc, a0, b0);
    const s0 = try circuit.xorGate(alloc, a0_xor_b0, cin);

    const c1 = try circuit.or3Gate(alloc, a0_and_b0, a0_and_cin, b0_and_cin);

    const a1_and_b1 = try circuit.andGate(alloc, a1, b1);
    const a1_and_c1 = try circuit.andGate(alloc, a1, c1);
    const b1_and_c1 = try circuit.andGate(alloc, b1, c1);

    const a1_xor_b1 = try circuit.xorGate(alloc, a1, b1);
    const s1 = try circuit.xorGate(alloc, a1_xor_b1, c1);

    const cout = try circuit.or3Gate(alloc, a1_and_b1, a1_and_c1, b1_and_c1);

    _ = try circuit.output(alloc, cout);
    _ = try circuit.output(alloc, s1);
    _ = try circuit.output(alloc, s0);

    // 1-bit fa
    // const a = try circuit.input(alloc, "a");
    // const b = try circuit.input(alloc, "b");
    //
    // const cin = try circuit.input(alloc, "cin");
    //
    // const a_and_b = try circuit.andGate(alloc, a, b);
    // const a_and_cin = try circuit.andGate(alloc, a, cin);
    // const b_and_cin = try circuit.andGate(alloc, b, cin);
    //
    // const a_xor_b = try circuit.xorGate(alloc, a, b);
    // const s = try circuit.xorGate(alloc, a_xor_b, cin);
    //
    // const cout = try circuit.or3Gate(alloc, a_and_b, a_and_cin, b_and_cin);
    //
    // _ = try circuit.output(alloc, cout);
    // _ = try circuit.output(alloc, s);
    const area = try CircuitEntity.translateToEntity(a_alloc, circuit);

    var al = std.ArrayList(u8){};
    defer al.deinit(alloc);

    const serialized = try area.toNbt(a_alloc);

    try serialized.toBytes(alloc, &al, true, true);

    try nbt.zipNbt("rca.nbt", al.items);
}
