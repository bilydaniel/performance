const std = @import("std");
const zson = @import("zson.zig");

const print = std.debug.print;
const math = std.math;

const EARTH_RADIUS = 6372.8; // KM

fn DgrToRad(dgr: f64) f64 {
    return (dgr * (std.math.pi / 180.0));
}

fn haversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    const dy = DgrToRad(y1 - y0);
    const dx = DgrToRad(x1 - x0);
    const y0_rad = DgrToRad(y0);
    const y1_rad = DgrToRad(y1);

    const rootTerm = (math.pow(f64, math.sin(dy / 2), 2)) + math.cos(y0_rad) * math.cos(y1_rad) * (math.pow(f64, math.sin(dx / 2), 2));
    const result = 2 * radius * math.asin(math.sqrt(rootTerm));
    return result;
}

pub fn main() !void {
    const start_time = std.time.milliTimestamp();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer std.debug.print("LEAKS: {}\n", .{gpa.deinit()});
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("gen/pairs.json", .{});
    const meta = try file.metadata();
    const file_size = meta.size();
    defer file.close();

    const inputJSON = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(inputJSON);

    var inputJSONList = std.ArrayList(u8).init(allocator);
    defer inputJSONList.deinit();

    try inputJSONList.appendSlice(inputJSON);

    //std.debug.print("{s}\n", .{content});

    //TODO: casey ma tohle:
    //u32 MinimumJSONPairEncoding = 6*4;
    //u64 MaxPairCount = InputJSON.Count / MinimumJSONPairEncoding;
    //nechci zatim pouzivat, je to "optimalizace"
    var parsed_values = std.ArrayList(zson.HaversinePair).init(allocator);
    defer parsed_values.deinit();

    //print("INPUT_JSON: {s}\n", .{inputJSON});
    //print("parse_values: {}\n", .{parsed_values});
    //print("LEN: {d}\n", .{inputJSON.len});
    //const data = try zson.mock();
    _ = try zson.parseHaversinePairs(&inputJSONList, &parsed_values);
    //print("parsed_values: {}\n", .{parsed_values});
    //print("pairs_count: {}\n", .{pairs_count});

    //print("{}\n", .{pairs_count});

    const mid_time = std.time.milliTimestamp();

    var sum: f64 = 0;
    var count: i64 = 0;

    for (parsed_values.items) |pair| {
        //print("{d} {d} {d} {d}\n", pair);
        sum += haversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        count += 1;
    }
    const average = sum / @as(f64, @floatFromInt(count));
    const end_time = std.time.milliTimestamp();

    print("****************************\n", .{});
    print("sum: {d}\n", .{sum});
    print("count: {d}\n", .{count});
    print("average: {d}\n", .{average});
    print("start_time: {d}\n", .{start_time});
    print("mid_time: {d}\n", .{mid_time});
    print("end_time: {d}\n", .{end_time});
}
