#include <cstdint>
#include <format>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <stdexcept>
#include <aux.hpp>

namespace aux_img {
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

cv::Mat fromSharedMat(SharedMat sharedMat) {
	auto format = opencv_format_from_pixel_format(sharedMat.pixel_format, sharedMat.depth);
	return cv::Mat(sharedMat.rows, sharedMat.cols, format, sharedMat.data);
}
}

extern "C" {
void aux_img_write_text(aux_img::SharedMat mat, const char *text, aux_img::Vec2i pos, aux_img::Vec3i color, float scale, float thickness, bool bottomLeftOrigin) {
	cv::Mat cv_mat = aux_img::fromSharedMat(mat);
	auto cv_org    = cv::Point(pos.x, pos.y);
	auto cv_color  = cv::Scalar(color.x, color.y, color.z);
	cv::putText(cv_mat, text, cv_org, cv::FONT_HERSHEY_SIMPLEX, scale, cv_color, thickness, cv::LINE_8, bottomLeftOrigin);
}
}
