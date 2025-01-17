package auximg
import "core:c"
import "core:strings"

foreign import stdcpp "system:c++"
foreign import opencv_core "system:opencv_core"
foreign import opencv_imgproc "system:opencv_imgproc"

// only consider Linux for now
foreign import auximg "libauximg.so"
@(link_prefix = "aux_img_", default_calling_convention = "c")
foreign auximg {
	// @param bottomLeftOrigin When true, the image data origin is at the bottom-left corner. Otherwise, it is at the top-left corner
	put_text :: proc(mat: SharedMat, text: cstring, pos: Vec2i, color: Vec3i = Vec3i{0, 0, 0}, scale: c.float = 1.0, thickness: c.float = 1.0, bottomLeftOrigin: bool = false) ---
}

mat_put_text :: proc(
	mat: SharedMat,
	text: cstring,
	pos: [2]i32,
	color: [3]f32 = {0, 0, 0},
	scale: f32 = 1.0,
	thickness: f32 = 1.0,
	bottomLeftOrigin: bool = false,
) {
	pos_ := Vec2i{pos[0], pos[1]}
	color_ := Vec3i{c.int(color[0]), c.int(color[1]), c.int(color[2])}
	put_text(mat, text, pos_, color_, scale, thickness, bottomLeftOrigin)
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
	data:         rawptr,
	rows:         u16,
	cols:         u16,
	depth:        Depth,
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
