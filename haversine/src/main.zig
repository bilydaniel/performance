const std = @import("std");
const zson = @import("zson.zig");
const profiling = @import("profiling.zig");
const Profiler = @import("profiler.zig");

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

pub fn PrintTimeElapsed(label: []const u8, total: u64, begin: u64, end: u64) !void {
    const elapsed = end - begin;
    const percent = 100.0 * (@as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(total)));
    print("{s}: {d} ({d:.2}%)\n", .{ label, elapsed, percent });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const pa = std.heap.page_allocator;
    Profiler.map = std.AutoHashMap(u64, u32).init(pa);
    defer Profiler.map.deinit();

    Profiler.BeginProfile();

    //var Prof_Begin: u64 = 0;
    //var Prof_Read: u64 = 0;
    //var Prof_MiscSetup: u64 = 0;
    //var Prof_Parse: u64 = 0;
    //var Prof_Sum: u64 = 0;
    //var Prof_MiscOutput: u64 = 0;
    //var Prof_End: u64 = 0;

    //Prof_Begin = profiling.ReadCPUTimer();

    //defer std.debug.print("LEAKS: {}\n", .{gpa.deinit()});
    const allocator = gpa.allocator();

    //Prof_Read = profiling.ReadCPUTimer();
    const read_block = Profiler.TimeBlock("Read", @src());
    var file = try std.fs.cwd().openFile("gen/pairs.json", .{});
    const meta = try file.metadata();
    const file_size = meta.size();
    defer file.close();

    const inputJSON = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(inputJSON);
    read_block.end();
    const misc_setup = Profiler.TimeBlock("MiscSetup", @src());
    //Prof_MiscSetup = profiling.ReadCPUTimer();

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
    misc_setup.end();
    const prof_parse = Profiler.TimeBlock("Parse", @src());
    //Prof_Parse = profiling.ReadCPUTimer();
    _ = try zson.parseHaversinePairs(&inputJSONList, &parsed_values);
    prof_parse.end();
    const prof_sum = Profiler.TimeBlock("Sum", @src());
    //Prof_Sum = profiling.ReadCPUTimer();
    //print("parsed_values: {}\n", .{parsed_values});
    //print("pairs_count: {}\n", .{pairs_count});

    //print("{}\n", .{pairs_count});

    var sum: f64 = 0;
    var count: i64 = 0;

    for (parsed_values.items) |pair| {
        //print("{d} {d} {d} {d}\n", pair);
        sum += haversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        count += 1;
    }
    prof_sum.end();
    //Prof_MiscOutput = profiling.ReadCPUTimer();
    const average = sum / @as(f64, @floatFromInt(count));
    //Prof_End = profiling.ReadCPUTimer();
    //const TotalCPUElapsed = Prof_End - Prof_Begin;

    //const cpuFreq = profiling.EstimateCPUTimerFreq();
    //if (cpuFreq != 0) {
    //const time = 1000.0 * @as(f64, @floatFromInt(TotalCPUElapsed)) / @as(f64, @floatFromInt(cpuFreq));
    //std.debug.print("\nTotal time: {d:.4}ms (CPU freq {d} Hz)\n", .{ time, cpuFreq });
    //}

    print("****************************\n", .{});
    print("sum: {d}\n", .{sum});
    print("count: {d}\n", .{count});
    print("average: {d}\n", .{average});

    // PrintTimeElapsed("Startup", TotalCPUElapsed, Prof_Begin, Prof_Read);
    // PrintTimeElapsed("Read", TotalCPUElapsed, Prof_Read, Prof_MiscSetup);
    // PrintTimeElapsed("MiscSetup", TotalCPUElapsed, Prof_MiscSetup, Prof_Parse);
    // PrintTimeElapsed("Parse", TotalCPUElapsed, Prof_Parse, Prof_Sum);
    // PrintTimeElapsed("Sum", TotalCPUElapsed, Prof_Sum, Prof_MiscOutput);
    // PrintTimeElapsed("MiscOutput", TotalCPUElapsed, Prof_MiscOutput, Prof_End);
    Profiler.EndProfile();
}
