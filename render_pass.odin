package oren

RenderPass :: struct {
	queues:   [][dynamic]Transform,
	renderer: ^Renderer,
}

render_pass_create :: proc(renderer: ^Renderer) -> (pass: RenderPass) {
	pass.queues = make([][dynamic]Transform, len(renderer._models))
	pass.renderer = renderer
	for &queue in pass.queues {
		queue = make([dynamic]Transform)
	}
	return pass
}

render_pass_render_model :: proc(pass: ^RenderPass, model: ModelHandle, transform: Transform) {
	append(&pass.queues[model], transform)
}

render_pass_commit :: proc(pass: ^RenderPass, world_to_clip: ^matrix[4, 4]f32) {
	// interface := &pass.renderer._interface
	internal := &pass.renderer._internal
	pass.renderer._interface.bind_projection(internal, world_to_clip)
	for queue, i in pass.queues {
		if len(queue) == 0 {continue}
		pass.renderer._interface.bind_transformations(internal, queue[:])
		pass.renderer._interface.render_model(internal, pass.renderer._models[i], len(queue))
	}
}

render_pass_reset :: proc(pass: ^RenderPass) {
	for &queue in pass.queues {
		clear(&queue)
	}
}

render_pass_delete :: proc(pass: ^RenderPass) {
	for queue in pass.queues {
		delete(queue)
	}
	delete(pass.queues)
}
