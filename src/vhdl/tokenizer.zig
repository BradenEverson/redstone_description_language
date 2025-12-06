//! Tokenizer for the VHDL spec

const std = @import("std");

const TokenizeError = error{
    UnexpectedEOF,
    UnexpectedCharacter,
};

pub const TokenTag = enum {
    ident,
    number,
    semicolon,
    dot,
};

pub const Token = struct {
    tag: TokenTag,
    line: usize,
    col: usize,
    data: []const u8,
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
                curr = Token{
                    .tag = .ident,
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
            '=' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .equals,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            '.' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .dot,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            ';' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .semicolon,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
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
            '\r' => {
                idx += 1;
                if (idx < stream.len and stream[idx] == '\n') {
                    idx += 1;
                }
                line += 1;
                col = 1;
            },
            else => {
                std.debug.print("Unexpected character: '{c}' at line {}, col {}\n", .{ stream[idx], line, col });

                return TokenizeError.UnexpectedCharacter;
            },
        }

        if (curr) |tok| {
            try tokens.append(alloc, tok);
        }
    }

    try tokens.append(alloc, .{ .col = col, .line = line, .tag = .eof, .data = undefined });
}
