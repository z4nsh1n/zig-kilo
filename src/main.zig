const std = @import("std");
const Io = std.Io;

const zig_kilo = @import("zig_kilo");

pub fn main(init: std.process.Init) !void {
    _ = init; // autofix
    try zig_kilo.main_loopp();
}
