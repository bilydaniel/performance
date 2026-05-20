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

    b.installArtifact(generator);
    b.installArtifact(haversine);

    // GENERATOR RUN STEP
    const run_generator_step = b.step("run_generator", "Run the generator application");
    const run_generator_cmd = b.addRunArtifact(generator);

    run_generator_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_generator_cmd.addArgs(args);
    }
    run_generator_step.dependOn(&run_generator_cmd.step);

    // HAVERSINE RUN STEP
    const run_haversine_step = b.step("run_haversine", "Run the haversine application");
    const run_haversine_cmd = b.addRunArtifact(haversine);

    run_haversine_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_haversine_cmd.addArgs(args);
    }
    run_haversine_step.dependOn(&run_haversine_cmd.step);
}
