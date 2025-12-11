//! NBT Tag Types

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
};

pub const ParsedTag = union(Tag) {
    end,
    byte: u8,
    short: u16,
    int: u32,
    long: u64,
    float: f32,
    double: f64,
    byte_array: []const u8,
    string: []const u8,
    list: []ParsedTag,
    compound: []ParsedTag,
};
