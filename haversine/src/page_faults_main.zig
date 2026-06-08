const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");
const ReadTest = @import("read_test.zig");
const Profiling = @import("profiling.zig");

pub fn main() !void {
    const pageSize = 4096;
    const pageCount = 4096;
    const totalSize = pageSize * pageCount;

    //csv header
    std.debug.print("Page Count, Touch Count, Fault Count, Extra Faults\n", .{});

    for (0..pageCount) |touchCount| {
        const touchSize = touchCount * pageSize;

        const data = try std.posix.mmap(
            null, // let the os pick the memory
            totalSize,
            std.posix.PROT.READ | std.posix.PROT.WRITE, // read and write
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, // anon = ram, not a file(mmap is used for mapping files too), private = not shared between processes
            -1,
            0,
        );
        defer std.posix.munmap(data);

        const startFaults = Profiling.readOSPageFaultCount();
        for (0..touchSize) |i| {
            //data[i] = @truncate(i);
            data[totalSize - 1 - i] = @truncate(i);
        }
        const endFaults = Profiling.readOSPageFaultCount();

        const faultCount = endFaults - startFaults;

        std.debug.print("{}, {}, {}, {}\n", .{ pageCount, touchCount, faultCount, faultCount - touchCount });
    }
}
