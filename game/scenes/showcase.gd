extends Control
## Витрина: как окно существа в Героях. У каждого свой квадрат с рамкой, там он по кругу показывает всё, что умеет.
## Квадраты по два в ряд, как газетная полоса; колесо или два пальца — прокрутка.
## Запуск: godot --path game res://scenes/showcase.tscn
## Отладка: -- --shot=<префикс> — кадр <префикс>-list.png, потом выход.

const ARENA := preload("res://scenes/creature_test.gd")  # записи существ: модели и анимации
const CELL := 620  # сторона квадрата, пикселей
const GAP := 18
const PAUSE := 1.2  # стойка между анимациями, секунд
const WALK_TIME := 3.0  # сколько идёт на месте, секунд
const CAMERA_FOV := 25.0
const CAMERA_DIR := Vector3(0.55, 0.35, 1.0)  # сбоку и немного сверху
const FRAME := 1.35  # сколько высот существа входит в кадр
const FRAME_COLOR := Color(0.72, 0.58, 0.3)
const GRASS_TINT := Color(0.52, 0.62, 0.46)
const NEW_CREATURES := {"houndmaster": preload("res://scenes/houndmaster_config.gd").MASTER,
	"hammerer": preload("res://scenes/hammerer_config.gd").UNIT}

var _shot := ""
var columns := 2
var cell_size := CELL
var _views: Array = []  # пары квадрат и его мир: мир за кадром не рисуем
## Масштаб квадратов: щипок на трекпаде или Ctrl+колесо. Подкласс с _fit(grid) кладёт сетку в _zoom_grid.
var cell_zoom := 1.0
var _zoom_grid: GridContainer


func _ready() -> void:
	var grid := _build_page()
	for id: String in NEW_CREATURES:
		if not ARENA.CREATURES.has(id):
			_make_cell(id, grid)
	for id: String in ARENA.CREATURES:
		_make_cell(id, grid)
	_finish()


func _build_page() -> GridContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	var page := ColorRect.new()
	page.color = Color(0.1, 0.09, 0.08)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var margin := MarginContainer.new()
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, GAP)
	center.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	margin.add_child(grid)
	return grid


func _process(_delta: float) -> void:
	var screen := get_viewport_rect()
	for pair: Array in _views:
		var shown: bool = pair[0].get_global_rect().intersects(screen)
		pair[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED


func _finish() -> void:
	if _shot != "":
		await get_tree().create_timer(4.0).timeout
		print("FPS ", Engine.get_frames_per_second())
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot + "-list.png")
		get_tree().quit()


## Рамка со своим миром и камерой на существо заданной высоты; подпись добавляет вызывающий.
func _make_frame(grid: GridContainer, size: float) -> Dictionary:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.BLACK
	box.border_color = FRAME_COLOR
	box.set_border_width_all(3)
	box.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", box)
	grid.add_child(frame)
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2.ONE * cell_size
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_PASS  # колесо идёт в прокрутку
	frame.add_child(holder)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	holder.add_child(view)
	_views.append([holder, view])
	_build_world(view)
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	view.add_child(camera)
	var look := Vector3(0, size * 0.5, 0)
	camera.position = look + CAMERA_DIR.normalized() * size * FRAME * 0.5 / tan(deg_to_rad(CAMERA_FOV * 0.5))
	camera.look_at_from_position(camera.position, look)
	return {"frame": frame, "view": view}


func _make_label(frame: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)
	return label


## Квадрат: рамка, свой мир с существом и подпись внизу.
func _make_cell(id: String, grid: GridContainer) -> void:
	var cfg: Dictionary = NEW_CREATURES[id] if NEW_CREATURES.has(id) else ARENA.CREATURES[id]
	var cell := _make_frame(grid, cfg.size)
	var view: SubViewport = cell.view
	var frame: Control = cell.frame
	_configure_lighting(view, cfg)
	var unit := Creature.new()
	view.add_child(unit)
	unit.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	if cfg.has("run") and unit.anim.has_animation(cfg.run):
		unit.anim.get_animation(cfg.run).loop_mode = Animation.LOOP_LINEAR
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
	unit.face(unit.position + Vector3.BACK + Vector3.RIGHT)
	var label := _make_label(frame)
	_cycle(unit, cfg, label)


## Metallic surfaces need an environment to reflect, even with a flat backdrop.
func _configure_lighting(view: SubViewport, cfg: Dictionary) -> void:
	if not cfg.get("showcase_metal_light", false):
		return
	preload("res://scenes/metal_lighting.gd").apply(view)


func _build_world(view: SubViewport) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.76, 0.9)
	env.environment.ambient_light_energy = 0.9
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_color = Color(1.0, 0.88, 0.74)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	view.add_child(sun)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 60.0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ground/grass.png")
	mat.albedo_color = GRASS_TINT
	mat.roughness = 1.0
	mat.uv1_scale = Vector3.ONE * 10.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	view.add_child(ground)


## Один круг: стойка, удар, ходьба, реакция, защита, смерть. Каждая запись: подпись, анимация, с какой доли, сколько секунд.
func _cycle(unit: Creature, cfg: Dictionary, label: Label) -> void:
	var steps := [
		["стойка", "idle", 0.0, PAUSE * 2.0],
		[cfg.get("attack_label", "удар"), cfg.attack, cfg.attack_from, 0.0],
		["ходьба", "walk", 0.0, WALK_TIME],
		["реакция на удар", cfg.hurt, 0.0, cfg.hurt_len],
		["защита", cfg.defend, cfg.defend_from, cfg.defend_len],
		["смерть", "fall", 0.0, 0.0],
	]
	if cfg.has("run"):
		steps.insert(3, ["бег", cfg.run, 0.0, WALK_TIME])
	if cfg.has("fidget"):
		steps.insert(steps.size() - 1, ["отклик", cfg.fidget, 0.0, 0.0])
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


func _input(event: InputEvent) -> void:
	var factor := 1.0
	if event is InputEventMagnifyGesture:
		factor = event.factor
	elif event is InputEventMouseButton and event.pressed and (event.ctrl_pressed or event.meta_pressed):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			factor = 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			factor = 1.0 / 1.1
	if factor == 1.0 or _zoom_grid == null or not has_method("_fit"):
		return
	cell_zoom = clampf(cell_zoom * factor, 0.5, 4.0)
	call("_fit", _zoom_grid)
	get_viewport().set_input_as_handled()

