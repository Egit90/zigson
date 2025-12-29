const std = @import("std");

pub const TokenError = error{
    UnexpectedCharacter,
    UnterminatedString,
    InvalidNumber,
    InvalidKeyword,
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
        if (self.checkForEof()) |eof_token| return eof_token;
        self.skipWhiteSpace();
        if (self.checkForEof()) |eof_token| return eof_token;

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
            '0'...'9', '-' => self.tokenizeNumber(),
            't', 'f', 'n' => self.tokenizeKeyword(),
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

    fn tokenizeNumber(self: *Tokenizer) !Token {
        const start = self.current - 1;
        const has_minus = self.source[start] == '-';

        // Consume integer part
        const digit_start = self.current;
        while (self.current < self.source.len and std.ascii.isDigit(self.source[self.current])) {
            self.current += 1;
        }

        // If we had minus but no digits, that's an error
        if (has_minus and self.current == digit_start) {
            return TokenError.InvalidNumber;
        }

        // Check for decimal point
        if (self.current < self.source.len and self.source[self.current] == '.') {
            self.current += 1; // consume '.'

            // Must have at least one digit after decimal point!
            if (self.current >= self.source.len or !std.ascii.isDigit(self.source[self.current])) {
                return TokenError.InvalidNumber;
            }

            // Consume fractional part
            while (self.current < self.source.len and std.ascii.isDigit(self.source[self.current])) {
                self.current += 1;
            }
        }

        return Token.init(.number, self.source[start..self.current]);
    }

    fn tokenizeKeyword(self: *Tokenizer) !Token {
        const start = self.current - 1;

        while (self.current < self.source.len and std.ascii.isAlphanumeric(self.source[self.current])) {
            self.current += 1;
        }

        const text = self.source[start..self.current];

        if (std.mem.eql(u8, text, "true")) {
            return Token.init(.true_literal, text);
        }

        if (std.mem.eql(u8, text, "false")) {
            return Token.init(.false_literal, text);
        }

        if (std.mem.eql(u8, text, "null")) {
            return Token.init(.null_literal, text);
        }

        return TokenError.InvalidKeyword;
    }

    fn skipWhiteSpace(self: *Tokenizer) void {
        while (self.current < self.source.len and std.ascii.isWhitespace(self.source[self.current])) {
            self.current += 1;
        }
    }

    fn checkForEof(self: *Tokenizer) ?Token {
        if (self.current >= self.source.len) {
            return Token.init(.eof, "");
        }
        return null;
    }
};

test "tokenize true" {
    var tokenizer = Tokenizer.init("true");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .true_literal);
}

test "tokenize false" {
    var tokenizer = Tokenizer.init("false");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .false_literal);
}

test "tokenize null" {
    var tokenizer = Tokenizer.init("null");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .null_literal);
}

test "tokenize negative integer" {
    var tokenizer = Tokenizer.init("-123");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .number);
    try std.testing.expectEqualStrings("-123", token.lexeme);
}

test "tokenize negative float" {
    var tokenizer = Tokenizer.init("-3.14");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .number);
    try std.testing.expectEqualStrings("-3.14", token.lexeme);
}

test "invalid number with just minus" {
    var tokenizer = Tokenizer.init("-");
    const result = tokenizer.nextToken();
    try std.testing.expectError(TokenError.InvalidNumber, result);
}

test "invalid number with trailing dot" {
    var tokenizer = Tokenizer.init("34.");
    const result = tokenizer.nextToken();
    try std.testing.expectError(TokenError.InvalidNumber, result);
}

test "tokenize integer" {
    var tokenizer = Tokenizer.init("123");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .number);
    try std.testing.expectEqualStrings("123", token.lexeme);
}

test "tokenize float" {
    var tokenizer = Tokenizer.init("3.14");
    const token = try tokenizer.nextToken();
    try std.testing.expect(token.type == .number);
    try std.testing.expectEqualStrings("3.14", token.lexeme);
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
