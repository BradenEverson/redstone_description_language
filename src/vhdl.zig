//! Subset of the VHDL Spec that allows describing digial logic systems

const std = @import("std");

const dl = @import("dl.zig");
const Circuit = dl.Circuit;

pub fn parseToCircuit(alloc: std.mem.Allocator, data: []const u8) !Circuit {
    _ = alloc;
    _ = data;

    return error.UnexpectedEOF;
}

test {
    _ = @import("vhdl/tokenizer.zig");
    _ = @import("vhdl/parser.zig");
}
