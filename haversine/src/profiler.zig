const std = @import("std");
const Profiling = @import("profiling.zig");

pub var profiler: Profiler = undefined;
var parent: u32 = 0;
var counter: u32 = 1;
const profiler_enabled = true;

pub var map: std.AutoHashMap(u64, u32) = undefined;

pub fn TimeBlock(name: []const u8, src: std.builtin.SourceLocation) Block {
    return TimeBlockBandwith(name, src, 0);
}
pub fn TimeBlockBandwith(name: []const u8, src: std.builtin.SourceLocation, byte_count: u64) Block {
    if (!profiler_enabled) {
        //TODO: make better with comptime, no idea how for now
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

pub fn TimeFunction(src: std.builtin.SourceLocation) Block {
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
            anchor.PrintTimeElapsed(totalElapsed, cpufreq);
        }
    }
}

const Profiler = struct {
    Anchors: [4096]Anchor,
    StartTSC: i64,
    EndTSC: i64,
};

const Anchor = struct {
    TSCElapsedExclusive: i64,
    TSCElapsedInclusive: i64,
    HitCount: u64,
    Label: []const u8,
    ProcessedByteCount: u64,

    pub fn PrintTimeElapsed(this: Anchor, totalElapsed: i64, cpufreq: u64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsedExclusive)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("\t{s}[{d}]: {d}({d:.2}%)", .{ this.Label, this.HitCount, this.TSCElapsedExclusive, percent });

        if (this.TSCElapsedExclusive != this.TSCElapsedInclusive) {
            const percentInclusive = 100 * @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(totalElapsed));
            std.debug.print("\n\t\t({d:.2}%) with children", .{percentInclusive});
        }

        if (this.ProcessedByteCount > 0) {
            const megabyte: f64 = 1024 * 1024;
            const gigabyte: f64 = megabyte * 1024;

            const seconds: f64 = @as(f64, @floatFromInt(this.TSCElapsedInclusive)) / @as(f64, @floatFromInt(cpufreq));
            const bytes_per_second: f64 = @as(f64, @floatFromInt(this.ProcessedByteCount)) / seconds;
            const megabytes: f64 = @as(f64, @floatFromInt(this.ProcessedByteCount)) / megabyte;
            const gigabytes_per_second = bytes_per_second / gigabyte;
            std.debug.print("\n\t\t{d:.3}mb at {d:.2}gb/s", .{ megabytes, gigabytes_per_second });
        }
        std.debug.print("\n", .{});
    }
};

const Block = struct {
    Label: []const u8,
    StartTSC: i64,
    ParentIndex: u32,
    AnchorIndex: u32,
    OldTSCElapsedInclusive: i64,

    pub fn start(label: []const u8, anchor_index: u32, byte_count: u64) Block {
        var anchor = &profiler.Anchors[anchor_index];
        anchor.ProcessedByteCount += byte_count;
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
        if (!profiler_enabled) {
            return;
        }
        const elapsed: i64 = @as(i64, @intCast(Profiling.ReadCPUTimer())) - this.StartTSC;
        parent = this.ParentIndex;

        var parentAnchor = &profiler.Anchors[this.ParentIndex];
        var anchor = &profiler.Anchors[this.AnchorIndex];
        parentAnchor.TSCElapsedExclusive -= elapsed;
        anchor.TSCElapsedExclusive += elapsed;
        anchor.TSCElapsedInclusive = this.OldTSCElapsedInclusive + elapsed;
        anchor.HitCount += 1;
        anchor.Label = this.Label;
    }
};
