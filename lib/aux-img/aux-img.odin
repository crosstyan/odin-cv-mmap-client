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
	put_text_impl :: proc(mat: SharedMat, text: cstring, pos: Vec2i, color: Vec3i = Vec3i{0, 0, 0}, scale: c.float = 1.0, thickness: c.float = 1.0, bottomLeftOrigin: bool = false) ---
	rectangle_impl :: proc(mat: SharedMat, pos1: Vec2i, pos2: Vec2i, color: Vec3i = Vec3i{0, 0, 0}, thickness: c.int = 1) ---
	draw_whole_body_skeleton_impl :: proc(mat: SharedMat, data: rawptr, options: DrawSkeletonOptions) ---
}

put_text :: #force_inline proc(
	mat: SharedMat,
	text: cstring,
	pos: [2]i32,
	color: [3]f32 = {0, 0, 0},
	scale: f32 = 1.0,
	thickness: f32 = 1.0,
	bottomLeftOrigin: bool = false,
) {
	put_text_impl(
		mat,
		text,
		Vec2i{pos[0], pos[1]},
		Vec3i{c.int(color[0]), c.int(color[1]), c.int(color[2])},
		scale,
		thickness,
		bottomLeftOrigin,
	)
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


Layout :: enum {
	RowMajor = 0,
	ColMajor = 1,
}

DrawSkeletonOptions :: struct {
	layout:             Layout,
	is_draw_landmarks:  bool,
	is_draw_bones:      bool,
	landmark_radius:    c.int,
	landmark_thickness: c.int,
	bone_thickness:     c.int,
}
