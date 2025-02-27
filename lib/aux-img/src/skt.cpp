#include <cstdint>
#include <cassert>
#include <functional>
#include <span>
#include <aux.hpp>
#include <format>
#include <stdexcept>

#ifndef M_COLOR_SPINE
#define M_COLOR_SPINE 138, 201, 38
#endif

#ifndef M_COLOR_ARMS
#define M_COLOR_ARMS 255, 202, 58
#endif

#ifndef M_COLOR_LEGS
#define M_COLOR_LEGS 25, 130, 196
#endif

#ifndef M_COLOR_FINGERS
#define M_COLOR_FINGERS 255, 0, 0
#endif

#ifndef M_COLOR_FACE
#define M_COLOR_FACE 255, 200, 0
#endif

#ifndef M_COLOR_FOOT
#define M_COLOR_FOOT 255, 128, 0
#endif

namespace aux_img {
constexpr auto NUM_KEYPOINTS = 133;
struct Landmark {
	uint8_t index;
	int color[3];

	uint8_t base_0_index() const {
		assert(index > 0);
		return index - 1;
	}
};

constexpr Landmark body_landmarks[] = {
	// nose
	{1, {M_COLOR_SPINE}},
	// left_eye
	{2, {M_COLOR_SPINE}},
	// right_eye
	{3, {M_COLOR_SPINE}},
	// left_ear
	{4, {M_COLOR_SPINE}},
	// right_ear
	{5, {M_COLOR_SPINE}},
	// left_shoulder
	{6, {M_COLOR_ARMS}},
	// right_shoulder
	{7, {M_COLOR_ARMS}},
	// left_elbow
	{8, {M_COLOR_ARMS}},
	// right_elbow
	{9, {M_COLOR_ARMS}},
	// left_wrist
	{10, {M_COLOR_ARMS}},
	// right_wrist
	{11, {M_COLOR_ARMS}},
	// left_hip
	{12, {M_COLOR_LEGS}},
	// right_hip
	{13, {M_COLOR_LEGS}},
	// left_knee
	{14, {M_COLOR_LEGS}},
	// right_knee
	{15, {M_COLOR_LEGS}},
	// left_ankle
	{16, {M_COLOR_LEGS}},
	// right_ankle
	{17, {M_COLOR_LEGS}},
};

constexpr Landmark foot_landmarks[] = {
	// left_big_toe
	{18, {M_COLOR_FOOT}},
	// left_small_toe
	{19, {M_COLOR_FOOT}},
	// left_heel
	{20, {M_COLOR_FOOT}},
	// right_big_toe
	{21, {M_COLOR_FOOT}},
	// right_small_toe
	{22, {M_COLOR_FOOT}},
	// right_heel
	{23, {M_COLOR_FOOT}},
};

constexpr Landmark face_landmarks[] = {
	// chin contour
	{24, {M_COLOR_FACE}},
	{25, {M_COLOR_FACE}},
	{26, {M_COLOR_FACE}},
	{27, {M_COLOR_FACE}},
	{28, {M_COLOR_FACE}},
	{29, {M_COLOR_FACE}},
	{30, {M_COLOR_FACE}},
	{31, {M_COLOR_FACE}},
	{32, {M_COLOR_FACE}},
	{33, {M_COLOR_FACE}},
	{34, {M_COLOR_FACE}},
	{35, {M_COLOR_FACE}},
	{36, {M_COLOR_FACE}},
	{37, {M_COLOR_FACE}},
	{38, {M_COLOR_FACE}},
	{39, {M_COLOR_FACE}},
	{40, {M_COLOR_FACE}},
	// right eyebrow
	{41, {M_COLOR_FACE}},
	{42, {M_COLOR_FACE}},
	{43, {M_COLOR_FACE}},
	{44, {M_COLOR_FACE}},
	{45, {M_COLOR_FACE}},
	// left eyebrow
	{46, {M_COLOR_FACE}},
	{47, {M_COLOR_FACE}},
	{48, {M_COLOR_FACE}},
	{49, {M_COLOR_FACE}},
	{50, {M_COLOR_FACE}},
	// nasal bridge
	{51, {M_COLOR_FACE}},
	{52, {M_COLOR_FACE}},
	{53, {M_COLOR_FACE}},
	{54, {M_COLOR_FACE}},
	// nasal base
	{55, {M_COLOR_FACE}},
	{56, {M_COLOR_FACE}},
	{57, {M_COLOR_FACE}},
	{58, {M_COLOR_FACE}},
	{59, {M_COLOR_FACE}},
	// right eye
	{60, {M_COLOR_FACE}},
	{61, {M_COLOR_FACE}},
	{62, {M_COLOR_FACE}},
	{63, {M_COLOR_FACE}},
	{64, {M_COLOR_FACE}},
	{65, {M_COLOR_FACE}},
	// left eye
	{66, {M_COLOR_FACE}},
	{67, {M_COLOR_FACE}},
	{68, {M_COLOR_FACE}},
	{69, {M_COLOR_FACE}},
	{70, {M_COLOR_FACE}},
	{71, {M_COLOR_FACE}},
	// lips
	{72, {M_COLOR_FACE}},
	{73, {M_COLOR_FACE}},
	{74, {M_COLOR_FACE}},
	{75, {M_COLOR_FACE}},
	{76, {M_COLOR_FACE}},
	{77, {M_COLOR_FACE}},
	{78, {M_COLOR_FACE}},
	{79, {M_COLOR_FACE}},
	{80, {M_COLOR_FACE}},
	{81, {M_COLOR_FACE}},
	{82, {M_COLOR_FACE}},
	{83, {M_COLOR_FACE}},
	{84, {M_COLOR_FACE}},
	{85, {M_COLOR_FACE}},
	{86, {M_COLOR_FACE}},
	{87, {M_COLOR_FACE}},
	{88, {M_COLOR_FACE}},
	{89, {M_COLOR_FACE}},
	{90, {M_COLOR_FACE}},
	{91, {M_COLOR_FACE}},
};

constexpr Landmark hand_landmarks[] = {
	// Right hand
	{92, {M_COLOR_FINGERS}},  // right_wrist
	{93, {M_COLOR_FINGERS}},  // right_thumb_metacarpal
	{94, {M_COLOR_FINGERS}},  // right_thumb_mcp
	{95, {M_COLOR_FINGERS}},  // right_thumb_ip
	{96, {M_COLOR_FINGERS}},  // right_thumb_tip
	{97, {M_COLOR_FINGERS}},  // right_index_metacarpal
	{98, {M_COLOR_FINGERS}},  // right_index_mcp
	{99, {M_COLOR_FINGERS}},  // right_index_pip
	{100, {M_COLOR_FINGERS}}, // right_index_tip
	{101, {M_COLOR_FINGERS}}, // right_middle_metacarpal
	{102, {M_COLOR_FINGERS}}, // right_middle_mcp
	{103, {M_COLOR_FINGERS}}, // right_middle_pip
	{104, {M_COLOR_FINGERS}}, // right_middle_tip
	{105, {M_COLOR_FINGERS}}, // right_ring_metacarpal
	{106, {M_COLOR_FINGERS}}, // right_ring_mcp
	{107, {M_COLOR_FINGERS}}, // right_ring_pip
	{108, {M_COLOR_FINGERS}}, // right_ring_tip
	{109, {M_COLOR_FINGERS}}, // right_pinky_metacarpal
	{110, {M_COLOR_FINGERS}}, // right_pinky_mcp
	{111, {M_COLOR_FINGERS}}, // right_pinky_pip
	{112, {M_COLOR_FINGERS}}, // right_pinky_tip
	// Left hand
	{113, {M_COLOR_FINGERS}}, // left_wrist
	{114, {M_COLOR_FINGERS}}, // left_thumb_metacarpal
	{115, {M_COLOR_FINGERS}}, // left_thumb_mcp
	{116, {M_COLOR_FINGERS}}, // left_thumb_ip
	{117, {M_COLOR_FINGERS}}, // left_thumb_tip
	{118, {M_COLOR_FINGERS}}, // left_index_metacarpal
	{119, {M_COLOR_FINGERS}}, // left_index_mcp
	{120, {M_COLOR_FINGERS}}, // left_index_pip
	{121, {M_COLOR_FINGERS}}, // left_index_tip
	{122, {M_COLOR_FINGERS}}, // left_middle_metacarpal
	{123, {M_COLOR_FINGERS}}, // left_middle_mcp
	{124, {M_COLOR_FINGERS}}, // left_middle_pip
	{125, {M_COLOR_FINGERS}}, // left_middle_tip
	{126, {M_COLOR_FINGERS}}, // left_ring_metacarpal
	{127, {M_COLOR_FINGERS}}, // left_ring_mcp
	{128, {M_COLOR_FINGERS}}, // left_ring_pip
	{129, {M_COLOR_FINGERS}}, // left_ring_tip
	{130, {M_COLOR_FINGERS}}, // left_pinky_metacarpal
	{131, {M_COLOR_FINGERS}}, // left_pinky_mcp
	{132, {M_COLOR_FINGERS}}, // left_pinky_pip
	{133, {M_COLOR_FINGERS}}, // left_pinky_tip
};

struct Bone {
	uint8_t start;
	uint8_t end;
	int color[3];

	uint8_t base_0_start() const {
		assert(start > 0);
		return start - 1;
	}

	uint8_t base_0_end() const {
		assert(end > 0);
		return end - 1;
	}
};

constexpr Bone body_bones[] = {
	// left_tibia
	{16, 14, {M_COLOR_LEGS}},
	// left_femur
	{14, 12, {M_COLOR_LEGS}},
	// right_tibia
	{17, 15, {M_COLOR_LEGS}},
	// right_femur
	{15, 13, {M_COLOR_LEGS}},
	// pelvis
	{12, 13, {M_COLOR_LEGS}},
	// left_contour
	{6, 12, {M_COLOR_SPINE}},
	// right_contour
	{7, 13, {M_COLOR_SPINE}},
	// clavicle
	{6, 7, {M_COLOR_SPINE}},
	// left_humerus
	{6, 8, {M_COLOR_ARMS}},
	// left_radius
	{8, 10, {M_COLOR_ARMS}},
	// right_humerus
	{7, 9, {M_COLOR_ARMS}},
	// right_radius
	{9, 11, {M_COLOR_ARMS}},
	// head
	{2, 3, {M_COLOR_FACE}},
	// left_eye
	{1, 2, {M_COLOR_FACE}},
	// right_eye
	{1, 3, {M_COLOR_FACE}},
	// left_ear
	{2, 4, {M_COLOR_FACE}},
	// right_ear
	{3, 5, {M_COLOR_FACE}},
	// left_foot_toe
	{16, 18, {M_COLOR_FOOT}},
	// left_foot_small_toe
	{16, 19, {M_COLOR_FOOT}},
	// left_foot_heel
	{16, 20, {M_COLOR_FOOT}},
	// right_foot_toe
	{17, 21, {M_COLOR_FOOT}},
	// right_foot_small_toe
	{17, 22, {M_COLOR_FOOT}},
	// right_foot_heel
	{17, 23, {M_COLOR_FOOT}},
};

constexpr Bone hand_bones[] = {
	// right_thumb_metacarpal
	{92, 93, {M_COLOR_FINGERS}},
	// right_thumb_proximal_phalanx
	{93, 94, {M_COLOR_FINGERS}},
	// right_thumb_distal_phalanx
	{94, 95, {M_COLOR_FINGERS}},
	// right_index_metacarpal
	{92, 97, {M_COLOR_FINGERS}},
	// right_index_proximal_phalanx
	{97, 98, {M_COLOR_FINGERS}},
	// right_index_middle_phalanx
	{98, 99, {M_COLOR_FINGERS}},
	// right_index_distal_phalanx
	{99, 100, {M_COLOR_FINGERS}},
	// right_middle_metacarpal
	{92, 101, {M_COLOR_FINGERS}},
	// right_middle_proximal_phalanx
	{101, 102, {M_COLOR_FINGERS}},
	// right_middle_middle_phalanx
	{102, 103, {M_COLOR_FINGERS}},
	// right_middle_distal_phalanx
	{103, 104, {M_COLOR_FINGERS}},
	// right_ring_metacarpal
	{92, 105, {M_COLOR_FINGERS}},
	// right_ring_proximal_phalanx
	{105, 106, {M_COLOR_FINGERS}},
	// right_ring_middle_phalanx
	{106, 107, {M_COLOR_FINGERS}},
	// right_ring_distal_phalanx
	{107, 108, {M_COLOR_FINGERS}},
	// right_pinky_metacarpal
	{92, 109, {M_COLOR_FINGERS}},
	// right_pinky_proximal_phalanx
	{109, 110, {M_COLOR_FINGERS}},
	// right_pinky_middle_phalanx
	{110, 111, {M_COLOR_FINGERS}},
	// right_pinky_distal_phalanx
	{111, 112, {M_COLOR_FINGERS}},
	// left_thumb_metacarpal
	{113, 114, {M_COLOR_FINGERS}},
	// left_thumb_proximal_phalanx
	{114, 115, {M_COLOR_FINGERS}},
	// left_thumb_distal_phalanx
	{115, 116, {M_COLOR_FINGERS}},
	// left_index_metacarpal
	{113, 118, {M_COLOR_FINGERS}},
	// left_index_proximal_phalanx
	{118, 119, {M_COLOR_FINGERS}},
	// left_index_middle_phalanx
	{119, 120, {M_COLOR_FINGERS}},
	// left_index_distal_phalanx
	{120, 121, {M_COLOR_FINGERS}},
	// left_middle_metacarpal
	{113, 122, {M_COLOR_FINGERS}},
	// left_middle_proximal_phalanx
	{122, 123, {M_COLOR_FINGERS}},
	// left_middle_middle_phalanx
	{123, 124, {M_COLOR_FINGERS}},
	// left_middle_distal_phalanx
	{124, 125, {M_COLOR_FINGERS}},
	// left_ring_metacarpal
	{113, 126, {M_COLOR_FINGERS}},
	// left_ring_proximal_phalanx
	{126, 127, {M_COLOR_FINGERS}},
	// left_ring_middle_phalanx
	{127, 128, {M_COLOR_FINGERS}},
	// left_ring_distal_phalanx
	{128, 129, {M_COLOR_FINGERS}},
	// left_pinky_metacarpal
	{113, 130, {M_COLOR_FINGERS}},
	// left_pinky_proximal_phalanx
	{130, 131, {M_COLOR_FINGERS}},
	// left_pinky_middle_phalanx
	{131, 132, {M_COLOR_FINGERS}},
	// left_pinky_distal_phalanx
	{132, 133, {M_COLOR_FINGERS}},
};

auto for_each_landmark(std::function<void(Landmark)> callback) -> void {
	for (const auto &landmark : body_landmarks) {
		callback(landmark);
	}
	for (const auto &landmark : foot_landmarks) {
		callback(landmark);
	}
	for (const auto &landmark : face_landmarks) {
		callback(landmark);
	}
	for (const auto &landmark : hand_landmarks) {
		callback(landmark);
	}
}

auto for_each_bone(std::function<void(Bone)> callback) -> void {
	for (const auto &bone : body_bones) {
		callback(bone);
	}
	for (const auto &bone : hand_bones) {
		callback(bone);
	}
}

void for_each_with_pair(std::span<const float> points, std::function<void(std::tuple<float, float>, int)> callback) {
	if (points.size() % 2 != 0) {
		throw std::invalid_argument("points.size() % 2 != 0");
	}
	for (int i = 0; i < points.size(); i += 2) {
		callback({points[i], points[i + 1]}, i / 2);
	}
}

// Helper function to draw a circle directly on the SharedMat data
void drawCircle(SharedMat &mat, int x, int y, int radius, const int color[3], int thickness) {
	// For simplicity, we'll only support U8 depth
	if (mat.depth != Depth::U8) {
		throw std::runtime_error(
			std::format("Unsupported depth {} for CImg. Only U8 is currently supported.",
						depth_to_string(mat.depth)));
	}

	auto img = aux_img::createCImgViewU8(mat);

	const uint8_t col[3] = {
		static_cast<uint8_t>(color[0]),
		static_cast<uint8_t>(color[1]),
		static_cast<uint8_t>(color[2])};

	if (thickness < 0) {
		// Filled circle
		img.draw_circle(x, y, radius, col);
	} else {
		// Outlined circle
		img.draw_circle(x, y, radius, col, 1.0f, thickness);
	}

	prepareForInterleaved(img);
}

// Helper function to draw a line directly on the SharedMat data
void drawLine(SharedMat &mat, int x1, int y1, int x2, int y2, const int color[3], int thickness) {
	// For simplicity, we'll only support U8 depth
	if (mat.depth != Depth::U8) {
		throw std::runtime_error(
			std::format("Unsupported depth {} for CImg. Only U8 is currently supported.",
						depth_to_string(mat.depth)));
	}

	auto img = aux_img::createCImgViewU8(mat);

	const uint8_t col[3] = {
		static_cast<uint8_t>(color[0]),
		static_cast<uint8_t>(color[1]),
		static_cast<uint8_t>(color[2])};

	img.draw_line(x1, y1, x2, y2, col, thickness);

	prepareForInterleaved(img);
}

// row based, with shape of (133, 2)
void draw_whole_body_landmark_row_based(SharedMat &mat, std::span<const float> points, int radius = 3, int thickness = -1) {
	if (points.size() != NUM_KEYPOINTS * 2) {
		throw std::invalid_argument("points.size() != 133 * 2");
	}
	for_each_landmark([&points, &mat, radius, thickness](Landmark landmark) {
		const auto index = landmark.base_0_index();
		auto x           = static_cast<int>(points[index * 2]);
		auto y           = static_cast<int>(points[index * 2 + 1]);
		drawCircle(mat, x, y, radius, landmark.color, thickness);
	});
}

// column based, with shape of (2, 133)
void draw_whole_body_landmark_col_based(SharedMat &mat, std::span<const float> points, int radius = 3, int thickness = -1) {
	if (points.size() != NUM_KEYPOINTS * 2) {
		throw std::invalid_argument("points.size() != 2 * 133");
	}
	for_each_landmark([xs = points.subspan(0, NUM_KEYPOINTS), ys = points.subspan(NUM_KEYPOINTS, NUM_KEYPOINTS),
					   &mat, radius, thickness](Landmark landmark) {
		const auto index = landmark.base_0_index();
		auto x           = static_cast<int>(xs[index]);
		auto y           = static_cast<int>(ys[index]);
		drawCircle(mat, x, y, radius, landmark.color, thickness);
	});
}

// row based, with shape of (133, 2)
void draw_whole_body_skeleton_row_based(SharedMat &mat, std::span<const float> points, int thickness = 2) {
	if (points.size() != NUM_KEYPOINTS * 2) {
		throw std::invalid_argument("points.size() != 133 * 2");
	}
	for_each_bone([&points, &mat, thickness](Bone bone) {
		const auto start_index = bone.base_0_start();
		const auto end_index   = bone.base_0_end();
		// with stride of 2
		const auto start_x = static_cast<int>(points[start_index * 2]);
		const auto start_y = static_cast<int>(points[start_index * 2 + 1]);
		const auto end_x   = static_cast<int>(points[end_index * 2]);
		const auto end_y   = static_cast<int>(points[end_index * 2 + 1]);
		drawLine(mat, start_x, start_y, end_x, end_y, bone.color, thickness);
	});
}

void draw_whole_body_skeleton_col_based(SharedMat &mat, std::span<const float> points, int thickness = 2) {
	if (points.size() != NUM_KEYPOINTS * 2) {
		throw std::invalid_argument("points.size() != 133 * 2");
	}
	for_each_bone([xs = points.subspan(0, NUM_KEYPOINTS), ys = points.subspan(NUM_KEYPOINTS, NUM_KEYPOINTS),
				   &mat, thickness](Bone bone) {
		const auto start_index = bone.base_0_start();
		const auto end_index   = bone.base_0_end();
		const auto start_x     = static_cast<int>(xs[start_index]);
		const auto start_y     = static_cast<int>(ys[start_index]);
		const auto end_x       = static_cast<int>(xs[end_index]);
		const auto end_y       = static_cast<int>(ys[end_index]);
		drawLine(mat, start_x, start_y, end_x, end_y, bone.color, thickness);
	});
}
}

extern "C" {
void aux_img_draw_whole_body_skeleton_impl(aux_img::SharedMat mat, const float *data, aux_img::DrawSkeletonOptions options) {
	auto points = std::span(data, aux_img::NUM_KEYPOINTS * 2);

	// if (options.is_draw_bones) {
	// 	if (options.layout == aux_img::Layout::RowMajor) {
	// 		aux_img::draw_whole_body_skeleton_row_based(mat, points, options.bone_thickness);
	// 	} else {
	// 		aux_img::draw_whole_body_skeleton_col_based(mat, points, options.bone_thickness);
	// 	}
	// }

	// if (options.is_draw_landmarks) {
	// 	if (options.layout == aux_img::Layout::RowMajor) {
	// 		aux_img::draw_whole_body_landmark_row_based(mat, points, options.landmark_radius, options.landmark_thickness);
	// 	} else {
	// 		aux_img::draw_whole_body_landmark_col_based(mat, points, options.landmark_radius, options.landmark_thickness);
	// 	}
	// }
};
}
