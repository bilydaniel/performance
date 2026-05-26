const std = @import("std");
const Profiling = @import("profiling.zig");

pub var profiler: Profiler = undefined;
var parent: u32 = 0;
var anchorCounter: u32 = 1;
const profilerEnabled = true; //TODO: make it better for disabled profiler

pub fn timeFunction(comptime src: std.builtin.SourceLocation) Block {
    return timeBlock(src.fn_name);
}

pub fn timeBlock(comptime name: []const u8) Block {
    return timeBlockBandwith(name, 0);
}

pub fn timeBlockBandwith(comptime name: []const u8, byte_count: u64) Block {
    if (!profilerEnabled) {
        return Block{
            .parentIndex = 0,
            .anchorIndex = 0,
            .label = "",
            .startTSC = 0,
            .oldTSCElapsedInclusive = 0,
        };
    }

    // static variable hack
    // TODO: maybe try to make a version without the hack and compare
    const static = struct {
        var index: u32 = 0;
        var _name = name; // name is here just to force the compiler to make separate instances of the struct, otherwise there is only one and i have only one index value for all the functions
    };

    if (static.index == 0) {
        static.index = anchorCounter;
        anchorCounter += 1;
    }

    return Block.start(name, static.index, byte_count);
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
    TSCElapsedExclusive: i64, //excludes the children
    TSCElapsedInclusive: i64, //includes the childern
    hitCount: u64,
    label: []const u8,
    processedByteCount: u64,

    pub fn printTimeElapsed(this: Anchor, totalElapsed: i64, cpufreq: u64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("\t{s}[{d}]: {d}({d:.2}%) - {d:.4}ms", .{ this.label, this.hitCount, this.TSCElapsedExclusive, percent, 1000 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(cpufreq)) });

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
    oldTSCElapsedInclusive: i64, // fixes wrong meassurements of recursive calls, overwriting the bad values from the recursive children

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

        // exlude the childs time
        var parentAnchor = &profiler.anchors[this.parentIndex];
        parentAnchor.TSCElapsedExclusive -= elapsed;

        var anchor = &profiler.anchors[this.anchorIndex];
        anchor.TSCElapsedExclusive += elapsed;

        anchor.TSCElapsedInclusive = this.oldTSCElapsedInclusive + elapsed;
        anchor.hitCount += 1;
        anchor.label = this.label;
    }
};
