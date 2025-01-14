package main
import "base:runtime"
import "components/cvmmap"
import "core:c"
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
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3
GLSL_VERSION :: "#version 150"

SHM_NAME :: "/tmp_vid"
ZEROMQ_ADDR :: "ipc:///tmp/tmp_vid"


gui_main :: proc() {
	context.logger = log.create_console_logger(log.Level.Debug)
	assert(cast(bool)glfw.Init(), "Failed to initialize GLFW")
	defer glfw.Terminate()

	// Set Window Hints
	// https://www.glfw.org/docs/latest/window_guide.html#window_hints
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.RESIZABLE, 1)

	window := glfw.CreateWindow(640, 800, "Test", nil, nil)
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

	client := cvmmap.create(SHM_NAME, ZEROMQ_ADDR)
	log.info("created")
	defer {
		cvmmap.destroy(client)
		log.info("destroyed")
	}
	TextureInfo :: struct {
		texture_buffer: []u8,
		width:          u32,
		height:         u32,
		is_dirty:       bool,
	}
	texture_index: Maybe(u32) = nil
	info: Maybe(TextureInfo) = nil
	on_frame := proc(info: cvmmap.FrameInfo, frame_index: u32, buffer: []u8, user_data: rawptr) {
		texture_info := cast(^Maybe(TextureInfo))user_data
		texture_info^ = TextureInfo{buffer, u32(info.width), u32(info.height), true}
	}
	client.on_frame = on_frame
	client.user_data = &info
	error_type, _ := cvmmap.init(client)
	assert(error_type == cvmmap.CvMmapError.None, "failed to initialize cv-mmap client")
	error_type = cvmmap.start(client)
	defer {
		cvmmap.stop(client)
		log.info("stopped")
	}
	assert(error_type == cvmmap.CvMmapError.None, "failed to start cv-mmap client")

	IterContext :: struct {
		running: bool,
	}

	handle_texture :: proc(info: ^Maybe(TextureInfo), texture_index: ^Maybe(u32)) {
		if i, ok := info.?; !ok {
			return
		} else {
			if !i.is_dirty {
				return
			}
			if tid, ok := texture_index.?; ok {
				// https://learnopengl.com/Getting-started/Textures
				// https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
				// glTexSubImage2D to update the texture (I'm assuming the parameters are the same)
				// gl.BindTexture(gl.TEXTURE_2D, tid)
				// gl.TexSubImage2D(
				// 	gl.TEXTURE_2D,
				// 	0,
				// 	0,
				// 	0,
				// 	cast(i32)i.width,
				// 	cast(i32)i.height,
				// 	gl.RGBA,
				// 	gl.UNSIGNED_BYTE,
				// 	raw_data(i.texture_buffer),
				// )
			} else {
				// Create a OpenGL texture identifier
				t_tid: u32
				gl.GenTextures(1, &t_tid)
				gl.BindTexture(gl.TEXTURE_2D, t_tid)
				binding: i32
				// Setup filtering parameters for display
				gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
				gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
				// Upload pixels into texture
				gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)

				// gl.GetIntegerv(gl.TEXTURE_BINDING_2D, &binding)
				// log.infof("TextureID={}; Texture binding ID={}", t_tid, binding)
				// https://docs.gl/gl3/glTexImage2D
				// https://github.com/drbrain/opengl/blob/master/ext/opengl/gl-enums.h
				gl.TexImage2D(
					gl.TEXTURE_2D,
					0,
					gl.BGR,
					cast(i32)i.width,
					cast(i32)i.height,
					0,
					gl.RGBA,
					gl.UNSIGNED_BYTE,
					raw_data(i.texture_buffer),
				)
				err := gl.GetError()
				if err != gl.NO_ERROR {
					log.errorf("Error={}", err)
				}
				texture_index^ = t_tid
			}
			// un-mark dirty
			info^ = TextureInfo{i.texture_buffer, i.width, i.height, false}
		}
	}

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		imgui_impl_opengl3.NewFrame()
		imgui_impl_glfw.NewFrame()
		im.NewFrame()

		handle_texture(&info, &texture_index)
		if im.Begin("Window containing a quit button") {
			if im.Button("quit me!") {
				glfw.SetWindowShouldClose(window, true)
			}
			if tid, ok := texture_index.?; ok {
				if i, okk := info.?; okk {
					im.Image(
						cast(im.TextureID)(uintptr(tid)),
						im.Vec2{cast(f32)i.width, cast(f32)i.height},
					)
				}
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

main :: proc() {
	// cli_main()
	gui_main()
}
