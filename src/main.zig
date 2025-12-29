const std = @import("std");

pub const Value = union(enum) {
    null_value,
    bool_value: bool,
    number: f64,
    string: []const u8,
    array: []const Value,
};

test "create array value" {
    const items = [_]Value{
        Value{ .number = 1 },
        Value{ .number = 2 },
        Value{ .number = 4 },
    };
    const arr = Value{ .array = &items };

    try std.testing.expect(arr.array.len == 3);
    try std.testing.expect(arr.array[0].number == 1);
}

test "create string value" {
    const str = Value{ .string = "hello" };
    try std.testing.expect(std.mem.eql(u8, str.string, "hello"));
}

test "create number value" {
    const int_val = Value{ .number = 42 };
    const float_val = Value{ .number = 42.14 };
    try std.testing.expect(int_val.number == 42.0);
    try std.testing.expect(float_val.number == 42.14);
}

test "create null value" {
    const val = Value{ .null_value = {} };
    try std.testing.expect(val == .null_value);
}

test "create boolean value" {
    const val_true = Value{ .bool_value = true };
    const val_false = Value{ .bool_value = false };
    try std.testing.expect(val_true.bool_value == true);
    try std.testing.expect(val_false.bool_value == false);
}

pub fn main() !void {}
