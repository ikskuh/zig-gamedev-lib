const std = @import("std");

pub const Color = struct {
    pub const Self = @This();

    red: f32,
    green: f32,
    blue: f32,

    pub fn rgb(r: f32, g: f32, b: f32) Self {
        return Color{
            .red = r,
            .green = g,
            .blue = b,
        };
    }

    pub fn parse(comptime spec: []const u8) Color {
        return switch (spec.len) {
            3 => {
                return Color{
                    .red = f32(std.fmt.parseInt(u8, spec[0..1], 16) catch unreachable) / 15.0,
                    .green = f32(std.fmt.parseInt(u8, spec[1..2], 16) catch unreachable) / 15.0,
                    .blue = f32(std.fmt.parseInt(u8, spec[2..3], 16) catch unreachable) / 15.0,
                };
            },
            4 => {
                if (spec[0] != '#')
                    @compileError("unsupported color literal!");
                return parse(spec[1..]);
            },
            6 => {
                return Color{
                    .red = f32(std.fmt.parseInt(u8, spec[0..2], 16) catch unreachable) / 255.0,
                    .green = f32(std.fmt.parseInt(u8, spec[2..4], 16) catch unreachable) / 255.0,
                    .blue = f32(std.fmt.parseInt(u8, spec[4..6], 16) catch unreachable) / 255.0,
                };
            },
            7 => {
                if (spec[0] != '#')
                    @compileError("unsupported color literal!");
                return parse(spec[1..]);
            },
            else => @compileError("unsupported color literal!"),
        };
    }
};


comptime {
    @import("std").meta.refAllDecls(@This());
}