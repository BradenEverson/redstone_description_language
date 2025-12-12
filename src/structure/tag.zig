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
    name: []const u8,
    ty: NbtType,

    pub fn deinit(self: *NbtNode, alloc: std.mem.Allocator) void {
        switch (self.ty) {
            .list => |elems| {
                for (elems) |elem| {
                    elem.deinit(alloc);
                    alloc.destroy(elem);
                }

                alloc.free(elems);
            },
            .compound => |elems| {
                for (elems) |elem| {
                    elem.deinit(alloc);
                    alloc.destroy(elem);
                }

                alloc.free(elems);
            },
            else => {},
        }
    }

    pub fn parseSingular(alloc: std.mem.Allocator, data: []const u8, named: bool, force_tag: ?Tag) !struct { *NbtNode, usize } {
        var tag: Tag = undefined;
        var used: usize = 0;

        if (force_tag) |ft| {
            tag = ft;
        } else {
            tag = try Tag.fromByte(data[0]);
            used += 1;
        }

        const node = try alloc.create(NbtNode);

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
                node.name = name;
            }

            used += len;
        }

        switch (tag) {
            .end => node.ty = .end,
            .byte => {
                node.ty = .{ .byte = data[used] };
                used += 1;
            },
            .short => {
                const buf: *const [2]u8 = @ptrCast(data[used .. used + 2].ptr);
                const num = std.mem.readInt(u16, buf, .big);
                node.ty = .{ .short = num };
                used += 2;
            },
            .int => {
                const buf: *const [4]u8 = @ptrCast(data[used .. used + 4].ptr);
                const num = std.mem.readInt(u32, buf, .big);
                node.ty = .{ .int = num };
                used += 4;
            },
            .long => {
                const buf: *const [8]u8 = @ptrCast(data[used .. used + 8].ptr);
                const num = std.mem.readInt(u64, buf, .big);
                node.ty = .{ .long = num };
                used += 8;
            },
            .float => {
                const num = std.mem.bytesAsValue(f32, data[used .. used + 4]).*;
                node.ty = .{ .float = num };
                used += 4;
            },
            .double => {
                const num = std.mem.bytesAsValue(f64, data[used .. used + 8]).*;
                node.ty = .{ .double = num };
                used += 8;
            },
            .byte_array => {},
            .string => {},
            .list => {
                const list_tag = try Tag.fromByte(data[used]);
                used += 1;

                const buf: *const [4]u8 = @ptrCast(data[used .. used + 4].ptr);
                const len = std.mem.readInt(u32, buf, .big);
                used += 4;

                const elems = try alloc.alloc(*NbtNode, len);

                for (0..len) |i| {
                    // parse out `len` sub elements of the list, asserting each
                    // is of the `list_tag`

                    const elem, const new_used = try NbtNode.parseSingular(alloc, data[used..], false, list_tag);
                    used += new_used;

                    elems[i] = elem;
                }

                node.ty = .{ .list = elems };
            },
            .compound => {},
        }

        return .{ node, used };
    }
};

test "simple parse" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const end = .{0x00};
    const res, _ = try NbtNode.parseSingular(alloc, &end, false, null);
    defer alloc.destroy(res);

    try std.testing.expectEqual(.end, res.ty);
}

test "named byte" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x01,
        0x00,
        0x02,
        'h',
        'i',
        0x72,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.byte, ty);
    try std.testing.expectEqual(0x72, res.ty.byte);
    try std.testing.expectEqualStrings("hi", res.name);
}

test "named short" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x02,
        0x00,
        0x05,
        's',
        'h',
        'o',
        'r',
        't',
        0x70,
        0x07,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.short, ty);
    try std.testing.expectEqual(0x7007, res.ty.short);
    try std.testing.expectEqualStrings("short", res.name);
}

test "named int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x03,
        0x00,
        0x03,
        'i',
        'n',
        't',
        0x12,
        0x34,
        0x56,
        0x78,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.int, ty);
    try std.testing.expectEqual(0x12345678, res.ty.int);
    try std.testing.expectEqualStrings("int", res.name);
}

test "named long" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x04,
        0x00,
        0x04,
        'l',
        'o',
        'n',
        'g',
        0xDE,
        0xAD,
        0xBE,
        0xEF,
        0x12,
        0x34,
        0x56,
        0x78,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.long, ty);
    try std.testing.expectEqual(0xDEADBEEF12345678, res.ty.long);
    try std.testing.expectEqualStrings("long", res.name);
}

test "list" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x09,
        0x00,
        0x07,
        'l',
        'i',
        's',
        't',
        ' ',
        ':',
        'O',
        0x02,

        0x00,
        0x00,
        0x00,
        0x04,

        0x01,
        0x02,

        0x03,
        0x04,

        0x05,
        0x06,

        0x07,
        0x08,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);

    defer res.deinit(alloc);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.list, ty);
    try std.testing.expectEqualStrings("list :O", res.name);

    const expected = [_]u16{ 0x0102, 0x0304, 0x0506, 0x0708 };

    for (res.ty.list, 0..) |elem, i| {
        try std.testing.expectEqual(expected[i], elem.ty.short);
    }
}
