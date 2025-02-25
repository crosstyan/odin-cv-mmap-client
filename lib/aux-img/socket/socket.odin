package socket

import zmq "../../odin-zeromq"
import info "../info"
import "core:log"
import "core:strings"
import "core:thread"

PoseInfo :: info.PoseInfo
Thread :: thread.Thread
OnInfo_Proc :: proc(info: PoseInfo, user_data: rawptr)
ZmqError :: zmq.ZmqError

AuxImgClient :: struct {
	_zmq_addr:     string,
	_zmq_ctx:      ^zmq.Context,
	_zmq_sock:     ^zmq.Socket,
	_polling_task: Maybe(^Thread),
	_is_running:   bool,
	// callbacks
	user_data:     rawptr,
	on_info:       OnInfo_Proc,
	_has_init:     bool,
}

create :: proc(zmq_addr: string, zmq_ctx: ^zmq.Context = nil) -> ^AuxImgClient {
	ctx := zmq_ctx if zmq_ctx != nil else zmq.ctx_new()
	client := new(AuxImgClient)
	client._zmq_addr = zmq_addr
	client._zmq_ctx = ctx
	client._zmq_sock = zmq.socket(ctx, zmq.SUB)
	client._polling_task = nil
	client._is_running = false
	client.user_data = nil
	client.on_info = nil
	client._has_init = false
	return client
}

destroy :: proc(self: ^AuxImgClient) {
	stop(self)
	zmq.close(self._zmq_sock)
	zmq.ctx_term(self._zmq_ctx)
	free(self)
}

// Refactored error types using tagged unions
AuxImgError :: union {
	ZmqError,
	StateError,
}

StateError :: enum {
	AlreadyInitialized,
	NeverInitialized,
	AlreadyRunning,
}

// Initialize the ZMQ socket and subscribe to messages
init :: proc(self: ^AuxImgClient) -> (err: AuxImgError) {
	if self._has_init {
		return StateError.AlreadyInitialized
	}

	zmq_addr_c := strings.clone_to_cstring(self._zmq_addr)
	defer delete(zmq_addr_c)

	// Set CONFLATE option to only receive the latest message
	code := cast(int)zmq.setsockopt_bool(self._zmq_sock, zmq.CONFLATE, true)
	if code != 0 {
		return ZmqError{code, "setsockopt_bool"}
	}

	// Connect to the ZMQ socket
	code = cast(int)zmq.connect(self._zmq_sock, zmq_addr_c)
	if code != 0 {
		return ZmqError{code, "connect"}
	}

	// Subscribe to all messages (empty string means subscribe to everything)
	code = cast(int)zmq.setsockopt_bytes(self._zmq_sock, zmq.SUBSCRIBE, []u8{})
	if code != 0 {
		zmq.disconnect(self._zmq_sock, zmq_addr_c)
		return ZmqError{code, "setsockopt_bytes"}
	}

	self._has_init = true
	return nil
}

@(private)
_polling_task :: proc(t: ^Thread) {
	client := cast(^AuxImgClient)t.data

	recv_data :: proc(skt: ^zmq.Socket) -> ([]u8, bool) {
		msg := zmq.Message{}
		data, ok := zmq.recv_msg_bytes(&msg, skt)
		defer zmq.msg_close(&msg)
		if !ok {
			return nil, false
		}

		data_copy := make([]u8, len(data))
		copy(data_copy, data)
		return data_copy, true
	}

	for client._is_running {
		data, ok := recv_data(client._zmq_sock)
		if !ok {
			continue
		}
		defer delete(data)

		pose_info, unmarshal_ok := info.unmarshal(data)
		if !unmarshal_ok {
			log.errorf("Failed to unmarshal pose detection info")
			continue
		}
		defer info.destroy(pose_info)

		if client.on_info != nil {
			client.on_info(pose_info, client.user_data)
		}
	}
}

start :: proc(self: ^AuxImgClient, init_context := context) -> (err: AuxImgError) {
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

stop :: proc(self: ^AuxImgClient) {
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
		self._polling_task = nil
	}
}
