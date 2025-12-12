//! Subset of the VHDL Spec that allows describing digial logic systems

const std = @import("std");

const dl = @import("dl.zig");
const Circuit = dl.Circuit;

pub fn parseToCircuit(alloc: std.mem.Allocator, path: []const u8) !Circuit {
    _ = alloc;
    _ = path;

    return error.UnexpectedEOF;
}

test {
    _ = @import("vhdl/tokenizer.zig");
    _ = @import("vhdl/parser.zig");
}
