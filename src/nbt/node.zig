//! NBT Tag Types

const std = @import("std");

pub const Tag = enum(u8) {
    end = 0,
    byte = 1,
    short = 2,
    int = 3,
    long = 4,
    float = 5,
    double = 6,
    byte_array = 7,
    string = 8,
    list = 9,
    compound = 10,

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
    compound: std.ArrayList(*NbtNode),
};

pub const NbtNode = struct {
    name: ?[]const u8,
    ty: NbtType,

    pub fn format(
        self: *const NbtNode,
        writer: anytype,
    ) !void {
        if (self.name) |name| {
            try writer.print("{s} ", .{name});
        }
        switch (self.ty) {
            .end => {
                try writer.print("[[end]]\n", .{});
            },
            .byte => |b| {
                try writer.print("[[byte]]: 0x{X}\n", .{b});
            },
            .short => |s| {
                try writer.print("[[short]]: {d}\n", .{s});
            },
            .int => |i| {
                try writer.print("[[int]]: {d}\n", .{i});
            },
            .long => |l| {
                try writer.print("[[long]]: {d}\n", .{l});
            },
            .float => |f| {
                try writer.print("[[float]]: {d}\n", .{f});
            },
            .double => |d| {
                try writer.print("[[double]]: {d}\n", .{d});
            },
            .byte_array => |ba| {
                try writer.print("[[byte array]]: {any}\n", .{ba});
            },
            .string => |s| {
                try writer.print("[[string]]: {s}\n", .{s});
            },
            .list => |l| {
                try writer.print("[[list]]:\n", .{});
                for (l) |elem| {
                    try writer.print("\t{f}", .{elem});
                }
            },
            .compound => |c| {
                try writer.print("[[compound]]:\n", .{});
                for (c.items) |elem| {
                    try writer.print("\t{f}", .{elem});
                }
            },
        }
    }

    pub fn deinit(self: *NbtNode, alloc: std.mem.Allocator) void {
        switch (self.ty) {
            .list => |elems| {
                for (elems) |elem| {
                    elem.deinit(alloc);
                    alloc.destroy(elem);
                }

                alloc.free(elems);
            },
            .compound => |*elems| {
                for (elems.items) |elem| {
                    elem.deinit(alloc);
                    alloc.destroy(elem);
                }

                elems.deinit(alloc);
            },
            else => {},
        }
    }

    pub fn toBytes(self: *const NbtNode, alloc: std.mem.Allocator, buf: *std.ArrayList(u8), include_tag: bool, include_name: bool) !void {
        const tag: Tag = self.ty;
        if (include_tag) {
            const tag_byte = @intFromEnum(tag);
            try buf.append(alloc, tag_byte);
        }

        if (tag != .end and include_name) {
            if (self.name) |name| {
                const len = std.mem.toBytes(@as(u16, @truncate(name.len)));
                try buf.append(alloc, len[1]);
                try buf.append(alloc, len[0]);

                for (name) |char| {
                    try buf.append(alloc, char);
                }
            } else {
                // No name, no len
                try buf.append(alloc, 0x00);
                try buf.append(alloc, 0x00);
            }
        }

        switch (self.ty) {
            .end => {},
            .byte => |b| {
                try buf.append(alloc, b);
            },
            .short => |s| {
                const short = std.mem.toBytes(s);
                try buf.append(alloc, short[1]);
                try buf.append(alloc, short[0]);
            },
            .int => |i| {
                const int = std.mem.toBytes(i);
                try buf.append(alloc, int[3]);
                try buf.append(alloc, int[2]);
                try buf.append(alloc, int[1]);
                try buf.append(alloc, int[0]);
            },
            .long => |l| {
                const long = std.mem.toBytes(l);
                try buf.append(alloc, long[7]);
                try buf.append(alloc, long[6]);
                try buf.append(alloc, long[5]);
                try buf.append(alloc, long[4]);
                try buf.append(alloc, long[3]);
                try buf.append(alloc, long[2]);
                try buf.append(alloc, long[1]);
                try buf.append(alloc, long[0]);
            },
            .float => |f| {
                const float = std.mem.toBytes(f);
                try buf.append(alloc, float[3]);
                try buf.append(alloc, float[2]);
                try buf.append(alloc, float[1]);
                try buf.append(alloc, float[0]);
            },
            .double => |d| {
                const double = std.mem.toBytes(d);
                try buf.append(alloc, double[7]);
                try buf.append(alloc, double[6]);
                try buf.append(alloc, double[5]);
                try buf.append(alloc, double[4]);
                try buf.append(alloc, double[3]);
                try buf.append(alloc, double[2]);
                try buf.append(alloc, double[1]);
                try buf.append(alloc, double[0]);
            },
            .byte_array => |ba| {
                const len = std.mem.toBytes(@as(u32, @truncate(ba.len)));
                try buf.append(alloc, len[3]);
                try buf.append(alloc, len[2]);
                try buf.append(alloc, len[1]);
                try buf.append(alloc, len[0]);

                for (ba) |byte| {
                    try buf.append(alloc, byte);
                }
            },
            .string => |s| {
                const len = std.mem.toBytes(@as(u16, @truncate(s.len)));
                try buf.append(alloc, len[1]);
                try buf.append(alloc, len[0]);

                for (s) |byte| {
                    try buf.append(alloc, byte);
                }
            },

            .list => |l| {
                var ty: Tag = .end;
                if (l.len > 0) {
                    ty = l[0].ty;
                }

                const ty_byte = @intFromEnum(ty);
                try buf.append(alloc, ty_byte);

                const len = std.mem.toBytes(@as(u32, @truncate(l.len)));
                try buf.append(alloc, len[3]);
                try buf.append(alloc, len[2]);
                try buf.append(alloc, len[1]);
                try buf.append(alloc, len[0]);

                for (l) |li| {
                    try li.toBytes(alloc, buf, false, false);
                }
            },
            .compound => |c| {
                for (c.items) |ci| {
                    try ci.toBytes(alloc, buf, true, true);
                }
            },
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
        node.name = null;

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
            .byte_array => {
                const buf: *const [4]u8 = @ptrCast(data[used .. used + 4].ptr);
                const len = std.mem.readInt(u32, buf, .big);
                used += 4;

                node.ty = .{ .byte_array = data[used .. used + len] };
                used += len;
            },
            .string => {
                const buf: *const [2]u8 = @ptrCast(data[used .. used + 2].ptr);
                const len = std.mem.readInt(u16, buf, .big);
                used += 2;

                node.ty = .{ .string = data[used .. used + len] };
                used += len;
            },
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
            .compound => {
                var sub_elems = std.ArrayList(*NbtNode){};
                var curr, var used_len = try NbtNode.parseSingular(alloc, data[used..], true, null);
                used += used_len;

                try sub_elems.append(alloc, curr);
                var curr_ty: Tag = curr.ty;

                while (curr_ty != .end) {
                    curr, used_len = try NbtNode.parseSingular(alloc, data[used..], true, null);
                    used += used_len;
                    curr_ty = curr.ty;

                    try sub_elems.append(alloc, curr);
                }

                node.ty = .{ .compound = sub_elems };
            },
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
    try std.testing.expectEqualStrings("hi", res.name.?);
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
    try std.testing.expectEqualStrings("short", res.name.?);
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
    try std.testing.expectEqualStrings("int", res.name.?);
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
    try std.testing.expectEqualStrings("long", res.name.?);
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

    defer {
        res.deinit(alloc);
        alloc.destroy(res);
    }

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.list, ty);
    try std.testing.expectEqualStrings("list :O", res.name.?);

    const expected = [_]u16{ 0x0102, 0x0304, 0x0506, 0x0708 };

    for (res.ty.list, 0..) |elem, i| {
        try std.testing.expectEqual(expected[i], elem.ty.short);
    }
}

test "string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x08,
        0x00,
        0x05,
        'h',
        'e',
        'l',
        'l',
        'o',
        0x00,
        0x05,
        'w',
        'o',
        'r',
        'l',
        'd',
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer alloc.destroy(res);

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.string, ty);
    try std.testing.expectEqualStrings("world", res.ty.string);
    try std.testing.expectEqualStrings("hello", res.name.?);
}

test "compound" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const nbt = [_]u8{
        0x0a,
        0x00,
        0x00,
        0x01,
        0x00,
        0x04,
        't',
        'y',
        'p',
        'e',
        0x72,
        0x00,
    };
    const res, _ = try NbtNode.parseSingular(alloc, &nbt, true, null);
    defer {
        res.deinit(alloc);
        alloc.destroy(res);
    }

    const ty: Tag = res.ty;
    try std.testing.expectEqual(.compound, ty);
    try std.testing.expectEqual(null, res.name);

    const expected = [_]NbtNode{
        .{
            .name = "type",
            .ty = .{ .byte = 0x72 },
        },

        .{
            .name = null,
            .ty = .end,
        },
    };

    for (res.ty.compound.items, 0..) |item, i| {
        try std.testing.expectEqual(expected[i].ty, item.ty);
        if (expected[i].name) |name| {
            try std.testing.expectEqualStrings(name, item.name.?);
        }
    }
}

test "simple byte serialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var bytes = std.ArrayList(u8){};
    defer bytes.deinit(alloc);

    const node = NbtNode{ .name = "hello", .ty = .{ .byte = 0x72 } };
    try node.toBytes(alloc, &bytes, true);

    const expected = [_]u8{
        0x01,
        0x00,
        0x05,
        'h',
        'e',
        'l',
        'l',
        'o',
        0x72,
    };

    try std.testing.expectEqualSlices(u8, &expected, bytes.items);
}
