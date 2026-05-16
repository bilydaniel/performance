const std = @import("std");
const main = @import("main.zig");

var registers: [8]i16 = undefined;
var zeroFlag: bool = undefined;
var signFlag: bool = undefined;
pub var ip: i32 = undefined;

pub fn init() void {
    registers = @splat(0);
    zeroFlag = false;
    signFlag = false;
    ip = 0;
}

pub fn executeInstruction(instruction: main.Instruction) !void {
    std.debug.print("instruction: {}\n", .{instruction});
    var result: i16 = 0;
    switch (instruction.op) {
        .mov_imm_r => {
            switch (instruction.mod) {
                0 => {
                    if (instruction.d == 0) {
                        registers[instruction.reg] = instruction.imm;
                    }
                },
                else => unreachable,
            }
        },
        .mov_rm_rm => {
            switch (instruction.mod) {
                3 => {
                    if (instruction.d == 1) {
                        registers[instruction.reg] = registers[instruction.rm];
                    } else {
                        registers[instruction.rm] = registers[instruction.reg];
                    }
                },
                else => unreachable,
            }
        },
        .add_rm_rm => {
            switch (instruction.mod) {
                3 => {
                    if (instruction.d == 1) {
                        registers[instruction.reg] +%= registers[instruction.rm];
                        result = registers[instruction.reg];
                    } else {
                        registers[instruction.rm] +%= registers[instruction.reg];
                        result = registers[instruction.rm];
                    }
                },
                else => unreachable,
            }
            checkForFlags(result);
        },
        .add_imm_rm => {
            switch (instruction.mod) {
                3 => {
                    registers[instruction.rm] +%= instruction.imm;
                    result = registers[instruction.rm];
                },
                else => unreachable,
            }
            checkForFlags(result);
        },
        .sub_rm_rm => {
            switch (instruction.mod) {
                3 => {
                    if (instruction.d == 1) {
                        registers[instruction.reg] -%= registers[instruction.rm];
                        result = registers[instruction.reg];
                    } else {
                        registers[instruction.rm] -%= registers[instruction.reg];
                        result = registers[instruction.rm];
                    }
                },
                else => unreachable,
            }
            checkForFlags(result);
        },
        .sub_imm_rm => {
            switch (instruction.mod) {
                3 => {
                    registers[instruction.rm] -%= instruction.imm;
                    result = registers[instruction.rm];
                },
                else => unreachable,
            }
            checkForFlags(result);
        },
        .cmp_rm_rm => {
            switch (instruction.mod) {
                3 => {
                    if (instruction.d == 1) {
                        result = registers[instruction.reg] -% registers[instruction.rm];
                    } else {
                        result = registers[instruction.rm] -% registers[instruction.reg];
                    }
                },
                else => unreachable,
            }
            checkForFlags(result);
        },
        .jnz => {
            if (zeroFlag == false) {
                const im = @as(i8, @intCast(instruction.imm));
                ip += im;
            }
        },
        else => {
            unreachable;
        },
    }
    //printFlags();
    printRegisters();
}

fn checkForFlags(result: i16) void {
    zeroFlag = (result == 0);
    signFlag = (result < 0);
}

fn resetFlags() void {
    zeroFlag = false;
    signFlag = false;
}

pub fn getFlags(aw: *std.Io.Writer.Allocating) !void {
    try aw.writer.print("   IP:{} ZF: {}, SF: {}\n", .{ ip, zeroFlag, signFlag });
}

pub fn printFlags() void {
    std.debug.print("IP: {} ZF: {}, SF: {}\n", .{ ip, zeroFlag, signFlag });
}

pub fn printRegisters() void {
    std.debug.print("AX: {d} [{b}]\n", .{ registers[0], registers[0] });
    std.debug.print("BX: {d} [{b}]\n", .{ registers[3], registers[3] });
    std.debug.print("CX: {d} [{b}]\n", .{ registers[1], registers[1] });
    std.debug.print("DX: {d} [{b}]\n", .{ registers[2], registers[2] });
    std.debug.print("SP: {d} [{b}]\n", .{ registers[4], registers[4] });
    std.debug.print("BP: {d} [{b}]\n", .{ registers[5], registers[5] });
    std.debug.print("SI: {d} [{b}]\n", .{ registers[6], registers[6] });
    std.debug.print("DI: {d} [{b}]\n", .{ registers[7], registers[7] });
    printFlags();
}
