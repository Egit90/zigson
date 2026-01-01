const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const TokenType = @import("tokenizer.zig").TokenType;
const Value = @import("main.zig").Value;

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedEof,
    ObjectSyntaxError,
};

pub const Parser = struct {
    tokenizer: *tokenizer.Tokenizer,
    current_token: tokenizer.Token,
    allocator: std.mem.Allocator,

    pub fn init(t: *tokenizer.Tokenizer, a: std.mem.Allocator) !Parser {
        var p = Parser{
            .tokenizer = t,
            .current_token = undefined,
            .allocator = a,
        };
        // get first Token
        p.current_token = try p.tokenizer.nextToken();
        return p;
    }

    pub fn parseValue(self: *Parser) anyerror!Value {
        const val = switch (self.current_token.type) {
            TokenType.null_literal => Value{ .null_value = {} },
            TokenType.number => Value{ .number = try std.fmt.parseFloat(f64, self.current_token.lexeme) },
            TokenType.true_literal => Value{ .bool_value = true },
            TokenType.false_literal => Value{ .bool_value = false },
            TokenType.string => Value{ .string = try self.allocator.dupe(u8, self.current_token.lexeme) },
            TokenType.left_bracket => return try self.parseArray(),
            TokenType.left_brace => return try self.parseObject(),
            else => ParserError.UnexpectedToken,
        };
        _ = try self.advance();
        return val;
    }

    pub fn parseArray(self: *Parser) anyerror!Value {
        var list = try std.ArrayList(Value).initCapacity(self.allocator, 0);
        _ = try self.advance();

        // empty array
        if (self.current_token.type == .right_bracket) {
            const items = try list.toOwnedSlice(self.allocator);
            return Value{ .array = items };
        }

        // parse first value
        const first = try self.parseValue();
        try list.append(self.allocator, first);

        // parse remaining values
        while (self.current_token.type == .comma) {
            _ = try self.advance();
            const v = try self.parseValue();
            try list.append(self.allocator, v);
        }

        // Expect closing bracket
        if (self.current_token.type != .right_bracket) {
            return ParserError.UnexpectedToken;
        }
        _ = try self.advance(); // Move past the closing ]
        const items = try list.toOwnedSlice(self.allocator);
        return Value{ .array = items };
    }
    pub fn parseObject(self: *Parser) !Value {
        _ = try self.advance(); // pass the {
        var map = std.StringHashMap(Value).init(self.allocator);

        // empty object
        if (self.current_token.type == .right_brace) {
            _ = try self.advance(); // pass the }
            return Value{ .object = map };
        }

        // parse first key-value pair
        if (self.current_token.type != TokenType.string) {
            return ParserError.ObjectSyntaxError;
        }
        const first_key = try self.removeQuotes(self.current_token.lexeme);
        _ = try self.advance(); // pass the key

        if (self.current_token.type != TokenType.colon) {
            return ParserError.ObjectSyntaxError;
        }
        _ = try self.advance(); // pass the :

        const first_val = try self.parseValue();
        try map.put(first_key, first_val);

        // parse remaining key-value pairs
        while (self.current_token.type == .comma) {
            _ = try self.advance(); // pass the ,

            if (self.current_token.type != TokenType.string) {
                return ParserError.ObjectSyntaxError;
            }
            const key = try self.removeQuotes(self.current_token.lexeme);
            _ = try self.advance(); // pass the key

            if (self.current_token.type != TokenType.colon) {
                return ParserError.ObjectSyntaxError;
            }
            _ = try self.advance(); // pass the :

            const val = try self.parseValue();
            try map.put(key, val);
        }

        // expect closing }
        if (self.current_token.type != .right_brace) {
            return ParserError.UnexpectedToken;
        }
        _ = try self.advance(); // pass the }

        return Value{ .object = map };
    }

    pub fn advance(self: *Parser) !tokenizer.Token {
        const old_token = self.current_token;
        self.current_token = try self.tokenizer.nextToken();
        return old_token;
    }

    fn removeQuotes(self: *Parser, str: []const u8) ![]const u8 {
        _ = self;
        if (str.len >= 2 and str[0] == '"' and str[str.len - 1] == '"') {
            return str[1..str.len - 1];
        }
        return str;
    }
};

test "parse null" {
    const source = "null";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    try std.testing.expect(value == .null_value);
}

test "parse number" {
    const source = "123";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    try std.testing.expect(value == .number);
    try std.testing.expect(value.number == 123.0);
}
test "parse false" {
    const source = "false";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    try std.testing.expect(value == .bool_value);
    try std.testing.expect(value.bool_value == false);
}

test "parse true" {
    const source = "true";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    try std.testing.expect(value == .bool_value);
    try std.testing.expect(value.bool_value == true);
}

test "parse float" {
    const source = "123.32";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    try std.testing.expect(value == .number);
    try std.testing.expect(value.number == 123.32);
}

test "parse string" {
    const source = "\"elie\"";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    defer a.free(value.string);
    try std.testing.expect(value == .string);
    try std.testing.expect(std.mem.eql(u8, value.string, "\"elie\""));
}

test "parse empty array" {
    const source = "[]";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    defer a.free(value.array);

    try std.testing.expect(value == .array);
    try std.testing.expect(value.array.len == 0);
}

test "parse array of numbers" {
    const source = "[1, 2, 3]";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    defer a.free(value.array);

    try std.testing.expect(value.array.len == 3);
    try std.testing.expect(value.array[0].number == 1.0);
    try std.testing.expect(value.array[1].number == 2.0);
    try std.testing.expect(value.array[2].number == 3.0);
}

test "parse mixed array" {
    const source = "[true, 42, null]";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    const value = try parser.parseValue();
    defer a.free(value.array);

    try std.testing.expect(value.array.len == 3);
    try std.testing.expect(value.array[0] == .bool_value);
    try std.testing.expect(value.array[1] == .number);
    try std.testing.expect(value.array[2] == .null_value);
}

test "parse empty object" {
    const source = "{}";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    var value = try parser.parseValue();
    defer value.object.deinit();

    try std.testing.expect(value == .object);
    try std.testing.expect(value.object.count() == 0);
}

test "parse simple object" {
    const source = "{\"name\": \"Elie\", \"age\": 25}";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    var value = try parser.parseValue();
    defer {
        var it = value.object.valueIterator();
        while (it.next()) |v| {
            if (v.* == .string) a.free(v.string);
        }
        value.object.deinit();
    }

    try std.testing.expect(value == .object);
    try std.testing.expect(value.object.count() == 2);

    const name = value.object.get("name").?;
    try std.testing.expect(name == .string);

    const age = value.object.get("age").?;
    try std.testing.expect(age == .number);
    try std.testing.expect(age.number == 25.0);
}

test "parse nested object" {
    const source = "{\"user\": {\"name\": \"Elie\"}}";
    const a = std.testing.allocator;
    var t = tokenizer.Tokenizer.init(source);
    var parser = try Parser.init(&t, a);
    var value = try parser.parseValue();
    defer {
        var user_obj = value.object.getPtr("user").?;
        var it = user_obj.object.valueIterator();
        while (it.next()) |v| {
            if (v.* == .string) a.free(v.string);
        }
        user_obj.object.deinit();
        value.object.deinit();
    }

    try std.testing.expect(value == .object);
    const user = value.object.get("user").?;
    try std.testing.expect(user == .object);

    const name = user.object.get("name").?;
    try std.testing.expect(name == .string);
}
