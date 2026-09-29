const std = @import("std");
const posix = std.posix;
var orig:posix.termios = undefined;

const VTIME = 5;
const VMIN = 6;

pub fn die(err_msg:[]const u8) void {
    std.debug.print("{s}", .{err_msg});
}

pub fn loop() !void {
    try enable_raw_mode();
    defer disable_raw_mode() catch {};

    var c:[1]u8 = undefined;
    while (true) {
        c[0] = 0;
        // if (posix.errno(posix.read(posix.STDIN_FILENO, @ptrCast(&c), 1)) != posix.E.AGAIN){
        if(try posix.read(posix.STDIN_FILENO, &c) == -1){ 
            die("Error: READ\n");
        }
        if (std.ascii.isControl(c[0])) {
            std.debug.print("{d}\r\n", .{c[0]});
        } else {
            std.debug.print("{d} ('{c})\r\n", .{c[0], c[0]});
        }
        if (c[0] == 'q') {
            break;
        }
    }
}


pub fn enable_raw_mode() !void {
   
    orig = try posix.tcgetattr(posix.STDIN_FILENO);
    var raw = orig;


    // set timeout timer
    raw.cc[VTIME] = 1;
    raw.cc[VMIN] = 0;

    // misc. flags
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    
    // control flags

    // input flags
    raw.iflag.ICRNL = false; // Is already disabled.
    raw.iflag.BRKINT = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;
    raw.iflag.IXON = false; // Is already disabled.
    raw.lflag.IEXTEN = false; // is already set

    raw.cflag.CSIZE = .CS8;
    //output flags
    raw.oflag.OPOST = false;

    try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw);
}

pub fn disable_raw_mode() !void {
    try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, orig);
}
