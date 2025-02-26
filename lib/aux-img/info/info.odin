package info
import auximg ".."
import "core:c"
import "core:encoding/endian"
import "core:fmt"
import "core:log"
import "core:strings"

NUM_KEYPOINTS :: auximg.NUM_KEYPOINTS

BoundingBox :: [4]u16
Skeleton :: [NUM_KEYPOINTS * 2]f32

PoseInfo :: struct {
	frame_index:  u32,
	keypoints:    [dynamic]Skeleton,
	bounding_box: [dynamic]BoundingBox,
}

destroy :: proc(info: ^PoseInfo) {
	delete(info.keypoints)
	delete(info.bounding_box)
	info.keypoints = nil
	info.bounding_box = nil
}

clone :: proc(info: PoseInfo) -> PoseInfo {
	keypoints_copy := make([dynamic]Skeleton, len(info.keypoints))
	copy(keypoints_copy[:], info.keypoints[:])

	bounding_box_copy := make([dynamic]BoundingBox, len(info.bounding_box))
	copy(bounding_box_copy[:], info.bounding_box[:])

	return PoseInfo{info.frame_index, keypoints_copy, bounding_box_copy}
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
	frame_index, ok = endian.get_u32(rest[:4], .Little)
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
		KP_SIZE_PER_UNIT :: NUM_KEYPOINTS * 2 * size_of(f32)
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
	print_as_hex :: proc(index: int, data: []u8) {
		b, err := strings.builder_make_none()
		defer strings.builder_destroy(&b)
		for d in data {
			fmt.sbprintf(&b, "{:02x} ", d)
		}
		s := string(b.buf[:])
		log.debugf("index={}, data={}", index, s)
	}
	if num_boxes != 0 {
		BB_SIZE_PER_UNIT :: 4 * size_of(u16)
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
	bounding_box_color:     [3]c.double,
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
		pt1 := [2]c.int{c.int(bb[0]), c.int(bb[1])}
		pt2 := [2]c.int{c.int(bb[2]), c.int(bb[3])}
		auximg.rectangle(
			mat,
			pt1,
			pt2,
			opts.bounding_box_color,
			c.int(opts.bounding_box_thickness),
		)
	}
}
