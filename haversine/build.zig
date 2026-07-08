const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const generator = b.addExecutable(.{
        .use_llvm = true,
        .name = "generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/generator.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    const haversine = b.addExecutable(.{
        .use_llvm = true,
        .name = "haversine",
        .root_module = b.createModule(.{
            // Fixed: changed from src/generator.zig to src/haversine.zig
            .root_source_file = b.path("src/haversine.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });
    haversine.linkLibC();

    const readOverhead = b.addExecutable(.{
        .use_llvm = true,
        .name = "read_overhead",
        .root_module = b.createModule(.{
            // Fixed: changed from src/generator.zig to src/haversine.zig
            .root_source_file = b.path("src/read_overhead_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .strip = false,
        }),
    });
    readOverhead.linkLibC();
    readOverhead.addAssemblyFile(b.path("src/nop_loop.o"));

    const pageFaults = b.addExecutable(.{
        .use_llvm = true,
        .name = "page_faults",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/page_faults_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });
    pageFaults.linkLibC();

    const fileRead = b.addExecutable(.{
        .use_llvm = true,
        .name = "file_read",
        .root_module = b.createModule(.{
            // Fixed: changed from src/generator.zig to src/haversine.zig
            .root_source_file = b.path("src/file_read_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .strip = false,
        }),
    });

    const haversineTester = b.addExecutable(.{
        .use_llvm = true,
        .name = "haversine_tester",
        .root_module = b.createModule(.{
            // Fixed: changed from src/generator.zig to src/haversine.zig
            .root_source_file = b.path("src/haversine_tester_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .strip = false,
        }),
    });
    haversineTester.linkLibC();

    b.installArtifact(generator);
    b.installArtifact(haversine);
    b.installArtifact(readOverhead);
    b.installArtifact(pageFaults);
    b.installArtifact(fileRead);
    b.installArtifact(haversineTester);

    // GENERATOR RUN STEP
    const run_generator_step = b.step("run_generator", "Run the generator application");
    const run_generator_cmd = b.addRunArtifact(generator);
    if (b.args) |args| {
        run_generator_cmd.addArgs(args);
    }
    run_generator_step.dependOn(&run_generator_cmd.step);

    // HAVERSINE RUN STEP
    const run_haversine_step = b.step("run_haversine", "Run the haversine application");
    const run_haversine_cmd = b.addRunArtifact(haversine);
    if (b.args) |args| {
        run_haversine_cmd.addArgs(args);
    }
    run_haversine_step.dependOn(&run_haversine_cmd.step);

    // READ OVERHEAD RUN STEP
    const install_read_overhead = b.addInstallArtifact(readOverhead, .{});
    const run_read_overhead_step = b.step("run_read_overhead", "");
    const run_read_overhead_cmd = b.addRunArtifact(readOverhead);
    run_read_overhead_cmd.step.dependOn(&install_read_overhead.step);
    if (b.args) |args| {
        run_read_overhead_cmd.addArgs(args);
    }
    run_read_overhead_step.dependOn(&run_read_overhead_cmd.step);

    // PAGE FAULTS RUN STEP
    const run_page_faults_step = b.step("run_page_faults", "");
    const run_page_faults_cmd = b.addRunArtifact(pageFaults);
    if (b.args) |args| {
        run_page_faults_cmd.addArgs(args);
    }
    run_page_faults_step.dependOn(&run_page_faults_cmd.step);

    // FILE READ
    const run_file_read_step = b.step("run_file_read", "");
    const run_file_read_cmd = b.addRunArtifact(fileRead);
    run_file_read_step.dependOn(&run_file_read_cmd.step);

    // HAVERSINE TESTER
    const run_haversine_tester_step = b.step("run_haversine_tester", "");
    const run_haversine_tester_cmd = b.addRunArtifact(haversineTester);
    run_haversine_tester_step.dependOn(&run_haversine_tester_cmd.step);
}
