package auximg

// from LSB (0) to MSB (7)
PoseDetectionBits :: enum u8 {
	// should always be `1`
	ENABLED          = 0,
	// start of a group
	SYN              = 1,
	// end of a group
	FIN              = 2,
	// whether the keypoints are available (still be filled with zeros if not)
	HAS_KEYPOINTS    = 3,
	// whether the bounding box is available (`xyxy` format)
	HAS_BBOX         = 4,
	// whether the keypoints are in column major order (default is row major)
	USE_COLUMN_MAJOR = 5,
}
PoseDetectionFlag :: bit_set[PoseDetectionBits;u8]
#assert(size_of(PoseDetectionFlag) == size_of(u8))

PoseDetectionInfo :: struct #packed {
	tracking_id:  u32,
	flags:        PoseDetectionFlag,
	keypoints:    [NUM_KEYPOINTS_PAIR]f32,
	bounding_box: [4]f32,
}
