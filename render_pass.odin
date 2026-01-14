package oren

RenderPass :: struct {
	queues: [][dynamic]Transform,
}

render_pass_make :: proc(renderer: Renderer, allocator := context.allocator) -> (pass: RenderPass) {
	pass.queues = make([][dynamic]Transform, len(renderer._models), allocator)
	for &queue in pass.queues {
		queue = make([dynamic]Transform)
	}
	return pass
}

render_pass_render_model :: proc(pass: ^RenderPass, model: ModelHandle, transform: Transform) {
	append(&pass.queues[model], transform)
}

render_pass_commit :: proc(
	pass: ^RenderPass,
	renderer: ^Renderer,
	world_to_clip: ^matrix[4, 4]f32,
) {
	// interface := &pass.renderer._interface
	internal := renderer._internal
	renderer._interface.bind_projection(&renderer._internal, world_to_clip)
	for queue, i in pass.queues {
		if len(queue) == 0 {continue}
		renderer._interface.bind_transformations(&renderer._internal, queue[:])
		renderer._interface.render_model(&renderer._internal, renderer._models[i], len(queue))
	}
}

render_pass_reset :: proc(pass: ^RenderPass) {
	for &queue in pass.queues {
		clear(&queue)
	}
}

render_pass_delete :: proc(pass: ^RenderPass, allocator := context.allocator) {
	for queue in pass.queues {
		delete(queue)
	}
	delete(pass.queues, allocator)
}
