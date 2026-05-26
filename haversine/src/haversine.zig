const std = @import("std");
const zson = @import("zson.zig");
const profiling = @import("profiling.zig");
const Profiler = @import("profiler.zig");

const print = std.debug.print;
const math = std.math;

const EARTH_RADIUS = 6372.8; // KM

fn dgrToRad(dgr: f64) f64 {
    return (dgr * (std.math.pi / 180.0));
}

fn haversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    const dy = dgrToRad(y1 - y0);
    const dx = dgrToRad(x1 - x0);
    const y0_rad = dgrToRad(y0);
    const y1_rad = dgrToRad(y1);

    const rootTerm = (math.pow(f64, math.sin(dy / 2), 2)) + math.cos(y0_rad) * math.cos(y1_rad) * (math.pow(f64, math.sin(dx / 2), 2));
    const result = 2 * radius * math.asin(math.sqrt(rootTerm));
    return result;
}

pub fn printTimeElapsed(label: []const u8, total: u64, begin: u64, end: u64) !void {
    const elapsed = end - begin;
    const percent = 100.0 * (@as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(total)));
    print("{s}: {d} ({d:.2}%)\n", .{ label, elapsed, percent });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //TODO: test out arena allocator

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    //TODO: init / deinit map in profiler

    Profiler.beginProfile();
    const time_block = Profiler.timeFunction(@src());

    //var Prof_Begin: u64 = 0;
    //var Prof_Read: u64 = 0;
    //var Prof_MiscSetup: u64 = 0;
    //var Prof_Parse: u64 = 0;
    //var Prof_Sum: u64 = 0;
    //var Prof_MiscOutput: u64 = 0;
    //var Prof_End: u64 = 0;

    //Prof_Begin = profiling.ReadCPUTimer();

    //Prof_Read = profiling.ReadCPUTimer();
    var file = try std.fs.cwd().openFile("pairs.json", .{});
    defer file.close();

    const stat = try file.stat();
    const fileSize = stat.size;

    std.debug.print("file_size: {}", .{fileSize});

    const inputJSON = try allocator.alloc(u8, fileSize);
    var buffer: [4096 * 4]u8 = undefined; // the bigger buffer the faster it seems to be
    var reader = file.reader(&buffer);

    const read_block = Profiler.timeBlockBandwith("read_bandwith", fileSize);

    //const inputJSON = try reader.interface.readAlloc(allocator, fileSize);
    try reader.interface.readSliceAll(inputJSON);
    //TODO: casey has allocation and reading split, he is measuring only the reading
    //so maybe split it too

    //const inputJSON = try file.readToEndAlloc(allocator, fileSize);

    read_block.end();

    defer allocator.free(inputJSON);
    //Prof_MiscSetup = profiling.ReadCPUTimer();

    //std.debug.print("{s}\n", .{content});

    //TODO: casey ma tohle:
    //u32 MinimumJSONPairEncoding = 6*4;
    //u64 MaxPairCount = InputJSON.Count / MinimumJSONPairEncoding;
    //nechci zatim pouzivat, je to "optimalizace"
    var parsed_values = std.ArrayList(zson.Pair).empty;
    defer parsed_values.deinit(allocator);

    //print("INPUT_JSON: {s}\n", .{inputJSON});
    //print("parse_values: {}\n", .{parsed_values});
    //print("LEN: {d}\n", .{inputJSON.len});
    //const data = try zson.mock();
    //Prof_Parse = profiling.ReadCPUTimer();
    _ = try zson.parseHaversinePairs(allocator, inputJSON, &parsed_values);
    //Prof_Sum = profiling.ReadCPUTimer();
    //print("parsed_values: {}\n", .{parsed_values});
    //print("pairs_count: {}\n", .{pairs_count});

    //print("{}\n", .{pairs_count});

    const sum_block = Profiler.timeBlockBandwith("Sum", parsed_values.items.len * @sizeOf(zson.Pair));

    var sum: f64 = 0;
    var count: i64 = 0;

    for (parsed_values.items) |pair| {
        //print("{d} {d} {d} {d}\n", pair);
        sum += haversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        count += 1;
    }
    sum_block.end();
    //Prof_MiscOutput = profiling.ReadCPUTimer();
    const average = sum / @as(f64, @floatFromInt(count));
    //Prof_End = profiling.ReadCPUTimer();
    //const TotalCPUElapsed = Prof_End - Prof_Begin;

    //const cpuFreq = profiling.EstimateCPUTimerFreq();
    //if (cpuFreq != 0) {
    //const time = 1000.0 * @as(f64, @floatFromInt(TotalCPUElapsed)) / @as(f64, @floatFromInt(cpuFreq));
    //std.debug.print("\nTotal time: {d:.4}ms (CPU freq {d} Hz)\n", .{ time, cpuFreq });
    //}

    print("sum: {d}\n", .{sum});
    print("count: {d}\n", .{count});
    print("average: {d}\n", .{average});

    // PrintTimeElapsed("Startup", TotalCPUElapsed, Prof_Begin, Prof_Read);
    // PrintTimeElapsed("Read", TotalCPUElapsed, Prof_Read, Prof_MiscSetup);
    // PrintTimeElapsed("MiscSetup", TotalCPUElapsed, Prof_MiscSetup, Prof_Parse);
    // PrintTimeElapsed("Parse", TotalCPUElapsed, Prof_Parse, Prof_Sum);
    // PrintTimeElapsed("Sum", TotalCPUElapsed, Prof_Sum, Prof_MiscOutput);
    // PrintTimeElapsed("MiscOutput", TotalCPUElapsed, Prof_MiscOutput, Prof_End);
    time_block.end();
    Profiler.endProfile();
}
