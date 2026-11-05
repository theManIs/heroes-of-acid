extends RefCounted
## Neutral reflection environment for the hammerer's showcase and creature arena.


static func apply(root: Node, enabled := true) -> void:
	var world: WorldEnvironment = root.find_children("*", "WorldEnvironment", false, false)[0]
	var env := world.environment
	var fill := root.get_node_or_null("MetalFill")
	if not world.has_meta("metal_light_saved"):
		world.set_meta("metal_light_saved", true)
		world.set_meta("original_sky", env.sky)
		world.set_meta("original_reflections", env.reflected_light_source)
	if not enabled:
		env.sky = world.get_meta("original_sky") if world.has_meta("original_sky") else null
		env.reflected_light_source = world.get_meta("original_reflections")
		if fill:
			root.remove_child(fill)
			fill.queue_free()
		return
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.65, 0.68, 0.72)
	material.sky_horizon_color = Color(0.85, 0.85, 0.85)
	material.ground_horizon_color = Color(0.72, 0.72, 0.72)
	material.ground_bottom_color = Color(0.35, 0.36, 0.38)
	env.sky = Sky.new()
	env.sky.sky_material = material
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if fill:
		return
	fill = DirectionalLight3D.new()
	fill.name = "MetalFill"
	fill.rotation_degrees = Vector3(-30, -140, 0)
	fill.light_color = Color(0.9, 0.94, 1.0)
	fill.light_energy = 0.75
	root.add_child(fill)
