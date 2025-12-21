//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const Circuit = @import("dl.zig").Circuit;
const nbt = @import("nbt.zig");
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const BlockType = enum(u8) {
    air,
    redstone_dust,
    redstone_torch,
    comparator,
    repeater,

    pub fn toStr(self: BlockType) []const u8 {
        return switch (self) {
            .air => "minecraft:air",
            .redstone_dust => "minecraft:redstone_dust",
            .redstone_torch => "minecraft:redstone_torch",
            .comparator => "minecraft:comparator",
            .repeater => "minecraft:repeater",
        };
    }
};

const Point = struct { x: usize = 0, y: usize = 0, z: usize = 0 };

const Block = struct {
    ty: BlockType,
    loc: Point,
    metadata: u8,
};

pub const CircuitEntity = struct {
    width: usize,
    height: usize,
    length: usize,

    inputs: std.ArrayList(Point) = .{},
    outputs: std.ArrayList(Point) = .{},

    blocks: std.ArrayList(Block) = .{},

    inline fn adjustSize(self: *CircuitEntity, point: Point) void {
        if (point.x >= self.width) {
            self.width = point.x + 1;
        }

        if (point.y >= self.height) {
            self.height = point.y + 1;
        }

        if (point.z >= self.length) {
            self.length = point.z + 1;
        }
    }

    pub fn deinit(self: *CircuitEntity, alloc: std.mem.Allocator) void {
        alloc.free(self.blocks);
    }

    pub fn setInput(self: *CircuitEntity, alloc: std.mem.Allocator, input: Point) !void {
        try self.inputs.append(alloc, input);
        self.adjustSize(input);
    }

    pub fn setOutput(self: *CircuitEntity, alloc: std.mem.Allocator, output: Point) !void {
        try self.outputs.append(alloc, output);
        self.adjustSize(output);
    }

    fn setBlock(self: *CircuitEntity, alloc: std.mem.Allocator, block: Block) !void {
        try self.blocks.append(alloc, block);
        self.adjustSize(block.loc);
    }

    fn place(self: *CircuitEntity, alloc: std.mem.Allocator, block: BlockType, at: Point) !void {
        const to_place = Block{
            .loc = at,
            .ty = block,
            .metadata = 0,
        };

        try self.setBlock(alloc, to_place);
    }

    /// Connects an output of other to an input of self, modifying self. You can safely destroy other after
    /// this operation is complete
    pub fn combine(self: *CircuitEntity, other: *CircuitEntity, to_self_input: usize, from_other_output: usize) !void {
        // TODO: Shift the width and all points in self over by other's dimensions, place other's output at
        // the location of self's input
        _ = self;
        _ = other;
        _ = to_self_input;
        _ = from_other_output;
    }

    pub fn translateToEntity(self: *CircuitEntity, alloc: std.mem.Allocator, circuit: Circuit) !void {
        _ = self;
        _ = alloc;
        _ = circuit;
    }

    pub fn toNbt(self: *const CircuitEntity, alloc: std.mem.Allocator) !NbtNode {
        const root = try nbt.compound(alloc, "");
        errdefer {
            root.deinit(alloc);
            alloc.destroy(root);
        }

        const size_list = try alloc.alloc(*NbtNode, 3);

        size_list[0] = try nbt.int(alloc, null, self.width);
        size_list[1] = try nbt.int(alloc, null, self.height);
        size_list[2] = try nbt.int(alloc, null, self.length);

        const list = try nbt.list(alloc, "size", size_list);

        try nbt.add(alloc, root, list);

        // TODO: Create palette based only on blocks used
        const palette_list = try alloc.alloc(*NbtNode, 1);

        const air_tag = try nbt.compound(alloc, null);
        const tag_name = try nbt.string(alloc, "Name", BlockType.redstone_dust.toStr());
        try nbt.add(alloc, air_tag, tag_name);

        palette_list[0] = air_tag;
        const p_list = try nbt.list(alloc, "palette", palette_list);

        try nbt.add(alloc, root, try list(alloc, "palette", p_list));

        const total_blocks = self.blocks.items.len;
        const blocks_list = try alloc.alloc(*NbtNode, total_blocks);

        var idx: usize = 0;
        for (self.blocks.items) |block| {
            const b_entry = try nbt.compound(alloc, null);

            const pos_list = try alloc.alloc(*NbtNode, 3);
            pos_list[0] = try nbt.int(alloc, null, @intCast(block.loc.x));
            pos_list[1] = try nbt.int(alloc, null, @intCast(block.loc.y));
            pos_list[2] = try nbt.int(alloc, null, @intCast(block.loc.z));
            try nbt.add(alloc, b_entry, try list(alloc, "pos", pos_list));

            // TODO: Get the state value from the palette
            const state: u32 = 1;

            try nbt.add(alloc, b_entry, try nbt.int(alloc, "state", state));

            blocks_list[idx] = b_entry;
            idx += 1;
        }

        try nbt.add(alloc, root, try list(alloc, "blocks", blocks_list));
        return root;
    }
};

test "basic construction" {}
