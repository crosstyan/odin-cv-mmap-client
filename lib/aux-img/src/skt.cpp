#include <cstdint>
#include <format>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <stdexcept>

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

const char *depth_to_string(const Depth depth) {
	switch (depth) {
	case Depth::U8:
		return "U8";
	case Depth::S8:
		return "S8";
	case Depth::U16:
		return "U16";
	case Depth::S16:
		return "S16";
	case Depth::F16:
		return "F16";
	case Depth::S32:
		return "S32";
	case Depth::F32:
		return "F32";
	case Depth::F64:
		return "F64";
	default:
		return "unknown";
	}
}

const char *cv_depth_to_string(const int depth) {
	return depth_to_string(static_cast<Depth>(depth));
}

const char *pixel_format_to_string(const PixelFormat fmt) {
	switch (fmt) {
	case PixelFormat::RGB:
		return "RGB";
	case PixelFormat::BGR:
		return "BGR";
	case PixelFormat::RGBA:
		return "RGBA";
	case PixelFormat::BGRA:
		return "BGRA";
	case PixelFormat::GRAY:
		return "GRAY";
	case PixelFormat::YUV:
		return "YUV";
	case PixelFormat::YUYV:
		return "YUYV";
	default:
		return "unknown";
	}
}

int opencv_format_from_pixel_format(PixelFormat pixel_format, Depth depth) {
	if (pixel_format == PixelFormat::RGB || pixel_format == PixelFormat::BGR) {
		if (depth == Depth::U8) {
			return CV_8UC3;
		} else if (depth == Depth::U16) {
			return CV_16UC3;
		} else if (depth == Depth::F32) {
			return CV_32FC3;
		}
	} else if (pixel_format == PixelFormat::RGBA || pixel_format == PixelFormat::BGRA) {
		if (depth == Depth::U8) {
			return CV_8UC4;
		} else if (depth == Depth::U16) {
			return CV_16UC4;
		} else if (depth == Depth::F32) {
			return CV_32FC4;
		}
	} else if (pixel_format == PixelFormat::GRAY) {
		if (depth == Depth::U8) {
			return CV_8UC1;
		} else if (depth == Depth::U16) {
			return CV_16UC1;
		} else if (depth == Depth::F32) {
			return CV_32FC1;
		}
	}
	throw std::invalid_argument(std::format("Unsupported pixel format {}({}) "
											"and depth {}({})",
											pixel_format_to_string(pixel_format),
											static_cast<uint8_t>(pixel_format),
											depth_to_string(depth),
											static_cast<uint8_t>(depth)));
}

// @sa: https://docs.opencv.org/4.x/d3/d63/classcv_1_1Mat.html#a5fafc033e089143062fd31015b5d0f40
//
// data: Pointer to the user data. Matrix constructors that take data and step
// parameters do not allocate matrix data. Instead, they just initialize the
// matrix header that points to the specified data, which means that no data is
// copied. This operation is very efficient and can be used to process external
// data using OpenCV functions. The external data is not automatically
// deallocated, so you should take care of it.
cv::Mat fromSharedMat(SharedMat sharedMat) {
	auto format = opencv_format_from_pixel_format(sharedMat.pixel_format, sharedMat.depth);
	return cv::Mat(sharedMat.rows, sharedMat.cols, format, sharedMat.data);
}

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
}

extern "C" {
void im_skt_write_something(aux_img::SharedMat mat, const char *c_str_msg, aux_img::Vec2i pos, aux_img::Vec3i color, float thickness) {
	cv::Mat cv_mat = aux_img::fromSharedMat(mat);
	auto cv_org    = cv::Point(pos.x, pos.y);
	auto cv_color  = cv::Scalar(color.x, color.y, color.z);
	cv::putText(cv_mat, c_str_msg, cv_org, cv::FONT_HERSHEY_SIMPLEX, 1.0, cv_color, thickness);
}
}
