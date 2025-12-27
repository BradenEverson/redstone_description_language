//! Parser for translating VHDL Tokens to a VHDL AST :D

pub const std = @import("std");

pub const tokenizer = @import("tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Keyword = tokenizer.Keyword;
pub const TokenTag = tokenizer.TokenTag;

pub const dl = @import("../dl.zig");
pub const Circuit = dl.Circuit;

pub const TopLevel = union(enum) {
    entity: EntityDef,
    arch: Architecture,
};

pub const Architecture = struct {
    name: []const u8,
    of: []const u8,

    internal_signals: std.ArrayList(IO),
    mappings: []Expr,
};

pub const Expr = union(enum) {
    binary: struct { left: *const Expr, op: BinaryOp, right: *const Expr },
    unary: struct { expr: *const Expr, op: UnaryOp },
    input: *const IO,

    pub fn toCircuit(self: Expr, alloc: std.mem.Allocator, circuit: *Circuit) !void {
        _ = self;
        _ = alloc;
        _ = circuit;
    }
};

pub const BinaryOp = enum {
    binary_and,
    binary_or,
    binary_xor,
};

pub const UnaryOp = enum {
    not,
};

pub const EntityDef = struct {
    name: []const u8,

    inputs: std.ArrayList(IO),
    outputs: std.ArrayList(IO),
};

pub const IO = struct {
    name: []const u8,
    ty: StdLogic,
};

pub const StdLogic = union(enum) {
    single,
    vector: u8,
};

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedKeyword,
    ExpectedSemicolon,
    OutOfTokens,
    MismatchedEntityName,
};

pub const Parser = struct {
    tokens: []const Token,
    cursor: usize,

    pub fn init(tokens: []const Token) Parser {
        return Parser{
            .tokens = tokens,
            .cursor = 0,
        };
    }

    fn peekWhole(self: *const Parser) Token {
        if (self.cursor >= self.tokens.len) {
            return Token{
                .tag = .eof,
                .data = "",
                .col = 0,
                .line = 0,
            };
        }
        return self.tokens[self.cursor];
    }

    fn peek(self: *const Parser) TokenTag {
        if (self.cursor >= self.tokens.len) {
            return .eof;
        }
        return self.tokens[self.cursor].tag;
    }

    fn peekN(self: *const Parser, n: comptime_int) TokenTag {
        if (self.cursor + n >= self.tokens.len) {
            return .eof;
        }
        return self.tokens[self.cursor + n].tag;
    }

    fn advance(self: *Parser) void {
        if (self.cursor < self.tokens.len) {
            self.cursor += 1;
        }
    }

    fn consume(self: *Parser, tok: TokenTag) ParserError!void {
        if (self.peek() == tok) {
            self.advance();
            return;
        } else {
            return ParserError.UnexpectedToken;
        }
    }

    fn consumeKw(self: *Parser, kw: Keyword) ParserError!void {
        if (self.peek() == .keyword) {
            const keyword = self.tokens[self.cursor].toKeyword().?;
            if (keyword == kw) {
                self.advance();
                return;
            } else {
                return ParserError.UnexpectedKeyword;
            }
        } else {
            return ParserError.UnexpectedToken;
        }
    }

    fn atEnd(self: *Parser) bool {
        return self.peek() == .eof;
    }

    pub fn parse(self: *Parser, alloc: std.mem.Allocator, ast: *std.ArrayList(*const TopLevel)) !void {
        while (!self.atEnd()) {
            const expr = try self.statement(alloc);
            try ast.append(alloc, expr);
        }
    }

    /// Statement FOR NOW is either
    /// `entity` "NAME" is {ENTITY} end `entity` "NAME";
    /// `architecture` "NAME" of "ENTITY" is {ARCHITECTURE} end `architecture` "NAME";
    pub fn statement(self: *Parser, alloc: std.mem.Allocator) !*const TopLevel {
        switch (self.peek()) {
            .keyword => switch (self.peekWhole().toKeyword().?) {
                .entity => {
                    // `entity` "NAME" is {ENTITY} end `entity` "NAME";
                    try self.consumeKw(.entity);

                    const entity_name = self.peekWhole().data;
                    try self.consume(.ident);

                    try self.consumeKw(.is);

                    const en = try self.entity(alloc, entity_name);
                    errdefer alloc.destroy(en);

                    try self.consumeKw(.end);
                    try self.consumeKw(.entity);

                    const name = self.peekWhole();
                    try self.consume(.ident);
                    try self.consume(.semicolon);

                    if (!std.mem.eql(u8, name.data, entity_name)) return ParserError.MismatchedEntityName;

                    return en;
                },
                .architecture => {
                    // `architecture` "NAME" of "ENTITY" is {ARCHITECTURE} end `architecture` "NAME";
                    try self.consumeKw(.architecture);

                    const arch_name = self.peekWhole().data;
                    try self.consume(.ident);

                    try self.consumeKw(.of);
                    const of_entity = self.peekWhole().data;
                    try self.consume(.ident);
                    try self.consumeKw(.is);

                    const arch = try self.architecture(alloc, arch_name, of_entity);
                    errdefer alloc.destroy(arch);

                    try self.consumeKw(.end);
                    try self.consumeKw(.architecture);

                    const end_arch_name = self.peekWhole().data;
                    try self.consume(.ident);

                    if (!std.mem.eql(u8, end_arch_name, arch_name)) return ParserError.MismatchedEntityName;

                    try self.consume(.semicolon);

                    return arch;
                },

                else => return ParserError.UnexpectedKeyword,
            },
            .eof => return ParserError.OutOfTokens,
            else => return ParserError.UnexpectedToken,
        }
    }

    /// An entity description defined by
    /// `PORT` OPEN_PAREN
    ///     {`IDENT` COLON IN/OUT STD_LOGIC{_VECTOR(NUM DOWNTO NUM)}? {SEMICOLON}?} ..*
    /// CLOSE_PAREN SEMICOLON
    pub fn entity(self: *Parser, alloc: std.mem.Allocator, name: []const u8) !*const TopLevel {
        const tl = try alloc.create(TopLevel);
        errdefer alloc.destroy(tl);

        try self.consumeKw(.port);
        try self.consume(.open_paren);

        var en = EntityDef{
            .name = name,
            .inputs = .{},
            .outputs = .{},
        };

        while (self.peek() != .close_paren) {
            const mapping_name = self.peekWhole().data;
            try self.consume(.ident);
            try self.consume(.colon);

            const al = if (self.peekWhole().toKeyword()) |kw| switch (kw) {
                .in => &en.inputs,
                .out => &en.outputs,
                else => return ParserError.UnexpectedKeyword,
            } else {
                return ParserError.UnexpectedToken;
            };

            self.advance();

            var port = IO{ .name = mapping_name, .ty = .single };

            const ty = self.peekWhole().toKeyword().?;
            switch (ty) {
                .std_logic => self.advance(),
                .std_logic_vector => {
                    self.advance();
                    try self.consume(.open_paren);

                    const top = self.peekWhole();
                    try self.consume(.number);
                    const top_n = try std.fmt.parseInt(u8, top.data, 10);

                    try self.consumeKw(.downto);

                    const bot = self.peekWhole();
                    try self.consume(.number);
                    const bot_n = try std.fmt.parseInt(u8, bot.data, 10);

                    try self.consume(.close_paren);

                    port.ty = .{ .vector = top_n - bot_n };
                },
                else => return ParserError.UnexpectedKeyword,
            }

            try al.append(alloc, port);

            // check for ; or ); consume ; if just
            const end = self.peek();
            if (end == .semicolon) self.advance();
        }

        try self.consume(.close_paren);
        try self.consume(.semicolon);

        tl.* = .{ .entity = en };
        return tl;
    }

    pub fn architecture(self: *Parser, alloc: std.mem.Allocator, name: []const u8, of_entity: []const u8) !*const TopLevel {
        const tl = try alloc.create(TopLevel);
        errdefer alloc.destroy(tl);

        const arch: Architecture = .{ .name = name, .of = of_entity, .internal_signals = .{}, .mappings = undefined };

        // TODO: Before we reach begin there could be internal signal mappings we need to care about
        // maybe this switch could be one of those cool labeled switch loop things
        switch (self.peek()) {
            .keyword => switch (self.peekWhole().toKeyword().?) {
                .begin => {
                    self.advance();
                    while (!self.peekWhole().isKeyword(.end)) {
                        self.advance();
                    }
                },
                else => return ParserError.UnexpectedKeyword,
            },

            .eof => return ParserError.OutOfTokens,
            else => return ParserError.UnexpectedToken,
        }

        tl.* = .{ .arch = arch };
        return tl;
    }
};

test "entity parse" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const token_stream =
        \\entity IDENT is
        \\port(
        \\ foo: in std_logic;
        \\ bar: out std_logic_vector(7 downto 0));
        \\end entity IDENT;
    ;

    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(alloc);

    try tokenizer.tokenize(token_stream, &tokens, alloc);

    var parser = Parser.init(tokens.items);

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var al = std.ArrayList(*const TopLevel){};
    defer al.deinit(a_alloc);

    try parser.parse(a_alloc, &al);

    const entity = al.items[0].*.entity;

    try std.testing.expectEqualStrings("IDENT", entity.name);

    try std.testing.expectEqual(1, entity.inputs.items.len);
    try std.testing.expectEqualStrings("foo", entity.inputs.items[0].name);
    try std.testing.expectEqual(.single, entity.inputs.items[0].ty);

    try std.testing.expectEqual(1, entity.outputs.items.len);
    try std.testing.expectEqualStrings("bar", entity.outputs.items[0].name);
    try std.testing.expectEqual(StdLogic{ .vector = 7 }, entity.outputs.items[0].ty);
}

test "parse architecture" {
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

    try tokenizer.tokenize(token_stream, &tokens, alloc);

    var parser = Parser.init(tokens.items);

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const a_alloc = arena.allocator();

    var al = std.ArrayList(*const TopLevel){};
    defer al.deinit(a_alloc);

    try parser.parse(a_alloc, &al);
}
