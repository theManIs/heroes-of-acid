extends SceneTree
## Лист кадров: каждый клип файла в нескольких моментах, чтобы понять, что в нём происходит.
## Запуск: godot --path game --script <этот файл> -- <res-путь модели> <выход.png>
## Подпись строк — порядок клипов, он печатается в лог.

const COLUMNS := 6
const CELL := 260
const HEIGHT := 1.3


func _initialize() -> void:
	await process_frame  # до первого кадра дерево ещё не собрано и камера не встанет
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i.ONE * CELL
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.5, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 25.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(4.0, 2.2, 6.0), Vector3(0, 0.6, 0))
	var model: Node3D = load(args[0]).instantiate()
	root.add_child(model)
	var box: AABB = model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	model.scale = Vector3.ONE * HEIGHT / box.size.y
	model.position = -box.get_center() * model.scale.x + Vector3.UP * HEIGHT * 0.5
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var clips := Array(player.get_animation_list()).filter(func(c: String) -> bool: return not c.contains("|"))  # копии с приставкой неполные
	var sheet := Image.create_empty(CELL * COLUMNS, CELL * clips.size(), false, Image.FORMAT_RGBA8)
	for row in clips.size():
		print("ROW ", row, " ", clips[row], " ", snappedf(player.get_animation(clips[row]).length, 0.01))
		player.play(clips[row])
		player.pause()
		for col in COLUMNS:
			player.seek(player.get_animation(clips[row]).length * col / (COLUMNS - 1.0), true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
	sheet.save_png(args[1])
	quit()
