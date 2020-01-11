const std = @import("std");

/// rgb color tuple with 8 bit color values.
pub const RGB = packed struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Header = packed struct {
    id: u8 = 0x0A,
    version: u8,
    compression: u8,
    bpp: u8,
    xmin: u16,
    ymin: u16,
    xmax: u16,
    ymax: u16,
    horizontalDPI: u16,
    verticalDPI: u16,
    builtinPalette: [16 * 3]u8,
    _reserved0: u8 = 0,
    planes: u8,
    stride: u16,
    paletteInformation: u16,
    screenWidth: u16,
    screenHeight: u16,

    var padding: [54]u8 = undefined;

    comptime {
        std.debug.assert(@sizeOf(@This()) == 74);
    }
};

fn SubImage(comptime Pixel: type) type {
    return struct {
        const Self = @This();

        allocator: *std.mem.Allocator,
        pixels: []Pixel,
        width: usize,
        height: usize,
        palette: ?*[256]RGB,

        pub fn initLinear(allocator: *std.mem.Allocator, header: Header, file: *std.fs.File, stream: *std.fs.File.InStream.Stream) !Self {
            const width = @as(usize, header.xmax - header.xmin);
            const height = @as(usize, header.ymax - header.ymin);

            var img = Self{
                .allocator = allocator,
                .pixels = try allocator.alloc(Pixel, width * height),
                .width = width,
                .height = height,
                .palette = null,
            };
            errdefer img.deinit();

            var decoder = RLEDecoder.init(stream);

            var y: usize = 0;
            while (y < img.height) : (y += 1) {
                var offset: usize = 0;
                var x: usize = 0;

                // read all pixels from the current row
                while (offset < header.stride and x < img.width) : (offset += 1) {
                    const byte = try decoder.readByte();
                    switch (Pixel) {
                        u1 => {},
                        u4 => {},
                        u8 => {
                            img.pixels[y * img.width + x] = byte;
                            x += 1;
                        },
                        RGB => {},
                        else => @compileError(@typeName(Pixel) ++ " not supported yet!"),
                    }
                }

                // discard the rest of the bytes in the current row
                while (offset < header.stride) : (offset += 1) {
                    _ = try decoder.readByte();
                }
            }

            try decoder.finish();

            if (Pixel != RGB) {
                try file.seekFromEnd(-769);

                if ((try stream.readByte()) != 0x0C)
                    return error.MissingPalette;

                var pal = try allocator.create([256]RGB);
                errdefer allocator.destroy(pal);

                for (pal) |*c| {
                    c.r = try stream.readByte();
                    c.g = try stream.readByte();
                    c.b = try stream.readByte();
                }

                img.palette = pal;
            }

            return img;
        }

        pub fn deinit(self: Self) void {
            if (self.palette) |pal| {
                self.allocator.destroy(pal);
            }
            self.allocator.free(self.pixels);
        }
    };
}

pub const Format = enum {
    bpp1,
    bpp4,
    bpp8,
    bpp24,
};

pub const Image = union(Format) {
    bpp1: SubImage(u1),
    bpp4: SubImage(u4),
    bpp8: SubImage(u8),
    bpp24: SubImage(RGB),

    pub fn deinit(image: Image) void {
        switch (image) {
            .bpp1 => |img| img.deinit(),
            .bpp4 => |img| img.deinit(),
            .bpp8 => |img| img.deinit(),
            .bpp24 => |img| img.deinit(),
        }
    }
};

pub fn load(allocator: *std.mem.Allocator, file: *std.fs.File) !Image {
    var inStream = &file.inStream();
    const stream = &inStream.stream;

    var header: Header = undefined;
    try stream.readNoEof(std.mem.asBytes(&header));
    try stream.readNoEof(&Header.padding);

    if (header.id != 0x0A)
        return error.InvalidFileFormat;

    if (header.planes != 1)
        return error.UnsupportedFormat;

    std.debug.warn("{}\n", .{header});

    var img: Image = undefined;
    switch (header.bpp) {
        1 => img = Image{
            .bpp1 = try SubImage(u1).initLinear(allocator, header, file, stream),
        },
        4 => img = Image{
            .bpp4 = try SubImage(u4).initLinear(allocator, header, file, stream),
        },
        8 => img = Image{
            .bpp8 = try SubImage(u8).initLinear(allocator, header, file, stream),
        },
        24 => img = Image{
            .bpp24 = try SubImage(RGB).initLinear(allocator, header, file, stream),
        },
        else => return error.UnsupportedFormat,
    }
    return img;
}

const RLEDecoder = struct {
    const Run = struct {
        value: u8,
        remaining: usize,
    };

    stream: *std.fs.File.InStream.Stream,
    currentRun: ?Run,

    fn init(stream: *std.fs.File.InStream.Stream) RLEDecoder {
        return RLEDecoder{
            .stream = stream,
            .currentRun = null,
        };
    }

    fn readByte(self: *RLEDecoder) !u8 {
        if (self.currentRun) |*run| {
            var result = run.value;
            run.remaining -= 1;
            if (run.remaining == 0)
                self.currentRun = null;
            return result;
        } else {
            while (true) {
                var byte = try self.stream.readByte();
                if (byte == 0xC0) // skip over "zero length runs"
                    continue;
                if ((byte & 0xC0) == 0xC0) {
                    const len = byte & 0x3F;
                    std.debug.assert(len > 0);
                    const result = try self.stream.readByte();
                    if (len > 1) {
                        // we only need to store a run in the decoder if it is longer than 1
                        self.currentRun = .{
                            .value = result,
                            .remaining = len - 1,
                        };
                    }
                    return result;
                } else {
                    return byte;
                }
            }
        }
    }

    fn finish(decoder: RLEDecoder) !void {
        if (decoder.currentRun != null)
            return error.RLEStreamIncomplete;
    }
};
