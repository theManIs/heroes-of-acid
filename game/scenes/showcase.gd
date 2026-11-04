extends Node3D
## Витрина: существа по два в ряд, каждое по кругу показывает всё, что умеет, как в окне покупки в Героях.
## Колесо, два пальца или стрелки — прокрутка списка.
## Запуск: godot --path game res://scenes/showcase.tscn
## Отладка: -- --shot=<префикс> — кадр <префикс>-list.png, потом выход.

const ARENA := preload("res://scenes/creature_test.gd")  # записи существ: модели и анимации
const PAUSE := 1.2  # стойка между анимациями, секунд
const WALK_TIME := 3.0  # сколько идёт на месте, секунд
const CAMERA_FOV := 25.0
const CAMERA_DIR := Vector3(0.0, 0.5, 1.0)  # спереди и немного сверху
const CAMERA_DIST := 13.0
const COLUMN := 2.2  # от центра до существа по ширине, метров
const ROW := 4.4  # шаг рядов, метров
const SCROLL_WHEEL := 0.6  # метров за щелчок колеса
const SCROLL_GESTURE := 0.08  # чувствительность двух пальцев
const SCROLL_KEYS := 6.0  # метров в секунду

var camera := Camera3D.new()
var _scroll := ROW * 0.5  # в кадре два ряда: смотрим между ними
var _scroll_max := 0.0
var _shot := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	_build_world()
	camera.fov = CAMERA_FOV
	add_child(camera)
	var ids: Array = ARENA.CREATURES.keys()
	for i in ids.size():
		var spot := Vector3(-COLUMN if i % 2 == 0 else COLUMN, 0.0, i / 2 * ROW)
		_show_unit(ids[i], spot)
	_scroll_max = maxf(_scroll, ((ids.size() - 1) / 2 - 0.5) * ROW)
	_apply_scroll()
	if _shot != "":
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot + "-list.png")
		get_tree().quit()


func _apply_scroll() -> void:
	var look := Vector3(0.0, 0.8, _scroll)
	camera.position = look + CAMERA_DIR.normalized() * CAMERA_DIST
	camera.look_at(look)


func _scroll_by(amount: float) -> void:
	_scroll = clampf(_scroll + amount, ROW * 0.5, _scroll_max)
	_apply_scroll()


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


func _show_unit(id: String, spot: Vector3) -> void:
	var cfg: Dictionary = ARENA.CREATURES[id]
	var unit := Creature.new()
	add_child(unit)
	unit.position = spot
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
	unit.turn_bones(cfg.get("bone_turn", {}))  # поза рук и оружия, как в бою
	unit.defend_pin = cfg.get("defend_pin", true)
	unit.scale_bones(cfg.defend, cfg.get("defend_calm", []), cfg.get("defend_calm_by", 1.0))
	unit.scale_bones(cfg.hurt, cfg.get("hurt_calm", []), cfg.get("hurt_calm_by", 1.0))
	unit.face(spot + Vector3.BACK)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 10
	label.position = spot + Vector3(0.0, cfg.size + 0.25, 0.0)
	label.no_depth_test = true  # подпись не прячется за соседним рядом
	add_child(label)
	_cycle(unit, cfg, label)


## Один круг: стойка, удар, ходьба, реакция, защита, смерть. Каждая запись: подпись, анимация, с какой доли, сколько секунд.
func _cycle(unit: Creature, cfg: Dictionary, label: Label3D) -> void:
	var steps := [
		["стойка", "idle", 0.0, PAUSE * 2.0],
		["удар", cfg.attack, cfg.attack_from, 0.0],
		["ходьба", "walk", 0.0, WALK_TIME],
		["реакция на удар", cfg.hurt, 0.0, cfg.hurt_len],
		["защита", cfg.defend, cfg.defend_from, cfg.defend_len],
		["смерть", "fall", 0.0, 0.0],
	]
	while true:
		for step: Array in steps:
			if not unit.anim.has_animation(step[1]):
				continue
			label.text = "%s: %s" % [cfg.name, step[0]]
			unit.anim.play(step[1], 0.2)
			unit.anim.seek(unit.anim.get_animation(step[1]).length * step[2], true)
			var time: float = step[3] if step[3] > 0.0 else unit.anim.get_animation(step[1]).length * (1.0 - step[2])
			await get_tree().create_timer(time).timeout
			if step[1] != "fall":
				unit.anim.play("idle", 0.3)
				await get_tree().create_timer(PAUSE).timeout
		await get_tree().create_timer(PAUSE).timeout


func _process(delta: float) -> void:
	var keys := Input.get_axis("ui_up", "ui_down")
	if keys != 0.0:
		_scroll_by(keys * SCROLL_KEYS * delta)


func _unhandled_input(event: InputEvent) -> void:
	var pan := event as InputEventPanGesture
	if pan:
		_scroll_by(pan.delta.y * SCROLL_GESTURE)
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_by(SCROLL_WHEEL if click.button_index == MOUSE_BUTTON_WHEEL_DOWN else -SCROLL_WHEEL)
