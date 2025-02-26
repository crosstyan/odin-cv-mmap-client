#pragma once

#include <cstdint>
#include <opencv2/core.hpp>

namespace aux_img {
/// @note use with `pixel_format` field in `frame_info_t`
enum class PixelFormat : uint8_t {
	/// usually 24bit RGB (8bit per channel, depth=U8)
	RGB = 0,
	BGR,
	RGBA,
	BGRA,
	/// channel=1
	GRAY,
	YUV,
	YUYV,
};

/// @note use with `depth` field in `frame_info_t`
enum class Depth : uint8_t {
	U8  = CV_8U,
	S8  = CV_8S,
	U16 = CV_16U,
	S16 = CV_16S,
	S32 = CV_32S,
	F32 = CV_32F,
	F64 = CV_64F,
	F16 = CV_16F,
};

// assuming step = cols * channels
// no curious step values/padding
struct SharedMat {
	uint8_t *data;
	uint16_t rows;
	uint16_t cols;
	Depth depth;
	PixelFormat pixel_format;
};

struct Vec2f {
	float x;
	float y;
};
struct Vec2i {
	int x;
	int y;
};

struct Vec3i {
	int x;
	int y;
	int z;
};

struct Vec3d {
	double x;
	double y;
	double z;
};

const char *depth_to_string(const Depth depth);

const char *cv_depth_to_string(const int depth);

const char *pixel_format_to_string(const PixelFormat fmt);

int opencv_format_from_pixel_format(PixelFormat pixel_format, Depth depth);

// @sa: https://docs.opencv.org/4.x/d3/d63/classcv_1_1Mat.html#a5fafc033e089143062fd31015b5d0f40
//
// data: Pointer to the user data. Matrix constructors that take data and step
// parameters do not allocate matrix data. Instead, they just initialize the
// matrix header that points to the specified data, which means that no data is
// copied. This operation is very efficient and can be used to process external
// data using OpenCV functions. The external data is not automatically
// deallocated, so you should take care of it.
cv::Mat fromSharedMat(SharedMat sharedMat);

enum class Layout : uint8_t {
	RowMajor = 0,
	ColMajor,
};

struct DrawSkeletonOptions {
	Layout layout;
	bool is_draw_landmarks;
	bool is_draw_bones;
	int landmark_radius;
	int landmark_thickness;
	int bone_thickness;
};
}


extern "C" {
void aux_img_put_text_impl(aux_img::SharedMat mat,
						   const char *text,
						   aux_img::Vec2i pos,
						   aux_img::Vec3d color,
						   double scale,
						   int thickness,
						   bool bottomLeftOrigin);
// caller should check the length of data to be
// 133 * 2 * sizeof(float) = 1064 bytes
// expecting row-major order
// i.e. 133 keypoints, each with x and y coordinates
// [[x1, y1], [x2, y2], ..., [x133, y133]] in a flat array
//
// This function will trust the caller and not check the length,
// but take whatever is passed to it.
void aux_img_draw_whole_body_skeleton_impl(aux_img::SharedMat mat, const float *data, aux_img::DrawSkeletonOptions options);
void aux_img_rectangle_impl(aux_img::SharedMat mat, aux_img::Vec2i start, aux_img::Vec2i end, aux_img::Vec3d color, int thickness);
}
