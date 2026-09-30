//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const posix = std.posix;
const tui = @import("tui");
const libc = std.c;

const KILO_VERSION = "0.0.1";


const EditorConfig = struct {
    screen_rows: u32 = 0,
    screen_cols: u32 = 0,
    cx: u32 = 0,
    cy: u32 = 0,
};

var E:EditorConfig = .{};

/// Convert a char to control key code
// pub inline fn ctrl_key(k:u8) tui.Key {
//     return @enumFromInt(k & 0x1f);
// }

/// print error message to stderr
pub fn die(err_msg:[]const u8) void {
    tui.clr_screen();
    // std.debug.print("{s}", .{err_msg});
    @panic(err_msg) ;
}

// Todo: Move this into tui.
pub fn editor_read_key() tui.Key{
    const c=tui.read_key_wait();
    if (c == tui.Key.ESC) {
        var seq:[3]tui.Key = .{.Null, .Null, .Null};
        seq[0] = tui.read_key();
        seq[1] = tui.read_key();
        if (seq[0] == tui.Key.Null or seq[1] == tui.Key.Null) return c;
        // start escape seq
        if (seq[0] == tui.Key.LBracket) {
            if (@intFromEnum(seq[1]) >= @intFromEnum(tui.Key.Zero) and 
                @intFromEnum(seq[1]) < @intFromEnum(tui.Key.Nine)) {
                seq[2] = tui.read_key();
                if (seq[2] == tui.Key.Tilde) {
                    switch (seq[1]) {
                        tui.Key.Three => return tui.Key.Delete,
                        tui.Key.Five => return tui.Key.PageUp,
                        tui.Key.Six =>  return tui.Key.PageDown,
                        tui.Key.One, tui.Key.Seven => return tui.Key.Home,
                        tui.Key.Four, tui.Key.Eight => return tui.Key.End,
                        else => unreachable,
                    }
                }
            } 
            switch (seq[1]) {
                tui.Key.A => return tui.Key.ARROW_UP,
                tui.Key.B => return tui.Key.ARROW_DOWN,
                tui.Key.C => return tui.Key.ARROW_RIGHT,
                tui.Key.D => return tui.Key.ARROW_LEFT,
                tui.Key.H => return tui.Key.Home,
                tui.Key.F => return tui.Key.End,
                else => unreachable,
            }
        }
        return tui.Key.ESC;
    }
    return c;
}

pub fn editor_move_cursor(key: tui.Key) void {
    switch (key) {
        tui.Key.ARROW_UP => if (E.cy != 0) {E.cy -= 1;},
        tui.Key.ARROW_DOWN => if(E.cy < E.screen_rows - 1) {E.cy += 1;},
        tui.Key.ARROW_LEFT => if(E.cx != 0) {E.cx -= 1;},
        tui.Key.ARROW_RIGHT => if(E.cx < E.screen_cols - 1 ) {E.cx += 1;},
        // tui.Key.PageDown, // => E.cy = E.screen_rows - 1,
        // tui.Key.PageUp => |r| {
        //     E.cy = 0},
        tui.Key.Home => E.cx = 0,
        tui.Key.End => E.cx = E.screen_cols - 1,
        else => unreachable,
    }
}


pub fn editor_process_key_press() bool {
    const c:tui.Key = editor_read_key();
    switch (c) {
        tui.ctrl_key('q'), tui.Key.Delete => {
        // tui.Key.Q => {
            tui.clr_screen();
            return false;
        },
        tui.Key.w => editor_move_cursor(tui.Key.ARROW_UP), 
        tui.Key.a => editor_move_cursor(tui.Key.ARROW_LEFT), 
        tui.Key.s => editor_move_cursor(tui.Key.ARROW_DOWN),
        tui.Key.d => editor_move_cursor(tui.Key.ARROW_RIGHT),
        tui.Key.PageDown, tui.Key.PageUp => |key|{
            var times = E.screen_rows;
            while (times > 0) {
                times -= 1;
                editor_move_cursor(if (key == tui.Key.PageUp) tui.Key.ARROW_UP else tui.Key.ARROW_DOWN);
            }
        },
        tui.Key.ARROW_UP, tui.Key.ARROW_DOWN, tui.Key.ARROW_LEFT, tui.Key.ARROW_RIGHT,
        tui.Key.Home, tui.Key.End => {
            editor_move_cursor(c);
        },
       else => return true,
    }
    return true;
}

pub fn editor_refresh_screen(alloc: std.mem.Allocator) void {
    tui.get_terminal_size(&E.screen_rows, &E.screen_cols);
    var buffer = std.ArrayList(u8).initCapacity(alloc, E.screen_cols*E.screen_rows) catch  
        return die("editor_draw_rows");
    // defer buffer.clearAndFree(alloc);
    defer buffer.deinit(alloc);
    // tui.clr_screen();
    buffer.appendSlice(alloc, "\x1b[?25l") catch die("editor_refresh_screen");
    buffer.appendSlice(alloc, "\x1b[1;1H") catch die("editor_refresh_screen");
    // buffer.appendSlice(alloc, "\x1b[3J") catch die("editor_refresh_screen");
    editor_draw_rows(&buffer, alloc);
    // buffer.appendSlice(alloc, "\x1b[H") catch die("editor_refresh_screen");
    const s = std.fmt.allocPrint(alloc, "\x1b[{d};{d}H", .{E.cy+1, E.cx+1}) catch blk: {
        die("editor_refresh_screen");
        break :blk "unreachable";
    };
    defer alloc.free(s);
    buffer.appendSlice(alloc, s) catch die("editor_refresh_screen");
    buffer.appendSlice(alloc, "\x1b[?25h") catch die("editor_refresh_screen");
    _ = libc.write(libc.STDOUT_FILENO, buffer.items.ptr, buffer.items.len);
}

pub fn editor_draw_rows(buffer:*std.ArrayList(u8), alloc:std.mem.Allocator) void {
    for (0..E.screen_rows) |y| {
        if (y == E.screen_rows/3) {
            const welcome_str = std.fmt.allocPrint(alloc, "Kilo editor -- version {s}", .{KILO_VERSION}) 
                catch "Kilo editor";
            defer alloc.free(welcome_str);
            buffer.appendSlice(alloc, welcome_str) catch die("editor_draw_rows");
        } else {
            buffer.appendSlice(alloc, "~\x1b[K") catch die("editor_draw_rows");
            // _ = libc.write(libc.STDOUT_FILENO, "~", 1);
        }
        if(y < E.screen_rows - 1) {
        buffer.appendSlice(alloc, "\r\n") catch die("editor_draw_rows");
        }
    }
    buffer.appendSlice(alloc, "\x1b[4;5H") catch die("editor_refresh_screen");
    // _ = libc.write(libc.STDOUT_FILENO, buffer.items.ptr, buffer.items.len);
}

pub fn init_editor() void {
    tui.get_terminal_size(&E.screen_rows, &E.screen_cols);
    E.cx = 0;
    E.cy = 0;
}

pub fn run(init: std.process.Init) !void { 
    try tui.enable_raw_mode();
    defer tui.disable_raw_mode() catch {};
    init_editor();

    var is_running:bool = true;
    while (is_running) {
        editor_refresh_screen(init.gpa);
        // tui.get_terminal_size(&rows, &cols);
        // std.debug.print("rows:{d}, cols:{d}", .{E.screen_rows,E.screen_cols});
        is_running = editor_process_key_press();
    }
}
