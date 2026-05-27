const std = @import("std");
const Profiling = @import("profiling.zig");

const TestMode = enum {
    uninitialized,
    testing,
    completed,
    err,
};

const RepetitionTestResults = struct {
    testCount: u64 = 0,
    totalTime: u64 = 0,
    maxTime: u64 = 0,
    minTime: u64 = 0,

    pub fn print(this: @This(), cpuFreq: u64, byteCount: u64) void {
        printTime("Min", @floatFromInt(this.minTime), cpuFreq, byteCount);
        std.debug.print("\n", .{});

        printTime("Max", @floatFromInt(this.maxTime), cpuFreq, byteCount);
        std.debug.print("\n", .{});

        if (this.testCount > 0) {
            printTime("Max", this.totalTime / this.testCount, cpuFreq, byteCount);
            std.debug.print("\n", .{});
        }
    }
};

const RepetitionTester = struct {
    targetProcessedByteCount: u64,
    cpuFreq: u64,
    tryForTime: u64,
    testsStartedAt: u64,

    testMode: TestMode,
    printNewMinimums: bool,
    openBlockCount: u32,
    closedBlockCount: u32,

    timeThisTest: u64,
    bytesThisTest: u64,
    results: RepetitionTestResults,

    pub fn err(this: *@This(), msg: []u8) void {
        this.testMode = .err;
        std.debug.print("ERROR: {s}\n", .{msg});
    }

    pub fn newTestWave(this: *@This(), targetProcessedByteCount: u64, cpuFreq: u64, secondsToTry: u32) void {
        if (this.testMode == .uninitialized) {
            this.testMode = .testing;
            this.targetProcessedByteCount = targetProcessedByteCount;
            this.cpuFreq = cpuFreq;
            this.printNewMinimums = true;
            this.results.minTime = std.math.maxInt(u64);
        } else if (this.testMode == .completed) {
            this.testMode = .testing;

            if (this.targetProcessedByteCount != targetProcessedByteCount) {
                this.err("targetProcessedByteCount has changed"); //if it changed between calls
            }

            if (this.cpuFreq != cpuFreq) {
                this.err("targetProcessedByteCount has changed"); //if it changed between calls
            }
        }

        this.tryForTime = secondsToTry * cpuFreq;
        this.testsStartedAt = Profiling.readCPUTimer();
    }

    pub fn beginTime(this: *@This()) void {
        this.openBlockCount += 1;
        this.timeThisTest -= Profiling.readCPUTimer();
    }

    pub fn endTime(this: *@This()) void {
        this.closedBlockCount += 1;
        this.timeThisTest += Profiling.readCPUTimer();
    }

    pub fn countBytes(this: *@This(), byteCount: u64) void {
        this.bytesThisTest += byteCount;
    }

    pub fn isTesting(this: *@This()) bool {
        if (this.testMode == .testing) {
            const currTime = Profiling.readCPUTimer();

            if (this.openBlockCount > 0) {
                if (this.openBlockCount != this.closedBlockCount) {
                    this.err("wrong block counts");
                }

                if (this.bytesThisTest != this.targetProcessedByteCount) {
                    this.err("wrong bytes counts");
                }

                if (this.testMode == .testing) {
                    //TODO: @continue
                }
            }
        }
    }
};

fn secondsFromCpuTime(cpuTime: f64, cpuFreq: u64) f64 {
    if (cpuFreq == 0) {
        return 0;
    }

    return cpuTime / @as(f64, @floatFromInt(cpuFreq));
}

//TODO: casey has a second version with cpuTime: u64
fn printTime(label: []u8, cpuTime: f64, cpuFreq: u64, byteCount: u64) void {
    std.debug.print("{s}: {d:.1}", .{ label, cpuTime });

    if (cpuFreq > 0) {
        const seconds = secondsFromCpuTime(cpuTime, cpuFreq);
        std.debug.print(" ({d}ms)", .{1000 * seconds});

        if (byteCount > 0) {
            const gb = 1024 * 1024 * 1024;
            const bestBandwith = byteCount / (gb * seconds);
            std.debug.print(" {d}gb/s", .{bestBandwith});
        }
    }
}
