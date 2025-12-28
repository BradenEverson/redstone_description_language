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

    internal_signals: std.ArrayList(IO) = .{},
    mappings: std.ArrayList(Assignment) = .{},
};

pub const Assignment = struct {
    output: []const u8,
    assignment: *const Expr,
};

pub const Expr = union(enum) {
    binary: struct { left: *const Expr, op: BinaryOp, right: *const Expr },
    unary: struct { expr: *const Expr, op: UnaryOp },
    input: []const u8,

    pub fn print(self: *const Expr, tabs: u8) void {
        switch (self.*) {
            .input => |in| {
                for (0..tabs) |_| {
                    std.debug.print("\t", .{});
                }
                std.debug.print("input: {s}\n", .{in});
            },

            .binary => |b| {
                for (0..tabs) |_| {
                    std.debug.print("\t", .{});
                }
                std.debug.print("BINARY {any}\n", .{b.op});
                print(b.left, tabs + 1);
                print(b.right, tabs + 1);
            },

            .unary => |u| {
                for (0..tabs) |_| {
                    std.debug.print("\t", .{});
                }
                std.debug.print("UNARY {any}\n", .{u.op});
                print(u.expr, tabs + 1);
            },
        }
    }

    pub fn toCircuit(self: Expr, alloc: std.mem.Allocator, circuit: *Circuit) !dl.GateId {
        switch (self) {
            .input => |in| {
                return try circuit.input(alloc, in);
            },

            .binary => |b| {
                const left = try b.left.toCircuit(alloc, circuit);
                const right = try b.right.toCircuit(alloc, circuit);

                return switch (b.op) {
                    .binary_and => try circuit.andGate(alloc, left, right),
                    .binary_or => try circuit.orGate(alloc, left, right),
                    .binary_xor => try circuit.xorGate(alloc, left, right),
                };
            },

            .unary => |u| {
                const expr = try u.expr.toCircuit(alloc, circuit);

                return switch (u.op) {
                    .not => try circuit.notGate(alloc, expr),
                };
            },
        }
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

const ParsingErrors = ParserError || std.mem.Allocator.Error;

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

        var arch: Architecture = .{ .name = name, .of = of_entity, .internal_signals = .{}, .mappings = .{} };

        // TODO: Before we reach begin there could be internal signal mappings we need to care about
        // maybe this switch could be one of those cool labeled switch loop things
        parse: switch (self.peek()) {
            .keyword => switch (self.peekWhole().toKeyword().?) {
                .begin => {
                    self.advance();
                    while (!self.peekWhole().isKeyword(.end)) {
                        if (self.peekWhole().isKeyword(.with)) {
                            @panic("TODO: With-Select Syntax");
                        } else {
                            const ident = self.peekWhole();
                            try self.consume(.ident);

                            try self.consume(.lt);
                            try self.consume(.equals);

                            const assign = try self.assignment(alloc, ident.data);
                            try arch.mappings.append(alloc, assign);
                        }
                    }
                    break :parse;
                },
                else => return ParserError.UnexpectedKeyword,
            },

            .eof => return ParserError.OutOfTokens,
            else => return ParserError.UnexpectedToken,
        }

        tl.* = .{ .arch = arch };
        return tl;
    }

    /// An assignment is either a when-else, or just a logical statement
    pub fn assignment(self: *Parser, alloc: std.mem.Allocator, binds: []const u8) !Assignment {
        var assign: Assignment = undefined;

        assign.output = binds;
        assign.assignment = try self.parseOrXor(alloc);

        try self.consume(.semicolon);

        return assign;
    }

    pub fn parseOrXor(self: *Parser, alloc: std.mem.Allocator) ParsingErrors!*const Expr {
        var left = try self.parseAnd(alloc);

        while (self.peekWhole().isKeyword(.logic_or) or self.peekWhole().isKeyword(.logic_xor)) {
            const op = self.peekWhole().toKeyword().?;
            self.advance();

            const right = try self.parseAnd(alloc);

            const b_op = switch (op) {
                .logic_or => BinaryOp.binary_or,
                .logic_xor => BinaryOp.binary_xor,
                else => unreachable,
            };

            const expr = try alloc.create(Expr);
            expr.* = .{ .binary = .{ .left = left, .op = b_op, .right = right } };

            left = expr;
        }

        return left;
    }

    pub fn parseAnd(self: *Parser, alloc: std.mem.Allocator) ParsingErrors!*const Expr {
        var left = try self.parseNot(alloc);

        while (self.peekWhole().isKeyword(.logic_and)) {
            self.advance();

            const right = try self.parseNot(alloc);

            const expr = try alloc.create(Expr);
            expr.* = .{ .binary = .{ .left = left, .op = .binary_and, .right = right } };

            left = expr;
        }

        return left;
    }

    pub fn parseNot(self: *Parser, alloc: std.mem.Allocator) ParsingErrors!*const Expr {
        if (self.peekWhole().isKeyword(.logic_not)) {
            self.advance();

            const expr = try alloc.create(Expr);
            const next = try self.parseNot(alloc);

            expr.* = .{ .unary = .{ .expr = next, .op = .not } };

            return expr;
        } else {
            return self.parseTerm(alloc);
        }
    }

    pub fn parseTerm(self: *Parser, alloc: std.mem.Allocator) ParsingErrors!*const Expr {
        switch (self.peek()) {
            .ident => {
                const expr = try alloc.create(Expr);

                expr.* = .{ .input = self.peekWhole().data };
                self.advance();

                return expr;
            },

            .open_paren => {
                self.advance();

                const expr = try self.parseOrXor(alloc);
                errdefer alloc.destroy(expr);

                try self.consume(.close_paren);
                return expr;
            },

            else => return error.UnexpectedToken,
        }
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

    const arch = al.items[0].arch;

    try std.testing.expectEqualStrings("LOGIC", arch.name);
    try std.testing.expectEqualStrings("IDENT", arch.of);

    try std.testing.expectEqual(0, arch.internal_signals.items.len);
    try std.testing.expectEqual(1, arch.mappings.items.len);

    const mapping = arch.mappings.items[0];

    try std.testing.expectEqualStrings("bar", mapping.output);

    try std.testing.expectEqual(.not, mapping.assignment.unary.op);
    try std.testing.expectEqualStrings("foo", mapping.assignment.unary.expr.input);
}
