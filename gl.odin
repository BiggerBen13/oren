#+private
package oren 

import gl "odingl"

import "core:log"

PosIndex :: 0
TransformationIndex :: 1

_gl_Renderer :: struct {
	vao:                gl.VertexArray,
	vertex_buf:         gl.Buffer,
	index_buf:          gl.Buffer,
	transformation_buf: gl.Buffer,
	program:            gl.Program,
}

_gl_init_renderer :: proc() -> (render_int: _gl_Renderer) {
	_gl_create_buffers(&render_int)
	_gl_configure_buffers(&render_int)
	_gl_load_program(&render_int)

	return render_int
}

_gl_load_program :: proc(rend: ^_gl_Renderer) {
	vertex_shad, vert_err := gl.shader_create_from_file("shaders/renderer_vert.glsl", .Vertex)
	if vert_err != nil {
		log.error("couldn't compile vertex shader:", vert_err)
	}
	defer gl.shader_delete(vertex_shad)

	frag_shad, frag_err := gl.shader_create_from_file("shaders/renderer_frag.glsl", .Fragment)
	if frag_err != nil {
		log.error("couldn't compile fragment shader:", frag_err)
	}
	defer gl.shader_delete(frag_shad)
	shaders := [?]gl.Shader{vertex_shad, frag_shad}

	program, prog_err := gl.program_create_and_link(shaders[:])
	if prog_err != nil {
		log.error("couldn't link program:", prog_err)
	}
	rend.program = program
}

_gl_create_buffers :: proc(rend: ^_gl_Renderer) {
	gl.vertex_array_create(&rend.vao)
	gl.buffer_create(&rend.vertex_buf)
	gl.buffer_create(&rend.index_buf)
	gl.buffer_create(&rend.transformation_buf)
}

_gl_configure_buffers :: proc(rend: ^_gl_Renderer) {
	gl.vertex_array_bind(rend.vao)
	defer gl.vertex_array_unbind()

	gl.buffer_bind(rend.index_buf, .ElementArrayBuffer)

	gl.buffer_bind(rend.vertex_buf, .ArrayBuffer)
	vertex_attrib := gl.AttribDescriptor {
		size      = 3,
		type      = .Float,
		normalize = false,
		stride    = 3 * size_of(f32),
		pointer   = 0,
	}

	gl.vertex_attributes_set(PosIndex, vertex_attrib)

	gl.buffer_bind(rend.transformation_buf, .ArrayBuffer)

	column_size :: 4 * size_of(f32)
	mat_size :: size_of(matrix[4, 4]f32)

	trans_row_attrib := gl.AttribDescriptor {
		size      = 4,
		type      = .Float,
		normalize = false,
		stride    = mat_size,
		pointer   = 0,
	}

	gl.vertex_attributes_set(TransformationIndex, trans_row_attrib)
	trans_row_attrib.pointer += column_size
	gl.vertex_attributes_set(TransformationIndex + 1, trans_row_attrib)
	trans_row_attrib.pointer += column_size
	gl.vertex_attributes_set(TransformationIndex + 2, trans_row_attrib)
	trans_row_attrib.pointer += column_size
	gl.vertex_attributes_set(TransformationIndex + 3, trans_row_attrib)

	gl.vertex_attributes_set_divisor(TransformationIndex, 1)
	gl.vertex_attributes_set_divisor(TransformationIndex + 1, 1)
	gl.vertex_attributes_set_divisor(TransformationIndex + 2, 1)
	gl.vertex_attributes_set_divisor(TransformationIndex + 3, 1)

	gl.vertex_attributes_enable(PosIndex)
	gl.vertex_attributes_enable(TransformationIndex)
	gl.vertex_attributes_enable(TransformationIndex + 1)
	gl.vertex_attributes_enable(TransformationIndex + 2)
	gl.vertex_attributes_enable(TransformationIndex + 3)
}

_gl_bind_transformations :: proc(ptr: rawptr, transformations: []Transform) {
	rend := cast(^_gl_Renderer)ptr

	gl.vertex_array_bind(rend.vao)
	defer gl.vertex_array_unbind()

	gl.buffer_bind(rend.transformation_buf, .ArrayBuffer)
	gl.buffer_data(rend.transformation_buf, .ArrayBuffer, transformations, .StaticDraw)
}

_gl_bind_model_data :: proc(ptr: rawptr, vertices: []Vertex, indices: []Index) {
	rend := cast(^_gl_Renderer)ptr
	gl.vertex_array_bind(rend.vao)
	defer gl.vertex_array_unbind()
	gl.buffer_bind(rend.vertex_buf, .ArrayBuffer)
	gl.buffer_data(rend.vertex_buf, .ArrayBuffer, vertices, .StaticDraw)
	gl.buffer_bind(rend.index_buf, .ElementArrayBuffer)
	gl.buffer_data(rend.index_buf, .ElementArrayBuffer, indices, .StaticDraw)
}

_gl_draw_model :: proc(ptr: rawptr, model: _Model, count: uint) {
	rend := cast(^_gl_Renderer)ptr
	gl.vertex_array_bind(rend.vao)
	defer gl.vertex_array_unbind()
	gl.program_use(rend.program)
	gl.draw_elements_instanced_base_vertex(
		.Triangles,
		i32(model.len_idx),
		.uInt,
		cast(rawptr)uintptr(model.start_idx * size_of(Index)),
		i32(count),
		i32(model.start_vert),
	)
}

_gl_destroy :: proc(ptr: rawptr) {
	rend := cast(^_gl_Renderer)ptr
	gl.vertex_array_delete(&rend.vao)
	gl.buffer_delete(&rend.index_buf)
	gl.buffer_delete(&rend.vertex_buf)
	gl.buffer_delete(&rend.transformation_buf)
	gl.program_delete(rend.program)
}

_gl_bind_projection :: proc(ptr: rawptr, projection: ^matrix[4, 4]f32) {
	rendr := cast(^_gl_Renderer)ptr
	gl.program_use(rendr.program)
	gl.uniform_set_4x4f32(0, false, projection)
}

gl_renderer :: proc(gl_renderer: ^_gl_Renderer) -> RendererInterface {
	return RendererInterface {
		bind_projection = _gl_bind_projection,
		bind_transformations = _gl_bind_transformations,
		bind_model_data = _gl_bind_model_data,
		render_model = _gl_draw_model,
		destroy = _gl_destroy,
	}
}
