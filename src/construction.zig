//! Intermediate Representation for building the physical Minecraft entity

const Circuit = @import("dl.zig").Circuit;
const NbtNode = @import("nbt/node.zig").NbtNode;

pub const CircuitEntity = struct {
    pub fn toNbt(self: *CircuitEntity) NbtNode {
        _ = self;

        return .{ .name = null, .ty = .end };
    }
};

pub fn translateToEntity(circuit: Circuit) CircuitEntity {
    _ = circuit;
    return .{};
}
