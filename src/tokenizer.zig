const std = @import("std");

pub const TokenError = error{
    UnexpectedCharacter,
    UnterminatedString,
};

pub const TokenType = enum {
    left_brace, // {
    right_brace, // }
    left_bracket, // [
    right_bracket, // ]
    colon, // :
    comma, // ,
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

    pub fn nextToken(self: *Tokenizer) !Token {
        if (self.current >= self.source.len) {
            return Token.init(.eof, "");
        }

        while (self.current < self.source.len and skipWhiteSpace(self.source[self.current])) {
            self.current += 1;
        }

        if (self.current >= self.source.len) {
            return Token.init(.eof, "");
        }

        const c = self.source[self.current];
        self.current += 1;
        return switch (c) {
            '{' => Token.init(.left_brace, "{"),
            '}' => Token.init(.right_brace, "}"),
            '[' => Token.init(.left_bracket, "["),
            ']' => Token.init(.right_bracket, "]"),
            ':' => Token.init(.colon, ":"),
            ',' => Token.init(.comma, ","),
            '"' => self.tokenizeString(),
            else => TokenError.UnexpectedCharacter,
        };
    }

    fn tokenizeString(self: *Tokenizer) !Token {
        const start = self.current - 1; // include the opening "

        // find the closing quote
        while (self.current < self.source.len and self.source[self.current] != '"') {
            self.current += 1;
        }

        if (self.current >= self.source.len) return TokenError.UnterminatedString;
        self.current += 1; // move past the "
        return Token.init(.string, self.source[start..self.current]);
    }
};

pub fn skipWhiteSpace(char: u8) bool {
    return switch (char) {
        ' ', '\t', '\n' => true,
        else => false,
    };
}

test "tokenize string" {
    var tokenizer = Tokenizer.init("\"hello\"");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .string);
    try std.testing.expectEqualStrings("\"hello\"", token.lexeme);
}

test "all whitespace returns eof" {
    var tokenizer = Tokenizer.init("   ");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .eof);
}

test "unexpected character returns error" {
    var tokenizer = Tokenizer.init("@");
    const result = tokenizer.nextToken();
    try std.testing.expectError(TokenError.UnexpectedCharacter, result);
}

test "skip whitespace" {
    var tokenizer = Tokenizer.init("  {  }  ");
    const t1 = try tokenizer.nextToken();
    const t2 = try tokenizer.nextToken();
    try std.testing.expect(t1.type == .left_brace);
    try std.testing.expect(t2.type == .right_brace);
}

test "tokenize colon" {
    var tokenizer = Tokenizer.init(":");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .colon);
}

test "tokenize comma" {
    var tokenizer = Tokenizer.init(",");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .comma);
}

test "tokenize right bracket" {
    var tokenizer = Tokenizer.init("]");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .right_bracket);
}

test "tokenize left bracket" {
    var tokenizer = Tokenizer.init("[");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .left_bracket);
}

test "tokenize left brace" {
    var tokenizer = Tokenizer.init("{");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .left_brace);
}

test "tokenize right brace" {
    var tokenizer = Tokenizer.init("}");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .right_brace);
}

test "token type exists" {
    const token = Token.init(.left_brace, "{");
    try std.testing.expect(token.type == .left_brace);
    try std.testing.expectEqualStrings("{", token.lexeme);
}
