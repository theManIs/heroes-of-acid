extends Node3D
## Витрина: существо стоит на траве и по кругу показывает всё, что умеет, как в окне покупки в Героях.
## Стрелки влево и вправо или клик — другое существо.
## Запуск: godot --path game res://scenes/showcase.tscn
## Отладка: -- --id=<существо> --shot=<префикс> — кадры <префикс>-<анимация>.png за один круг, потом выход.

const ARENA := preload("res://scenes/creature_test.gd")  # записи существ: модели и анимации
const PAUSE := 1.2  # стойка между анимациями, секунд
const WALK_TIME := 3.0  # сколько идёт на месте, секунд
const CAMERA_FOV := 25.0
const CAMERA_DIR := Vector3(0.45, 0.45, 1.0)  # сбоку и немного сверху
const FRAME := 1.5  # сколько высот существа входит в кадр

var camera := Camera3D.new()
var title := Label.new()
var ids: Array = ARENA.CREATURES.keys()
var index := 0
var unit: Creature
var _round := 0  # смена существа обрывает прежний круг
var _shot := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--id="):
			index = maxi(ids.find(arg.trim_prefix("--id=")), 0)
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	_build_world()
	camera.fov = CAMERA_FOV
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_child(title)
	_show_unit()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.76, 0.9)
	env.environment.ambient_light_energy = 0.9
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_color = Color(1.0, 0.88, 0.74)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 60.0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ground/grass.png")
	mat.albedo_color = Color(0.52, 0.62, 0.46)
	mat.roughness = 1.0
	mat.uv1_scale = Vector3.ONE * 10.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	add_child(ground)


func _show_unit() -> void:
	_round += 1
	if unit:
		unit.queue_free()
	var cfg: Dictionary = ARENA.CREATURES[ids[index]]
	unit = Creature.new()
	add_child(unit)
	unit.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	if cfg.has("variants"):
		unit.set_textures(cfg.variants[-1].get("textures", {}))
		if cfg.variants[-1].has("glow"):
			unit.add_glow(cfg.variants[-1].glow)
	if cfg.get("smoke", false):
		unit.add_smoke()
	unit.defend_from = cfg.defend_from
	unit.defend_len = cfg.defend_len
	unit.hurt_len = cfg.hurt_len
	unit.face(unit.position + Vector3.RIGHT)
	var look := Vector3(0, cfg.size * 0.5, 0)
	var dist: float = cfg.size * FRAME * 0.5 / tan(deg_to_rad(CAMERA_FOV * 0.5))
	camera.position = look + CAMERA_DIR.normalized() * dist
	camera.look_at(look)
	_cycle(cfg, _round)


## Один круг: стойка, удар, ходьба, реакция, защита, смерть. Каждая запись: подпись, анимация, с какой доли, сколько секунд.
func _cycle(cfg: Dictionary, id: int) -> void:
	while id == _round:
		var steps := [
			["стойка", "idle", 0.0, PAUSE * 2.0],
			["удар", cfg.attack, cfg.attack_from, 0.0],
			["ходьба", "walk", 0.0, WALK_TIME],
			["реакция на удар", cfg.hurt, 0.0, cfg.hurt_len],
			["защита", cfg.defend, cfg.defend_from, cfg.defend_len],
			["смерть", "fall", 0.0, 0.0],
		]
		for step: Array in steps:
			if not unit.anim.has_animation(step[1]):
				continue
			title.text = "%s: %s" % [cfg.name, step[0]]
			unit.anim.play(step[1], 0.2)
			unit.anim.seek(unit.anim.get_animation(step[1]).length * step[2], true)
			var time: float = step[3] if step[3] > 0.0 else unit.anim.get_animation(step[1]).length * (1.0 - step[2])
			await get_tree().create_timer(time * 0.5).timeout
			if id != _round:
				return
			_save_shot(step[1])
			await get_tree().create_timer(time * 0.5).timeout
			if id != _round:
				return
			if step[1] != "fall":
				unit.anim.play("idle", 0.3)
				await get_tree().create_timer(PAUSE).timeout
				if id != _round:
					return
		await get_tree().create_timer(PAUSE).timeout
		if _shot != "":
			get_tree().quit()
			return


func _save_shot(anim_name: String) -> void:
	if _shot != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s-%s.png" % [_shot, anim_name])


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("ui_left"):
		step = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		step = 1
	if step != 0:
		index = posmod(index + step, ids.size())
		_show_unit()
