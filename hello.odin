package main

import "core:fmt"


// https://odin.handmade.network/blog/p/1723-the_metaprogramming_dilemma
// I can't apply anything compile-time check like C++ template
// or Zig comptime
// 
// https://odin-lang.org/docs/overview/#procedures-using-explicit-parametric-polymorphism-parapoly
do_n_times :: proc(n: u32, f: proc(_: u32, _: rawptr), ctx: rawptr) {
	for i := u32(0); i < n; i += 1 {
		f(i, ctx)
	}
}

main :: proc() {
	fmt.println("Hello from outside")
	LocalContext :: struct {
		x: u8,
		y: u8,
		z: f32,
	}
	ctx := LocalContext{1, 2, 3.0}

	// do it like C...
	// > Odin only has non-capturing lambda procedures. 
	// For closures to work correctly would require a form of automatic memory management 
	// which will never be implemented into Odin.
	// I'm fine with it
	do_n_times(3, proc(i: u32, p_ctx: rawptr) {
			ctx := cast(^LocalContext)p_ctx
			fmt.printfln("inside! x={} y={} z={} for {}", ctx.x, ctx.y, ctx.z, i)
		}, &ctx)
}
