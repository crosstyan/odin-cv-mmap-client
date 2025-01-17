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
}


extern "C" {
void aux_img_write_text(aux_img::SharedMat mat,
						const char *text,
						aux_img::Vec2i pos,
						aux_img::Vec3i color,
						float scale,
						float thickness,
						bool bottomLeftOrigin);
}
