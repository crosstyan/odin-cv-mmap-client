package cvmmap
import zmq "../../lib/odin-zeromq"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:sys/posix"
import "core:thread"

ZmqError :: zmq.ZmqError
FD :: posix.FD
Thread :: thread.Thread
FRAME_TOPIC_MAGIC :: 0x7d
// I think it's -1
BAD_MMAP_ADDR :: cast(rawptr)cast(uintptr)0xFFFFFFFFFFFFFFFF
NAME_MAX_LEN :: 24
SHM_PAYLOAD_OFFSET :: 256
// CV-MMAP\0
CV_MMAP_MAGIC_LEN :: 8
CV_MMAP_MAGIC_STR :: "CV-MMAP"

// same as OpenCV's definitions
Depth :: enum u8 {
	U8,
	S8,
	U16,
	S16,
	S32,
	F32,
	F64,
	F16,
}

PixelFormat :: enum u8 {
	RGB,
	BGR,
	RGBA,
	BGRA,
	GRAY,
	YUV,
	YUYV,
}

FrameInfo :: struct #packed {
	width:        u16,
	height:       u16,
	channels:     u8,
	depth:        Depth,
	buffer_size:  u32,
	pixel_format: PixelFormat,
}

FrameMetadata :: struct #packed {
	frame_index: u32,
	info:        FrameInfo,
}

SyncMessage :: struct #packed {
	magic:       u8,
	frame_index: u32,
	label:       [NAME_MAX_LEN]u8,
}

OnFrame_Proc :: proc(metadata: FrameMetadata, buffer: []u8, user_data: rawptr)

SharedBuffer :: struct {
	// mmaped shared memory with size
	_shm:     []u8,
	// image buffer
	image:    []u8,
	// metadata region
	metadata: []u8,
}

CvMmapClient :: struct {
	_instance_name:    string,
	_shm_name:         string,
	_zmq_addr:         string,
	_zmq_ctx:          ^zmq.Context,
	_is_owned_zmq_ctx: bool,
	_zmq_sock:         ^zmq.Socket,
	_shm_fd:           Maybe(posix.FD),
	_shared_buffer:    Maybe(SharedBuffer),
	_has_init:         bool,
	// task
	_polling_task:     Maybe(^Thread),
	_is_running:       bool,
	// callbacks
	// used in `on_frame` callback
	user_data:         rawptr,
	on_frame:          OnFrame_Proc,
}

// Refactored error types using tagged unions
CvMmapError :: union {
	ZmqError,
	ShmError,
	StateError,
}

ShmError :: struct {
	errno: int,
	what:  string,
}

StateError :: enum {
	AlreadyInitialized,
	NeverInitialized,
	AlreadyRunning,
}

// create a new cv-mmap client
//
// will create a new ZMQ context if not provided
//
// a proper life cycle the client:
// create -> init -> setting callbacks -> start -> stop -> destroy
create :: proc(instance_name: string, zmq_ctx: ^zmq.Context = nil) -> ^CvMmapClient {
	ctx := zmq_ctx if zmq_ctx != nil else zmq.ctx_new()
	is_owned_zmq_ctx := zmq_ctx == nil

	client := new(CvMmapClient)
	client._instance_name = strings.clone(instance_name)
	client._shm_name = fmt.aprintf("cvmmap_%s", instance_name)
	client._zmq_addr = fmt.aprintf("ipc:///tmp/cvmmap_%s", client._instance_name)
	client._zmq_ctx = ctx
	client._is_owned_zmq_ctx = is_owned_zmq_ctx
	client._zmq_sock = zmq.socket(ctx, zmq.SUB)
	client._shm_fd = nil
	client._shared_buffer = nil
	client._has_init = false

	client._polling_task = nil
	client._is_running = false

	client.user_data = nil
	client.on_frame = nil
	return client
}

destroy :: proc(self: ^CvMmapClient) {
	stop(self)
	if self._zmq_sock != nil {
		zmq.close(self._zmq_sock)
	}
	if self._is_owned_zmq_ctx {
		zmq.ctx_term(self._zmq_ctx)
	}
	delete(self._instance_name)
	delete(self._shm_name)
	delete(self._zmq_addr)
	free(self)
}

// setup the ZMQ socket and Open the shared memory file descriptor
init :: proc(self: ^CvMmapClient) -> (err: CvMmapError) {
	if self._has_init {
		return StateError.AlreadyInitialized
	}

	zmq_addr_c := strings.clone_to_cstring(self._zmq_addr)
	defer delete(zmq_addr_c)

	code := cast(int)zmq.setsockopt_bool(self._zmq_sock, zmq.CONFLATE, true)
	if code != 0 {
		return ZmqError{code, "setsockopt_bool"}
	}
	// ensure recv() wakes up periodically so we can exit cleanly
	code = cast(int)zmq.setsockopt_int(self._zmq_sock, zmq.RCVTIMEO, 100) // 100 ms
	if code != 0 {
		return ZmqError{code, "setsockopt_int(RCVTIMEO)"}
	}

	// http://api.zeromq.org/4-2:zmq-connect
	code = cast(int)zmq.connect(self._zmq_sock, zmq_addr_c)
	if code != 0 {
		return ZmqError{code, "connect"}
	}

	has_err := false
	defer if has_err {
		zmq.disconnect(self._zmq_sock, zmq_addr_c)
	}

	topic := [1]u8{FRAME_TOPIC_MAGIC}
	code = cast(int)zmq.setsockopt_bytes(self._zmq_sock, zmq.SUBSCRIBE, topic[:])
	if code != 0 {
		has_err = true
		return ZmqError{code, "setsockopt_bytes"}
	}

	shm_name_c := strings.clone_to_cstring(self._shm_name)
	defer delete(shm_name_c)
	// READONLY
	// MODE is meaningless for consumer, only meaningful when `O_CREAT` is set
	fd := posix.shm_open(shm_name_c, {}, {})
	if fd == -1 {
		has_err = true
		return ShmError{cast(int)posix.get_errno(), "shm_open"}
	}
	log.infof("shm_name: %s; shm_fd: %d", self._shm_name, fd)

	self._shm_fd = fd
	self._has_init = true
	return nil
}

// @note: this is an alias (non allocating)
// @see https://odin-lang.org/docs/overview/
@(private)
_get_sync_msg_get_label :: proc(msg: ^SyncMessage) -> string {
	return string(cstring(raw_data(msg.label[:])))
}

@(private)
_get_shared_buffer :: proc(fd: posix.FD) -> (SharedBuffer, CvMmapError) {
	image_buffer: SharedBuffer
	stat: posix.stat_t
	ok := posix.fstat(fd, &stat)
	if ok != .OK {
		return image_buffer, ShmError{cast(int)posix.get_errno(), "fstat"}
	}
	shm_ptr := posix.mmap(nil, cast(c.size_t)stat.st_size, {.READ}, {.SHARED}, fd, 0)
	if shm_ptr == nil || shm_ptr == BAD_MMAP_ADDR {
		return image_buffer, ShmError{cast(int)posix.get_errno(), "mmap"}
	}
	image_buffer._shm = (cast([^]u8)shm_ptr)[:stat.st_size]
	// memory layout:
	// 0 - SHM_PAYLOAD_OFFSET: metadata
	//    - 8: magic
	//    - rest: metadata_rel:
	//      - 4: frame_index
	//      - rest: frame_info
	// SHM_PAYLOAD_OFFSET - end: image
	image_buffer.image = image_buffer._shm[SHM_PAYLOAD_OFFSET:]
	image_buffer.metadata = image_buffer._shm[:SHM_PAYLOAD_OFFSET]
	cv_mmap_magic := string(cstring(raw_data(image_buffer.metadata[:CV_MMAP_MAGIC_LEN])))
	assert(
		cv_mmap_magic == CV_MMAP_MAGIC_STR,
		fmt.tprintf(
			"invalid cv-mmap magic; expected=%s; actual=%s",
			CV_MMAP_MAGIC_STR,
			cv_mmap_magic,
		),
	)
	return image_buffer, nil
}

@(private)
_metadata :: proc(image_buffer_state: ^SharedBuffer) -> ^FrameMetadata {
	return cast(^FrameMetadata)(raw_data(image_buffer_state.metadata[CV_MMAP_MAGIC_LEN:]))
}

@(private)
_polling_task :: proc(t: ^Thread) {
	client := cast(^CvMmapClient)t.data

	recv_sync_msg :: proc(skt: ^zmq.Socket) -> (SyncMessage, bool) {
		sync_msg := SyncMessage{}
		msg := zmq.Message{}
		data, ok := zmq.recv_msg_bytes(&msg, skt)
		defer zmq.msg_close(&msg)
		if !ok {
			return sync_msg, false
		}
		if l := len(data); l < size_of(SyncMessage) {
			log.errorf("invalid message size={}; required size={}", l, size_of(SyncMessage))
			return sync_msg, false
		}
		sync_msg = (cast(^SyncMessage)(raw_data(data)))^
		if sync_msg.magic != FRAME_TOPIC_MAGIC {
			log.errorf("invalid magic={}", sync_msg.magic)
			return sync_msg, false
		}
		return sync_msg, true
	}

	on_initial_frame :: proc(client: ^CvMmapClient) -> bool {
		ok: bool = ---
		assert(client._shm_fd != nil, "`nil` shm_fd")
		sync_msg: SyncMessage
		sync_msg, ok = recv_sync_msg(client._zmq_sock)
		if !ok {
			return false
		}
		fd: FD
		fd, ok = client._shm_fd.?
		assert(ok, "`nil` shm_fd")

		image_buffer, err := _get_shared_buffer(fd)
		if err != nil {
			log.errorf("failed to get image buffer; err={}", err)
			return false
		}
		client._shared_buffer = image_buffer
		if (client.on_frame != nil) {
			meta_ptr := _metadata(&image_buffer)
			client.on_frame(meta_ptr^, image_buffer.image, client.user_data)
		}
		return true
	}

	for client._is_running {
		if client._shared_buffer == nil {
			ok := on_initial_frame(client)
			if !ok {
				continue
			}
		}
		ok: bool = ---
		sync_msg: SyncMessage
		sync_msg, ok = recv_sync_msg(client._zmq_sock)
		if !ok {
			continue
		}
		label := _get_sync_msg_get_label(&sync_msg)
		if label != client._instance_name {
			log.errorf("invalid label={}; expected={}", label, client._instance_name)
			continue
		}
		if (client.on_frame != nil) {
			assert(client._shared_buffer != nil, "`nil` image buffer")
			meta_ptr := _metadata(&client._shared_buffer.?)
			client.on_frame(meta_ptr^, client._shared_buffer.?.image, client.user_data)
		}
	}
}

// start the polling thread, initialize memory mapping
start :: proc(self: ^CvMmapClient, init_context := context) -> (err: CvMmapError) {
	if !self._has_init {
		return StateError.NeverInitialized
	}
	if self._is_running {
		return StateError.AlreadyRunning
	}
	self._is_running = true
	self._polling_task = thread.create(_polling_task)
	self._polling_task.?.data = self
	self._polling_task.?.init_context = init_context
	thread.start(self._polling_task.?)
	return nil
}

// join the polling thread, destroy the thread and unmap the shared memory
stop :: proc(self: ^CvMmapClient) {
	if !self._has_init {
		return
	}
	if !self._is_running {
		return
	}
	self._is_running = false
	if task, ok := self._polling_task.?; ok {
		thread.join(task)
		thread.destroy(task)
	}
	// close the socket now that the polling thread is gone
	if self._zmq_sock != nil {
		zmq.close(self._zmq_sock)
		self._zmq_sock = nil
	}
	if self._shared_buffer != nil {
		res := posix.munmap(raw_data(self._shared_buffer.?._shm), len(self._shared_buffer.?._shm))
		assert(res != .FAIL, "munmap failed")
		self._shared_buffer = nil
	}
	if self._shm_fd != nil {
		posix.close(self._shm_fd.?)
		self._shm_fd = nil
	}
}
