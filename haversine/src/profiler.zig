const std = @import("std");
const Profiling = @import("profiling.zig");

pub var profiler: Profiler = undefined;
var parent: u32 = 0;
var counter: u32 = 1;

pub var map: std.StringHashMap(u32) = undefined;

pub fn TimeBlock(name: []const u8, src: std.builtin.SourceLocation) !Block {
    var AnchorIndex: u32 = 0;
    const line = src.line;
    var buffer: [64]u8 = undefined;
    const key = std.fmt.bufPrint(&buffer, "{s}:{d}", .{ src.file, line }) catch "invalid";
    std.debug.print("KEY: {s}\n", .{key});
    std.debug.print("MAP: {?}\n", .{map.get(key)});

    if (map.get(key)) |value| {
        std.debug.print("GET\n", .{});
        AnchorIndex = value;
    } else {
        AnchorIndex = map.count() + 1;
        std.debug.print("PUT {s}:{d}\n", .{ key, AnchorIndex });
        map.put(key, AnchorIndex) catch {};
    }

    return Block.start(name, AnchorIndex);
}

pub fn TimeBlock(name: []const u8, src: std.builtin.SourceLocation) !Block {
    var AnchorIndex: u32 = 0;

    // Create a hash of the file and line
    var hasher = std.hash.Wyhash.init(0);

    // Hash the file path
    hasher.update(src.file);

    // Hash a separator to avoid collisions
    hasher.update(":");

    // Convert line number to string and hash it
    var line_buf: [16]u8 = undefined;
    const line_str = std.fmt.bufPrint(&line_buf, "{d}", .{src.line}) catch unreachable;
    hasher.update(line_str);

    // Get the final hash value to use as key
    const key_hash = hasher.final();

    // Debug output
    if (debug_output) {
        // Optional: Print the original info
        std.debug.print("Source: {s}:{d} -> Hash: {x}\n", .{ src.file, src.line, key_hash });
    }

    // Check the map using the hash as the key
    if (map.get(key_hash)) |value| {
        AnchorIndex = value;
    } else {
        AnchorIndex = @intCast(u32, map.count() + 1);
        try map.put(key_hash, AnchorIndex);
    }

    return Block.start(name, AnchorIndex);
}

pub fn TimeFunction(src: std.builtin.SourceLocation) !Block {
    return TimeBlock(src.fn_name, src);
}

pub fn BeginProfile() void {
    profiler = .{
        .StartTSC = 0,
        .EndTSC = 0,
        .Anchors = std.mem.zeroes([4096]Anchor),
    };

    profiler.StartTSC = @intCast(Profiling.ReadCPUTimer());
}

pub fn EndProfile() void {
    profiler.EndTSC = @intCast(Profiling.ReadCPUTimer());
    const cpufreq = Profiling.EstimateCPUTimerFreq();

    const totalElapsed = profiler.EndTSC - profiler.StartTSC;

    if (cpufreq > 0) {
        std.debug.print("Total time: {d:.4}ms ({d})\n", .{ 1000 * @as(f64, @floatFromInt(totalElapsed)) / @as(f64, @floatFromInt(cpufreq)), cpufreq });
    }
    for (profiler.Anchors) |anchor| {
        if (anchor.TSCElapsedInclusive > 0) {
            anchor.PrintTimeElapsed(totalElapsed);
        }
    }
}

const Profiler = struct {
    Anchors: [4096]Anchor,
    StartTSC: i64,
    EndTSC: i64,

    //pub fn BlockStart(this: *Profiler, name: []const u8) void {}
    //pub fn BlockEnd(this: *Profiler, name: []const u8) void {}
    //pub fn FunctionStart(this: *Profiler) void {
    //const info = @src();
    //}
    //pub fn FunctionEnd(this: *Profiler) void {
    //const info = @src();
    //}
};

const Anchor = struct {
    TSCElapsedExclusive: i64,
    TSCElapsedInclusive: i64,
    HitCount: u64,
    Label: []const u8,

    pub fn PrintTimeElapsed(this: Anchor, totalElapsed: i64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("   {s}[{d}]: {d}({d}%)\n", .{ this.Label, this.HitCount, this.TSCElapsedExclusive, percent });
        std.debug.print("ex: {d} in: {d}\n", .{ this.TSCElapsedExclusive, this.TSCElapsedInclusive });

        if (this.TSCElapsedExclusive != this.TSCElapsedInclusive) {
            const percentInclusive = 100 * @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(totalElapsed));
            std.debug.print(",({d}%) with children\n", .{percentInclusive});
        }
    }
};

const Block = struct {
    Label: []const u8,
    StartTSC: i64,
    ParentIndex: u32,
    AnchorIndex: u32,
    OldTSCElapsedInclusive: i64,

    pub fn start(label: []const u8, anchor_index: u32) Block {
        const anchor = profiler.Anchors[anchor_index];
        const block = Block{
            .ParentIndex = parent,
            .AnchorIndex = anchor_index,
            .Label = label,
            .StartTSC = @intCast(Profiling.ReadCPUTimer()),
            .OldTSCElapsedInclusive = anchor.TSCElapsedInclusive,
        };
        parent = anchor_index;
        return block;
    }

    pub fn end(this: Block) void {
        const elapsed: i64 = @as(i64, @intCast(Profiling.ReadCPUTimer())) - this.StartTSC;
        parent = this.ParentIndex;

        var parentAnchor = &profiler.Anchors[this.ParentIndex];
        var anchor = &profiler.Anchors[this.AnchorIndex];
        parentAnchor.TSCElapsedExclusive -= elapsed;
        anchor.TSCElapsedExclusive += elapsed;
        anchor.TSCElapsedInclusive = this.OldTSCElapsedInclusive + elapsed;
        anchor.HitCount += 1;
        anchor.Label = this.Label; //TODO: no idea why
    }
};
