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
            printTime("Avg", @as(f64, @floatFromInt(this.totalTime)) / @as(f64, @floatFromInt(this.testCount)), cpuFreq, byteCount);
            std.debug.print("\n", .{});
        }
    }
};

pub const RepetitionTester = struct {
    targetProcessedByteCount: u64 = 0,
    cpuFreq: u64 = 0,
    tryForTime: u64 = 0,
    testsStartedAt: u64 = 0,

    testMode: TestMode = .uninitialized,
    printNewMinimums: bool = false,
    openBlockCount: u32 = 0,
    closedBlockCount: u32 = 0,

    timeThisTest: u64 = 0,
    bytesThisTest: u64 = 0,
    results: RepetitionTestResults = .{},

    pub fn init() @This() {
        return @This();
    }

    pub fn err(this: *@This(), msg: []const u8) void {
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
        this.timeThisTest -%= Profiling.readCPUTimer();
    }

    pub fn endTime(this: *@This()) void {
        this.closedBlockCount += 1;
        this.timeThisTest +%= Profiling.readCPUTimer();
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
                    const elapsedTime = this.timeThisTest;

                    this.results.testCount += 1;
                    this.results.totalTime += elapsedTime;

                    if (this.results.maxTime < elapsedTime) {
                        this.results.maxTime = elapsedTime;
                    }

                    if (this.results.minTime > elapsedTime) {
                        this.results.minTime = elapsedTime;

                        // reset the time if min was found
                        this.testsStartedAt = currTime;

                        if (this.printNewMinimums) {
                            printTime("Min", @floatFromInt(this.results.minTime), this.cpuFreq, this.bytesThisTest);
                            std.debug.print("               \r", .{});
                        }
                    }

                    this.openBlockCount = 0;
                    this.closedBlockCount = 0;
                    this.timeThisTest = 0;
                    this.bytesThisTest = 0;
                }
            }

            if ((currTime - this.testsStartedAt) > this.tryForTime) {
                this.testMode = .completed;
                std.debug.print("                                                          \r", .{});
                this.results.print(this.cpuFreq, this.targetProcessedByteCount);
            }
        }

        return this.testMode == .testing;
    }
};

fn secondsFromCpuTime(cpuTime: f64, cpuFreq: u64) f64 {
    if (cpuFreq == 0) {
        return 0;
    }

    return cpuTime / @as(f64, @floatFromInt(cpuFreq));
}

//TODO: casey has a second version with cpuTime: u64
fn printTime(label: []const u8, cpuTime: f64, cpuFreq: u64, byteCount: u64) void {
    std.debug.print("{s}: {d:.1}", .{ label, cpuTime });

    if (cpuFreq > 0) {
        const seconds = secondsFromCpuTime(cpuTime, cpuFreq);
        std.debug.print(" ({d}ms)", .{1000 * seconds});

        if (byteCount > 0) {
            const gb = 1024 * 1024 * 1024;
            const bestBandwith = @as(f64, @floatFromInt(byteCount)) / (gb * seconds);
            std.debug.print(" {d}gb/s", .{bestBandwith});
        }
    }
}
