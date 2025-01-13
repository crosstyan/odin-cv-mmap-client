package cvmmap
import zmq "../../lib/odin-zeromq"
import "base:runtime"
import "core:log"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import "core:thread"

Thread :: thread.Thread
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

SyncMessage :: struct #packed {
	magic:       u8,
	frame_count: u32,
	info:        FrameInfo,
}


CvMmapClient :: struct {
	_shm_name:     string,
	_zmq_addr:     string,
	_zmq_ctx:      ^zmq.Context,
	_zmq_sock:     ^zmq.Socket,
	_shm_size:     Maybe(uint),
	_shm_fd:       Maybe(posix.FD),
	_shm_ptr:      Maybe([^]u8),
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
	client._shm_size = nil
	client._shm_fd = nil
	client._shm_ptr = nil
	client._has_init = false

	client._polling_task = nil
	client._is_running = false

	client.user_data = nil
	client.on_frame = nil
	return client
}

destroy :: proc(self: ^CvMmapClient) {
	stop(self)
	if self._shm_fd != nil {
		posix.close(self._shm_fd.?)
	}
	zmq.close(self._zmq_sock)
	zmq.ctx_term(self._zmq_ctx)
	free(self)
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

init :: proc(self: ^CvMmapClient) -> (error_type: CvMmapError, code: int) {
	error_type = CvMmapError.None
	code = 0

	if self._has_init {
		error_type = CvMmapError.AlreadyInitialized
		return
	}

	zmq_addr_c := strings.clone_to_cstring(self._zmq_addr)
	defer delete(zmq_addr_c)

	code = cast(int)zmq.setsockopt_bool(self._zmq_sock, zmq.CONFLATE, true)
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}
	// http://api.zeromq.org/4-2:zmq-connect
	code = cast(int)zmq.connect(self._zmq_sock, zmq_addr_c)
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}
	topic := [1]u8{FRAME_TOPIC_MAGIC}
	code = cast(int)zmq.setsockopt_bytes(self._zmq_sock, zmq.SUBSCRIBE, topic[:])
	if code != 0 {
		error_type = CvMmapError.Zmq
		return
	}

	shm_name_c := strings.clone_to_cstring(self._shm_name)
	defer delete(shm_name_c)
	fd := posix.shm_open(shm_name_c, {.WRONLY}, {.IRUSR, .IRGRP, .IROTH})
	if fd == -1 {
		error_type = CvMmapError.Shm
		code = cast(int)posix.get_errno()
		return
	}
	self._shm_fd = fd
	self._has_init = true
	return
}

@(private)
_frame_buffer :: proc(self: ^CvMmapClient) -> ([]u8, bool) {
	ptr, ok := self._shm_ptr.?
	if !ok {
		return nil, false
	}
	size: uint
	size, ok = self._shm_size.?
	if !ok {
		return nil, false
	}
	return ptr[:size], true
}

@(private)
_polling_task :: proc(t: ^Thread) {
	client := cast(^CvMmapClient)t.data

	recv_sync_msg :: proc(skt: ^zmq.Socket) -> (SyncMessage, bool) {
		sync_msg := SyncMessage{}
		msg := zmq.Message{}
		data, ok := zmq.recv_raw_msg_as_bytes(&msg, skt)
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

	at_first_frame :: proc(client: ^CvMmapClient) -> bool {
		// https://github.com/odin-lang/Odin/issues/29
		ok: bool = ---
		assert(client._shm_fd != nil, "shm_fd is nil")
		sync_msg: SyncMessage
		sync_msg, ok = recv_sync_msg(client._zmq_sock)
		if !ok {
			return false
		}
		client._shm_size = cast(uint)sync_msg.info.buffer_size
		client._shm_ptr =
		cast(^u8)posix.mmap(nil, client._shm_size.?, {.READ}, {.SHARED}, client._shm_fd.?, 0)
		if client._shm_ptr == nil {
			log.errorf("mmap failed; errno={}", posix.get_errno())
			return false
		}
		slice: []u8
		slice, ok = _frame_buffer(client)
		if (client.on_frame != nil) && ok {
			client.on_frame(sync_msg.info, slice, client.user_data)
		}
		return true
	}

	for client._is_running {
		if client._shm_ptr == nil {
			ok := at_first_frame(client)
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
		if (client._shm_size.?) != cast(uint)sync_msg.info.buffer_size {
			log.errorf(
				"buffer size mismatch; expected={}; actual={}",
				client._shm_size.?,
				sync_msg.info.buffer_size,
			)
			continue
		}
		slice: []u8
		slice, ok = _frame_buffer(client)
		if (client.on_frame != nil) && ok {
			client.on_frame(sync_msg.info, slice, client.user_data)
		}
	}
}

start :: proc(self: ^CvMmapClient, init_context := context) -> CvMmapError {
	if !self._has_init {
		return CvMmapError.NeverInitialized
	}
	if self._is_running {
		return CvMmapError.AlreadyRunning
	}
	self._is_running = true
	self._polling_task = thread.create(_polling_task)
	self._polling_task.?.data = self
	self._polling_task.?.init_context = init_context
	thread.start(self._polling_task.?)
	return CvMmapError.None
}

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
	if self._shm_ptr != nil {
		posix.munmap(self._shm_ptr.?, self._shm_size.?)
		self._shm_ptr = nil
	}
	self._shm_size = nil
	if self._shm_fd != nil {
		posix.close(self._shm_fd.?)
		self._shm_fd = nil
	}
}
