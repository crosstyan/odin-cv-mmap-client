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
	put_text_impl :: proc(mat: SharedMat, text: cstring, pos: Vec2i, color: Vec3d, scale: c.double, thickness: c.int, bottomLeftOrigin: bool) ---
	rectangle_impl :: proc(mat: SharedMat, pt1: Vec2i, pt2: Vec2i, color: Vec3d, thickness: c.int) ---
	draw_whole_body_skeleton_impl :: proc(mat: SharedMat, data: [^]c.float, options: DrawSkeletonOptions) ---
}

NUM_KEYPOINTS :: 133
NUM_KEYPOINTS_PAIR :: 2 * NUM_KEYPOINTS

draw_whole_body_skeleton :: #force_inline proc(
	mat: SharedMat,
	keypoints: []f32,
	options: DrawSkeletonOptions,
) {
	assert(len(keypoints) == NUM_KEYPOINTS_PAIR, "keypoints must have 2 * NUM_KEYPOINTS elements")
	draw_whole_body_skeleton_impl(mat, raw_data(keypoints), options)
}

put_text :: #force_inline proc(
	mat: SharedMat,
	text: cstring,
	pos: [2]c.int,
	color: [3]c.double = {0, 0, 0},
	scale: c.double = 1.0,
	thickness: c.int = 1,
	bottomLeftOrigin: bool = false,
) {
	put_text_impl(
		mat,
		text,
		Vec2i{pos[0], pos[1]},
		Vec3d{c.double(color[0]), c.double(color[1]), c.double(color[2])},
		scale,
		thickness,
		bottomLeftOrigin,
	)
}

rectangle :: #force_inline proc(
	mat: SharedMat,
	pt1: [2]c.int,
	pt2: [2]c.int,
	color: [3]c.double = {0, 0, 0},
	thickness: c.int = 1,
) {
	rectangle_impl(
		mat,
		Vec2i{pt1[0], pt1[1]},
		Vec2i{pt2[0], pt2[1]},
		Vec3d{c.double(color[0]), c.double(color[1]), c.double(color[2])},
		thickness,
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

Vec3d :: struct {
	x: c.double,
	y: c.double,
	z: c.double,
}

Layout :: enum u8 {
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
