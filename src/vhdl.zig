//! Subset of the VHDL Spec that allows describing digial logic systems

const std = @import("std");

const dl = @import("dl.zig");
const Circuit = dl.Circuit;

const tokenizer = @import("vhdl/tokenizer.zig");
const Token = tokenizer.Token;

const parse = @import("vhdl/parser.zig");
const Parser = parse.Parser;
const TopLevel = parse.TopLevel;

pub fn parseToCircuit(alloc: std.mem.Allocator, data: []const u8) !Circuit {
    const circuit = Circuit{};

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(a_alloc);

    try tokenizer.tokenize(data, &tokens, a_alloc);

    var parser = Parser.init(tokens.items);

    var al = std.ArrayList(*const TopLevel){};
    defer al.deinit(a_alloc);

    try parser.parse(a_alloc, &al);

    return circuit;
}

test {
    _ = @import("vhdl/tokenizer.zig");
    _ = @import("vhdl/parser.zig");
}
