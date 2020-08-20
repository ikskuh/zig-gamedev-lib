/// provides a NetBMP loader
pub const netbpm = @import("netbpm.zig");

/// provides a PCX loader
pub const pcx = @import("pcx.zig");

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
