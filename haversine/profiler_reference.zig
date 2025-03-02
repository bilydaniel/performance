const std = @import("std");

// Timing functions
fn readCPUTimer() u64 {
    // On x86/x64, use rdtsc instruction
    // Note: a real implementation might want to use rdtscp or serialize properly
    if (@import("builtin").cpu.arch == .x86_64) {
        return asm volatile ("rdtsc"
            : [ret] "={eax}" (-> u32),
              [ret_high] "={edx}" (-> u32),
        );
    } else {
        // Fallback to std time
        return std.time.milliTimestamp();
    }
}

fn estimateCPUTimerFreq() u64 {
    // This is a simplified version, a real implementation would calibrate
    // against a known time source
    return 3_000_000_000; // Assuming 3GHz CPU
}

// Profile structure
const ProfileAnchor = struct {
    tscElapsed: u64 = 0,
    tscElapsedChildren: u64 = 0,
    hitCount: u64 = 0,
    label: []const u8 = undefined,
};

const Profiler = struct {
    anchors: [4096]ProfileAnchor = [_]ProfileAnchor{.{}} ** 4096,
    startTSC: u64 = 0,
    endTSC: u64 = 0,
    parentIndex: u32 = 0,
};

var globalProfiler = Profiler{};

// Use comptime to generate unique identifiers for each function/block
fn generateAnchorIndex(comptime label: []const u8) u32 {
    // Simple hash of label string
    comptime {
        var hash: u32 = 0;
        for (label) |c| {
            hash = hash * 65599 + c;
        }
        return (hash % 4095) + 1; // Reserve 0 for root
    }
}

pub const ProfileBlock = struct {
    startTSC: u64,
    parentIndex: u32,
    anchorIndex: u32,
    label: []const u8,

    pub fn init(comptime label: []const u8) ProfileBlock {
        const anchorIndex = generateAnchorIndex(label);
        const parentIndex = globalProfiler.parentIndex;

        globalProfiler.parentIndex = anchorIndex;

        return ProfileBlock{
            .startTSC = readCPUTimer(),
            .parentIndex = parentIndex,
            .anchorIndex = anchorIndex,
            .label = label,
        };
    }

    pub fn deinit(self: *ProfileBlock) void {
        const elapsed = readCPUTimer() - self.startTSC;
        globalProfiler.parentIndex = self.parentIndex;

        var parent = &globalProfiler.anchors[self.parentIndex];
        var anchor = &globalProfiler.anchors[self.anchorIndex];

        parent.tscElapsedChildren += elapsed;
        anchor.tscElapsed += elapsed;
        anchor.hitCount += 1;
        anchor.label = self.label;
    }
};

// Convenience macros (in Zig, these are functions)
pub fn timeBlock(comptime label: []const u8) ProfileBlock {
    return ProfileBlock.init(label);
}

pub fn timeFunction() ProfileBlock {
    return comptime timeBlock(@src().fn_name);
}

pub fn beginProfile() void {
    globalProfiler = Profiler{};
    globalProfiler.startTSC = readCPUTimer();
}

pub fn endAndPrintProfile() void {
    globalProfiler.endTSC = readCPUTimer();
    const cpuFreq = estimateCPUTimerFreq();

    const totalCPUElapsed = globalProfiler.endTSC - globalProfiler.startTSC;

    if (cpuFreq > 0) {
        std.debug.print("\nTotal time: {d:.4}ms (CPU freq {d})\n", .{ 1000.0 * @as(f64, @floatFromInt(totalCPUElapsed)) / @as(f64, @floatFromInt(cpuFreq)), cpuFreq });
    }

    for (globalProfiler.anchors, 0..) |anchor, i| {
        if (anchor.tscElapsed > 0) {
            printTimeElapsed(totalCPUElapsed, &globalProfiler.anchors[i]);
        }
    }
}

fn printTimeElapsed(totalTSCElapsed: u64, anchor: *const ProfileAnchor) void {
    const elapsed = anchor.tscElapsed - anchor.tscElapsedChildren;
    const percent = 100.0 * @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(totalTSCElapsed));

    std.debug.print("  {s}[{d}]: {d} ({d:.2}%", .{ anchor.label, anchor.hitCount, elapsed, percent });

    if (anchor.tscElapsedChildren > 0) {
        const percentWithChildren = 100.0 * @as(f64, @floatFromInt(anchor.tscElapsed)) /
            @as(f64, @floatFromInt(totalTSCElapsed));
        std.debug.print(", {d:.2}% w/children", .{percentWithChildren});
    }

    std.debug.print(")\n", .{});
}

// Example usage
pub fn main() void {
    beginProfile();

    // Example function with profiling
    exampleFunction();

    endAndPrintProfile();
}

fn exampleFunction() void {
    var block = timeFunction();
    defer block.deinit();

    // Simulate work
    var sum: u64 = 0;
    for (0..1000) |_| {
        sum += 1;
        std.time.sleep(1 * std.time.ns_per_ms);
    }

    // Call another function
    nestedFunction();
}

fn nestedFunction() void {
    var block = timeFunction();
    defer block.deinit();

    // Simulate more work
    var sum: u64 = 0;
    for (0..500) |_| {
        sum += 1;
        std.time.sleep(1 * std.time.ns_per_ms);
    }
}
