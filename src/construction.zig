//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const Circuit = @import("dl.zig").Circuit;
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const BlockType = enum(u8) {
    redstone_dust,
    redstone_torch,
    comparator,
    repeater,
    air = 0x0,
};

pub const Block = union(BlockType) {
    redstone_dust,
    redstone_torch,
    comparator: u8,
    repeater: u8,
    air,
};

pub const CircuitEntity = struct {
    width: usize,
    height: usize,
    length: usize,

    blocks: []Block,

    pub fn init(alloc: std.mem.Allocator, w: usize, h: usize, l: usize) !CircuitEntity {
        const buf = try alloc.alloc(Block, w * h * l);
        for (buf) |*item| {
            item = .air;
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

    pub fn toNbt(self: *const CircuitEntity, alloc: std.mem.Allocator) !NbtNode {
        _ = self;
        _ = alloc;

        return .{ .name = null, .ty = .end };
    }
};

pub fn translateToEntity(alloc: std.mem.Allocator, circuit: Circuit) !CircuitEntity {
    _ = alloc;
    _ = circuit;
    return .{};
}
