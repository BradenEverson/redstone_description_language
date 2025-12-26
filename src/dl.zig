//! Digital Logic Gates and Convenience Structs for Generating a Circuit IR

const std = @import("std");

pub const GateId = packed struct { id: usize };

pub const Circuit = struct {
    gates: std.ArrayList(Gate) = .{},
    inputs: std.StringHashMapUnmanaged(*Input) = .{},
    outputs: std.ArrayList(usize) = .{},
    pub fn deinit(self: *Circuit, alloc: std.mem.Allocator) void {
        var vals = self.inputs.keyIterator();
        while (vals.next()) |k| {
            const ptr = self.inputs.get(k.*).?;
            _ = self.inputs.remove(k.*);
            alloc.destroy(ptr);
        }

        self.inputs.deinit(alloc);
        self.outputs.deinit(alloc);
        self.gates.deinit(alloc);
    }

    pub fn depOn(self: *const Circuit, dep_on: GateId) u32 {
        var result: u32 = 0;
        for (self.outputs.items) |o| {
            const out = self.gates.items[o];
            result += self.depOnRec(dep_on, out);
        }
        return result;
    }

    fn depOnRec(self: *const Circuit, dep_on: GateId, curr: Gate) u32 {
        var result: u32 = 0;
        switch (curr) {
            .input => |_| return 0,
            .and_gate => |binary| {
                if (binary.left == dep_on or binary.right == dep_on) {
                    result += 1;
                }
                const left = self.gates.items[binary.left.id];
                const right = self.gates.items[binary.right.id];

                result += self.depOnRec(dep_on, left) + self.depOnRec(dep_on, right);
            },
            .or_gate => |binary| {
                if (binary.left == dep_on or binary.right == dep_on) {
                    result += 1;
                }
                const left = self.gates.items[binary.left.id];
                const right = self.gates.items[binary.right.id];

                result += self.depOnRec(dep_on, left) + self.depOnRec(dep_on, right);
            },
            .xor_gate => |binary| {
                if (binary.left == dep_on or binary.right == dep_on) {
                    result += 1;
                }
                const left = self.gates.items[binary.left.id];
                const right = self.gates.items[binary.right.id];

                result += self.depOnRec(dep_on, left) + self.depOnRec(dep_on, right);
            },
            .nor_gate => |binary| {
                if (binary.left == dep_on or binary.right == dep_on) {
                    result += 1;
                }
                const left = self.gates.items[binary.left.id];
                const right = self.gates.items[binary.right.id];

                result += self.depOnRec(dep_on, left) + self.depOnRec(dep_on, right);
            },
            .nand_gate => |binary| {
                if (binary.left == dep_on or binary.right == dep_on) {
                    result += 1;
                }

                const left = self.gates.items[binary.left.id];
                const right = self.gates.items[binary.right.id];

                result += self.depOnRec(dep_on, left) + self.depOnRec(dep_on, right);
            },
            .not_gate => |unary| {
                if (unary.val == dep_on) {
                    result += 1;
                } else {
                    const val = self.gates.items[unary.val.id];

                    result += self.depOnRec(dep_on, val);
                }
            },
        }

        return result;
    }

    pub fn paddingNecessary(self: *const Circuit, at: GateId) u32 {
        const gate_at = self.gates.items[at.id];
        return switch (gate_at) {
            .input => |_| 2,
            .and_gate => |binary| {
                const left = self.paddingNecessary(binary.left);
                const right = self.paddingNecessary(binary.right);

                return 5 + left + right;
            },
            .or_gate => |binary| {
                const left = self.paddingNecessary(binary.left);
                const right = self.paddingNecessary(binary.right);

                return 4 + left + right;
            },
            .or_gate_3 => |o3| {
                const a = self.paddingNecessary(o3.a);
                const b = self.paddingNecessary(o3.b);
                const c = self.paddingNecessary(o3.c);

                return 4 + a + b + c;
            },
            .xor_gate => |binary| {
                const left = self.paddingNecessary(binary.left);
                const right = self.paddingNecessary(binary.right);

                return 4 + left + right;
            },
            .not_gate => |unary| {
                const val = self.paddingNecessary(unary.val);

                return @max(2, val);
            },
            else => @panic("Unimplemented"),
        };
    }

    pub fn set(self: *Circuit, name: []const u8, val: bool) void {
        if (self.inputs.get(name)) |in| {
            in.val = val;
        }
    }

    pub fn input(self: *Circuit, alloc: std.mem.Allocator, name: []const u8) !GateId {
        const in = try alloc.create(Input);
        in.* = Input{
            .name = name,
            .val = false,
        };

        try self.inputs.put(alloc, name, in);

        const gate = Gate{ .input = in };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn output(self: *Circuit, alloc: std.mem.Allocator, gate: GateId) !GateId {
        try self.outputs.append(alloc, gate.id);

        return .{ .id = gate.id };
    }

    pub fn andGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId) !GateId {
        const gate = Gate{ .and_gate = .{ .left = a, .right = b } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn or3Gate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId, c: GateId) !GateId {
        const gate = Gate{ .or_gate_3 = .{ .a = a, .b = b, .c = c } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn orGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId) !GateId {
        const gate = Gate{ .or_gate = .{ .left = a, .right = b } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn xorGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId) !GateId {
        const gate = Gate{ .xor_gate = .{ .left = a, .right = b } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn norGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId) !GateId {
        const gate = Gate{ .nor_gate = .{ .left = a, .right = b } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn nandGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId, b: GateId) !GateId {
        const gate = Gate{ .nand_gate = .{ .left = a, .right = b } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn notGate(self: *Circuit, alloc: std.mem.Allocator, a: GateId) !GateId {
        const gate = Gate{ .not_gate = .{ .val = a } };
        const idx = self.gates.items.len;

        try self.gates.append(alloc, gate);

        return .{ .id = idx };
    }

    pub fn eval(self: *Circuit, target: GateId) bool {
        return switch (self.gates.items[target.id]) {
            .input => |b| return b.val,

            .and_gate => |a| return self.eval(a.left) and self.eval(a.right),
            .or_gate => |o| return self.eval(o.left) or self.eval(o.right),
            .or_gate_3 => |o3| return self.eval(o3.a) or self.eval(o3.b) or self.eval(o3.c),
            .xor_gate => |x| return self.eval(x.left) ^ self.eval(x.right),

            .nor_gate => |no| return !(self.eval(no.left) or self.eval(no.right)),
            .nand_gate => |na| return !(self.eval(na.left) and self.eval(na.right)),

            .not_gate => |n| !self.eval(n.val),
        };
    }
};

pub const Input = struct {
    name: []const u8,
    val: bool,
};

pub const Gate = union(enum) {
    input: *const Input,

    and_gate: Binary,
    or_gate: Binary,
    or_gate_3: struct { a: GateId, b: GateId, c: GateId },
    xor_gate: Binary,

    nor_gate: Binary,
    nand_gate: Binary,

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

    try std.testing.expectEqual(0, circuit.inputs.size);
    try std.testing.expectEqual(0, circuit.outputs.items.len);
    try std.testing.expectEqual(0, circuit.gates.items.len);
}

test "inputs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.output(alloc, try circuit.input(alloc, "a"));

    circuit.set("a", true);
    var eval = circuit.eval(a);

    try std.testing.expectEqual(true, eval);

    circuit.set("a", false);
    eval = circuit.eval(a);

    try std.testing.expectEqual(false, eval);
}

test "and" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");

    const a_and_b = try circuit.output(alloc, try circuit.andGate(alloc, a, b));

    // 00
    circuit.set("a", false);
    circuit.set("b", false);
    try std.testing.expectEqual(false, circuit.eval(a_and_b));

    // 01
    circuit.set("a", false);
    circuit.set("b", true);
    try std.testing.expectEqual(false, circuit.eval(a_and_b));

    // 10
    circuit.set("a", true);
    circuit.set("b", false);
    try std.testing.expectEqual(false, circuit.eval(a_and_b));

    // 11
    circuit.set("a", true);
    circuit.set("b", true);
    try std.testing.expectEqual(true, circuit.eval(a_and_b));
}

test "or" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");

    const a_or_b = try circuit.output(alloc, try circuit.orGate(alloc, a, b));

    // 00
    circuit.set("a", false);
    circuit.set("b", false);
    try std.testing.expectEqual(false, circuit.eval(a_or_b));

    // 01
    circuit.set("a", false);
    circuit.set("b", true);
    try std.testing.expectEqual(true, circuit.eval(a_or_b));

    // 10
    circuit.set("a", true);
    circuit.set("b", false);
    try std.testing.expectEqual(true, circuit.eval(a_or_b));

    // 11
    circuit.set("a", true);
    circuit.set("b", true);
    try std.testing.expectEqual(true, circuit.eval(a_or_b));
}

test "not" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");

    const not_a = try circuit.output(alloc, try circuit.notGate(alloc, a));

    // 0
    circuit.set("a", false);
    try std.testing.expectEqual(true, circuit.eval(not_a));

    // 1
    circuit.set("a", true);
    try std.testing.expectEqual(false, circuit.eval(not_a));
}

test "xor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");

    const a_xor_b = try circuit.output(alloc, try circuit.xorGate(alloc, a, b));

    // 00
    circuit.set("a", false);
    circuit.set("b", false);
    try std.testing.expectEqual(false, circuit.eval(a_xor_b));

    // 01
    circuit.set("a", false);
    circuit.set("b", true);
    try std.testing.expectEqual(true, circuit.eval(a_xor_b));

    // 10
    circuit.set("a", true);
    circuit.set("b", false);
    try std.testing.expectEqual(true, circuit.eval(a_xor_b));

    // 11
    circuit.set("a", true);
    circuit.set("b", true);
    try std.testing.expectEqual(false, circuit.eval(a_xor_b));
}

test "nor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");

    const a_nor_b = try circuit.output(alloc, try circuit.norGate(alloc, a, b));

    // 00
    circuit.set("a", false);
    circuit.set("b", false);
    try std.testing.expectEqual(true, circuit.eval(a_nor_b));

    // 01
    circuit.set("a", false);
    circuit.set("b", true);
    try std.testing.expectEqual(false, circuit.eval(a_nor_b));

    // 10
    circuit.set("a", true);
    circuit.set("b", false);
    try std.testing.expectEqual(false, circuit.eval(a_nor_b));

    // 11
    circuit.set("a", true);
    circuit.set("b", true);
    try std.testing.expectEqual(false, circuit.eval(a_nor_b));
}

test "nand" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var circuit = Circuit{};
    defer circuit.deinit(alloc);

    const a = try circuit.input(alloc, "a");
    const b = try circuit.input(alloc, "b");

    const a_nand_b = try circuit.output(alloc, try circuit.nandGate(alloc, a, b));

    // 00
    circuit.set("a", false);
    circuit.set("b", false);
    try std.testing.expectEqual(true, circuit.eval(a_nand_b));

    // 01
    circuit.set("a", false);
    circuit.set("b", true);
    try std.testing.expectEqual(true, circuit.eval(a_nand_b));

    // 10
    circuit.set("a", true);
    circuit.set("b", false);
    try std.testing.expectEqual(true, circuit.eval(a_nand_b));

    // 11
    circuit.set("a", true);
    circuit.set("b", true);
    try std.testing.expectEqual(false, circuit.eval(a_nand_b));
}
