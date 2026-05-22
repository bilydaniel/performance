const std = @import("std");
const Profiling = @import("profiling.zig");

pub var profiler: Profiler = undefined;
var parent: u32 = 0;
var counter: u32 = 1;
const profilerEnabled = true;

pub var map: std.AutoHashMap(u64, u32) = undefined;

//TODO add name as comptime
pub fn timeBlock(name: []const u8, src: std.builtin.SourceLocation) Block {
    return timeBlockBandwith(name, src, 0);
}

pub fn timeBlockBandwith(name: []const u8, src: std.builtin.SourceLocation, byte_count: u64) Block {
    if (!profilerEnabled) {
        return Block{
            .ParentIndex = 0,
            .AnchorIndex = 0,
            .Label = "",
            .StartTSC = 0,
            .OldTSCElapsedInclusive = 0,
        };
    }
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(src.file);
    var AnchorIndex: u32 = 0;

    var line_buf: [16]u8 = undefined;
    const line_str = std.fmt.bufPrint(&line_buf, "{d}", .{src.line}) catch "invalid";

    hasher.update(line_str);
    const key_hash = hasher.final();

    if (map.get(key_hash)) |value| {
        AnchorIndex = value;
    } else {
        AnchorIndex = map.count() + 1;
        map.put(key_hash, AnchorIndex) catch {};
    }

    return Block.start(name, AnchorIndex, byte_count);
}

pub fn timeFunction(src: std.builtin.SourceLocation) Block {
    return timeBlock(src.fn_name, src);
}

pub fn beginProfile() void {
    profiler = .{
        .startTSC = 0,
        .endTSC = 0,
        .anchors = std.mem.zeroes([4096]Anchor),
    };

    profiler.startTSC = @intCast(Profiling.readCPUTimer());
}

pub fn endProfile() void {
    profiler.endTSC = @intCast(Profiling.readCPUTimer());
    const cpufreq = Profiling.estimateCPUTimerFreq();

    const totalElapsed = profiler.endTSC - profiler.startTSC;

    if (cpufreq > 0) {
        std.debug.print("Total time: {d:.4}ms ({d})\n", .{ 1000 * @as(f64, @floatFromInt(totalElapsed)) / @as(f64, @floatFromInt(cpufreq)), cpufreq });
    }
    for (profiler.anchors) |anchor| {
        if (anchor.TSCElapsedInclusive > 0) {
            anchor.printTimeElapsed(totalElapsed, cpufreq);
        }
    }
}

const Profiler = struct {
    anchors: [4096]Anchor,
    startTSC: i64,
    endTSC: i64,
};

const Anchor = struct {
    TSCElapsedExclusive: i64,
    TSCElapsedInclusive: i64,
    hitCount: u64,
    label: []const u8,
    processedByteCount: u64,

    pub fn printTimeElapsed(this: Anchor, totalElapsed: i64, cpufreq: u64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("\t{s}[{d}]: {d}({d:.2}%)", .{ this.label, this.hitCount, this.TSCElapsedExclusive, percent });

        if (this.TSCElapsedExclusive != this.TSCElapsedInclusive) {
            const percentInclusive = 100 * @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(totalElapsed));
            std.debug.print("\n\t\t({d:.2}%) with children", .{percentInclusive});
        }

        if (this.processedByteCount > 0) {
            const megabyte: f64 = 1024 * 1024;
            const gigabyte: f64 = megabyte * 1024;

            const seconds: f64 = @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(cpufreq));
            const bytesPerSecond: f64 = @as(f64, @floatFromInt(this.processedByteCount)) / seconds;
            const megabytes: f64 = @as(f64, @floatFromInt(this.processedByteCount)) / megabyte;
            const gigabytesPerSecond = bytesPerSecond / gigabyte;
            std.debug.print("\n\t\t{d:.3}mb at {d:.2}gb/s", .{ megabytes, gigabytesPerSecond });
        }
        std.debug.print("\n", .{});
    }
};

const Block = struct {
    label: []const u8,
    startTSC: i64,
    parentIndex: u32,
    anchorIndex: u32,
    oldTSCElapsedInclusive: i64,

    pub fn start(label: []const u8, anchorIndex: u32, byteCount: u64) Block {
        var anchor = &profiler.anchors[anchorIndex];
        anchor.processedByteCount += byteCount;
        const block = Block{
            .parentIndex = parent,
            .anchorIndex = anchorIndex,
            .label = label,
            .startTSC = @intCast(Profiling.readCPUTimer()),
            .oldTSCElapsedInclusive = anchor.TSCElapsedInclusive,
        };
        parent = anchorIndex;
        return block;
    }

    pub fn end(this: Block) void {
        if (!profilerEnabled) {
            return;
        }
        const elapsed: i64 = @as(i64, @intCast(Profiling.readCPUTimer())) - this.startTSC;
        parent = this.parentIndex;

        var parentAnchor = &profiler.anchors[this.parentIndex];
        var anchor = &profiler.anchors[this.anchorIndex];
        parentAnchor.TSCElapsedExclusive -= elapsed;
        anchor.TSCElapsedExclusive += elapsed;
        anchor.TSCElapsedInclusive = this.oldTSCElapsedInclusive + elapsed;
        anchor.hitCount += 1;
        anchor.label = this.label;
    }
};
