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
import im "lib/odin-imgui"
import "lib/odin-imgui/imgui_impl_glfw"
import "lib/odin-imgui/imgui_impl_opengl3"
import zmq "lib/odin-zeromq"
import gl "vendor:OpenGL"
import "vendor:glfw"

// https://gitlab.com/L-4/odin-imgui/-/blob/main/examples/glfw_opengl3/main.odin?ref_type=heads
// https://gist.github.com/SorenSaket/155afe1ec11a79def63341c588ade329

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)
// OpenGL 3.3
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3
GLSL_VERSION :: "#version 330"

SHM_NAME :: "/tmp_vid"
ZEROMQ_ADDR :: "ipc:///tmp/tmp_vid"

gui_main :: proc() {
	context.logger = log.create_console_logger(log.Level.Debug)
	assert(cast(bool)glfw.Init(), "Failed to initialize GLFW")
	defer glfw.Terminate()

	client := cvmmap.create(SHM_NAME, ZEROMQ_ADDR)
	log.info("created")
	defer {
		cvmmap.destroy(client)
		log.info("destroyed")
	}
	error_type, _ := cvmmap.init(client)
	assert(error_type == cvmmap.CvMmapError.None, "failed to initialize cv-mmap client")

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
	assert(imgui_impl_glfw.InitForOpenGL(window, true), "Failed to initialize ImGui GLFW")
	defer imgui_impl_glfw.Shutdown()
	assert(imgui_impl_opengl3.Init(GLSL_VERSION), "Failed to initialize ImGui OpenGL3")
	defer imgui_impl_opengl3.Shutdown()

	TextureInfo :: struct {
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
	}

	render_ctx := VideoRenderContext{false, false, false, 0, TextureInfo{nil, 0, 0}}
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
	proc(info: cvmmap.FrameInfo, frame_index: u32, buffer: []u8, user_data: rawptr) {
		ctx_opt := cast(^VideoRenderContext)user_data
		assert(ctx_opt != nil, "invalid user_data")
		if !ctx_opt._has_info_init {
			ctx_opt._has_info_init = true
		}
		ctx_opt.info = TextureInfo{buffer, u32(info.width), u32(info.height)}
		ctx_opt.is_dirty = true
	}
	client.user_data = &render_ctx
	error_type = cvmmap.start(client)
	defer {
		cvmmap.stop(client)
		log.info("stopped")
	}
	assert(error_type == cvmmap.CvMmapError.None, "failed to start cv-mmap client")

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

		if self.is_dirty {
			self.is_dirty = false
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

cli_main :: proc() {
	lk := sync.Mutex{}
	@(static) cv := sync.Cond{}
	context.logger = log.create_console_logger(log.Level.Debug)

	// create a copy of the context to be (with logging)
	// available until the end of `main` stack frame
	local_ctx: runtime.Context = context
	@(static) ctx: ^runtime.Context
	ctx = &local_ctx
	posix.signal(posix.Signal.SIGINT, proc "c" (sig: posix.Signal) {
		context = ctx^
		log.infof("signal={}", sig)
		sync.cond_signal(&cv)
	})
	log.info("signal handler set")

	client := cvmmap.create(SHM_NAME, ZEROMQ_ADDR)
	log.info("created")
	defer {
		cvmmap.destroy(client)
		log.info("destroyed")
	}
	on_frame := proc(info: cvmmap.FrameInfo, frame_index: u32, buffer: []u8, user_data: rawptr) {
		log.infof("[{}] FrameInfo={}; Len={}", frame_index, info, len(buffer))
	}
	client.on_frame = on_frame
	error_type, code := cvmmap.init(client)
	log.info("initialized")
	if error_type != cvmmap.CvMmapError.None {
		log.errorf("Error={}; Code={}", error_type, code)
		return
	}
	error_type = cvmmap.start(client)
	log.info("started")
	defer {
		cvmmap.stop(client)
		log.info("stopped")
	}
	if error_type != cvmmap.CvMmapError.None {
		log.errorf("Error={}", error_type)
		return
	}
	sync.cond_wait(&cv, &lk)
}

// https://github.com/odin-lang/Odin/blob/master/core/flags/example/example.odin
// https://pkg.odin-lang.org/core/flags/
main :: proc() {
	Options :: struct {
		cli: bool `usage:"run in cli mode"`,
	}
	parse_style: flags.Parsing_Style = .Odin
	opts := Options{}
	flags.parse_or_exit(&opts, os.args, parse_style)
	if opts.cli {
		cli_main()
	} else {
		gui_main()
	}
}
