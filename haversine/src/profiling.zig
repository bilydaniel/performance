const std = @import("std");
const c = @cImport(@cInclude("sys/time.h"));

pub fn ReadCPUTimer() u64 {
    var hi: u64 = 0;
    var lo: u64 = 0;

    asm volatile (
        \\rdtsc
        : [low] "={eax}" (lo),
          [high] "={edx}" (hi),
    );

    return (hi << 32 | lo);
}

pub fn ReadOSTimer() u64 {
    var value: c.timeval = undefined;
    _ = c.gettimeofday(&value, null);
    return 1_000_000 * @as(u64, @intCast(value.tv_sec)) + @as(u64, @intCast(value.tv_usec));
}

pub fn EstimateCPUTimerFreq() u64 {
    const milllisecondsToWait: u64 = 100;
    const osFreq = 1_000_000;

    const cpuStart = ReadCPUTimer();
    const osStart = ReadOSTimer();
    var osEnd: u64 = 0;
    var osElapsed: u64 = 0;
    const osWaitTime: u64 = osFreq * milllisecondsToWait / 1000;

    while (osElapsed < osWaitTime) {
        osEnd = ReadOSTimer();
        osElapsed = osEnd - osStart;
    }

    const cpuEnd = ReadCPUTimer();
    const cpuElapsed = cpuEnd - cpuStart;

    var cpuFreq: u64 = 0;
    if (osElapsed != 0) {
        cpuFreq = osFreq * cpuElapsed / osElapsed;
    }

    return cpuFreq;
}
