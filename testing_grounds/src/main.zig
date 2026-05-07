const std = @import("std");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn main() !void {
    var a: i32 = 1234;
    var b: i32 = 4567;
    _ = &a; // prevent comptime folding
    _ = &b;
    const c = add(a, b);
    std.debug.print("c: {}\n", .{c});
}
