#ifndef AUX_C_H
#define AUX_C_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum AuxImgPixelFormat : uint8_t {
	AUX_IMG_PIXEL_FORMAT_RGB = 0,
	AUX_IMG_PIXEL_FORMAT_BGR,
	AUX_IMG_PIXEL_FORMAT_RGBA,
	AUX_IMG_PIXEL_FORMAT_BGRA,
	AUX_IMG_PIXEL_FORMAT_GRAY,
	AUX_IMG_PIXEL_FORMAT_YUV,
	AUX_IMG_PIXEL_FORMAT_YUYV,
};

enum AuxImgDepth : uint8_t {
	AUX_IMG_DEPTH_U8 = 0,
	AUX_IMG_DEPTH_S8,
	AUX_IMG_DEPTH_U16,
	AUX_IMG_DEPTH_S16,
	AUX_IMG_DEPTH_S32,
	AUX_IMG_DEPTH_F32,
	AUX_IMG_DEPTH_F64,
	AUX_IMG_DEPTH_F16,
};

struct aux_img_shared_mat {
	uint8_t *data;
	uint16_t rows;
	uint16_t cols;
	AuxImgDepth depth;
	AuxImgPixelFormat pixel_format;
};
typedef struct aux_img_shared_mat aux_img_shared_mat_t;

struct aux_img_vec2f {
	float x;
	float y;
};
typedef struct aux_img_vec2f aux_img_vec2f_t;

struct aux_img_vec2i {
	int x;
	int y;
};
typedef struct aux_img_vec2i aux_img_vec2i_t;

struct aux_img_vec3i {
	int x;
	int y;
	int z;
};
typedef struct aux_img_vec3i aux_img_vec3i_t;

void aux_img_put_text(struct aux_img_shared_mat mat,
					  const char *text,
					  struct aux_img_vec2i pos,
					  struct aux_img_vec3i color,
					  float scale,
					  float thickness,
					  bool bottomLeftOrigin);
#ifdef __cplusplus
}
#endif

#endif
