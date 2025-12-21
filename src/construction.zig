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

pub const Block = union(BlockType) {
    air,
    redstone_dust,
    redstone_torch,
    comparator: u8,
    repeater: u8,
};

const Point = struct { x: usize = 0, y: usize = 0, z: usize = 0 };

pub const CircuitEntity = struct {
    width: usize,
    height: usize,
    length: usize,

    inputs: []Point = &[0]Point{},
    outputs: []Point = &[0]Point{},

    blocks: []Block,

    pub fn init(alloc: std.mem.Allocator, w: usize, h: usize, l: usize) !CircuitEntity {
        const buf = try alloc.alloc(Block, w * h * l);
        for (buf) |*item| {
            item.* = .air;
        }

        return CircuitEntity{
            .width = w,
            .height = h,
            .length = l,

            .blocks = buf,
        };
    }

    pub fn deinit(self: *CircuitEntity, alloc: std.mem.Allocator) void {
        alloc.free(self.blocks);
    }

    /// Connects an output of other to an input of self
    pub fn combine(self: *CircuitEntity, other: *CircuitEntity, to_self_input: usize, from_other_output: usize) !CircuitEntity {
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
