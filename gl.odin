#+private
package oren

import gl "vendor:OpenGL"

import "core:log"

PosIndex :: 0
UvIndex :: 1
TransformationIndex :: 2

CameraUniformName :: "mvp"

g_camera_uniform_location: i32

VertexShaderSrc :: #load("shaders/renderer_vert.glsl")
FragmentShaderSrc :: #load("shaders/renderer_frag.glsl")

_gl_Renderer :: struct {
	vao:                u32,
	vertex_buf:         u32,
	index_buf:          u32,
	uv_buf:             u32,
	transformation_buf: u32,
	program:            u32,
}


_gl_init_renderer :: proc() -> (render_int: _gl_Renderer) {
	_gl_create_buffers(&render_int)
	_gl_configure_buffers(&render_int)
	_gl_load_program(&render_int)

	return render_int
}

get_shader_status :: proc(shader: u32) -> (ok: bool) {
	status, log_len: i32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &status)
	if status != 0 {
		return true
	}

	gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &log_len)

	info_log := make([]u8, log_len, context.temp_allocator)
	gl.GetShaderInfoLog(shader, log_len, nil, raw_data(info_log))

	log.logf(.Error, "OPENGL SHADER_INFO: %s", string(info_log))
	return false
}

get_link_status :: proc(program: u32) -> (ok: bool) {
	status, log_len: i32
	gl.GetProgramiv(program, gl.LINK_STATUS, &status)
	if status != 0 {
		return true
	}

	gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_len)

	info_log := make([]u8, log_len, context.temp_allocator)
	gl.GetProgramInfoLog(program, log_len, nil, raw_data(info_log))

	log.logf(.Error, "OPENGL LINK_INFO: %s", string(info_log))
	return false
}

compile_shader_from_source :: proc(src: []u8, type: u32) -> (shader: u32) {
	source_len := i32(len(src))
	source := cstring(raw_data(src))
	shader = gl.CreateShader(type)
	gl.ShaderSource(shader, 1, &source, &source_len)
	gl.CompileShader(shader)
	if !get_shader_status(shader) {
		panic("couldn't compile shader")
	}
	return shader
}

_gl_load_program :: proc(rend: ^_gl_Renderer) {
	vertex_shad := compile_shader_from_source(VertexShaderSrc, gl.VERTEX_SHADER)
	defer gl.DeleteShader(vertex_shad)


	frag_shad := compile_shader_from_source(FragmentShaderSrc, gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(frag_shad)

	program := gl.CreateProgram()

	gl.AttachShader(program, vertex_shad)
	gl.AttachShader(program, frag_shad)

	gl.LinkProgram(program)

	if !get_link_status(program) {
		panic("couldn't link program")
	}
   
    g_camera_uniform_location = gl.GetUniformLocation(program, CameraUniformName)

	rend.program = program
}

_gl_create_buffers :: proc(rend: ^_gl_Renderer) {
	gl.GenVertexArrays(1, &rend.vao)
	gl.GenBuffers(1, &rend.vertex_buf)
	gl.GenBuffers(1, &rend.index_buf)
	gl.GenBuffers(1, &rend.uv_buf)
	gl.GenBuffers(1, &rend.transformation_buf)
}

_gl_configure_buffers :: proc(rend: ^_gl_Renderer) {
	gl.BindVertexArray(rend.vao)
	defer gl.BindVertexArray(0)

	// INDICES
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rend.index_buf)
	// VERTICES
	gl.BindBuffer(gl.ARRAY_BUFFER, rend.vertex_buf)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), 0)

	// UVS
	gl.BindBuffer(gl.ARRAY_BUFFER, rend.uv_buf)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 2 * size_of(f32), 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, rend.transformation_buf)

	// Transformations
	column_size :: 4 * size_of(f32)
	mat_size :: size_of(matrix[4, 4]f32)

	pointer: uintptr = 0

	gl.VertexAttribPointer(TransformationIndex, 4, gl.FLOAT, false, mat_size, pointer)
	pointer += column_size
	gl.VertexAttribPointer(TransformationIndex + 1, 4, gl.FLOAT, false, mat_size, pointer)
	pointer += column_size
	gl.VertexAttribPointer(TransformationIndex + 2, 4, gl.FLOAT, false, mat_size, pointer)
	pointer += column_size
	gl.VertexAttribPointer(TransformationIndex + 3, 4, gl.FLOAT, false, mat_size, pointer)

	gl.VertexAttribDivisor(TransformationIndex, 1)
	gl.VertexAttribDivisor(TransformationIndex + 1, 1)
	gl.VertexAttribDivisor(TransformationIndex + 2, 1)
	gl.VertexAttribDivisor(TransformationIndex + 3, 1)

	gl.EnableVertexAttribArray(PosIndex)
	gl.EnableVertexAttribArray(UvIndex)
	gl.EnableVertexAttribArray(TransformationIndex)
	gl.EnableVertexAttribArray(TransformationIndex + 1)
	gl.EnableVertexAttribArray(TransformationIndex + 2)
	gl.EnableVertexAttribArray(TransformationIndex + 3)
}

_gl_bind_transformations :: proc(ptr: rawptr, transformations: []Transform) {
	rend := cast(^_gl_Renderer)ptr

	gl.BindBuffer(gl.ARRAY_BUFFER, rend.transformation_buf)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(transformations) * size_of(Transform),
		raw_data(transformations),
		gl.STATIC_DRAW,
	)
}

_gl_bind_model_data :: proc(ptr: rawptr, vertices: []Vertex, indices: []Index, uvs: []Uv) {
	rend := cast(^_gl_Renderer)ptr

	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	// Vertices
	gl.BindBuffer(gl.ARRAY_BUFFER, rend.vertex_buf)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	// Uvs
	gl.BindBuffer(gl.ARRAY_BUFFER, rend.uv_buf)
	gl.BufferData(gl.ARRAY_BUFFER, len(uvs) * size_of(Uv), raw_data(uvs), gl.STATIC_DRAW)

	// Indices
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rend.index_buf)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(Index),
		raw_data(indices),
		gl.STATIC_DRAW,
	)
}

_gl_draw_model :: proc(ptr: rawptr, model: _Model, count: uint) {
	rend := cast(^_gl_Renderer)ptr

	gl.BindVertexArray(rend.vao)
	defer gl.BindVertexArray(0)

	gl.UseProgram(rend.program)
	gl.DrawElementsInstancedBaseVertex(
		gl.TRIANGLES,
		i32(model.len_idx),
		gl.UNSIGNED_INT,
		cast(rawptr)uintptr(model.start_idx * size_of(Index)),
		i32(count),
		i32(model.start_vert),
	)
}

_gl_destroy :: proc(ptr: rawptr) {
	rend := cast(^_gl_Renderer)ptr
	gl.DeleteVertexArrays(1, &rend.vao)
	gl.DeleteBuffers(1, &rend.index_buf)
	gl.DeleteBuffers(1, &rend.vertex_buf)
	gl.DeleteBuffers(1, &rend.transformation_buf)
	gl.DeleteBuffers(1, &rend.uv_buf)
	gl.DeleteProgram(rend.program)
}

_gl_bind_projection :: proc(ptr: rawptr, projection: ^matrix[4, 4]f32) {
	rendr := cast(^_gl_Renderer)ptr

	gl.UseProgram(rendr.program)
	gl.UniformMatrix4fv(g_camera_uniform_location, 1, false, raw_data(projection))
}

gl_renderer :: proc() -> RendererInterface {
	log.info(_gl_bind_projection)

	return RendererInterface {
		bind_projection = _gl_bind_projection,
		bind_transformations = _gl_bind_transformations,
		bind_model_data = _gl_bind_model_data,
		render_model = _gl_draw_model,
		destroy = _gl_destroy,
	}
}
