const std = @import("std");
const tokenizer_mod = @import("src/tokenizer.zig");
const parser_mod = @import("src/parser.zig");
const Value = @import("src/main.zig").Value;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== ZigSON JSON Parser Demo ===\n\n", .{});

    // Test 1: Parse a number
    std.debug.print("1. Parsing number: 42.5\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("42.5");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        std.debug.print("   Result: {d}\n\n", .{v.number});
    }

    // Test 2: Parse booleans
    std.debug.print("2. Parsing boolean: true\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("true");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        std.debug.print("   Result: {}\n\n", .{v.bool_value});
    }

    // Test 3: Parse null
    std.debug.print("3. Parsing null\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("null");
        var p = try parser_mod.Parser.init(&t, allocator);
        _ = try p.parseValue();
        std.debug.print("   Result: null_value\n\n", .{});
    }

    // Test 4: Parse a string
    std.debug.print("4. Parsing string: \"Hello, Zig!\"\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("\"Hello, Zig!\"");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        defer allocator.free(v.string);
        std.debug.print("   Result: {s}\n\n", .{v.string});
    }

    // Test 5: Parse simple array
    std.debug.print("5. Parsing array: [1, 2, 3, 4, 5]\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("[1, 2, 3, 4, 5]");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        defer allocator.free(v.array);
        std.debug.print("   Result: [ ", .{});
        for (v.array, 0..) |item, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{d}", .{item.number});
        }
        std.debug.print(" ]\n\n", .{});
    }

    // Test 6: Parse mixed array
    std.debug.print("6. Parsing mixed array: [true, 42, null, \"hello\"]\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("[true, 42, null, \"hello\"]");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        defer {
            for (v.array) |item| {
                if (item == .string) allocator.free(item.string);
            }
            allocator.free(v.array);
        }
        std.debug.print("   Result: [\n", .{});
        for (v.array) |item| {
            std.debug.print("     {any}\n", .{item});
        }
        std.debug.print("   ]\n\n", .{});
    }

    // Test 7: Parse nested array
    std.debug.print("7. Parsing nested array: [1, [2, 3], 4]\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("[1, [2, 3], 4]");
        var p = try parser_mod.Parser.init(&t, allocator);
        const v = try p.parseValue();
        defer {
            for (v.array) |item| {
                if (item == .array) allocator.free(item.array);
            }
            allocator.free(v.array);
        }
        std.debug.print("   Result: Nested array with {} elements\n", .{v.array.len});
        for (v.array, 0..) |item, i| {
            switch (item) {
                .number => |n| std.debug.print("     [{d}] = {d}\n", .{ i, n }),
                .array => |arr| std.debug.print("     [{d}] = array with {} elements\n", .{ i, arr.len }),
                else => std.debug.print("     [{d}] = {any}\n", .{ i, item }),
            }
        }
        std.debug.print("\n", .{});
    }

    // Test 8: Parse empty object
    std.debug.print("8. Parsing empty object: {{}}\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("{}");
        var p = try parser_mod.Parser.init(&t, allocator);
        var v = try p.parseValue();
        defer v.object.deinit();
        std.debug.print("   Result: Empty object with {} keys\n\n", .{v.object.count()});
    }

    // Test 9: Parse simple object
    std.debug.print("9. Parsing simple object: {{\"name\": \"Elie\", \"age\": 25}}\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("{\"name\": \"Elie\", \"age\": 25}");
        var p = try parser_mod.Parser.init(&t, allocator);
        var v = try p.parseValue();
        defer {
            var it = v.object.valueIterator();
            while (it.next()) |val| {
                if (val.* == .string) allocator.free(val.string);
            }
            v.object.deinit();
        }
        std.debug.print("   Result: Object with {} keys:\n", .{v.object.count()});
        var iter = v.object.iterator();
        while (iter.next()) |entry| {
            std.debug.print("     \"{s}\": {any}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        std.debug.print("\n", .{});
    }

    // Test 10: Parse object with array
    std.debug.print("10. Parsing object with array: {{\"numbers\": [1, 2, 3]}}\n", .{});
    {
        var t = tokenizer_mod.Tokenizer.init("{\"numbers\": [1, 2, 3]}");
        var p = try parser_mod.Parser.init(&t, allocator);
        var v = try p.parseValue();
        defer {
            if (v.object.getPtr("numbers")) |nums| {
                if (nums.* == .array) allocator.free(nums.array);
            }
            v.object.deinit();
        }
        std.debug.print("   Result: Object with {} key\n", .{v.object.count()});
        const numbers = v.object.get("numbers").?;
        std.debug.print("     \"numbers\": array with {} elements\n\n", .{numbers.array.len});
    }

    std.debug.print("=== Demo Complete! ===\n", .{});
    std.debug.print("\nYour JSON parser is fully functional!\n", .{});
}
