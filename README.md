# xq's Zig Game Development Library

> **NOTE:**
> THIS PROJECT IS NOW ARCHIVED AS THE CODE IN IT SPLIT INTO SEVERAL OTHER PROJECTS.
> 

## Modules

- **math3d**: contains basic vector math for game development
- **wavefrontObj**: Load [Wavefront Object](https://en.wikipedia.org/wiki/Wavefront_.obj_file) 3d models
- **netbpm**: Load [Netbpm](https://en.wikipedia.org/wiki/Netpbm_format) images
- **gles2**: OpenGL ES 2.0 loader/binding

## Usage

**Make the module available as `xq3d`:**

```zig
pub fn build(b: *Builder) void {
    const exe = b.addExecutable(…);
	
	…
    exe.addPackagePath("xq3d", "…/zig-gamedev-lib/src/lib.zig");
	…
}
```

**Include the module:**

```zig
const xq3d = @import("xq3d");

```

## Documentation
Read the source. There is none at the moment.
