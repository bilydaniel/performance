const std = @import("std");
const Profiling = @import("profiling.zig");

pub var profiler: Profiler = undefined;
var parent: u32 = 0;

pub fn TimeBlock(name: []const u8, src: std.builtin.SourceLocation) Block {
    const line = src.line;
    const counter = lineToCounter(line);
    return Block.start(name, counter);
}
pub fn TimeFunction(src: std.builtin.SourceLocation) Block {
    return TimeBlock(src.fn_name, src);
}

pub fn BeginProfile() void {
    profiler = .{
        .StartTSC = 0,
        .EndTSC = 0,
        .Anchors = std.mem.zeroes([4096]Anchor),
    };

    profiler.StartTSC = Profiling.ReadCPUTimer();
}

pub fn EndProfile() void {
    profiler.EndTSC = Profiling.ReadCPUTimer();
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

var seen: [100]u32 = undefined;
var seen_count: u32 = 0;

fn lineToCounter(line: u32) u32 {
    var i: u32 = 0;
    while (i < seen_count) : (i += 1) {
        if (seen[i] == line) return i;
    }

    seen[seen_count] = line;
    const saved_line = seen_count;
    seen_count += 1;
    return saved_line;
}

const Profiler = struct {
    Anchors: [4096]Anchor,
    StartTSC: u64,
    EndTSC: u64,

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
    TSCElapsedExclusive: u64,
    TSCElapsedInclusive: u64,
    HitCount: u64,
    Label: []const u8,

    pub fn PrintTimeElapsed(this: Anchor, totalElapsed: u64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("   {s}[{d}]: {d}({d}%)\n", .{ this.Label, this.HitCount, this.TSCElapsedExclusive, percent });
        if (this.TSCElapsedExclusive != this.TSCElapsedInclusive) {
            const percentInclusive = 100 * @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(totalElapsed));
            std.debug.print(",({d}%) with children", .{percentInclusive});
        }
    }
};

const Block = struct {
    Label: []const u8,
    StartTSC: u64,
    ParentIndex: u32,
    AnchorIndex: u32,
    OldTSCElapsedInclusive: u64,

    pub fn start(label: []const u8, anchor_index: u32) Block {
        const anchor = profiler.Anchors[anchor_index];
        const block = Block{
            .ParentIndex = parent,
            .AnchorIndex = anchor_index,
            .Label = label,
            .StartTSC = Profiling.ReadCPUTimer(),
            .OldTSCElapsedInclusive = anchor.TSCElapsedInclusive,
        };
        parent = anchor_index;
        return block;
    }

    pub fn end(this: Block) void {
        const elapsed = Profiling.ReadCPUTimer() - this.StartTSC;
        parent = this.ParentIndex;

        var parentAnchor = &profiler.Anchors[this.ParentIndex];
        var anchor = &profiler.Anchors[this.AnchorIndex];
        if (parentAnchor.TSCElapsedExclusive > 0) {
            parentAnchor.TSCElapsedExclusive -= elapsed;
        }
        anchor.TSCElapsedExclusive += elapsed;
        anchor.TSCElapsedInclusive = this.OldTSCElapsedInclusive + elapsed;
        anchor.HitCount += 1;
        anchor.Label = this.Label; //TODO: no idea why
    }
};
