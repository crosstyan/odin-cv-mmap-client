package main
import "base:runtime"
import "components/cvmmap"
import "core:c"
import "core:flags"
import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"
import "core:sync"
import "core:sys/posix"
import aux "lib/aux-img"
import aux_info "lib/aux-img/info"
import aux_skt "lib/aux-img/socket"
import im "lib/odin-imgui"
import "lib/odin-imgui/imgui_impl_glfw"
import "lib/odin-imgui/imgui_impl_opengl3"
import zmq "lib/odin-zeromq"
import gl "vendor:OpenGL"
import "vendor:glfw"

// https://gitlab.com/L-4/odin-imgui/-/blob/main/examples/glfw_opengl3/main.odin?ref_type=heads
// https://gist.github.com/SorenSaket/155afe1ec11a79def63341c588ade329

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)
// will modify the image buffer, which means you SHOULD NOT write to the buffer
// but to copy the buffer to a new one, and then modify it
MODIFY_IMAGE :: true
// OpenGL 3.3
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3
GLSL_VERSION :: "#version 330"

BIN_ZEROMQ_ADDR :: "ipc:///tmp/tmp_bin"

// check and unset the flag, return the original flag value
check_and_unset :: proc(flag: ^bool) -> bool {
	r := flag^
	flag^ = false
	return r
}

gui_main :: proc(instance_name: string) {
	context.logger = log.create_console_logger(log.Level.Debug)
	assert(cast(bool)glfw.Init(), "failed to initialize GLFW")
	defer glfw.Terminate()

	zmq_ctx := zmq.ctx_new()
	defer zmq.ctx_term(zmq_ctx)
	// http://wiki.zeromq.org/results:10gbe-tests
	// https://zguide.zeromq.org/docs/chapter2/#Messaging-Patterns
	// 
	//  We will use these often, but `zmq_recv()` is bad at dealing with
	//  arbitrary message sizes: it truncates messages to whatever buffer size
	//  you provide. So there's a second API that works with `zmq_msg_t`
	//  structures, with a richer but more difficult API

	client := cvmmap.create(instance_name, zmq_ctx)
	log.info("created")
	defer {
		cvmmap.destroy(client)
		log.info("cv-mmap client destroyed")
	}
	if err := cvmmap.init(client); err != nil {
		log.errorf("failed to initialize cv-mmap client: %v", err)
		assert(false, "failed to initialize cv-mmap client")
	}

	bin_client := aux_skt.create(BIN_ZEROMQ_ADDR, zmq_ctx)
	defer {
		aux_skt.destroy(bin_client)
		log.info("bin socket destroyed")
	}

	SharedPoseInfo :: struct {
		mutex: sync.Mutex,
		data:  Maybe(aux_info.PoseInfo),
	}
	pose_info := SharedPoseInfo{sync.Mutex{}, nil}
	on_bin_frame :: proc(info: aux_info.PoseInfo, user_data: rawptr) -> bool {
		shared_pose_info := cast(^SharedPoseInfo)user_data
		if sync.mutex_guard(&shared_pose_info.mutex) {
			if data, ok := shared_pose_info.data.?; ok {
				aux_info.destroy(&data)
			}
			shared_pose_info.data = info
		}
		return true
	}
	bin_client.on_info = on_bin_frame
	bin_client.user_data = &pose_info

	if err := aux_skt.init(bin_client); err != nil {
		log.errorf("failed to initialize aux-skt client: %v", err)
		assert(false, "failed to initialize aux-skt client")
	}

	if err := aux_skt.start(bin_client); err != nil {
		log.errorf("failed to start aux-skt client: %v", err)
		assert(false, "failed to start aux-skt client")
	}
	defer {
		aux_skt.stop(bin_client)
		log.info("bin socket stopped")
	}

	// Set Window Hints
	// https://www.glfw.org/docs/latest/window_guide.html#window_hints
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.RESIZABLE, 1)

	// https://stackoverflow.com/questions/66299684/how-to-prevent-glfw-window-from-showing-up-right-in-creating
	// https://github.com/glfw/glfw/commit/cd8df53d96a3f05ab66032fbaa69b3eead7f6295
	glfw.WindowHint_bool(glfw.VISIBLE, true)
	glfw.WindowHint_bool(glfw.DECORATED, true)
	glfw.WindowHint_bool(glfw.FLOATING, false)
	window := glfw.CreateWindow(640, 800, "Hello", nil, nil)
	assert(window != nil, "Failed to create window")
	defer glfw.DestroyWindow(window)
	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1) // vsync

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glfw.GetProcAddress(name)
	})

	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}

	when !DISABLE_DOCKING {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := im.GetStyle()
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}

	im.StyleColorsDark()
	assert(imgui_impl_glfw.InitForOpenGL(window, true), "failed to initialize ImGui GLFW")
	defer imgui_impl_glfw.Shutdown()
	assert(imgui_impl_opengl3.Init(GLSL_VERSION), "failed to initialize ImGui OpenGL3")
	defer imgui_impl_opengl3.Shutdown()

	TextureInfo :: struct {
		// if it's nil, it will use the shared memory buffer
		// directly;
		allocator:      Maybe(runtime.Allocator),
		texture_buffer: []u8,
		width:          u32,
		height:         u32,
	}

	VideoRenderContext :: struct {
		_has_info_init: bool,
		_has_gl_init:   bool,
		is_dirty:       bool,
		texture_index:  u32,
		info:           TextureInfo,
		pose_info:      ^SharedPoseInfo,
	}

	render_ctx := VideoRenderContext {
		false,
		false,
		false,
		0,
		TextureInfo{nil, nil, 0, 0},
		&pose_info,
	}
	gl_texture_from_bgr_buffer :: proc(buffer: []u8, width: u32, height: u32) -> u32 {
		// Create a OpenGL texture identifier
		tid: u32
		gl.GenTextures(1, &tid)
		gl.BindTexture(gl.TEXTURE_2D, tid)
		// Setup filtering parameters for display
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
		// Upload pixels into texture
		gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
		// https://docs.gl/gl3/glTexImage2D
		// https://github.com/drbrain/opengl/blob/master/ext/opengl/gl-enums.h
		// https://stackoverflow.com/questions/4745264/opengl-gl-bgr-not-working-for-texture-internal-format
		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGB,
			cast(i32)width,
			cast(i32)height,
			0,
			gl.BGR,
			gl.UNSIGNED_BYTE,
			raw_data(buffer),
		)
		return tid
	}

	client.on_frame =
	proc(metadata: cvmmap.FrameMetadata, buffer: []u8, user_data: rawptr) {
		info := metadata.info
		frame_index := metadata.frame_index
		ctx_opt := cast(^VideoRenderContext)user_data
		pose_info := ctx_opt.pose_info
		assert(ctx_opt != nil, "invalid user_data")
		when !MODIFY_IMAGE {
			ctx_opt.info = TextureInfo{nil, buffer, u32(info.width), u32(info.height)}
		} else {
			modify :: proc(
				data: rawptr,
				info: cvmmap.FrameInfo,
				pose_info: ^SharedPoseInfo,
				frame_index: u32,
			) {
				mat := aux.SharedMat {
					data,
					info.height,
					info.width,
					aux.Depth(info.depth),
					aux.PixelFormat(info.pixel_format),
				}
				opts := aux_info.DrawPoseOptions {
					landmark_radius        = 5,
					landmark_thickness     = -1,
					bone_thickness         = 2,
					bounding_box_thickness = 5,
					bounding_box_color     = {0, 250, 0},
				}
				if sync.mutex_guard(&pose_info.mutex) {
					if data, ok := pose_info.data.?; ok {
						in_range :: proc(val: u32, min: u32, max: u32) -> bool {
							return val >= min && val <= max
						}
						if in_range(data.frame_index, frame_index - 6, frame_index + 6) {
							aux_info.draw(mat, &data, opts)
						}
					}
				}
			}
			if !ctx_opt._has_info_init {
				loc_buf := make([]u8, len(buffer))
				copy(loc_buf, buffer)
				ctx_opt.info = TextureInfo {
					context.allocator,
					loc_buf,
					u32(info.width),
					u32(info.height),
				}
				modify(raw_data(ctx_opt.info.texture_buffer), info, pose_info, frame_index)
			} else {
				assert(ctx_opt.info.texture_buffer != nil, "invalid texture buffer")
				assert(len(ctx_opt.info.texture_buffer) == len(buffer), "invalid buffer size")
				copy(ctx_opt.info.texture_buffer, buffer)
				modify(raw_data(ctx_opt.info.texture_buffer), info, pose_info, frame_index)
			}
		}
		if !ctx_opt._has_info_init {
			ctx_opt._has_info_init = true
		}
		ctx_opt.is_dirty = true
	}
	client.user_data = &render_ctx
	if err := cvmmap.start(client); err != nil {
		log.errorf("failed to start cv-mmap client: %v", err)
		assert(false, "failed to start cv-mmap client")
	}
	defer {
		cvmmap.stop(client)
		log.info("cv-mmap client stopped")
	}

	handle_texture :: proc(self: ^VideoRenderContext) {
		if !self._has_info_init {
			return
		}
		if !self._has_gl_init {
			assert(self.info.texture_buffer != nil, "invalid texture buffer")
			assert(self.is_dirty, "invalid dirty state, expecting true")
			self.texture_index = gl_texture_from_bgr_buffer(
				self.info.texture_buffer,
				self.info.width,
				self.info.height,
			)
			self._has_gl_init = true
			self.is_dirty = false
			return
		}

		if check_and_unset(&self.is_dirty) {
			// https://learnopengl.com/Getting-started/Textures
			// https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
			// glTexSubImage2D to update the texture (I'm assuming the parameters are the same)
			gl.BindTexture(gl.TEXTURE_2D, self.texture_index)
			gl.TexSubImage2D(
				gl.TEXTURE_2D,
				0,
				0,
				0,
				cast(i32)self.info.width,
				cast(i32)self.info.height,
				gl.BGR,
				gl.UNSIGNED_BYTE,
				raw_data(self.info.texture_buffer),
			)
		}
	}

	max_width_retain_ar :: proc(target_max_width: f32, width: f32, height: f32) -> (f32, f32) {
		aspect_ratio := width / height
		new_width := width
		new_height := height
		if width > target_max_width {
			new_width = target_max_width
			new_height = new_width / aspect_ratio
		}
		return new_width, new_height
	}

	// call this function in the imgui loop, when targeting a window
	imgui_follow_glfw_window :: proc(window: glfw.WindowHandle) {
		pos_x, pos_y := glfw.GetWindowPos(window)
		size_x, size_y := glfw.GetWindowSize(window)
		im.SetWindowPos(im.Vec2{cast(f32)pos_x, cast(f32)pos_y}, im.Cond.Always)
		im.SetWindowSize(im.Vec2{cast(f32)size_x, cast(f32)size_y}, im.Cond.Always)
	}

	// https://news.ycombinator.com/item?id=21685027
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		imgui_impl_opengl3.NewFrame()
		imgui_impl_glfw.NewFrame()
		im.NewFrame()

		handle_texture(&render_ctx)
		// https://github.com/ocornut/imgui/issues/3693
		// https://github.com/ocornut/imgui/issues/5277
		if im.Begin("Window containing a quit button", flags = {.NoResize}) {
			imgui_follow_glfw_window(window)
			im.SetWindowSize(im.Vec2{640, 800}, im.Cond.Once)
			BORDER :: 20
			MIN_WIDTH :: 320
			window_width := im.GetWindowWidth()
			target_width: f32
			if w := window_width - BORDER; w > MIN_WIDTH {
				target_width = w
			} else {
				target_width = MIN_WIDTH
			}
			if im.Button("quit me!") {
				glfw.SetWindowShouldClose(window, true)
			}
			if render_ctx._has_gl_init {
				width, height := max_width_retain_ar(
					target_width,
					cast(f32)render_ctx.info.width,
					cast(f32)render_ctx.info.height,
				)
				im.Image(
					cast(im.TextureID)(uintptr(render_ctx.texture_index)),
					im.Vec2{width, height},
				)
			}
		}
		im.End()

		im.Render()
		display_w, display_h := glfw.GetFramebufferSize(window)
		gl.Viewport(0, 0, display_w, display_h)
		gl.ClearColor(0, 0, 0, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

		when !DISABLE_DOCKING {
			backup_current_window := glfw.GetCurrentContext()
			im.UpdatePlatformWindows()
			im.RenderPlatformWindowsDefault()
			glfw.MakeContextCurrent(backup_current_window)
		}

		glfw.SwapBuffers(window)
	}
}

cli_main :: proc(instance_name: string) {
	lk := sync.Mutex{}
	@(static) cv := sync.Cond{}
	context.logger = log.create_console_logger(log.Level.Debug)

	// for logging in the signal handler
	local_ctx: runtime.Context = context
	@(static) ctx: ^runtime.Context
	ctx = &local_ctx
	posix.signal(posix.Signal.SIGINT, proc "c" (sig: posix.Signal) {
		context = ctx^
		log.infof("signal={}", sig)
		sync.cond_signal(&cv)
	})
	log.info("signal handler set")

	client := cvmmap.create(instance_name)
	log.info("created")
	defer {
		cvmmap.destroy(client)
		log.info("destroyed")
	}
	on_frame := proc(metadata: cvmmap.FrameMetadata, buffer: []u8, user_data: rawptr) {
		log.infof("[{}] FrameInfo={}; Len={}", metadata.frame_index, metadata.info, len(buffer))
	}
	client.on_frame = on_frame
	err := cvmmap.init(client)
	assert(err == nil, fmt.tprintf("failed to initialize cv-mmap client: %v", err))
	log.info("initialized")

	err = cvmmap.start(client)
	log.info("started")
	assert(err == nil, fmt.tprintf("failed to start cv-mmap client: %v", err))
	defer {
		cvmmap.stop(client)
		log.info("stopped")
	}

	sync.cond_wait(&cv, &lk)
}


// https://github.com/odin-lang/Odin/blob/master/core/flags/example/example.odin
// https://pkg.odin-lang.org/core/flags/
main :: proc() {
	Options :: struct {
		cli:           bool `usage:"run in cli mode"`,
		instance_name: string `usage:"instance name"`,
	}
	parse_style: flags.Parsing_Style = .Odin
	opts := Options{}
	flags.parse_or_exit(&opts, os.args, parse_style)
	// https://github.com/odin-lang/Odin/blob/16eca1ded12373cd5a106d20796458a374940771/examples/demo/demo.odin#L1397
	if opts.cli {
		cli_main(opts.instance_name)
	} else {
		gui_main(opts.instance_name)
	}
}
