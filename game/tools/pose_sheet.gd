extends Node3D
## Лист поз: кадры каждой анимации существа сбоку и спереди, для проверки клипов по картинке.
## Запуск: godot --path game res://tools/pose_sheet.tscn -- --id=<существо> --out=<файл.png> [--anims=idle,walk]

const ARENA := preload("res://scenes/creature_test.gd")
const CELL := 300
const FRAMES := 5

var id := "lantern-archer"
var out := "pose_sheet.png"
var names: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--id="):
			id = arg.trim_prefix("--id=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--anims="):
			names = Array(arg.trim_prefix("--anims=").split(","))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var cfg: Dictionary = ARENA.CREATURES[id]
	var c := Creature.new()
	add_child(c)
	c.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	c.scale_bones(cfg.hurt, cfg.get("hurt_calm", []), cfg.get("hurt_calm_by", 1.0))
	c.set_process(false)
	c.set_physics_process(false)
	# Длина шага: размах стопы вперёд-назад, за половину цикла стопа на земле проходит его целиком.
	if c.anim.has_animation("walk"):
		var walk: Animation = c.anim.get_animation("walk")
		var foot := c.skeleton.find_bone("mixamorig_LeftFoot")
		c.anim.play("walk")
		var low := INF
		var high := -INF
		for step in 40:
			c.anim.seek(walk.length * step / 40.0, true)
			if foot >= 0:
				var x := c.to_local(c.bone_world(foot)).x
				low = minf(low, x)
				high = maxf(high, x)
		print("walk: длина %.2f с, размах стопы %.2f м, скорость %.2f м/с" % [walk.length, high - low, (high - low) / (walk.length * 0.5)])
	if names.is_empty():
		names = Array(c.anim.get_animation_list())
	var camera := Camera3D.new()
	camera.fov = 25.0
	add_child(camera)
	var views := [Vector3(0, 1.0, 5.0), Vector3(5.0, 1.0, 0)]  # спереди (существо лицом к +X повёрнуто ниже) и сбоку
	c.rotation.y = -PI / 2.0
	var viewport := get_viewport()
	viewport.size = Vector2i(CELL, CELL)
	DisplayServer.window_set_size(Vector2i(CELL, CELL))
	await get_tree().process_frame
	var sheet := Image.create(CELL * FRAMES, CELL * 2 * names.size(), false, Image.FORMAT_RGB8)
	for row in names.size():
		var a: Animation = c.anim.get_animation(names[row])
		c.anim.play(names[row])
		for v in views.size():
			camera.position = views[v]
			camera.look_at(Vector3(0, 1.0, 0))
			for f in FRAMES:
				c.anim.seek(a.length * f / (FRAMES - 1.0), true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var shot := viewport.get_texture().get_image()
				shot.convert(Image.FORMAT_RGB8)
				shot.resize(CELL, CELL)
				sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(f * CELL, (row * 2 + v) * CELL))
	sheet.save_png(out)
	get_tree().quit()
