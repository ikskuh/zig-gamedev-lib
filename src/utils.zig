const std = @import("std");


comptime {
    @import("std").meta.refAllDecls(@This());
}

pub fn cstringToSlice(ptr: [*c]const u8) []const u8 {
    var len: usize = 0;
    while (ptr[len] != 0) {
        len += 1;
    }
    return ptr[0..len];
}