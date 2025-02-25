package info
import auximg ".."
import "core:c"
import "core:encoding/endian"

NUM_KEYPOINTS_PAIR :: auximg.NUM_KEYPOINTS_PAIR

BoundingBox :: [4]f32
Skeleton :: [NUM_KEYPOINTS_PAIR * 2]f32

PoseInfo :: struct {
	frame_index:  u32,
	keypoints:    [dynamic]Skeleton,
	bounding_box: [dynamic]BoundingBox,
}

destroy :: proc(info: PoseInfo) {
	delete(info.keypoints)
	delete(info.bounding_box)
}

unmarshal :: proc(data: []u8) -> (info: PoseInfo, ok: bool) {
	MIN_SIZE :: 4 + 1 + 1
	info = PoseInfo{}
	ok = true
	if len(data) < MIN_SIZE {
		ok = false
		return
	}
	frame_index: u32
	rest := data
	frame_index, ok = endian.get_u32(rest[0:4], .Little)
	if !ok {
		return
	}
	rest = rest[4:]

	num_keypoints := rest[0]
	rest = rest[1:]

	num_boxes := rest[0]
	rest = rest[1:]

	keypoints: [dynamic]Skeleton = nil
	if num_keypoints != 0 {
		KP_SIZE_PER_UNIT :: NUM_KEYPOINTS_PAIR * 2 * size_of(f32)
		if len(rest) < int(num_keypoints) * KP_SIZE_PER_UNIT {
			ok = false
			return
		}
		keypoints = make([dynamic]Skeleton, num_keypoints)
		defer {
			if !ok {
				delete(keypoints)
			}
		}
		for i in 0 ..< num_keypoints {
			rest_ptr := ([^]u8)(raw_data(rest))
			kp_ptr := ([^]u8)(&keypoints[i])
			r := rest_ptr[:KP_SIZE_PER_UNIT]
			k := kp_ptr[:KP_SIZE_PER_UNIT]
			copy(k, r)
			rest = rest[KP_SIZE_PER_UNIT:]
		}
	}
	bounding_box: [dynamic]BoundingBox = nil
	if num_boxes != 0 {
		BB_SIZE_PER_UNIT :: 4 * size_of(f32)
		if len(rest) < int(num_boxes) * BB_SIZE_PER_UNIT {
			ok = false
			return
		}
		bounding_box = make([dynamic]BoundingBox, num_boxes)
		defer {
			if !ok {
				delete(bounding_box)
			}
		}
		for i in 0 ..< num_boxes {
			rest_ptr := ([^]u8)(raw_data(rest))
			bb_ptr := ([^]u8)(&bounding_box[i])
			r := rest_ptr[:BB_SIZE_PER_UNIT]
			b := bb_ptr[:BB_SIZE_PER_UNIT]
			copy(b, r)
			rest = rest[BB_SIZE_PER_UNIT:]
		}
	}
	info = PoseInfo{frame_index, keypoints, bounding_box}
	return
}

DrawPoseOptions :: struct {
	landmark_radius:        int,
	landmark_thickness:     int,
	bone_thickness:         int,
	bounding_box_thickness: int,
	bounding_box_color:     [3]f32,
}

draw :: proc(mat: auximg.SharedMat, info: ^PoseInfo, opts: DrawPoseOptions) {
	if info == nil {
		return
	}

	skt_opts := auximg.DrawSkeletonOptions {
		auximg.Layout.RowMajor,
		true,
		true,
		c.int(opts.landmark_radius),
		c.int(opts.landmark_thickness),
		c.int(opts.bone_thickness),
	}
	for &kps in info.keypoints {
		// kps is row major. i.e. [NUM_KEYPOINTS_PAIR][2]f32
		auximg.draw_whole_body_skeleton(mat, kps[:], skt_opts)
	}

	for &bb in info.bounding_box {
		// bb is [x1, y1, x2, y2]
		pt1 := [2]i32{i32(bb[0]), i32(bb[1])}
		pt2 := [2]i32{i32(bb[2]), i32(bb[3])}
		auximg.rectangle(
			mat,
			pt1,
			pt2,
			opts.bounding_box_color,
			c.int(opts.bounding_box_thickness),
		)
	}
}
