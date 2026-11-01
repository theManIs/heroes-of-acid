extends Node3D
## Витрина: существа рядами, в ряду одна модель от высокой детализации к низкой.
## Колесо или два пальца — прокрутка вниз по списку; щипок или Ctrl + колесо — зум к курсору; левая кнопка — двигать вид.
## Запуск: godot --path game res://scenes/showcase.tscn
## Отладка: -- --shot=<префикс> — кадры <префикс>-list.png, -zoom.png. Уровни собирает pipelines/creature/build_showcase.sh.

const ARENA := preload("res://scenes/creature_test.gd")
const ROWS := [
	{"id": "flesh-golem", "levels": [1436104, 200000, 50000, 20000, 10000, 5000, 2500]},
	{"id": "militiaman", "levels": [19816, 10000, 5000, 2500, 1250]},
]
const COLUMN := 2.4  # метров между моделями в ряду
const ROW_STEP := 3.8  # метров между рядами
const VIEW_Z := 27.0  # дистанция камеры на общем плане: весь ряд в кадре
const NEAR_Z := 3.0
const FAR_Z := 40.0
const SCROLL_STEP := 0.6
const ZOOM_PINCH := 1.0  # чувствительность щипка
const ZOOM_WHEEL := 1.12

var camera := Camera3D.new()
var _top := 0.0  # верх списка, метров
var _bottom := 0.0
var _half_width := 0.0
var _dragging := false


func _ready() -> void:
	_build_world()
	var y := 0.0
	for row: Dictionary in ROWS:
		_build_row(row, y)
		_half_width = maxf(_half_width, COLUMN * (row.levels.size() - 1) * 0.5)
		y -= ROW_STEP
	_top = -0.6
	_bottom = y + ROW_STEP - 0.6
	camera.position = Vector3(0, _top, VIEW_Z)
	_build_hud()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.2, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	camera.fov = 20.0  # узкий угол: перспектива не разворачивает крайние модели
	add_child(camera)


func _build_row(row: Dictionary, y: float) -> void:
	var cfg: Dictionary = ARENA.CREATURES[row.id]
	var material := _material_of(load(cfg.scene))
	var title := _label(cfg.name, 0.01)
	title.position = Vector3(-COLUMN * (row.levels.size() - 1) * 0.5, y + 2.3, 0)
	add_child(title)
	var levels: Array = row.levels
	for i in levels.size():
		var c := Creature.new()
		add_child(c)
		var scene: PackedScene = load("res://assets/showcase/%s-%d.glb" % [row.id, levels[i]])
		c.setup(scene, cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
		c.position = Vector3((i - (levels.size() - 1) * 0.5) * COLUMN, y, 0)
		c.face(c.position + Vector3.BACK)
		for mesh: MeshInstance3D in c.model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_surface_override_material(0, material)
		var label := _label(_count_text(levels[i]), 0.005)
		label.position = c.position + Vector3(0, -0.22, 0)
		add_child(label)


func _material_of(scene: PackedScene) -> Material:
	var node := scene.instantiate()
	var mesh: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false)[0]
	var material := mesh.mesh.surface_get_material(0)
	node.free()
	return material


func _label(text: String, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 48
	label.outline_size = 12
	label.shaded = false
	return label


## 1436104 → «1 436 104»: число с пробелами.
func _count_text(count: int) -> String:
	var digits := str(count)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return out


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var hint := Label.new()
	hint.text = "Колесо или два пальца — прокрутка, щипок или Ctrl + колесо — зум, левая кнопка — двигать"
	hint.position = Vector2(16, 12)
	hud.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	var pinch := event as InputEventMagnifyGesture
	if pinch:
		_zoom_at(pow(pinch.factor, ZOOM_PINCH), pinch.position)
		return
	var pan := event as InputEventPanGesture
	if pan:
		_scroll(-pan.delta.y * SCROLL_STEP * 0.25)
		return
	var click := event as InputEventMouseButton
	if click:
		if click.button_index == MOUSE_BUTTON_LEFT:
			_dragging = click.pressed
		elif click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var up := click.button_index == MOUSE_BUTTON_WHEEL_UP
			if click.ctrl_pressed:
				_zoom_at(ZOOM_WHEEL if up else 1.0 / ZOOM_WHEEL, click.position)
			else:
				_scroll(SCROLL_STEP if up else -SCROLL_STEP)
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		var scale_at := 2.0 * camera.position.z * tan(deg_to_rad(camera.fov * 0.5)) / get_viewport().get_visible_rect().size.y
		camera.position += Vector3(-motion.relative.x, motion.relative.y, 0) * scale_at
		_clamp_camera()


func _scroll(amount: float) -> void:
	camera.position.y += amount
	_clamp_camera()


## Зум к курсору: точка под курсором остаётся на месте.
func _zoom_at(factor: float, screen: Vector2) -> void:
	var before := _point_under(screen)
	camera.position.z = clampf(camera.position.z / factor, NEAR_Z, FAR_Z)
	var after := _point_under(screen)
	camera.position += Vector3(before.x - after.x, before.y - after.y, 0)
	_clamp_camera()


func _point_under(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return origin + dir * (-origin.z / dir.z)


func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, -_half_width - COLUMN, _half_width + COLUMN)
	camera.position.y = clampf(camera.position.y, _bottom - 1.0, _top + 1.5)


func _shoot(prefix: String) -> void:
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-list.png")
	camera.position = Vector3(0, _bottom, VIEW_Z)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-bottom.png")
	camera.position = Vector3(-COLUMN, 0.9, 8.0)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-zoom.png")
	get_tree().quit()
