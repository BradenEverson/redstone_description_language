//! Digital Logic Gates and Convenience Structs for Generating a Circuit IR

const std = @import("std");

pub const GateId = packed struct { id: usize };

pub const Circuit = struct {
    gates: std.ArrayList(Gate) = .{},
    inputs: std.ArrayList(usize) = .{},
    outputs: std.ArrayList(usize) = .{},

    pub fn deinit(self: *Circuit, alloc: std.mem.Allocator) void {
        self.inputs.deinit(alloc);
        self.outputs.deinit(alloc);
        self.gates.deinit(alloc);
    }

    pub fn input(self: *Circuit, alloc: std.mem.Allocator) !GateId {
        const gate = Gate{ .input = false };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);
        try self.inputs.append(alloc, idx);

        return .{ .id = idx };
    }

    pub fn output(self: *Circuit, alloc: std.mem.Allocator, gate: GateId) !GateId {
        try self.outputs.append(alloc, gate.id);

        return .{ .id = gate.id };
    }

    pub fn set_input(self: *Circuit, gate: GateId, val: bool) void {
        self.gates.items[gate.id] = .{ .input = val };
    }

    pub fn eval(self: *Circuit, target: GateId) bool {
        return switch (self.gates.items[target.id]) {
            .input => |b| return b,
            .and_gate => |a| return self.eval(a.left) and self.eval(a.right),
            .or_gate => |o| return self.eval(o.left) or self.eval(o.right),
            .not_gate => |n| !self.eval(n.val),
        };
    }
};

pub const Gate = union(enum) {
    input: bool,
    and_gate: Binary,
    or_gate: Binary,
    not_gate: Unary,
};

pub const Binary = struct {
    left: GateId,
    right: GateId,
};

pub const Unary = struct {
    val: GateId,
};

test "init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    try std.testing.expectEqual(0, circuit.inputs.items.len);
    try std.testing.expectEqual(0, circuit.outputs.items.len);
    try std.testing.expectEqual(0, circuit.gates.items.len);
}

test "inputs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.output(alloc, try circuit.input(alloc));

    circuit.set_input(a, true);
    var eval = circuit.eval(a);

    try std.testing.expectEqual(true, eval);

    circuit.set_input(a, false);
    eval = circuit.eval(a);

    try std.testing.expectEqual(false, eval);
}
