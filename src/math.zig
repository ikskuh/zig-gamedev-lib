const std = @import("std");

pub fn toRadians(deg: var) @typeOf(deg) {
    return std.math.pi * deg / 180.0;
}

pub fn toDegrees(rad: var) @typeOf(deg) {
    return 180.0 * rad / std.math.pi;
}


comptime {
    @import("std").meta.refAllDecls(@This());
}