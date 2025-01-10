package cvmmap
import zmq "../../lib/odin-zeromq"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import "core:thread"

FRAME_TOPIC_MAGIC :: 0x7d

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
Thread :: thread.Thread

CvMmapClient :: struct {
	_shm_name:     string,
	_zmq_addr:     string,
	_zmq_ctx:      ^zmq.Context,
	_zmq_sock:     ^zmq.Socket,
	_shm_fd:       Maybe(posix.FD),
	_has_init:     bool,
	// task
	_polling_task: Maybe(^Thread),
	_is_running:   bool,
	// callbacks
	// used in `on_frame` callback
	user_data:     rawptr,
	on_frame:      proc(info: FrameInfo, buffer: []u8, user_data: rawptr),
}

create :: proc(shm_name: string, zmq_addr: string) -> ^CvMmapClient {
	client := new(CvMmapClient)
	client._shm_name = shm_name
	client._zmq_addr = zmq_addr
	client._zmq_ctx = zmq.ctx_new()
	client._zmq_sock = zmq.socket(client._zmq_ctx, zmq.SUB)
	client._shm_fd = nil
	client._has_init = false

	client._polling_task = nil
	client._is_running = false

	client.user_data = nil
	client.on_frame = nil
	return client
}

destroy :: proc(client: ^CvMmapClient) {
	stop(client)
	if client._shm_fd != nil {
		posix.close(client._shm_fd.?)
	}
	zmq.close(client._zmq_sock)
	zmq.ctx_term(client._zmq_ctx)
	free(client)
}

CvMmapError :: enum {
	None,
	// see the additional error codes
	Zmq,
	// see the additional error codes (errno usually)
	Shm,
	AlreadyInitialized,
	NeverInitialized,
	AlreadyRunning,
}

init :: proc(client: ^CvMmapClient) -> (error_type: CvMmapError, code: int) {
	error_type = CvMmapError.None
	code = 0

	if client._has_init {
		error_type = CvMmapError.AlreadyInitialized
		return
	}

	zmq_addr_c := strings.clone_to_cstring(client._zmq_addr)
	defer delete(zmq_addr_c)

	code = cast(int)zmq.setsockopt_bool(client._zmq_sock, zmq.CONFLATE, true)
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}
	// http://api.zeromq.org/4-2:zmq-connect
	code = cast(int)zmq.connect(client._zmq_sock, zmq_addr_c)
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}
	topic := [1]u8{FRAME_TOPIC_MAGIC}
	code = cast(int)zmq.setsockopt_bytes(client._zmq_sock, zmq.SUBSCRIBE, topic[:])
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}

	shm_name_c := strings.clone_to_cstring(client._shm_name)
	defer delete(shm_name_c)
	fd := posix.shm_open(shm_name_c, {.WRONLY}, {.IRUSR, .IRGRP, .IROTH})
	if fd == -1 {
		error_type = CvMmapError.Shm
		code = cast(int)posix.get_errno()
		return
	}
	client._shm_fd = fd
	client._has_init = true
	return
}

@(private)
_polling_task :: proc(t: ^Thread) {
	client := cast(^CvMmapClient)t.data
	for client._is_running {
		msg := zmq.Message{}
		data, ok := zmq.recv_raw_msg_as_bytes(&msg, client._zmq_sock)
		if !ok {
			continue
		}
		if len(data) < size_of(FrameInfo) {
			continue
		}
		info := cast(^FrameInfo)(raw_data(data))
		// TODO: resize the shared memory for the first of time
	}
}

start :: proc(client: ^CvMmapClient) -> CvMmapError {
	if !client._has_init {
		return CvMmapError.NeverInitialized
	}
	if client._is_running {
		return CvMmapError.AlreadyRunning
	}
	client._is_running = true
	client._polling_task = thread.create(_polling_task)
	client._polling_task.?.data = client
	thread.start(client._polling_task.?)
	return CvMmapError.None
}

stop :: proc(client: ^CvMmapClient) {
	if !client._has_init {
		return
	}
	if !client._is_running {
		return
	}
	client._is_running = false
	if task, ok := client._polling_task.?; ok {
		thread.join(task)
		thread.destroy(task)
	}
}
