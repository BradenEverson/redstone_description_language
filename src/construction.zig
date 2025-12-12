//! Intermediate Representation for building the physical Minecraft entity

const std = @import("std");

const Circuit = @import("dl.zig").Circuit;
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const CircuitEntity = struct {
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
