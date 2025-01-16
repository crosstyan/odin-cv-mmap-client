package auximg
import "core:c"

foreign import stdcpp "system:c++"
foreign import opencv_core "system:opencv_core"
foreign import opencv_imgproc "system:opencv_imgproc"

// only consider Linux for now
foreign import auximg "libauximg.so"
@(link_prefix = "aux_img_", default_calling_convention = "c")
foreign auximg {
	write_text :: proc(mat: SharedMat, msg: cstring, pos: Vec2i, color: Vec3i, thickness: c.float) ---
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
