package oren

import gl "vendor:OpenGL"

RENDERER_GL :: #config(RENDERER_GL, true)

// when RENDERER_GL {
internalRenderer :: _gl_Renderer
// }

Renderer :: struct {
	vertex_buf: [dynamic]Vertex,
	index_buf:  [dynamic]Index,
	uv_buf:     [dynamic]Uv,
	_internal:  internalRenderer,
	_interface: RendererInterface,
	_models:    [dynamic]_Model,
}


RendererInterface :: struct {
	bind_projection:      proc(_: rawptr, _: ^matrix[4, 4]f32),
	bind_transformations: proc(_: rawptr, _: []Transform),
	bind_model_data:      proc(_: rawptr, _: []Vertex, _: []Index, _: []Uv),
	render_model:         proc(_: rawptr, model: _Model, count: uint),
	destroy:              proc(_: rawptr),
}


Vertex :: [3]f32

Index :: u32

Uv :: [2]f32

ModelHandle :: distinct uint

Transform :: matrix[4, 4]f32

@(private)
_Model :: struct {
	start_vert: uint,
	len_vert:   uint,
	start_idx:  uint,
	len_idx:    uint,
}

renderer_init :: proc(proc_addr: gl.Set_Proc_Address_Type) {
	OPENGL_MAJOR :: 4
	OPENGL_MINOR :: 1

	gl.load_up_to(OPENGL_MAJOR, OPENGL_MINOR, proc_addr)
	gl.Enable(gl.DEPTH_TEST)
}

renderer_viewport_set :: proc(x, y, width, height: int) {
	gl.Viewport(i32(x), i32(y), i32(width), i32(height))
}

renderer_clear :: proc(r, g, b, a: f32) {
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.ClearColor(r, g, b, a)
}

renderer_make :: proc() -> (renderer: Renderer) {
	allocator := context.allocator
	renderer.vertex_buf = make([dynamic]Vertex, allocator)
	renderer.index_buf = make([dynamic]Index, allocator)
	renderer.uv_buf = make([dynamic]Uv, allocator)
	renderer._models = make([dynamic]_Model, allocator)

	// when RENDERER_GL {
	renderer._internal = _gl_init_renderer()
	renderer._interface = gl_renderer()
	// }

	return renderer
}

renderer_delete :: proc(renderer: ^Renderer) {
	delete(renderer.index_buf)
	delete(renderer.vertex_buf)
	delete(renderer.uv_buf)
	delete(renderer._models)
	renderer._interface.destroy(&renderer._internal)
}

@(require_results)
renderer_load_model :: proc(
	renderer: ^Renderer,
	vertex_buf: []Vertex,
	index_buf: []u32,
    uv_buf: []Uv,
) -> (
	handle: ModelHandle,
) {
	vertex_start: uint = len(renderer.vertex_buf)
	vertex_len: uint = len(vertex_buf)
	index_start: uint = len(renderer.index_buf)
	index_len: uint = len(index_buf)
	handle = ModelHandle(len(renderer._models))

	append_elems(&renderer.vertex_buf, ..vertex_buf)
	append_elems(&renderer.index_buf, ..index_buf)
	append_elems(&renderer.uv_buf, ..uv_buf)
	append_elems(
		&renderer._models,
		_Model {
			start_idx = index_start,
			len_idx = index_len,
			len_vert = vertex_len,
			start_vert = vertex_start,
		},
	)

	renderer._interface.bind_model_data(
		&renderer._internal,
		renderer.vertex_buf[:],
		renderer.index_buf[:],
        renderer.uv_buf[:],
	)

	return handle
}
