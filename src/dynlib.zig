const std = @import("std");
const builtin = @import("builtin");
const utils = @import("utils.zig");

pub const Error = error{
    LibraryNotFound,
    EntryPointNotFound,
    OutOfMemory,
};

const impl = comptime switch (builtin.os) {
    .linux => struct {
        const Handle = *@OpaqueType();

        const RTLD_LAZY = 1;
        const RTLD_NOW = 2;

        extern "dl" fn dlopen(filename: [*c]const u8, flags: c_int) ?Handle;
        extern "dl" fn dlsym(handle: Handle, symbol: [*c]const u8) ?*c_void;
        extern "dl" fn dlclose(handle: Handle) c_int;
        extern "dl" fn dlerror() [*]u8;

        fn getEntryPoint(handle: Handle, name: []const u8) Error!?Symbol {
            var buffer = [_]u8{0} ** 512;
            var alloca = std.heap.FixedBufferAllocator.init(buffer[0..]);
            var zstr = try alloca.allocator.alloc(u8, name.len + 1);
            std.mem.copy(u8, zstr, name);
            zstr[name.len] = 0;
            return dlsym(handle, zstr.ptr);
        }

        fn loadLibrary(name: []const u8) Error!Handle {
            var buffer = [_]u8{0} ** 512;
            var alloca = std.heap.FixedBufferAllocator.init(buffer[0..]);
            var zstr = try alloca.allocator.alloc(u8, name.len + 1);
            std.mem.copy(u8, zstr, name);
            zstr[name.len] = 0;
            return dlopen(zstr.ptr, RTLD_LAZY) orelse return Error.LibraryNotFound;
        }

        fn close(h: Handle) void {
            if (dlclose(h) != 0)
                std.debug.panic("Failed to close library: {}\n", utils.cstringToSlice(dlerror()));
        }
    },
    .windows => struct {},
    else => @compileError("OS not supported for shared-object!"),
};

pub const LibraryHandle = struct {
    const Self = @This();

    handle: impl.Handle,

    pub fn getEntryPoint(self: Self, name: []const u8) Error!Symbol {
        return impl.getEntryPoint(self.handle, name);
    }

    pub fn close(self: Self) void {
        impl.close(self.handle);
    }
};

pub const Symbol = *c_void;

pub fn loadLibrary(name: []const u8) Error!LibraryHandle {
    return LibraryHandle{
        .handle = try impl.loadLibrary(name),
    };
}


comptime {
    @import("std").meta.refAllDecls(@This());
}