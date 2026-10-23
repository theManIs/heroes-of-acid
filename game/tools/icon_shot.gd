extends Node3D
## Пиктограммы существ: каждое в стойке idle, лицом в камеру, снимок головы и торса 256×256.
## Запуск: godot --path game res://tools/icon_shot.tscn — пишет game/assets/creatures/<id>/icon.png.

const ARENA := preload("res://scenes/creature_test.gd")
const SIZE := 256

var camera := Camera3D.new()


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.16, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	camera.fov = 30.0
	add_child(camera)
	for id: String in ARENA.CREATURES:
		await _shoot(id, ARENA.CREATURES[id])
	get_tree().quit()


func _shoot(id: String, cfg: Dictionary) -> void:
	var c := Creature.new()
	add_child(c)
	c.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	c.face(Vector3(0, 0, 10))
	c.rotation.y = c._yaw
	await get_tree().create_timer(1.2).timeout
	# Голова и плечи: фокус чуть ниже головы (у сутулых голова впереди и низко), камера чуть сверху и сбоку.
	var top := c.size_top()
	var head := c.to_global(c.to_local(c.bone_world(c.skeleton.find_bone("Head"))))
	# Подстройка кадра на существо: icon_up — сдвиг фокуса (доля роста), icon_dist — отъезд камеры.
	var focus := head + Vector3(0, top * cfg.get("icon_up", -0.08), 0)
	camera.position = focus + Vector3(0.35, 0.2, 1.0).normalized() * top * cfg.get("icon_dist", 1.15)
	camera.look_at(focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var h := img.get_height()
	var side := int(h * 0.9)
	var rect := Rect2i((img.get_width() - side) / 2, (h - side) / 2, side, side)
	img = img.get_region(rect)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path("res://assets/creatures/%s/icon.png" % id)
	img.save_png(path)
	print("icon ", path)
	c.queue_free()
