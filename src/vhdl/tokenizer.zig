//! Tokenizer for the VHDL spec

const std = @import("std");

const TokenizeError = error{
    UnexpectedEOF,
    UnexpectedCharacter,
};

pub const TokenTag = enum {
    ident,
    keyword,
    number,
    semicolon,
    colon,
    dot,
    comma,
    single_quote,
    double_quote,

    open_paren,
    close_paren,
    lt,
    gt,

    equals,
    eof,

    /// Checks a single character for if it
    /// is one of the basic token types
    pub fn tryGetBasicToken(char: u8) ?TokenTag {
        return switch (char) {
            ':' => .colon,
            ';' => .semicolon,
            '\'' => .single_quote,
            '"' => .double_quote,
            '.' => .dot,
            ',' => .comma,
            '(' => .open_paren,
            ')' => .close_paren,
            '<' => .lt,
            '>' => .gt,
            '=' => .equals,
            else => null,
        };
    }
};

pub const Keyword = enum {
    logic_or,
    logic_and,
    logic_xor,
    logic_not,
    logic_nand,
    logic_nor,

    in,
    of,
    out,
    std_logic,
    std_logic_vector,
    downto,

    with,
    select,
    when,
    others,

    architecture,
    entity,
    port,
    begin,
    end,
    is,

    const mappings = std.StaticStringMap(Keyword).initComptime(.{
        .{ "with", .with },
        .{ "select", .select },
        .{ "when", .when },
        .{ "others", .others },

        .{ "or", .logic_or },
        .{ "and", .logic_and },
        .{ "xor", .logic_xor },
        .{ "not", .logic_not },
        .{ "nand", .logic_nand },
        .{ "nor", .logic_nor },

        .{ "architecture", .architecture },
        .{ "entity", .entity },
        .{ "port", .port },
        .{ "begin", .begin },
        .{ "end", .end },

        .{ "in", .in },
        .{ "out", .out },
        .{ "std_logic", .std_logic },
        .{ "std_logic_vector", .std_logic_vector },
        .{ "downto", .downto },
        .{ "is", .is },
        .{ "of", .of },
    });

    pub fn tryFromStr(str: []const u8) ?Keyword {
        return mappings.get(str);
    }
};

pub const Token = struct {
    tag: TokenTag,
    line: usize,
    col: usize,
    data: []const u8,

    pub fn toKeyword(self: *const Token) ?Keyword {
        return switch (self.tag) {
            .keyword => Keyword.tryFromStr(self.data),
            else => null,
        };
    }

    pub fn isKeyword(self: *const Token, kw: Keyword) bool {
        return switch (self.tag) {
            .keyword => return Keyword.tryFromStr(self.data).? == kw,
            else => false,
        };
    }
};

pub fn tokenize(stream: []const u8, tokens: *std.ArrayList(Token), alloc: std.mem.Allocator) !void {
    var idx: usize = 0;
    var line: usize = 1;
    var col: usize = 1;

    var curr: ?Token = undefined;

    while (idx < stream.len) {
        curr = null;

        const start_idx = idx;
        const start_col = col;

        switch (stream[idx]) {
            'a'...'z', 'A'...'Z', '_' => {
                while (idx < stream.len and (std.ascii.isAlphanumeric(stream[idx]) or stream[idx] == '_')) {
                    idx += 1;
                    col += 1;
                }

                const ident = stream[start_idx..idx];

                var tag: TokenTag = .ident;
                if (Keyword.tryFromStr(ident) != null) {
                    tag = .keyword;
                }

                curr = Token{
                    .tag = tag,
                    .line = line,
                    .col = start_col,
                    .data = ident,
                };
            },
            '0'...'9' => {
                while (idx < stream.len and std.ascii.isDigit(stream[idx])) {
                    idx += 1;
                    col += 1;
                }
                const number = stream[start_idx..idx];
                curr = Token{
                    .tag = .number,
                    .line = line,
                    .col = start_col,
                    .data = number,
                };
            },
            ' ', '\t' => {
                while (idx < stream.len and (stream[idx] == ' ' or stream[idx] == '\t')) {
                    idx += 1;
                    col += 1;
                }
            },
            '\n' => {
                idx += 1;
                line += 1;
                col = 1;
            },
            '-' => {
                idx += 1;
                if (idx < stream.len and stream[idx] == '-') {
                    while (idx < stream.len and stream[idx] != '\n') idx += 1;
                }

                idx += 1;
                line += 1;
                col = 1;
            },
            else => |other| {
                if (TokenTag.tryGetBasicToken(other)) |tag| {
                    idx += 1;
                    col += 1;
                    curr = Token{
                        .tag = tag,
                        .line = line,
                        .col = start_col,
                        .data = stream[start_idx..idx],
                    };
                } else {
                    std.debug.print("Unexpected character: '{c}' at line {}, col {}\n", .{ stream[idx], line, col });

                    return TokenizeError.UnexpectedCharacter;
                }
            },
        }

        if (curr) |tok| {
            try tokens.append(alloc, tok);
        }
    }

    try tokens.append(alloc, .{ .col = col, .line = line, .tag = .eof, .data = undefined });
}

test "entity tokenization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const token_stream =
        \\entity IDENT is
        \\port(
        \\ foo: in std_logic;
        \\ bar: out std_logic);
        \\end entity IDENT;
    ;

    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(alloc);

    try tokenize(token_stream, &tokens, alloc);

    const expected_tags = [_]TokenTag{
        .keyword,
        .ident,
        .keyword,
        .keyword,
        .open_paren,
        .ident,
        .colon,
        .keyword,
        .keyword,
        .semicolon,
        .ident,
        .colon,
        .keyword,
        .keyword,
        .close_paren,
        .semicolon,
        .keyword,
        .keyword,
        .ident,
        .semicolon,
        .eof,
    };

    const expected_keyword = [_]Keyword{ .entity, .is, .port, .in, .std_logic, .out, .std_logic, .end, .entity };
    var keywords_seen: usize = 0;

    const expected_idents = [_][]const u8{ "IDENT", "foo", "bar", "IDENT" };
    var idents_seen: usize = 0;

    try std.testing.expectEqual(expected_tags.len, tokens.items.len);

    for (0..expected_tags.len) |i| {
        try std.testing.expectEqual(expected_tags[i], tokens.items[i].tag);

        if (Keyword.tryFromStr(tokens.items[i].data)) |keyword| {
            try std.testing.expectEqual(expected_keyword[keywords_seen], keyword);
            keywords_seen += 1;
        }

        if (tokens.items[i].tag == .ident) {
            try std.testing.expectEqualStrings(expected_idents[idents_seen], tokens.items[i].data);
            idents_seen += 1;
        }
    }
}

test "simple architecture" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const token_stream =
        \\architecture LOGIC of IDENT is
        \\begin
        \\  bar <= not foo;
        \\end architecture LOGIC;
    ;

    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(alloc);

    try tokenize(token_stream, &tokens, alloc);

    const expected_tags = [_]TokenTag{
        .keyword,
        .ident,
        .keyword,
        .ident,
        .keyword,
        .keyword,
        .ident,
        .lt,
        .equals,
        .keyword,
        .ident,
        .semicolon,
        .keyword,
        .keyword,
        .ident,
        .semicolon,
        .eof,
    };

    const expected_keyword = [_]Keyword{
        .architecture,
        .of,
        .is,
        .begin,
        .logic_not,
        .end,
        .architecture,
    };
    var keywords_seen: usize = 0;

    const expected_idents = [_][]const u8{
        "LOGIC",
        "IDENT",
        "bar",
        "foo",
        "LOGIC",
    };
    var idents_seen: usize = 0;

    try std.testing.expectEqual(expected_tags.len, tokens.items.len);

    for (0..expected_tags.len) |i| {
        try std.testing.expectEqual(expected_tags[i], tokens.items[i].tag);

        if (Keyword.tryFromStr(tokens.items[i].data)) |keyword| {
            try std.testing.expectEqual(expected_keyword[keywords_seen], keyword);
            keywords_seen += 1;
        }

        if (tokens.items[i].tag == .ident) {
            try std.testing.expectEqualStrings(expected_idents[idents_seen], tokens.items[i].data);
            idents_seen += 1;
        }
    }
}

test "with select architecture" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const token_stream =
        \\architecture MUX of IDENT is
        \\begin
        \\  with FOO select
        \\  BAR <= B"101" when B"000",
        \\         B"010" when B"001",
        \\         B"100" when B"010",
        \\         B"111" when others;
        \\end architecture MUX;
    ;

    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(alloc);

    try tokenize(token_stream, &tokens, alloc);

    const expected_tags = [_]TokenTag{
        // architecture MUX of IDENT is
        .keyword,
        .ident,
        .keyword,
        .ident,
        .keyword,

        // begin
        .keyword,

        // with FOO select
        .keyword,
        .ident,
        .keyword,

        // BAR <= B"101" when B"000",
        .ident,
        .lt,
        .equals,
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .keyword,
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .comma,

        // B"010" when B"001",
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .keyword,
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .comma,

        // B"100" when B"010",
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .keyword,
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .comma,

        // B"111" when others;
        .ident,
        .double_quote,
        .number,
        .double_quote,
        .keyword,
        .keyword,
        .semicolon,

        // end architecture MUX;
        .keyword,
        .keyword,
        .ident,
        .semicolon,
        .eof,
    };

    try std.testing.expectEqual(expected_tags.len, tokens.items.len);

    for (0..expected_tags.len) |i| {
        try std.testing.expectEqual(expected_tags[i], tokens.items[i].tag);
    }
}
