//! Digital Logic Gates and Convenience Structs for Generating a Circuit IR

const std = @import("std");

pub const Circuit = struct {
    gates: std.ArrayList(Gate),
    inputs: std.ArrayList(usize),
    outputs: std.ArrayList(usize),

    pub fn deinit(self: *Circuit, alloc: std.mem.Allocator) void {
        self.inputs.deinit(alloc);
        self.outputs.deinit(alloc);
        self.gates.deinit(alloc);
    }
};

pub const Gate = union(enum) {
    and_gate: Binary,
    or_gate: Binary,
    not_gate: Unary,
};

pub const Binary = struct {
    left: usize,
    right: usize,
};

pub const Unary = struct {
    val: usize,
};
