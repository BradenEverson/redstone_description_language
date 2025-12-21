//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const Circuit = @import("dl.zig").Circuit;
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const BlockType = enum(u8) {
    air,
    redstone_dust,
    redstone_torch,
    comparator,
    repeater,
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
        _ = self;
        _ = alloc;

        return .{ .name = null, .ty = .end };
    }
};
