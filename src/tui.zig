const std = @import("std");
const posix = std.posix;
const libc = std.c;
var orig:posix.termios = undefined;

const VTIME = 5;
const VMIN = 6;

pub const Key = enum(u8) {
    Null = 0,
    SOH,
    STX,
    ETX,
    EOT,
    ENQ,
    ACK,
    BEL,
    BS,
    HT,
    LF,
    VT,
    FF,
    CR,
    SO,
    SI,
    DLE,
    DC1,
    DC2,
    DC3,
    DC4,
    NAK,
    SYN,
    ETB,
    CAN,
    EM,
    SUB,
    ESC,
    FS,
    GS,
    RS,
    US,
    Space,
    ExlamationMark,
    DoubleQuote,
    Hash,
    Dollar,
    Percent,
    Ampersand,
    SingleQuote,
    LParen,
    RParen,
    Asterisk,
    Plus,
    Comma,
    Hyphen,
    Period,
    Slash,
    Zero,
    One,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Colon,
    Semicolon,
    Lessthan,
    Equal,
    Greaterthan,
    Questionmark,
    At,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    LBracket,
    Backslash,
    RBracket,
    Caret,
    Underscore,
    GraveAccent,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    LBrace,
    Bar,
    RBrace,
    Tilde,
    Delete, // TODO: is not captured
    ARROW_LEFT,
    ARROW_RIGHT,
    ARROW_UP,
    ARROW_DOWN,
    PageUp,
    PageDown,
    Home,
    End,
};


fn die(err_msg:[]const u8) void {
    disable_raw_mode() catch {};
    @panic(err_msg);
}

/// Set the terminal into RAW mode
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
    // _ = libc.write(libc.STDOUT_FILENO, "\x1b[?1049h", 7);
}

/// Restore the original setting of the terminal
pub fn disable_raw_mode() !void {
    try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, orig);
    // _ = libc.write(libc.STDOUT_FILENO, "\x1b[?1049l", 7);
}

pub fn clr_screen() void {
    _ = libc.write(libc.STDOUT_FILENO, "\x1b[2J", 4);
    // _ = libc.write(libc.STDOUT_FILENO, "\x1b[H", 3);
    curs_mv(1, 1);
}

pub fn curs_mv(rows:u32, cols:u32) void {
    var buffer:[20]u8 = undefined;
    const str = std.fmt.bufPrint(&buffer, "\x1b[{d};{d}H", .{rows, cols}) catch "\x1b[H";
    _ = libc.write(libc.STDOUT_FILENO, str.ptr, str.len);
}

pub fn get_terminal_size(rows:*u32, cols:*u32) void {
    var ws:libc.winsize = undefined;
   
    // We don't do the ansi escape sequence as a back up method
    if (libc.ioctl(libc.STDOUT_FILENO, libc.T.IOCGWINSZ, &ws) == -1)  die("get_terminal_size");
    cols.* = ws.col;
    rows.* = ws.row;
}

pub fn curs_hide() void {
    _ = libc.write(libc.STDOUT_FILENO, "\x1b[?25l", 6);
}

pub fn curs_show() void {
    _ = libc.write(libc.STDOUT_FILENO, "\x1b[?25h", 6);
}

pub fn read_key_wait() Key{
    var nread:usize = 0;
    var c:[1]u8 = undefined;
    while (nread != 1){
        nread = posix.read(posix.STDIN_FILENO, &c) catch blk: {
            die("read_key_wait");
            break :blk 0;
        };
    }
    return @enumFromInt(c[0]);
}

pub fn read_key() Key {
    var c:[1]u8 = undefined;
    _ = posix.read(posix.STDIN_FILENO, &c) catch blk:{
        die("Error read_key");
        break :blk 0;
    };
    return @enumFromInt(c[0]);
}

pub inline fn ctrl_key(k:u8) Key {
    return @enumFromInt(k & 0x1f);
}
pub inline fn shift_key(k:u8) Key {
    _ = k;
    return Key.ACK;
}

