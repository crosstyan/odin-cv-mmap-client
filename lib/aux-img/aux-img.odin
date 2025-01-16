package auximg
import "core:c"

// only consider Linux for now
foreign import auximg "libauximg.a"
@(link_prefix = "aux_img_", default_calling_convention = "c")
foreign auximg {
    write_text(mat: SharedMat,msg: cstring, pos: Vec2i, color:Vec3i, thickness:c.float) -> void ---,
}

// same as OpenCV's definitions
Depth :: enum u8 {
	U8,
	S8,
	U16,
	S16,
	S32,
	F32,
	F64,
	F16,
}

PixelFormat :: enum u8 {
	RGB,
	BGR,
	RGBA,
	BGRA,
	GRAY,
	YUV,
	YUYV,
}

SharedMat :: struct {
    data:   rawptr,
    rows: u16,
    cols: u16,
    depth: Depth,
    pixel_format: PixelFormat,
}

Vec2i :: struct {
    x: c.int,
    y: c.int,
}

Vec2f :: struct {
    x: c.float,
    y: c.float,
}

Vec3i :: struct {
    x: c.int,
    y: c.int,
    z: c.int,
}
