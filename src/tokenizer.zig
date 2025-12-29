const std = @import("std");
pub const TokenType = enum {
    left_brace, // {
    right_brace, // }
    left_bracket, // [
    right_bracket, // ]
    colon, // ,
    string,
    number,
    true_literal,
    false_literal,
    null_literal,
    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8, // the actual text from the source

    pub fn init(token_type: TokenType, lexeme: []const u8) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
        };
    }
};

pub const Tokenizer = struct {
    source: []const u8,
    current: usize,

    pub fn init(source: []const u8) Tokenizer {
        return Tokenizer{
            .source = source,
            .current = 0,
        };
    }

    pub fn nextToken(self: *Tokenizer) Token {
        if (self.current >= self.source.len) {
            return Token.init(.eof, "");
        }

        const c = self.source[self.current];
        self.current += 1;

        return switch (c) {
            '{' => Token.init(.left_brace, "{"),
            else => Token.init(.eof, ""),
        };
    }
};

test "tokenize left brace" {
    var tokenizer = Tokenizer.init("{");
    const token = tokenizer.nextToken();
    try std.testing.expect(token.type == .left_brace);
}

test "token type exists" {
    const token = Token.init(.left_brace, "{");
    try std.testing.expect(token.type == .left_brace);
    try std.testing.expectEqualStrings("{", token.lexeme);
}
