const std = @import("std");

comptime {
    @import("std").meta.refAllDecls(@This());
}

// this file implements the Portable Anymap specification provided by
// http://netpbm.sourceforge.net/doc/pbm.html // P1, P4 => Bitmap
// http://netpbm.sourceforge.net/doc/pgm.html // P2, P5 => Graymap
// http://netpbm.sourceforge.net/doc/ppm.html // P3, P6 => Pixmap

/// one of the three types a netbpm graphic could be stored in.
pub const Format = enum {
    /// the image contains black-and-white pixels.
    bitmap,

    /// the image contains grayscale pixels.
    grayscale,

    /// the image contains RGB pixels.
    rgb,
};

/// RGB pixel value.
pub const Color = extern struct {
    pub r: u8,
    pub g: u8,
    pub b: u8,
};

/// Generic image datatype that contains pixels of type `T`.
pub fn AnymapData(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: *std.mem.Allocator,
        pixels: []T,

        /// width of the image in pixels.
        pub width: usize,

        /// height of the image in pixels.
        pub height: usize,

        /// releases the memory held by this instance.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.pixels);
        }

        /// tries to get a pixel from the image.
        pub fn get(self: Self, x: usize, y: usize) !T {
            if (x >= self.width or y >= self.height)
                return error.OutOfBounds;
            return self.pixels[y * self.width + x];
        }

        /// tries to set a pixel in the image.
        pub fn set(self: *Self, x: usize, y: usize, value: T) !void {
            if (x >= self.width or y >= self.height)
                return error.OutOfBounds;
            self.pixels[y * self.width + x] = value;
        }
    };
}

/// A decoded anymap. Contains either a black-and-white, grayscale or RGB image.
pub const Anymap = union(Format) {
    const Self = @This();
    bitmap: AnymapData(u1),
    grayscale: AnymapData(u8),
    rgb: AnymapData(Color),

    /// releases the data held by the contents of this image.
    pub fn deinit(self: Self) void {
        switch (self) {
            .bitmap => |bmp| bmp.deinit(),
            .grayscale => |bmp| bmp.deinit(),
            .rgb => |bmp| bmp.deinit(),
        }
    }

    /// returns the width of the contained image.
    pub fn getWidth(self: Self) usize {
        return switch (self) {
            .bitmap => |a| a.width,
            .grayscale => |a| a.width,
            .rgb => |a| a.width,
        };
    }

    /// returns the height of the contained image.
    pub fn getHeight(self: Self) usize {
        return switch (self) {
            .bitmap => |a| a.height,
            .grayscale => |a| a.height,
            .rgb => |a| a.height,
        };
    }
};

const Header = struct {
    format: Format,
    binary: bool,
    width: usize,
    height: usize,
    maxValue: usize,
};

fn isWhitespace(b: u8) bool {
    return switch (b) {
        // Whitespace (blanks, TABs, CRs, LFs).
        '\n', '\r', ' ', '\t' => true,
        else => false,
    };
}

fn readNextByte(stream: *std.io.InStream(std.fs.File.ReadError)) !u8 {
    while (true) {
        var b = try stream.readByte();
        switch (b) {
            // Before the whitespace character that delimits the raster, any characters
            // from a "#" through the next carriage return or newline character, is a
            // comment and is ignored. Note that this is rather unconventional, because
            // a comment can actually be in the middle of what you might consider a token.
            // Note also that this means if you have a comment right before the raster,
            // the newline at the end of the comment is not sufficient to delimit the raster.
            '#' => {
                // eat up comment
                while (true) {
                    var c = try stream.readByte();
                    switch (c) {
                        '\r', '\n' => break,
                        else => {},
                    }
                }
            },
            else => return b,
        }
    }
}

/// skips whitespace and comments, then reads a number from the stream.
/// this function reads one whitespace behind the number as a terminator.
fn parseNumber(stream: *std.io.InStream(std.fs.File.ReadError), buffer: []u8) !usize {
    var inputLength: usize = 0;
    while (true) {
        var b = try readNextByte(stream);
        if (isWhitespace(b)) {
            if (inputLength > 0) {
                return try std.fmt.parseInt(usize, buffer[0..inputLength], 10);
            } else {
                continue;
            }
        } else {
            if (inputLength >= buffer.len)
                return error.OutOfMemory;
            buffer[inputLength] = b;
            inputLength += 1;
        }
    }
}

fn parseHeader(allocator: *std.mem.Allocator, stream: *std.io.InStream(std.fs.File.ReadError)) !Header {
    var hdr: Header = undefined;

    var magic: [2]u8 = undefined;
    try stream.readNoEof(magic[0..]);

    if (std.mem.eql(u8, magic, "P1")) {
        hdr.binary = false;
        hdr.format = .bitmap;
        hdr.maxValue = 1;
    } else if (std.mem.eql(u8, magic, "P2")) {
        hdr.binary = false;
        hdr.format = .grayscale;
    } else if (std.mem.eql(u8, magic, "P3")) {
        hdr.binary = false;
        hdr.format = .rgb;
    } else if (std.mem.eql(u8, magic, "P4")) {
        hdr.binary = true;
        hdr.format = .bitmap;
        hdr.maxValue = 1;
    } else if (std.mem.eql(u8, magic, "P5")) {
        hdr.binary = true;
        hdr.format = .grayscale;
    } else if (std.mem.eql(u8, magic, "P6")) {
        hdr.binary = true;
        hdr.format = .rgb;
    } else {
        return error.InvalidFormat;
    }

    var readBuffer: [16]u8 = undefined;

    hdr.width = try parseNumber(stream, readBuffer[0..]);
    hdr.height = try parseNumber(stream, readBuffer[0..]);
    if (hdr.format != .bitmap) {
        hdr.maxValue = try parseNumber(stream, readBuffer[0..]);
    }

    return hdr;
}

fn loadBinaryBitmap(data: *AnymapData(u1), stream: *std.io.InStream(std.fs.File.ReadError)) !void {
    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) {
            var b = try stream.readByte();

            var i: usize = 0;
            while (x < data.width and i < 8) {
                // set bit is black, cleared bit is white
                // bits are "left to right" (so msb to lsb)
                try data.set(x, y, if ((b & (u8(1) << @truncate(u3, 7 - i))) != 0) u1(0) else u1(1));

                x += 1;
                i += 1;
            }
        }
    }
}

fn loadAsciiBitmap(data: *AnymapData(u1), stream: *std.io.InStream(std.fs.File.ReadError)) !void {
    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) {
            var b = try stream.readByte();
            if (isWhitespace(b)) {
                continue;
            }
            // 1 is black, 0 is white in PBM spec.
            // we use 1=white, 0=black in u1 format
            try data.set(x, y, if (b == '0') u1(1) else u1(0));
            x += 1;
        }
    }
}

fn readLinearizedValue(stream: *std.io.InStream(std.fs.File.ReadError), maxValue: usize) !u8 {
    return if (maxValue > 255)
        @truncate(u8, 255 * usize(try stream.readIntBig(u16)) / maxValue)
    else
        @truncate(u8, 255 * usize(try stream.readByte()) / maxValue);
}

fn loadBinaryGraymap(data: *AnymapData(u8), stream: *std.io.InStream(std.fs.File.ReadError), maxValue: usize) !void {
    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) : (x += 1) {
            try data.set(x, y, try readLinearizedValue(stream, maxValue));
        }
    }
}

fn loadAsciiGraymap(data: *AnymapData(u8), stream: *std.io.InStream(std.fs.File.ReadError), maxValue: usize) !void {
    var readBuffer: [16]u8 = undefined;

    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) : (x += 1) {
            var b = try parseNumber(stream, readBuffer[0..]);

            try data.set(x, y, @truncate(u8, 255 * b / maxValue));
        }
    }
}

fn loadBinaryRgbmap(data: *AnymapData(Color), stream: *std.io.InStream(std.fs.File.ReadError), maxValue: usize) !void {
    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) : (x += 1) {
            var r = try readLinearizedValue(stream, maxValue);
            var g = try readLinearizedValue(stream, maxValue);
            var b = try readLinearizedValue(stream, maxValue);
            try data.set(x, y, Color{
                .r = r,
                .g = g,
                .b = b,
            });
        }
    }
}

fn loadAsciiRgbmap(data: *AnymapData(Color), stream: *std.io.InStream(std.fs.File.ReadError), maxValue: usize) !void {
    var readBuffer: [16]u8 = undefined;

    var y: usize = 0;
    while (y < data.height) : (y += 1) {
        var x: usize = 0;
        while (x < data.width) : (x += 1) {
            var r = try parseNumber(stream, readBuffer[0..]);
            var g = try parseNumber(stream, readBuffer[0..]);
            var b = try parseNumber(stream, readBuffer[0..]);

            try data.set(x, y, Color{
                .r = @truncate(u8, 255 * r / maxValue),
                .g = @truncate(u8, 255 * g / maxValue),
                .b = @truncate(u8, 255 * b / maxValue),
            });
        }
    }
}

/// Loads a netbpm image from the given file path.
/// Allocates required memory by the given allocator.
pub fn load(allocator: *std.mem.Allocator, path: []const u8) !Anymap {
    var file = try std.fs.File.openRead(path);
    defer file.close();

    var stream = file.inStream();

    var header = try parseHeader(allocator, &stream.stream);

    std.debug.warn("parsed: {}\n", header);

    switch (header.format) {
        .bitmap => {
            var data = AnymapData(u1){
                .allocator = allocator,
                .pixels = try allocator.alloc(u1, header.width * header.height),
                .width = header.width,
                .height = header.height,
            };

            if (header.binary) {
                try loadBinaryBitmap(&data, &stream.stream);
            } else {
                try loadAsciiBitmap(&data, &stream.stream);
            }

            return Anymap{
                .bitmap = data,
            };
        },

        .grayscale => {
            var data = AnymapData(u8){
                .allocator = allocator,
                .pixels = try allocator.alloc(u8, header.width * header.height),
                .width = header.width,
                .height = header.height,
            };

            if (header.binary) {
                try loadBinaryGraymap(&data, &stream.stream, header.maxValue);
            } else {
                try loadAsciiGraymap(&data, &stream.stream, header.maxValue);
            }

            return Anymap{
                .grayscale = data,
            };
        },

        .rgb => {
            var data = AnymapData(Color){
                .allocator = allocator,
                .pixels = try allocator.alloc(Color, header.width * header.height),
                .width = header.width,
                .height = header.height,
            };

            if (header.binary) {
                try loadBinaryRgbmap(&data, &stream.stream, header.maxValue);
            } else {
                try loadAsciiRgbmap(&data, &stream.stream, header.maxValue);
            }

            return Anymap{
                .rgb = data,
            };
        },
    }
}
