const std = @import("std");
const Profiling = @import("profiling.zig");

var profiler = Profiler{};
var counter: u64 = 0;

pub fn TimeBlock(name: []const u8) void {
    std.debug.print("{s}", .{name});
}
pub fn TimeFunction() void {
    const info = @src();
    TimeBlock(info.fn_name);
}

const Profiler = struct {
    Anchors: [4096]Anchor,

    StartTSC: u64,
    EndTSC: u64,

    pub fn BeginProfile(this: *Profiler) void {
        this.StartTSC = Profiling.ReadCPUTimer();
    }

    pub fn EndProfile(this: *Profiler) void {
        this.EndTSC = Profiling.ReadCPUTimer();
        const cpufreq = Profiling.EstimateCPUTimerFreq();

        const totalElapsed = this.EndTSC - this.StartTSC;

        if (cpufreq > 0) {
            std.debug.print("Total time: {d:.4}ms ({d})\n", .{ 1000 * @as(f64, @floatFromInt(totalElapsed)) / @as(f64, @floatFromInt(cpufreq)), cpufreq });
        }
        for (this.Anchors) |anchor| {
            if (anchor.TSCElapsed > 0) {
                anchor.PrintTimeElapsed(totalElapsed);
            }
        }
    }

    pub fn BlockStart(this: *Profiler, name: []const u8) void {}
    pub fn BlockEnd(this: *Profiler, name: []const u8) void {}
    pub fn FunctionStart(this: *Profiler) void {
        const info = @src();
    }
    pub fn FunctionEnd(this: *Profiler) void {
        const info = @src();
    }
};

const Anchor = struct {
    TSCElapsed: u64,
    HitCount: u64,
    Label: []const u8,

    pub fn PrintTimeElapsed(this: *Anchor, totalElapsed: u64) void {
        const percent = 100 * @as(f64, @floatFromInt(this.TSCElapsed)) / @as(f64, @floatFromInt(totalElapsed));
        std.debug.print("   {s}[{d}]: {d}({d})", .{ this.Label, this.HitCount, this.TSCElapsed, percent });
    }
};
