const std = @import("std");
const c = @cImport(@cInclude("sys/time.h"));

pub fn readCPUTimer() u64 {
    var high: u64 = 0;
    var low: u64 = 0;

    //TODO: what volatile means?
    asm volatile (
        \\rdtsc
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );

    return (high << 32 | low);
}

pub fn readOSTimer() u64 {
    var value: c.timeval = undefined;
    _ = c.gettimeofday(&value, null);
    return 1_000_000 * @as(u64, @intCast(value.tv_sec)) + @as(u64, @intCast(value.tv_usec));
}

pub fn readOSPageFaultCount() u64 {
    //var usage: std.posix.rusage = undefined;
    const usage = std.posix.getrusage(std.posix.rusage.SELF);
    return @intCast(usage.minflt + usage.majflt);
}

pub fn estimateCPUTimerFreq() u64 {
    const milllisecondsToWait: u64 = 100;
    const osFreq = 1_000_000;

    const cpuStart = readCPUTimer();
    const osStart = readOSTimer();
    var osEnd: u64 = 0;
    var osElapsed: u64 = 0;
    const osWaitTime: u64 = osFreq * milllisecondsToWait / 1000;

    while (osElapsed < osWaitTime) {
        osEnd = readOSTimer();
        osElapsed = osEnd - osStart;
    }

    const cpuEnd = readCPUTimer();
    const cpuElapsed = cpuEnd - cpuStart;

    var cpuFreq: u64 = 0;
    if (osElapsed != 0) {
        cpuFreq = osFreq * cpuElapsed / osElapsed;
    }

    return cpuFreq;
}

//FOR WINDOWS

// static u64 GetOSTimerFreq(void)
// {
// LARGE_INTEGER Freq;
// QueryPerformanceFrequency(&Freq);
// return Freq.QuadPart;
// }

// static u64 ReadOSTimer(void)
// {
// LARGE_INTEGER Value;
// QueryPerformanceCounter(&Value);
// return Value.QuadPart;
// }
