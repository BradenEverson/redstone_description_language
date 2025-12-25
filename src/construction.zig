//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const dl = @import("dl.zig");
const Circuit = dl.Circuit;
const Gate = dl.Gate;
const GateId = dl.GateId;

const nbt = @import("nbt.zig");
const NbtNode = @import("nbt/node.zig").NbtNode;

const STEPS_BEFORE_REPEATER: u32 = 5;

pub const BlockType = enum(u32) {
    redstone_wire = 0,
    redstone_torch = 1,
    comparator = 2,
    repeater = 3,
    white_wool = 4,
    lever = 5,
    redstone_lamp = 6,
};

pub const Point = struct { x: u32 = 0, y: u32 = 0, z: u32 = 0 };

pub const BlockMetadata = union(BlockType) {
    redstone_wire,
    redstone_torch,
    comparator: ComparatorMetadata,
    repeater: RepeaterMetadata,
    white_wool,
    lever: LeverMetadata,
    redstone_lamp,

    pub fn toStr(self: BlockMetadata) []const u8 {
        return switch (self) {
            .redstone_wire => "minecraft:redstone_wire",
            .redstone_torch => "minecraft:redstone_torch",
            .comparator => "minecraft:comparator",
            .repeater => "minecraft:repeater",
            .white_wool => "minecraft:white_wool",

            .lever => "minecraft:lever",
            .redstone_lamp => "minecraft:redstone_lamp",
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

            .lever => |l| {
                const properties = try nbt.compound(alloc, "Properties");

                const face = try nbt.string(alloc, "face", l.face.toStr());
                try nbt.add(alloc, properties, face);

                const facing = try nbt.string(alloc, "facing", l.facing.toStr());
                try nbt.add(alloc, properties, facing);

                const poweredStr = if (l.powered) "true" else "false";
                const mode = try nbt.string(alloc, "powered", poweredStr);
                try nbt.add(alloc, properties, mode);

                try nbt.add(alloc, tag, properties);
            },
            else => {},
        }

        return tag;
    }
};

pub const Placement = enum {
    floor,

    pub fn toStr(self: Placement) []const u8 {
        return switch (self) {
            .floor => "floor",
        };
    }
};

pub const LeverMetadata = struct {
    facing: Direction,
    face: Placement,
    powered: bool,
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

    internal_inputs: std.ArrayList(Point) = .{},
    inputs: std.ArrayList(struct { Point, []const u8 }) = .{},

    outputs: std.ArrayList(Point) = .{},

    blocks: std.AutoHashMapUnmanaged(Point, Block) = .{},

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
        self.internal_inputs.deinit(alloc);
        self.outputs.deinit(alloc);
        self.inputs.deinit(alloc);
    }

    pub fn setExternalInput(self: *CircuitEntity, alloc: std.mem.Allocator, p: Point, name: []const u8) !void {
        try self.inputs.append(alloc, .{ p, name });
        self.adjustSize(p);
    }

    pub fn setInput(self: *CircuitEntity, alloc: std.mem.Allocator, input: Point) !void {
        try self.internal_inputs.append(alloc, input);
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

        try self.blocks.put(alloc, block.loc, block);
        self.adjustSize(block.loc);
    }

    pub fn constructXorPadding(alloc: std.mem.Allocator, p: u32) !CircuitEntity {
        var padding = p;
        if (padding % 2 != 0) padding += 1;

        var area = CircuitEntity{};
        var curr_x: u32 = 0;

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 2,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        curr_x += 1;

        try area.connectPoints(alloc, .{ .x = curr_x - 1, .y = 0, .z = 2 }, .{ .x = curr_x + padding / 2, .y = 0, .z = 2 });
        try area.connectPoints(alloc, .{ .x = curr_x - 1, .y = 0, .z = 1 }, .{ .x = curr_x + padding / 2, .y = 0, .z = 1 });

        curr_x += padding / 2;

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .facing = .north, .mode = .subtract } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 2,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 3,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .facing = .north, .mode = .subtract } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 2,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 3,
            },
        });

        curr_x += 1;

        try area.connectPoints(alloc, .{ .x = curr_x + padding / 2, .y = 0, .z = 2 }, .{ .x = curr_x, .y = 0, .z = 2 });
        try area.connectPoints(alloc, .{ .x = curr_x + padding / 2, .y = 0, .z = 1 }, .{ .x = curr_x, .y = 0, .z = 1 });

        curr_x += padding / 2;

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 2,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .facing = .north, .delay = 1 } },
            .loc = .{
                .x = 1 + padding / 2,
                .y = 0,
                .z = 4,
            },
        });

        try area.setInput(alloc, .{ .x = 0, .y = 0, .z = 0 });
        try area.setInput(alloc, .{ .x = curr_x, .y = 0, .z = 0 });

        try area.setOutput(alloc, .{ .x = 1 + padding / 2, .y = 0, .z = 5 });

        return area;
    }

    pub fn constructOrN(alloc: std.mem.Allocator, n: u32, gap: u32) !CircuitEntity {
        var area = CircuitEntity{};

        for (0..n - 1) |i| {
            const x: u32 = @truncate(i);
            try area.setBlock(alloc, Block{
                .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
                .loc = .{
                    .x = x * (gap + 1),
                    .y = 0,
                    .z = 0,
                },
            });

            try area.setBlock(alloc, Block{
                .ty = .redstone_wire,
                .loc = .{
                    .x = x * (gap + 1),
                    .y = 0,
                    .z = 1,
                },
            });

            try area.connectPoints(alloc, .{ .x = x + gap + 1, .y = 0, .z = 1 }, .{ .x = x, .y = 0, .z = 1 });
            try area.setInput(alloc, .{ .x = x * (gap + 1), .y = 0, .z = 0 });
        }

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = (n - 1) * (gap + 1),
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = (n - 1) * (gap + 1),
                .y = 0,
                .z = 1,
            },
        });

        try area.setInput(alloc, .{ .x = (n - 1) * (gap + 1), .y = 0, .z = 0 });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = 0,
                .y = 0,
                .z = 2,
            },
        });

        try area.setOutput(alloc, .{ .x = 0, .y = 0, .z = 3 });

        return area;
    }

    pub fn constructInput(alloc: std.mem.Allocator, name: []const u8) !CircuitEntity {
        var area = CircuitEntity{};

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        });

        try area.setExternalInput(alloc, .{ .x = 0, .y = 0, .z = 0 }, name);

        try area.setOutput(alloc, .{ .x = 0, .y = 0, .z = 1 });

        return area;
    }

    pub fn constructOr(alloc: std.mem.Allocator) !CircuitEntity {
        return constructOrN(alloc, 2, 1);
    }

    pub fn constructAndPadding(alloc: std.mem.Allocator, p: u32) !CircuitEntity {
        var padding = p;
        if (padding % 2 == 0) padding += 1;

        var area = CircuitEntity{};

        var curr_x: u32 = 0;

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .mode = .subtract, .facing = .west } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .west } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        curr_x += 1;

        try area.connectPoints(alloc, .{ .x = curr_x - 1, .y = 0, .z = 1 }, .{ .x = curr_x + padding / 2, .y = 0, .z = 1 });
        curr_x += padding / 2;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .west } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .mode = .subtract, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 2,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .east } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        curr_x += 1;

        try area.connectPoints(alloc, .{ .x = curr_x + padding / 2, .y = 0, .z = 1 }, .{ .x = curr_x, .y = 0, .z = 1 });
        curr_x += padding / 2;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .east } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .mode = .subtract, .facing = .east } },
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        curr_x += 1;

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = curr_x,
                .y = 0,
                .z = 1,
            },
        });

        try area.setInput(alloc, .{ .x = 1, .y = 0, .z = 0 });
        try area.setInput(alloc, .{ .x = curr_x - 1, .y = 0, .z = 0 });

        try area.setOutput(alloc, .{ .x = 4 + padding / 2, .y = 0, .z = 3 });

        return area;
    }

    pub fn constructNot(alloc: std.mem.Allocator) !CircuitEntity {
        var area = CircuitEntity{};

        try area.setBlock(alloc, Block{
            .ty = .redstone_torch,
            .loc = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .comparator = .{ .facing = .north, .mode = .subtract } },
            .loc = .{
                .x = 0,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .facing = .north, .delay = 1 } },
            .loc = .{
                .x = 1,
                .y = 0,
                .z = 0,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = .{
                .x = 1,
                .y = 0,
                .z = 1,
            },
        });

        try area.setBlock(alloc, Block{
            .ty = .{ .repeater = .{ .facing = .north, .delay = 1 } },
            .loc = .{
                .x = 0,
                .y = 0,
                .z = 2,
            },
        });

        try area.setInput(alloc, .{ .x = 1, .y = 0, .z = 0 });
        try area.setOutput(alloc, .{ .x = 0, .y = 0, .z = 3 });

        return area;
    }

    pub fn shift(self: *CircuitEntity, alloc: std.mem.Allocator, dx: u32, dy: u32, dz: u32) !void {
        var placeholder = std.ArrayList(Block){};

        var blocks = self.blocks.valueIterator();
        while (blocks.next()) |block| {
            var new = block.*;
            new.loc.x += dx;
            new.loc.y += dy;
            new.loc.z += dz;

            try placeholder.append(alloc, new);
        }

        self.blocks.deinit(alloc);
        self.blocks = .{};

        for (placeholder.items) |insert| {
            try self.setBlock(alloc, insert);
        }

        for (self.internal_inputs.items) |*i| {
            i.x += dx;
            i.y += dy;
            i.z += dz;
        }

        for (self.inputs.items) |*i| {
            i.@"0".x += dx;
            i.@"0".y += dy;
            i.@"0".z += dz;
        }

        for (self.outputs.items) |*o| {
            o.x += dx;
            o.y += dy;
            o.z += dz;
        }

        placeholder.deinit(alloc);
    }

    /// Combines two circuit entities by shifting one to the left
    pub fn combine(self: *CircuitEntity, alloc: std.mem.Allocator, other: *CircuitEntity) !void {
        try self.shift(alloc, other.width + 10, 0, 0);

        var blocks = other.blocks.valueIterator();
        while (blocks.next()) |block| {
            try self.setBlock(alloc, block.*);
        }

        for (other.internal_inputs.items) |i| {
            try self.setInput(alloc, i);
        }

        for (other.inputs.items) |i| {
            try self.setExternalInput(alloc, i.@"0", i.@"1");
        }

        for (other.outputs.items) |o| {
            try self.setOutput(alloc, o);
        }
    }

    /// Connects an output of other to an input of self, modifying self. You can safely destroy other after
    /// this operation is complete
    pub fn connect(
        self: *CircuitEntity,
        alloc: std.mem.Allocator,
        other: *CircuitEntity,
        self_input_idx: usize,
        other_output_idx: usize,
    ) !void {
        const si = &self.internal_inputs.items[self_input_idx];
        const oo = &other.outputs.items[other_output_idx];
        while (si.x != oo.x) {
            const mag = @max(si.x, oo.x) - @min(si.x, oo.x);
            if (si.x < oo.x) {
                try self.shift(alloc, mag, 0, 0);
            } else {
                try other.shift(alloc, mag, 0, 0);
            }
        }

        while (self.collision(other)) {
            try self.shift(alloc, 0, 0, 1);
        }

        var blocks = other.blocks.valueIterator();
        while (blocks.next()) |b| {
            try self.setBlock(alloc, b.*);
        }

        for (other.internal_inputs.items) |in| {
            try self.setInput(alloc, .{
                .x = in.x,
                .y = in.y,
                .z = in.z,
            });
        }

        for (other.inputs.items) |in| {
            try self.setExternalInput(alloc, in.@"0", in.@"1");
        }

        for (0..other.outputs.items.len) |out| {
            if (out != other_output_idx) {
                try self.setOutput(alloc, other.outputs.items[out]);
            }
        }

        const curr = other.outputs.items[other_output_idx];
        const end = self.internal_inputs.items[self_input_idx];

        try self.connectPoints(alloc, end, curr);

        _ = self.internal_inputs.orderedRemove(self_input_idx);
    }

    /// Checks if a merge would result in any collisions
    fn collision(self: *const CircuitEntity, other: *const CircuitEntity) bool {
        var points = other.blocks.valueIterator();
        while (points.next()) |p| {
            if (self.blocks.contains(p.loc)) return true;
        }

        return false;
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

        const total_blocks = self.blocks.size;
        const blocks_list = try alloc.alloc(*NbtNode, total_blocks);

        var idx: usize = 0;
        var blocks = self.blocks.valueIterator();
        while (blocks.next()) |block| {
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

    fn translateGate(alloc: std.mem.Allocator, gid: GateId, circuit: Circuit) !CircuitEntity {
        var result: CircuitEntity = undefined;
        const gate = circuit.gates.items[gid.id];
        // const deps = circuit.depOn(gid);
        //
        // if (deps > 1 and gate != .input) {
        //     std.debug.print("{} deps on {} [{any}]\n", .{ deps, gid.id, gate });
        // }

        switch (gate) {
            .input => |in| {
                result = try CircuitEntity.constructInput(alloc, in.name);
            },
            .and_gate => |binary| {
                const padding_left = circuit.paddingNecessary(binary.left);
                const padding_right = circuit.paddingNecessary(binary.right);
                var parent = try CircuitEntity.constructAndPadding(alloc, padding_right + padding_left);

                const left = binary.left;
                const right = binary.right;

                var l_child = try CircuitEntity.translateGate(alloc, left, circuit);
                defer l_child.deinit(alloc);

                var r_child = try CircuitEntity.translateGate(alloc, right, circuit);
                defer r_child.deinit(alloc);

                try parent.connect(alloc, &l_child, 0, 0);
                try parent.connect(alloc, &r_child, 0, 0);

                result = parent;
            },
            .or_gate => |binary| {
                const padding_left = circuit.paddingNecessary(binary.left);
                const padding_right = circuit.paddingNecessary(binary.right);

                var parent = try CircuitEntity.constructOrN(alloc, 2, padding_left + padding_right);

                const left = binary.left;
                const right = binary.right;

                var l_child = try CircuitEntity.translateGate(alloc, left, circuit);
                defer l_child.deinit(alloc);

                var r_child = try CircuitEntity.translateGate(alloc, right, circuit);
                defer r_child.deinit(alloc);

                try parent.connect(alloc, &l_child, 0, 0);
                try parent.connect(alloc, &r_child, 0, 0);

                result = parent;
            },
            .xor_gate => |binary| {
                const padding_left = circuit.paddingNecessary(binary.left);
                const padding_right = circuit.paddingNecessary(binary.right);

                var parent = try CircuitEntity.constructXorPadding(alloc, padding_left + padding_right);
                const left = binary.left;
                const right = binary.right;

                var l_child = try CircuitEntity.translateGate(alloc, left, circuit);
                defer l_child.deinit(alloc);

                var r_child = try CircuitEntity.translateGate(alloc, right, circuit);
                defer r_child.deinit(alloc);

                try parent.connect(alloc, &l_child, 0, 0);
                try parent.connect(alloc, &r_child, 0, 0);

                result = parent;
            },
            .not_gate => |unary| {
                var parent = try CircuitEntity.constructNot(alloc);
                const val = unary.val;

                var child = try CircuitEntity.translateGate(alloc, val, circuit);
                defer child.deinit(alloc);

                try parent.connect(alloc, &child, 0, 0);

                result = parent;
            },
            else => @panic("TODO"),
        }

        return result;
    }

    pub fn isWool(self: *const CircuitEntity, check: Point) bool {
        if (self.blocks.get(check)) |p| {
            return p.ty == .white_wool;
        } else {
            return false;
        }
    }

    pub fn bridgeAt(self: *CircuitEntity, alloc: std.mem.Allocator, centered: Point) !void {
        // TODO: keep bridging until safe to unbridge
        var middle = centered;
        var before_before = centered;
        var before = centered;
        var after = centered;
        var after_after = centered;

        before.z -|= 1;
        before_before.z += 2;
        after.z += 1;
        after_after.z -|= 2;

        middle.y += 1;

        _ = self.blocks.remove(before);
        _ = self.blocks.remove(after);

        try self.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = before_before,
        });

        try self.setBlock(alloc, Block{
            .ty = .white_wool,
            .loc = before,
        });

        try self.setBlock(alloc, Block{
            .ty = .white_wool,
            .loc = middle,
        });

        try self.setBlock(alloc, Block{
            .ty = .white_wool,
            .loc = after,
        });

        before.y += 1;
        after.y += 1;
        middle.y += 1;

        try self.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = before,
        });

        try self.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = middle,
        });

        try self.setBlock(alloc, Block{
            .ty = .redstone_wire,
            .loc = after,
        });

        if (self.isWool(after_after)) {
            after_after.y += 1;
            try self.setBlock(alloc, Block{
                .ty = .redstone_wire,
                .loc = after_after,
            });
        } else {
            _ = self.blocks.remove(after_after);
            try self.setBlock(alloc, Block{
                .ty = .{ .repeater = .{ .delay = 1, .facing = .north } },
                .loc = after_after,
            });
        }
    }

    pub fn connectPoints(self: *CircuitEntity, alloc: std.mem.Allocator, from: Point, to: Point) !void {
        var curr = from;
        var steps: u32 = 1;

        while (!std.meta.eql(curr, to)) {
            var dir: Direction = .north;

            if (to.z != curr.z) {
                // move along z
                if (to.z > curr.z) {
                    dir = .north;
                    curr.z += 1;
                } else {
                    dir = .south;
                    curr.z -= 1;
                }
            } else if (to.x != curr.x) {
                // move along x
                if (to.x > curr.x) {
                    dir = .west;
                    curr.x += 1;
                } else {
                    dir = .east;
                    curr.x -= 1;
                }
            }

            const ty = if (steps % STEPS_BEFORE_REPEATER == 0 and !std.meta.eql(curr, to)) BlockMetadata{ .repeater = .{ .delay = 1, .facing = dir } } else .redstone_wire;

            if (self.blocks.contains(curr) and !std.meta.eql(curr, to)) {
                try self.bridgeAt(alloc, curr);
                curr.z += 2;
            } else {
                try self.setBlock(alloc, Block{
                    .ty = ty,
                    .loc = curr,
                });
            }

            steps += 1;
        }
    }

    pub fn translateToEntity(alloc: std.mem.Allocator, circuit: Circuit) !CircuitEntity {
        var result: CircuitEntity = .{};

        for (circuit.outputs.items) |output| {
            var generated = try CircuitEntity.translateGate(alloc, GateId{ .id = output }, circuit);
            defer generated.deinit(alloc);

            try result.combine(alloc, &generated);
        }

        var input_z = std.StringArrayHashMapUnmanaged(u32){};
        defer input_z.deinit(alloc);

        try result.shift(alloc, 1, 0, circuit.inputs.size * 4);

        var names = circuit.inputs.keyIterator();
        var idx: u32 = 0;

        const end = result.width;

        while (names.next()) |name| {
            std.debug.print("{s}\n", .{name.*});

            const z = idx * 4;
            try input_z.put(alloc, name.*, z);

            try result.connectPoints(alloc, .{ .x = end, .y = 0, .z = z }, .{ .x = 0, .y = 0, .z = z });

            try result.setBlock(alloc, .{
                .ty = .{ .lever = .{ .face = .floor, .powered = false, .facing = .west } },
                .loc = .{
                    .x = end,
                    .y = 0,
                    .z = z,
                },
            });

            idx += 1;
        }

        for (result.inputs.items) |input| {
            const to = input.@"0";
            const start = Point{
                .x = input.@"0".x,
                .y = input.@"0".y,
                .z = input_z.get(input.@"1").?,
            };

            try result.connectPoints(alloc, start, to);
            _ = result.blocks.remove(start);
            try result.setBlock(alloc, Block{
                .ty = .redstone_wire,
                .loc = start,
            });
        }

        for (result.outputs.items) |output| {
            _ = result.blocks.remove(output);
            try result.setBlock(alloc, Block{
                .ty = .redstone_lamp,
                .loc = output,
            });
        }

        return result;
    }
};
