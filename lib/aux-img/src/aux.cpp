#include <cstdint>
#include <format>
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

// Get the number of channels from pixel format
int channels_from_pixel_format(PixelFormat pixel_format) {
	switch (pixel_format) {
	case PixelFormat::RGB:
	case PixelFormat::BGR:
	case PixelFormat::YUV:
		return 3;
	case PixelFormat::RGBA:
	case PixelFormat::BGRA:
		return 4;
	case PixelFormat::GRAY:
		return 1;
	case PixelFormat::YUYV:
		return 2;
	default:
		throw std::invalid_argument(std::format("Unsupported pixel format {}({})",
												pixel_format_to_string(pixel_format),
												static_cast<uint8_t>(pixel_format)));
	}
}

// Helper function to create a CImg view of SharedMat data
cimg_library::CImg<uint8_t> createCImgViewU8(SharedMat &mat) {
	// For simplicity, we'll only support U8 depth
	if (mat.depth != Depth::U8) {
		throw std::runtime_error(
			std::format("Unsupported depth {} for CImg. Only U8 is currently supported.",
						depth_to_string(mat.depth)));
	}

	int channels = channels_from_pixel_format(mat.pixel_format);

	// https://www.codefull.net/2014/11/cimg-does-not-store-pixels-in-the-interleaved-format/
	// Create CImg from interleaved data with shared memory
	// The key is to specify the parameters in the right order:
	// (data, channels, width, height, depth, is_shared)
	// This is how CImg expects interleaved RGB/BGR data
	auto img = cimg_library::CImg<uint8_t>(mat.data, channels, mat.cols, mat.rows, 1, true);

	img.permute_axes("yzcx");
	return img;
}

void prepareForInterleaved(cimg_library::CImg<uint8_t> &img) {
	img.permute_axes("cxyz");
}

void drawText(SharedMat &mat, const char *text, Vec2i pos, Vec3d color, double scale, int thickness, bool bottomLeftOrigin) {
	auto img = createCImgViewU8(mat);

	// Use color directly as passed in
	uint8_t col[3] = {
		static_cast<uint8_t>(color.x),
		static_cast<uint8_t>(color.y),
		static_cast<uint8_t>(color.z)};

	// Adjust position if using bottom-left origin
	int y_pos = pos.y;
	if (bottomLeftOrigin) {
		y_pos = mat.rows - pos.y;
	}

	//  Approximate conversion: Scale factor for font size
	float font_size = static_cast<float>(scale * 13.0);

	img.draw_text(pos.x, y_pos, text, col, 0, 1, font_size);

	// Convert back to interleaved format
	prepareForInterleaved(img);

	// No need to copy data back since we're using shared memory
}

void drawRectangle(SharedMat &mat, Vec2i start, Vec2i end, Vec3d color, int thickness) {
	auto img = createCImgViewU8(mat);

	// Use color directly as passed in
	uint8_t col[3] = {
		static_cast<uint8_t>(color.x),
		static_cast<uint8_t>(color.y),
		static_cast<uint8_t>(color.z)};

	if (thickness <= 0) {
		// Filled rectangle
		img.draw_rectangle(start.x, start.y, end.x, end.y, col);
	} else {
		// Outlined rectangle
		img.draw_rectangle(start.x, start.y, end.x, end.y, col, 1.0f, ~0U);

		// For thicker lines, draw multiple rectangles
		for (int i = 1; i < thickness; i++) {
			if (start.x + i < end.x && start.y + i < end.y) {
				img.draw_rectangle(start.x + i, start.y + i, end.x - i, end.y - i, col, 1.0f, ~0U);
			}
		}
	}

	prepareForInterleaved(img);
}
}

extern "C" {
void aux_img_put_text_impl(aux_img::SharedMat mat, const char *text, aux_img::Vec2i pos, aux_img::Vec3d color, double scale, int thickness, bool bottomLeftOrigin) {
	aux_img::drawText(mat, text, pos, color, scale, thickness, bottomLeftOrigin);
}

void aux_img_rectangle_impl(aux_img::SharedMat mat, aux_img::Vec2i start, aux_img::Vec2i end, aux_img::Vec3d color, int thickness) {
	aux_img::drawRectangle(mat, start, end, color, thickness);
}
}
