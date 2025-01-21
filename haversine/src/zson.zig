const std = @import("std");

const print = std.debug.print;

const JsonValue = union(enum) {
    null,
    boolean: bool,
    number: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringHashMap(JsonValue),
};

pub fn parse(file: *std.fs.File) !JsonValue {
    try file.seekTo(0);
    var char: u8 = undefined;
    while (true) {
        print("test\n", .{});
        char = file.reader().readByte() catch |err| {
            print("READING ERROR: {}\n", .{err});
            break;
        };
        print("{}\n", .{char});
    }
    print("{}", .{file});
    const value = JsonValue{ .null = {} };
    print("{}", .{value});

    return JsonValue{ .null = {} };
}

const Pair = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};
const Data = struct {
    pairs: []const Pair,
};
pub fn asd() i64 {
    std.debug.print("{}\n", .{69});
    return 42;
}

pub fn mock() !Data {
    const data = Data{
        .pairs = &.{
            Pair{ .x0 = -96.59575683104899, .y0 = 30.788588467490378, .x1 = -87.46731317954121, .y1 = 1.8445901235399873 },
            Pair{ .x0 = 67.69145235694036, .y0 = 74.09065077126873, .x1 = 51.285092428591696, .y1 = 90 },
            Pair{ .x0 = 125.30291071996822, .y0 = 90, .x1 = 35.04410898291682, .y1 = 59.80779892671494 },
            Pair{ .x0 = 124.85635899390746, .y0 = 68.84789321130262, .x1 = 65.74380201730972, .y1 = 43.646871427123315 },
        },
    };
    return data;
}
