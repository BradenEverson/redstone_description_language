//! Subset of the VHDL Spec that allows describing digial logic systems

const std = @import("std");

const dl = @import("dl.zig");
const Circuit = dl.Circuit;

const tokenizer = @import("vhdl/tokenizer.zig");
const Token = tokenizer.Token;

const parse = @import("vhdl/parser.zig");
const Parser = parse.Parser;
const TopLevel = parse.TopLevel;

pub const VhdlError = error{
    ArchitectureDefBeforeEntity,
    DuplicateEntityDefinitions,
    IncompleteEntityArchDuo,
    NoEntity,
};

const CompletedEntity = struct {
    entity: ?parse.EntityDef,
    arch: ?parse.Architecture,
};

pub fn parseToCircuit(alloc: std.mem.Allocator, data: []const u8) !Circuit {
    var circuit = Circuit{};
    errdefer circuit.deinit(alloc);

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

    var full_entities = std.StringHashMapUnmanaged(CompletedEntity){};
    defer full_entities.deinit(alloc);

    for (al.items) |tl| {
        switch (tl.*) {
            .arch => |arch| {
                if (full_entities.get(arch.of)) |entity| {
                    var en = entity;
                    en.arch = arch;

                    try full_entities.put(alloc, arch.of, en);
                } else {
                    return error.ArchitectureDefBeforeEntity;
                }
            },

            .entity => |entity| {
                if (full_entities.contains(entity.name)) {
                    return error.DuplicateEntityDefinitions;
                }

                const en = CompletedEntity{
                    .entity = entity,
                    .arch = null,
                };

                try full_entities.put(alloc, entity.name, en);
            },
        }
    }

    // TODO: Go through each completed entity and generate a circuit for it
    var entities = full_entities.valueIterator();
    if (entities.next()) |entity| {
        const en = entity.entity orelse return error.IncompleteEntityArchDuo;
        const arch = entity.arch orelse return error.IncompleteEntityArchDuo;

        for (en.inputs.items) |in| {
            if (in.ty == .single) {
                _ = try circuit.input(alloc, in.name);
            } else {
                @panic("TODO: create a vector of inputs");
            }
        }

        for (arch.mappings.items) |mapping| {
            mapping.assignment.print(0);

            const out = try mapping.assignment.toCircuit(alloc, &circuit);
            _ = try circuit.output(alloc, out);
        }
    } else {
        return error.NoEntity;
    }

    return circuit;
}

test {
    _ = @import("vhdl/tokenizer.zig");
    _ = @import("vhdl/parser.zig");
}
