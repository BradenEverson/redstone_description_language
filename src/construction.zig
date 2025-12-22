//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const Circuit = @import("dl.zig").Circuit;
const nbt = @import("nbt.zig");
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const BlockType = enum(u32) {
    redstone_wire = 0,
    redstone_torch = 1,
    comparator = 2,
    repeater = 3,
};

pub const Point = struct { x: u32 = 0, y: u32 = 0, z: u32 = 0 };

pub const BlockMetadata = union(BlockType) {
    redstone_wire,
    redstone_torch,
    comparator: ComparatorMetadata,
    repeater: RepeaterMetadata,

    pub fn toStr(self: BlockMetadata) []const u8 {
        return switch (self) {
            .redstone_wire => "minecraft:redstone_wire",
            .redstone_torch => "minecraft:redstone_torch",
            .comparator => "minecraft:comparator",
            .repeater => "minecraft:repeater",
        };
    }

    pub fn toNbt(self: BlockMetadata, alloc: std.mem.Allocator) !*NbtNode {
        const tag = try nbt.compound(alloc, null);
        errdefer tag.deinit(alloc);

        const tag_name = try nbt.string(alloc, "Name", self.toStr());
        try nbt.add(alloc, tag, tag_name);

        switch (self) {
            .comparator => |cm| {
                const properties = try nbt.compound(alloc, "Properties");

                const facing = try nbt.string(alloc, "facing", cm.facing.toStr());
                try nbt.add(alloc, properties, facing);

                const mode = try nbt.string(alloc, "mode", cm.mode.toStr());
                try nbt.add(alloc, properties, mode);

                try nbt.add(alloc, tag, properties);
            },

            .repeater => |rm| {
                const properties = try nbt.compound(alloc, "Properties");

                const facing = try nbt.string(alloc, "facing", rm.facing.toStr());
                try nbt.add(alloc, properties, facing);

                const delayStr = try std.fmt.allocPrint(alloc, "{}", .{rm.delay});
                const mode = try nbt.string(alloc, "delay", delayStr);
                try nbt.add(alloc, properties, mode);

                try nbt.add(alloc, tag, properties);
            },
            else => {},
        }

        return tag;
    }
};

pub const ComparatorMetadata = struct {
    facing: Direction,
    mode: ComparatorMode,
};

pub const RepeaterMetadata = struct {
    facing: Direction,
    delay: u8,
};

pub const Direction = enum {
    north,
    south,
    east,
    west,

    pub fn toStr(self: Direction) []const u8 {
        return switch (self) {
            .north => "north",
            .south => "south",
            .east => "east",
            .west => "west",
        };
    }
};

pub const ComparatorMode = enum {
    subtract,
    add,

    pub fn toStr(self: ComparatorMode) []const u8 {
        return switch (self) {
            .subtract => "subtract",
            .add => "add",
        };
    }
};

pub const Block = struct {
    ty: BlockMetadata,
    loc: Point,
};

pub const CircuitEntity = struct {
    width: u32 = 0,
    height: u32 = 0,
    length: u32 = 0,

    inputs: std.ArrayList(Point) = .{},
    outputs: std.ArrayList(Point) = .{},

    blocks: std.ArrayList(Block) = .{},

    palette: std.AutoHashMapUnmanaged(BlockMetadata, u32) = .{},

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
        self.blocks.deinit(alloc);
        self.palette.deinit(alloc);
        self.inputs.deinit(alloc);
        self.outputs.deinit(alloc);
    }

    pub fn setInput(self: *CircuitEntity, alloc: std.mem.Allocator, input: Point) !void {
        try self.inputs.append(alloc, input);
        self.adjustSize(input);
    }

    pub fn setOutput(self: *CircuitEntity, alloc: std.mem.Allocator, output: Point) !void {
        try self.outputs.append(alloc, output);
        self.adjustSize(output);
    }

    pub fn setBlock(self: *CircuitEntity, alloc: std.mem.Allocator, block: Block) !void {
        if (!self.palette.contains(block.ty)) {
            try self.palette.put(alloc, block.ty, self.palette.size);
        }

        try self.blocks.append(alloc, block);
        self.adjustSize(block.loc);
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

    pub fn toNbt(self: *const CircuitEntity, alloc: std.mem.Allocator) !*NbtNode {
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

        var palette = self.palette.keyIterator();
        const palette_list = try alloc.alloc(*NbtNode, self.palette.size);

        while (palette.next()) |variant| {
            const tag = try variant.toNbt(alloc);
            palette_list[@as(usize, self.palette.get(variant.*).?)] = tag;
        }

        const p_list = try nbt.list(alloc, "palette", palette_list);

        try nbt.add(alloc, root, p_list);

        const total_blocks = self.blocks.items.len;
        const blocks_list = try alloc.alloc(*NbtNode, total_blocks);

        var idx: usize = 0;
        for (self.blocks.items) |block| {
            const b_entry = try nbt.compound(alloc, null);

            const pos_list = try alloc.alloc(*NbtNode, 3);
            pos_list[0] = try nbt.int(alloc, null, @intCast(block.loc.x));
            pos_list[1] = try nbt.int(alloc, null, @intCast(block.loc.y));
            pos_list[2] = try nbt.int(alloc, null, @intCast(block.loc.z));
            try nbt.add(alloc, b_entry, try nbt.list(alloc, "pos", pos_list));

            const state: u32 = self.palette.get(block.ty).?;

            try nbt.add(alloc, b_entry, try nbt.int(alloc, "state", state));

            blocks_list[idx] = b_entry;
            idx += 1;
        }

        try nbt.add(alloc, root, try nbt.list(alloc, "blocks", blocks_list));
        return root;
    }
};
