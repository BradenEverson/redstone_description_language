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
};

pub const NbtNode = union(Tag) {
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

    pub fn parseSingular(alloc: std.mem.Allocator, data: []const u8) !*NbtNode {
        const tag = try Tag.fromByte(data[0]);

        const len_msb = @as(u16, data[1]);
        const len_lsb = @as(u16, data[2]);

        const len = len_msb << 8 | len_lsb;
        var string: ?[]const u8 = null;

        if (len > 0) {
            string = data[3 .. 3 + len];
        }

        if (string) |name| {
            std.debug.print("{s}\n", .{name});
        }

        std.debug.print("{any}\n", .{tag});

        const node = try alloc.create(NbtNode);

        switch (tag) {
            .end => node.* = .end,
            .byte => {},
            .short => {},
            .int => {},
            .long => {},
            .float => {},
            .double => {},
            .byte_array => {},
            .string => {},
            .list => {},
            .compound => {},
        }

        return node;
    }
};
