//! Parser for translating VHDL Tokens to a VHDL AST :D

pub const std = @import("std");

pub const tokenizer = @import("tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Keyword = tokenizer.Keyword;
pub const TokenTag = tokenizer.TokenTag;

pub const TopLevel = union(enum) {
    entity: EntityDef,
    arch: Architecture,
};

pub const Architecture = struct {
    name: []const u8,
    of: []const u8,

    internal_signals: []IO,
    mappings: []Expr,
};

pub const Expr = union(enum) {
    binary: struct { left: *const Expr, op: BinaryOp, right: *const Expr },
    input: usize,
};

pub const BinaryOp = enum {
    binary_and,
    binary_or,
    binary_xor,
};

pub const EntityDef = struct {
    inputs: []IO,
    outputs: []IO,
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
};

pub const Parser = struct {
    tokens: []const Token,
    cursor: usize,
    arena: std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator, tokens: []const Token) Parser {
        return Parser{
            .arena = std.heap.ArenaAllocator.init(alloc),
            .tokens = tokens,
            .cursor = 0,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    fn peek(self: *const Parser) TokenTag {
        if (self.cursor >= self.tokens.len) {
            return .eof;
        }
        return self.tokens[self.cursor].tag;
    }

    fn peek_n(self: *const Parser, n: comptime_int) TokenTag {
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

    fn consume_kw(self: *Parser, kw: Keyword) ParserError!void {
        if (self.peek() == .keyword) {
            const keyword = Keyword.tryFromStr(self.tokens[self.cursor]).?;
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

    fn at_end(self: *Parser) bool {
        return self.peek() == .eof;
    }

    pub fn parse(self: *Parser, ast: *std.ArrayList(*const TopLevel)) !void {
        while (!self.at_end()) {
            const expr = try self.statement();
            try ast.append(self.arena.allocator(), expr);
        }
    }

    /// Statement FOR NOW is either
    /// `entity` "NAME" is {ENTITY} end `entity` "NAME";
    /// `architecture` "NAME" of "ENTITY" is {ARCHITECTURE} end `architecture` "NAME";
    pub fn statement(self: *Parser) !*const TopLevel {
        _ = self;
        return ParserError.OutOfTokens;
    }

    pub fn entity(self: *Parser) !*const TopLevel {
        _ = self;
        return ParserError.OutOfTokens;
    }

    pub fn architecture(self: *Parser) !*const TopLevel {
        _ = self;
        return ParserError.OutOfTokens;
    }
};
