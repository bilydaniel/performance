const std = @import("std");

pub fn asd() i64 {
    std.debug.print("{}\n", .{69});
    return 42;
}
