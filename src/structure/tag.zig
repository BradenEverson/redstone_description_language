//! NBT Tag Types

const std = @import("std");

pub const Tag = enum {
    end,
    byte,
    short,
    int,
    long,
    float,
    double,
    byte_array,
    string,
    list,
    compound,

    pub fn fromByte(byte: u8) !Tag {
        return switch (byte) {
            0 => .end,
            1 => .byte,
            2 => .short,
            3 => .int,
            4 => .long,
            5 => .float,
            6 => .double,
            7 => .byte_array,
            8 => .string,
            9 => .list,
            10 => .compound,
            else => NbtParseError.UnknownTag,
        };
    }
};

pub const NbtParseError = error{
    UnknownTag,
    WrongTypeInList,
};

pub const NbtType = union(Tag) {
    end,
    byte: u8,
    short: u16,
    int: u32,
    long: u64,
    float: f32,
    double: f64,
    byte_array: []const u8,
    string: []const u8,
    list: []*NbtNode,
    compound: []*NbtNode,
};

pub const NbtNode = struct {
    name: []const u8 = "",
    ty: NbtType,

    pub fn parseSingular(alloc: std.mem.Allocator, data: []const u8, named: bool) !struct { *NbtNode, usize } {
        const tag = try Tag.fromByte(data[0]);
        const node = try alloc.create(NbtNode);

        var used = 1;

        if (tag != .end and named) {
            const len_msb = @as(u16, data[used]);
            used += 1;
            const len_lsb = @as(u16, data[used]);
            used += 1;

            const len = len_msb << 8 | len_lsb;
            var string: ?[]const u8 = null;

            if (len > 0) {
                string = data[used .. used + len];
            }

            if (string) |name| {
                std.debug.print("{s}\n", .{name});
                node.name = name;
            }

            used += len;
        }

        std.debug.print("{any}\n", .{tag});

        switch (tag) {
            .end => node.ty = .end,
            .byte => {
                node.ty = .{ .byte = data[used] };
                used += 1;
            },
            .short => {
                const num = std.mem.readInt(u16, data[used .. used + 2], .big);
                node.ty = .{ .short = num };
                used += 2;
            },
            .int => {
                const num = std.mem.readInt(u32, data[used .. used + 4], .big);
                node.ty = .{ .short = num };
                used += 4;
            },
            .long => {
                const num = std.mem.readInt(u64, data[used .. used + 8], .big);
                node.ty = .{ .short = num };
                used += 8;
            },
            .float => {
                const num = std.mem.bytesAsValue(f32, data[used .. used + 4]).*;
                node.ty = .{ .float = num };
                used += 4;
            },
            .double => {
                const num = std.mem.bytesAsValue(f64, data[used .. used + 8]).*;
                node.ty = .{ .float = num };
                used += 8;
            },
            .byte_array => {},
            .string => {},
            .list => {
                const list_tag = Tag.fromByte(data[used]);
                used += 1;

                const len = std.mem.readInt(u32, data[used .. used + 4], .big);
                used += 4;

                const elems = try alloc.alloc(*NbtNode, len);

                for (0..len) |i| {
                    // parse out `len` sub elements of the list, asserting each
                    // is of the `list_tag`

                    const elem, const new_used = try NbtNode.parseSingular(alloc, data[used..], false);
                    used += new_used;

                    const t: Tag = elem.ty;
                    if (t != list_tag) {
                        return error.WrongTypeInList;
                    }

                    elems[i] = elem;
                }
            },
            .compound => {},
        }

        return .{ node, used };
    }
};

test "simple parse" {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const end = .{0x00};
    const res, _ = try NbtNode.parseSingular(alloc, end, false);
    defer alloc.destroy(res);

    try std.testing.expectEqual(.end, res.ty);
    try std.testing.expectEqualStrings("", res.name);
}
