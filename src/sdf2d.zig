const std = @import("std");

usingnamespace @import("zlm");

// this file implements 2D signed distance functions (SDFs)
// more info:
// https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm

// returns the intersection of both distances
pub fn intersect(comptime T: type, a: T, b: T) T {
    return std.math.max(T, a, b);
}

// returns the union of both distances
pub fn @"union"(comptime T: type, a: T, b: T) T {
    return std.math.min(T, a, b);
}

// subtracts one distance from the other.
pub fn subtract(comptime T: type, a: T, b: T) T {
    return std.math.max(T, -a, b);
}

// adds a `radius` sized bevel to the shape.
pub fn makeRound(comptime T: type, shape: T, radius: T) T {
    return shape - radius;
}

// makes the shape a `radius` thick "ring".
pub fn makeAnnular(comptime T: type, shape: T, radius: T) T {
    return std.math.fabs(T, shape) - radius;
}

pub fn sdCircle(p: vec2, r: f32) f32 {
    return length(p) - r;
}

pub fn sdLine(p: Vec2, a: Vec2, b: Vec2) f32 {
    const pa = p.sub(a);
    const ba = b.sub(a);
    var h = std.math.clamp(pa.dot(ba) / ba.dot(ba), 0.0, 1.0);
    return pa.sub(ba.scale(h)).length();
}
