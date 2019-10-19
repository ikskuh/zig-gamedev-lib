/// provides linear algebra with focus on game dev.
pub const math3d = @import("math3d.zig");


/// provides a NetBMP loader
pub const netbpm = @import("netbpm.zig");

/// this works around bugs in the zig compiler
pub usingnamespace if (@import("builtin").is_test)
    struct {}
else
    struct {
        pub const wavefrontObj = @import("wavefront-obj.zig");
        pub const gles2 = @import("gles2.zig");
        pub const dynlib = @import("dynlib.zig");
    };

/// provides functions and types to work with colors
pub const color = @import("color.zig");

/// provides some useful math functions
pub const math = @import("math.zig");

comptime {
    @import("std").meta.refAllDecls(@This());
}
