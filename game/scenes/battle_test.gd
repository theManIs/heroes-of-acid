extends Node3D
## Тест боя: поле 12×9, все существа слева против всех справа. Два пальца, стрелки или правая кнопка — двигать камеру.
## Игровой ход: каждое существо ходит один раз, порядок — по инициативе, он показан в шкале сверху.
## Твоя сторона — левая: клик по подсвеченному гексу — идти (дальность своя у каждого, MOVES), клик по противнику — подойти и ударить.
## Запуск: godot --path game res://scenes/battle_test.tscn
## Отладка: -- --auto — обе стороны играют сами, ускоренно; -- --shot=<префикс> — кадры <префикс>-start.png, -end.png.

const ARENA := preload("res://scenes/creature_test.gd")  # записи существ — там
const HOUNDMASTER_UNIT := preload("res://scenes/houndmaster_unit.gd")
const PAIR_PATHS := preload("res://scenes/houndmaster_paths.gd")
const MELEE_AREA := preload("res://scenes/melee_area.gd")
const SWORD := preload("res://scenes/sword_cursor.gd")
const BOW := preload("res://scenes/bow_cursor.gd")
const ACTION_ICON := preload("res://scenes/action_icon.gd")
const COLS := 12
const ROWS := 9
const START_ROWS: Array[int] = [0, 2, 3, 5, 6, 8, 1]  # ряды одиночных существ; пара размещается отдельно
const OBSTACLES := [  # преграда занимает свои гексы: ни встать, ни пройти; cells — колонка и ряд каждого
	{"id": "rock-ridge", "turn": 0.0, "cells": [Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 4)]},
	{"id": "dead-tree-v2", "turn": 2.1, "cells": [Vector2i(8, 6)], "sink": 0.1},  # sink — доля высоты под землёй: прячет подставку модели
]
const OBSTACLE_OVER := 1.15  # насколько модель шире занятых гексов: не выглядит вписанной в сетку
const OBSTACLE_HEIGHT := 2.0  # выше не бывает, метров: не закрывает существ в ряду за ней
const MOVES := {"ghoul": 6, "vampire": 5, "militiaman": 4, "lantern-archer": 4, "boilerman": 4, "flesh-golem": 3, "hammerer": 3, "houndmaster-pair": 3}  # обычное перемещение; вылазка собаки не ограничена
const WALK_RATE := 2.0  # ходьба вдвое быстрее, чем в арене
const OVERLAP := 0.1  # кулак входит в тело врага, метров
const TILE_HEIGHT := 0.01  # заливка гекса плоская, лежит на траве
const LINE_WIDTH := 0.03  # толщина контура гекса, метров
const LINE_COLOR := Color(1.0, 1.0, 0.9, 0.4)
const RADIUS := 0.6
const GRASS_TILE := 6.0  # сторона повтора текстуры травы, метров
const GRASS_PATCH := 37.0  # сторона повтора больших пятен, прячут повтор текстуры, метров
const GRASS_SHADER := """
shader_type spatial;
uniform sampler2D grass: source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D patches: repeat_enable, filter_linear_mipmap;
uniform vec3 tint;
uniform float tile;
uniform float patch;
uniform float size;
void fragment() {
	vec2 metres = UV * size;
	ALBEDO = texture(grass, metres / tile).rgb * tint * mix(0.72, 1.08, texture(patches, metres / patch).r);
	ROUGHNESS = 1.0;
}
"""
const GRASS_TINT := Color(0.52, 0.62, 0.46)  # приглушить: существа и контуры должны читаться лучше земли
const GROUND_SIZE := 80.0  # шире любого кадра, с прокруткой тоже
const PLAYER_TURN := Color(0.25, 0.55, 1.0)
const ENEMY_TURN := Color(1.0, 0.25, 0.2)
const TARGET := Color(0.3, 0.95, 0.35)  # противник под курсором — можно ударить
const RANGE_ALPHA := 0.18  # заливка гексов хода: трава видна сквозь неё
const NO_HEX := Vector2i(999, 999)
const QUEUE_ICON := 44.0  # размер пиктограммы в шкале инициативы
const QUEUE_GAP := 6  # расстояние между элементами шкалы
const QUEUE_MARGIN := 1.0  # рамка вокруг пиктограммы
const QUEUE_NOW := 2.0 / 3.0  # какая доля карты видна на этом ходу
const QUEUE_NEXT := 1.0 / 3.0  # какая доля карты видна на следующем ходу
const QUEUE_HOVER := 18.0  # скорость раскрытия карты под курсором
const CAMERA_DIR := Vector3(0, 1.0, 1.0)  # камера под 45° к земле
const CAMERA_FOV := 20.0  # узкий угол и камера дальше: дальние ряды почти не мельче ближних
const CAMERA_SIDE := 0.45  # запас по бокам поля, метров: крайние существа шире своих гексов
const CAMERA_HEAD := 2.2  # рост существа в дальнем ряду, метров: голова тоже в кадре
const CAMERA_SHIFT_X := -0.26  # крайние ряды сдвинуты влево на четверть гекса: по ним и центруем
const CREATURE_SCALE := 1.2  # существа крупнее гекса: так их лучше видно, соседи могут перекрывать друг друга
const PAN_GESTURE := 0.05  # чувствительность прокрутки двумя пальцами
const PAN_KEYS := 6.0  # скорость прокрутки стрелками, метров в секунду
const ZOOM_NEAR := 0.2  # насколько сокращается дистанция при полном приближении
const ZOOM_PINCH := 0.5  # чувствительность щипка
const ZOOM_WHEEL := 0.12  # шаг колеса мыши
const ZOOM_HOLD := 0.5  # жест молчит столько секунд — считаем, что пальцы отпущены
const GAME_SPEED := 2.0  # вся игра быстрее: анимации, ходьба и паузы
const AUTO_SPEED := 5.0  # ускорение при --auto
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

enum Turn { PLAYER, ENEMY, BUSY, OVER }

var sides: Array[Array] = [[], []]  # 0 — левая (твоя), 1 — правая
var creatures := ARENA.CREATURES.merged({"houndmaster-pair": preload("res://scenes/houndmaster_config.gd").pair()})
var _dog_reachable := {}
var _raid_targets := {}
var cells := {}  # Creature -> гекс
var active: Creature  # кто сейчас ходит
var board := Node3D.new()
var camera := Camera3D.new()
var status := Label.new()
var tiles := {}  # Vector2i (осевые координаты) -> MeshInstance3D
var obstacles := {}  # Vector2i -> true: гексы, занятые преградами
var turn := Turn.PLAYER
var reachable := {}  # Vector2i -> путь (Array[Vector2i]) для текущего хода игрока
var sword: Control
var bow: Control
var mode_button: Button  # смена режима огня: видна, когда ходит свой стрелок
var melee_mode_button := Button.new()
var queue_bar := HBoxContainer.new()  # шкала инициативы
var wait_button: Button
var round_no := 0  # номер игрового хода
var _queue: Array[Creature] = []  # кто ещё не ходил в этом игровом ходу
var _waiting: Array[Creature] = []  # нажали «Ждать»: сходят в конце игрового хода
var _wait_phase := false  # очередь ожидавших: ждать второй раз нельзя
var _hovered := NO_HEX
var _attack_from := NO_HEX  # гекс, с которого будет удар
var _targeted: Creature  # противник с зелёной обводкой
var _pointer_inside := true
var _inspected: Creature  # существо под курсором: показываем его дальность хода
var _auto := false
var _shot := ""
var _cam_base := Vector3.ZERO  # камера общего плана
var _pan := Vector3.ZERO  # сдвиг камеры над полем
var _dragging := false  # правая кнопка зажата
var _cam_look := Vector3.ZERO
var _zoom := 0.0  # 0 — общий план, 1 — вплотную
var _zoom_target := 0.0
var _zoom_focus := Vector3.ZERO  # на что смотрим при приближении
var _zoom_idle := INF  # секунд с последнего движения жеста


func _ready() -> void:
	Engine.time_scale = GAME_SPEED
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			_auto = true
			Engine.time_scale = AUTO_SPEED
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	for side in sides:
		for id: String in creatures:
			side.append(_make(id))
	add_child(board)
	_build_world()
	_build_board()
	_build_hud()
	_place_camera()
	get_viewport().size_changed.connect(_place_camera)
	_reset()
	get_window().mouse_exited.connect(_clear_hover)
	get_window().mouse_entered.connect(func(): _pointer_inside = true)
	if _shot != "":
		await get_tree().create_timer(0.8 * Engine.time_scale).timeout
		get_viewport().get_texture().get_image().save_png(_shot + "-start.png")


func _make(id: String) -> Creature:
	var c: Creature = HOUNDMASTER_UNIT.new() if id == "houndmaster-pair" else Creature.new()
	add_child(c)
	var cfg: Dictionary = creatures[id]
	c.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size * CREATURE_SCALE, cfg.attack_from, cfg.idle)
	if cfg.has("variants"):  # финальная генерация — последняя
		c.set_textures(cfg.variants[-1].get("textures", {}))
		if cfg.variants[-1].has("glow"):
			c.add_glow(cfg.variants[-1].glow)
	c.defend_anim = cfg.defend
	c.defend_from = cfg.defend_from
	c.defend_len = cfg.defend_len
	c.defend_lead = cfg.defend_lead
	c.hurt_len = cfg.hurt_len
	c.turn_bones(cfg.get("bone_turn", {}))
	c.defend_pin = cfg.get("defend_pin", true)
	c.scale_bones(cfg.defend, cfg.get("defend_calm", []), cfg.get("defend_calm_by", 1.0))
	c.scale_bones(cfg.hurt, cfg.get("hurt_calm", []), cfg.get("hurt_calm_by", 1.0))
	c.walk_speed = cfg.get("walk_speed", Creature.WALK_SPEED) * CREATURE_SCALE  # шаг крупнее — ноги не скользят
	c.shots = cfg.get("shots", {})
	c.set_shot(c.shots.keys()[0] if c.ranged() else "")
	c.configure_melee(cfg.get("melee_modes", {}))
	c.walk_rate = WALK_RATE
	c.set_meta("move", MOVES[id])
	c.set_meta("title", cfg.name)
	c.set_meta("icon", cfg.icon)
	if c is HOUNDMASTER_UNIT:
		(c as HOUNDMASTER_UNIT).raid_impact.connect(_show_queue)
	if cfg.get("smoke", false):
		c.add_smoke()
	return c


# --- Камера ---

## Поле главное: камера встаёт так близко, как только можно, чтобы всё поле вошло в кадр. Вызывается при каждом изменении окна.
func _place_camera() -> void:
	var off := _board_offset()
	var side := off.x + RADIUS * sqrt(3.0) * 0.5 + CAMERA_SIDE
	var far := -off.z - RADIUS
	var near := off.z + RADIUS
	var points: Array[Vector3] = [Vector3(-side + CAMERA_SHIFT_X, CAMERA_HEAD, far), Vector3(side + CAMERA_SHIFT_X, CAMERA_HEAD, far),
		Vector3(-side + CAMERA_SHIFT_X, 0, near), Vector3(side + CAMERA_SHIFT_X, 0, near)]
	var dir := CAMERA_DIR.normalized()
	var dist := 4.0
	var fit: Array[float] = []  # куда можно смотреть вдоль поля при этом расстоянии
	while dist < 60.0 and fit.is_empty():
		dist += 0.1
		for step in 61:
			var z := (step - 30) * 0.1
			_aim_camera(Vector3(CAMERA_SHIFT_X, 0.0, z), dir * dist)
			if points.all(func(p: Vector3) -> bool: return camera.is_position_in_frustum(p)):
				fit.append(z)
	_cam_look = Vector3(CAMERA_SHIFT_X, 0.0, (fit[0] + fit[-1]) * 0.5 if not fit.is_empty() else 0.0)  # посередине: запас поровну
	_cam_base = _cam_look + dir * dist
	_apply_zoom()


func _aim_camera(look: Vector3, offset: Vector3) -> void:
	camera.position = look + offset
	camera.look_at(look)


## Щипок и колесо: камера едет к точке под курсором; отпустил пальцы — вернулась на общий план.
func _apply_zoom() -> void:
	var look := (_cam_look + _pan).lerp(_zoom_focus, _zoom)
	camera.position = look + (_cam_base - _cam_look) * (1.0 - _zoom * ZOOM_NEAR)
	camera.look_at(look)


## Сдвинуть камеру над полем, не дальше его краёв.
func _pan_by(amount: Vector3) -> void:
	var off := _board_offset()
	_pan = Vector3(clampf(_pan.x + amount.x, -off.x, off.x), 0.0, clampf(_pan.z + amount.z, -off.z, off.z))
	_apply_zoom()


func _zoom_by(amount: float, screen: Vector2) -> void:
	if _zoom_target <= 0.001:  # начало жеста: выбрать, куда приближаемся
		var unit := _unit_on(_hex_under(screen))
		_zoom_focus = unit.position + Vector3.UP * unit.height * 0.6 if unit else _ground_point(screen)
	_zoom_target = clampf(_zoom_target + amount, 0.0, 1.0)
	_zoom_idle = 0.0


# --- Гексы (pointy-top, осевые координаты q, r) ---

func _hex_spacing() -> float:
	return RADIUS * sqrt(3.0)


func _hex_center(h: Vector2i) -> Vector3:
	var x := RADIUS * sqrt(3.0) * (h.x + h.y * 0.5)
	var z := RADIUS * 1.5 * h.y
	return Vector3(x, 0.0, z) - _board_offset()


func _board_offset() -> Vector3:
	var w := RADIUS * sqrt(3.0) * (COLS - 0.5)
	var d := RADIUS * 1.5 * (ROWS - 1)
	return Vector3(w * 0.5, 0.0, d * 0.5)


## Клетка по колонке и ряду прямоугольного поля → осевые координаты.
func _cell(col: int, row: int) -> Vector2i:
	return Vector2i(col - floori(row / 2.0), row)


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


func _hex_at(point: Vector3) -> Vector2i:
	var best := NO_HEX
	var best_d := INF
	for h: Vector2i in tiles:
		var d := _hex_center(h).distance_to(Vector3(point.x, 0.0, point.z))
		if d < best_d:
			best_d = d
			best = h
	return best if best_d < RADIUS else NO_HEX


func _is_pair(c: Creature) -> bool:
	return c is HOUNDMASTER_UNIT


func _footprint(c: Creature, anchor := NO_HEX) -> Array[Vector2i]:
	return PAIR_PATHS.footprint(cells[c] if anchor == NO_HEX else anchor, PAIR_PATHS.PAIR if _is_pair(c) else PAIR_PATHS.SINGLE)


func _formation_distance(a: Creature, b: Creature, anchor := NO_HEX) -> int:
	return PAIR_PATHS.distance(_footprint(a, anchor), _footprint(b))


func _blocked(exclude: Creature) -> Dictionary:
	var blocked := obstacles.duplicate()
	for side in sides:
		for c: Creature in side:
			if c != exclude and c.can_be_hit():
				for h in _footprint(c):
					blocked[h] = true
	return blocked


## Кратчайшие пути всей фигуры отряда. Мёртвые не мешают.
func _paths_from(from: Vector2i, who: Creature = null) -> Dictionary:
	if who == null:
		who = _unit_on(from)
	return PAIR_PATHS.paths(from, PAIR_PATHS.PAIR if _is_pair(who) else PAIR_PATHS.SINGLE, tiles, _blocked(who))


func _raid_options(target: Creature) -> Dictionary:
	if not _raid_targets.has(target):
		_raid_targets[target] = PAIR_PATHS.attacks(_dog_reachable, _footprint(target))
	return _raid_targets[target]


func _unit_on(h: Vector2i) -> Creature:
	for side in sides:
		for c: Creature in side:
			if c.can_be_hit() and _footprint(c).has(h):
				return c
	return null


# --- Сцена ---

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	# Темно, но с цветом: небо не видно на фоне, но даёт холодные тени и отражения металлу.
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.14, 0.17, 0.32)
	sky.sky_horizon_color = Color(0.6, 0.27, 0.17)
	sky.ground_horizon_color = Color(0.26, 0.14, 0.1)
	sky.ground_bottom_color = Color(0.06, 0.05, 0.06)
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 1.5
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 20, 0)  # высокое солнце: короткие тени, свет на обе стороны фигур
	sun.light_color = Color(1.0, 0.88, 0.74)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)

	# Заполняющий свет: теневая сторона фигур не проваливается в черноту.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, -25, 0)  # со стороны камеры
	fill.light_color = Color(0.72, 0.79, 1.0)
	fill.light_energy = 0.75
	add_child(fill)

	camera.fov = CAMERA_FOV
	add_child(camera)


func _build_board() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS - LINE_WIDTH * 0.6  # заливка вплотную к контуру
	mesh.bottom_radius = RADIUS - LINE_WIDTH * 0.6
	mesh.height = TILE_HEIGHT
	mesh.radial_segments = 6
	mesh.rings = 1
	for r in ROWS:
		for c in COLS:
			var h := _cell(c, r)
			var tile := MeshInstance3D.new()  # заливка подсветки: видна, только когда гекс подсвечен
			tile.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # подсветка не должна зависеть от цвета солнца
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tile.material_override = mat
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.visible = false
			tile.position = _hex_center(h) - Vector3(0, TILE_HEIGHT, 0)
			board.add_child(tile)
			tiles[h] = tile
	_build_lines()
	_build_grass()
	_build_obstacles()


func _build_obstacles() -> void:
	for item: Dictionary in OBSTACLES:
		var low := Vector3.INF
		var high := -Vector3.INF
		for at: Vector2i in item.cells:
			var h := _cell(at.x, at.y)
			obstacles[h] = true
			low = low.min(_hex_center(h))
			high = high.max(_hex_center(h))
		var pivot := Node3D.new()  # поворот вокруг середины занятых гексов
		pivot.position = (low + high) * 0.5
		pivot.rotation.y = item.turn
		board.add_child(pivot)
		var model: Node3D = load("res://assets/obstacles/%s.glb" % item.id).instantiate()
		pivot.add_child(model)
		var box := _bounds(model, Transform3D.IDENTITY)
		if item.cells.size() > 1 and box.size.z > box.size.x:  # длинной стороной вдоль занятых гексов
			pivot.rotation.y += PI * 0.5
			box = AABB(box.position, Vector3(box.size.z, box.size.y, box.size.x))
		var fit := minf((high.x - low.x + RADIUS * sqrt(3.0)) * OBSTACLE_OVER / box.size.x, (high.z - low.z + RADIUS * 2.0) * OBSTACLE_OVER / box.size.z)
		model.scale = Vector3.ONE * minf(fit, OBSTACLE_HEIGHT / box.size.y)
		var bounds := _bounds(model, Transform3D.IDENTITY)
		model.position -= Vector3(bounds.get_center().x, bounds.position.y + bounds.size.y * item.get("sink", 0.0), bounds.get_center().z)


## Габариты модели в её собственных координатах.
func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var xf := parent * node.transform
	var box := AABB()
	var mesh := node as MeshInstance3D
	if mesh:
		box = xf * mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var part := _bounds(child, xf)
			if part.size != Vector3.ZERO:
				box = part if box.size == Vector3.ZERO else box.merge(part)
	return box


## Контуры всех гексов одной сеткой: общая граница двух гексов рисуется один раз, иначе она вдвое толще внешней.
func _build_lines() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)  # контуры освещаются: в тени темнеют вместе с травой
	var drawn := {}
	for h: Vector2i in tiles:
		var center := _hex_center(h)
		for i in 6:
			var a := center + Vector3(sin(i * TAU / 6.0), 0.0, cos(i * TAU / 6.0)) * RADIUS
			var b := center + Vector3(sin((i + 1) * TAU / 6.0), 0.0, cos((i + 1) * TAU / 6.0)) * RADIUS
			var middle := Vector2i(roundi((a.x + b.x) * 50.0), roundi((a.z + b.z) * 50.0))  # середина ребра — одна у обоих соседей
			if drawn.has(middle):
				continue
			drawn[middle] = true
			var side := (b - a).cross(Vector3.UP).normalized() * LINE_WIDTH * 0.5
			for corner: Vector3 in [a - side, b - side, a + side, a + side, b - side, b + side]:
				st.add_vertex(corner)
	var lines := MeshInstance3D.new()
	lines.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.albedo_color = LINE_COLOR
	lines.material_override = mat
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.add_child(lines)


## Трава: рисованная текстура, большие пятна шума прячут её повтор.
func _build_grass() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var patches := NoiseTexture2D.new()
	patches.width = 512
	patches.height = 512
	patches.seamless = true
	patches.generate_mipmaps = true
	patches.noise = noise
	var shader := Shader.new()
	shader.code = GRASS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grass", load("res://assets/ground/grass.png"))
	mat.set_shader_parameter("patches", patches)
	mat.set_shader_parameter("tint", Vector3(GRASS_TINT.r, GRASS_TINT.g, GRASS_TINT.b))
	mat.set_shader_parameter("tile", GRASS_TILE)
	mat.set_shader_parameter("patch", GRASS_PATCH)
	mat.set_shader_parameter("size", GROUND_SIZE)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SIZE
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	ground.position.y = -TILE_HEIGHT * 2.0
	board.add_child(ground)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	status.offset_left = -600
	status.offset_right = -24
	status.offset_top = -60
	status.offset_bottom = -24
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	status.add_theme_constant_override("outline_size", 6)  # читается и на траве, и поверх существ
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_child(status)
	sword = Control.new()
	sword.set_script(SWORD)
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword.visible = false
	hud.add_child(sword)
	bow = Control.new()
	bow.set_script(BOW)
	bow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bow.visible = false
	hud.add_child(bow)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -100
	bar.offset_bottom = -16
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	hud.add_child(bar)
	mode_button = _action_button("Режим огня", _switch_mode, ACTION_ICON.Kind.FIRE_MODE)
	bar.add_child(mode_button)
	melee_mode_button.custom_minimum_size = Vector2(240, 64)
	melee_mode_button.pressed.connect(_switch_mode)
	bar.add_child(melee_mode_button)
	wait_button = _action_button("Ждать", _wait, ACTION_ICON.Kind.WAIT)
	bar.add_child(wait_button)
	bar.add_child(_action_button("Защита", _defend, ACTION_ICON.Kind.DEFEND))
	var restart := _action_button("Заново", _reset, ACTION_ICON.Kind.RESTART)  # отдельно, в углу: не боевое действие
	restart.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	restart.offset_left = 24
	restart.offset_right = 108
	restart.offset_top = -100
	restart.offset_bottom = -16
	hud.add_child(restart)

	queue_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	queue_bar.offset_top = 8
	queue_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_bar.add_theme_constant_override("separation", QUEUE_GAP)
	queue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(queue_bar)


func _action_button(title: String, action: Callable, kind: int) -> Button:
	var button := Button.new()
	button.tooltip_text = title
	button.custom_minimum_size = Vector2(84, 84)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())  # подложка — клякса в иконке
	button.pressed.connect(action)
	var icon := Control.new()
	icon.set_script(ACTION_ICON)
	icon.kind = kind
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return button


## Шкала инициативы: кто ходит сейчас, остаток этого хода, потом порядок следующего.
func _show_queue() -> void:
	for child in queue_bar.get_children():
		queue_bar.remove_child(child)
		child.queue_free()
	if turn == Turn.OVER:
		return
	queue_bar.add_child(_queue_label("Ход %d" % round_no))
	queue_bar.add_child(_queue_slot(active, true))
	for c: Creature in _queue:
		if c.can_be_hit():
			queue_bar.add_child(_queue_slot(c, false, QUEUE_NOW))
	if _waiting.any(func(c: Creature) -> bool: return c.can_be_hit()):
		queue_bar.add_child(_queue_label("Ждут"))
		var waiting: Array[Creature] = []
		for i in range(_waiting.size() - 1, -1, -1):
			if _waiting[i].can_be_hit():
				waiting.append(_waiting[i])
		_add_stack(waiting, QUEUE_NOW)
	queue_bar.add_child(_queue_label("Ход %d" % (round_no + 1)))
	_add_stack(_round_order(), QUEUE_NEXT)


## Стопка карт после подписи: верхняя видна целиком, из-под неё выглядывают остальные.
func _add_stack(cards: Array[Creature], shown: float) -> void:
	for i in cards.size():
		queue_bar.add_child(_queue_slot(cards[i], false, 1.0 if i == 0 else shown))


func _queue_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## Пиктограмма в шкале: рамка цвета стороны, у того, кто ходит сейчас, — крупнее.
## shown — какая доля карты видна справа из-под предыдущей: ближняя по очереди лежит сверху.
func _queue_slot(c: Creature, current: bool, shown := 1.0) -> Control:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	box.border_color = PLAYER_TURN if sides[0].has(c) else ENEMY_TURN
	box.set_border_width_all(int(QUEUE_MARGIN))
	box.set_content_margin_all(QUEUE_MARGIN)
	frame.add_theme_stylebox_override("panel", box)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := TextureRect.new()
	icon.texture = load(c.get_meta("icon"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2.ONE * (QUEUE_ICON * 1.3 if current else QUEUE_ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	frame.z_index = -queue_bar.get_child_count()  # чем дальше по очереди, тем ниже
	if shown >= 1.0:
		return frame
	var full := QUEUE_ICON + QUEUE_MARGIN * 2.0
	var slot := Control.new()  # шкала отводит только видимую часть, карта уходит под предыдущую
	slot.custom_minimum_size = Vector2(full * shown - QUEUE_GAP, full)
	slot.set_meta("rest", slot.custom_minimum_size.x)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position.x = slot.custom_minimum_size.x - full
	slot.add_child(frame)
	return slot


## Карта под курсором раскрывается целиком и раздвигает соседей, остальные возвращаются.
func _hover_queue(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var full := QUEUE_ICON + QUEUE_MARGIN * 2.0
	for slot: Control in queue_bar.get_children():
		if not slot.has_meta("rest"):
			continue
		var target: float = full - QUEUE_GAP if slot.get_global_rect().has_point(mouse) else slot.get_meta("rest")
		slot.custom_minimum_size.x = lerpf(slot.custom_minimum_size.x, target, 1.0 - exp(-QUEUE_HOVER * delta / Engine.time_scale))
		slot.get_child(0).position.x = slot.custom_minimum_size.x - full


# --- Ход боя ---

func _reset() -> void:
	if turn == Turn.BUSY or turn == Turn.ENEMY:
		return
	if active:
		active.set_outline(null)
	for s in sides.size():
		for i in sides[s].size():
			var c: Creature = sides[s][i]
			c.revive()
			c.defending = false
			cells[c] = _cell(1 if s == 0 else COLS - 2, 6) if _is_pair(c) else _cell(0 if s == 0 else COLS - 1, START_ROWS[i])
			c.position = _hex_center(cells[c])
			c.face(c.position + (Vector3.RIGHT if s == 0 else Vector3.LEFT))
	round_no = 0
	_queue.clear()
	_waiting.clear()
	_wait_phase = false
	_next_turn()


func _living(side: int) -> Array[Creature]:
	var out: Array[Creature] = []
	for c: Creature in sides[side]:
		if c.can_be_hit():
			out.append(c)
	return out


## Игровой ход: очередь из всех живых по инициативе, каждое существо ходит один раз. Очередь кончилась — новый ход.
func _next_turn() -> void:
	if _living(0).is_empty() or _living(1).is_empty():
		_game_over()
		return
	while true:
		if _queue.is_empty() and not _waiting.is_empty():
			_waiting.reverse()  # как в Героях: из ожидавших первыми ходят медленные
			_queue.assign(_waiting)
			_waiting.clear()
			_wait_phase = true
		elif _queue.is_empty():
			round_no += 1
			_queue = _round_order()
			_wait_phase = false
		active = _queue.pop_front()
		if active.can_be_hit():
			break
	active.defending = false
	reachable.clear()
	_raid_targets.clear()
	_dog_reachable.clear()
	if _is_pair(active):
		var blocked := _blocked(active)
		blocked[cells[active]] = true  # псарь остаётся дома
		_dog_reachable = PAIR_PATHS.paths(cells[active], PAIR_PATHS.DOG, tiles, blocked)
	_show_queue()
	var left: bool = sides[0].has(active)
	if active.ranged():
		active.update_shot(_enemy_adjacent(active))
	if left and not _auto:
		turn = Turn.PLAYER
		active.set_outline(PLAYER_TURN)
		reachable = _range_of(active)
		_paint()
		return
	turn = Turn.ENEMY
	active.set_outline(PLAYER_TURN if left else ENEMY_TURN)
	_paint()
	await get_tree().create_timer(0.6).timeout
	_ai_move(1 if left else 0)


## Порядок игрового хода: инициатива равна дальности хода, быстрые первыми; при равенстве — левая сторона.
func _round_order() -> Array[Creature]:
	var out := _living(0)
	out.append_array(_living(1))
	out.sort_custom(func(a: Creature, b: Creature) -> bool:
		if a.get_meta("move") != b.get_meta("move"):
			return a.get_meta("move") > b.get_meta("move")
		return sides[0].has(a) and not sides[0].has(b))
	return out


## Ходит сам: стрелок стреляет с места в ближайшего, две стрелы и бросок;
## остальные: рядом есть враг — бьёт, иначе идёт к ближайшему и бьёт, если дошёл.
func _ai_move(enemy_side: int) -> void:
	var enemies := _living(enemy_side)
	if _is_pair(active):
		var raid_target: Creature
		var raid_path: Array[Vector2i] = []
		for e: Creature in enemies:
			for path: Array in _raid_options(e).values():
				if raid_target == null or path.size() < raid_path.size():
					raid_target = e
					raid_path.assign(path)
		if raid_target:
			_raid(active, raid_target, raid_path)
			return
	if active.ranged():
		var nearest: Creature = enemies[0]
		for e: Creature in enemies:
			if _hex_distance(cells[active], cells[e]) < _hex_distance(cells[active], cells[nearest]):
				nearest = e
		var fired: int = active.get_meta("fired", 0) + 1
		active.set_meta("fired", fired)
		active.set_shot("lantern" if fired % 3 == 0 else "arrow")
		active.update_shot(_enemy_adjacent(active))
		_fire(active, nearest)
		return
	for e: Creature in enemies:
		if not _is_pair(active) and _formation_distance(active, e) == 1:
			_act(active, e, [] as Array[Vector2i])
			return
	var paths := _paths_from(cells[active])
	var best: Array[Vector2i] = []
	var target: Creature
	for h: Vector2i in paths:
		for e: Creature in enemies:
			if _formation_distance(active, e, h) == 1 and (target == null or paths[h].size() < best.size()):
				best = paths[h]
				target = e
	_act(active, target, best.slice(0, active.get_meta("move")))


## Пройти путь; если есть цель и стоим рядом с ней — ударить. Потом следующий ход.
func _act(who: Creature, target: Creature, path: Array[Vector2i]) -> void:
	turn = Turn.BUSY
	_set_target(null)
	_attack_from = NO_HEX
	_hovered = NO_HEX
	who.set_outline(null)
	reachable.clear()
	_paint()
	if not path.is_empty():
		cells[who] = path[-1]
		var points: Array[Vector3] = []
		for h in path:
			points.append(_hex_center(h))
		who.walk_path(points)
		await who.arrived
	if target and not _is_pair(who) and _formation_distance(who, target) == 1:
		if sides[1].has(who) or _auto:
			_choose_melee_mode(who, target)
		who.strike(target, _hex_spacing(), OVERLAP, _melee_victims(who, target, cells[who]))
		await get_tree().create_timer(who.hit_delay()).timeout
		_show_queue()  # убитый уходит из шкалы в момент попадания
		await get_tree().create_timer(1.5).timeout  # реакция цели
	elif target:
		who.face(target.position)
	_next_turn()


## Отдельная вылазка на всё поле: cells[who] остаётся исходным до и после атаки.
func _raid(who: Creature, target: Creature, path: Array[Vector2i]) -> void:
	turn = Turn.BUSY
	_set_target(null)
	who.set_outline(null)
	reachable.clear()
	_attack_from = NO_HEX
	_paint()
	var points: Array[Vector3] = []
	for h in path:
		points.append(_hex_center(h))
	var end: Vector2i = cells[who] if path.is_empty() else path[-1]
	var dog_center := _hex_center(end) + Vector3(0, 0, RADIUS * 1.5)
	var contact: Vector2i = cells[target]
	for h in _footprint(target):
		if dog_center.distance_squared_to(_hex_center(h)) < dog_center.distance_squared_to(_hex_center(contact)):
			contact = h
	await (who as HOUNDMASTER_UNIT).raid(target, points, _hex_center(contact))
	_next_turn()


## Вплотную к существу стоит живой враг: из лука стрелять нельзя.
func _enemy_adjacent(c: Creature) -> bool:
	for e: Creature in _living(1 if sides[0].has(c) else 0):
		if _formation_distance(c, e) == 1:
			return true
	return false


## Выстрел текущим режимом огня с места, потом следующий ход.
func _fire(who: Creature, target: Creature) -> void:
	turn = Turn.BUSY
	_set_target(null)
	who.set_outline(null)
	reachable.clear()
	_paint()
	await get_tree().create_timer(who.fire_shot(target, self)).timeout
	_show_queue()  # убитый уходит из шкалы в момент попадания
	await get_tree().create_timer(1.5).timeout  # реакция цели
	_next_turn()


func _game_over() -> void:
	turn = Turn.OVER
	reachable.clear()
	_show_queue()
	_paint()
	if _auto:
		print("Бой окончен. Слева живых: %d, справа: %d" % [_living(0).size(), _living(1).size()])
		await get_tree().create_timer(1.5 * Engine.time_scale).timeout
		if _shot != "":
			get_viewport().get_texture().get_image().save_png(_shot + "-end.png")
		get_tree().quit()


## Смена режима огня: не тратит ход.
func _switch_mode() -> void:
	if turn == Turn.PLAYER and not active.melee_modes.is_empty():
		active.next_melee_mode()
		_paint()
		return
	if turn == Turn.PLAYER and active.ranged():
		active.next_shot_mode(_enemy_adjacent(active))


## Ждать, как в Героях: существо сходит в конце этого игрового хода, один раз за ход.
func _wait() -> void:
	if turn != Turn.PLAYER or _wait_phase:
		return
	_waiting.append(active)
	active.set_outline(null)
	_set_target(null)
	_next_turn()


## Защита, как в Героях: ход заканчивается, до своего следующего хода удары не засчитываются.
func _defend() -> void:
	if turn != Turn.PLAYER:
		return
	active.defending = true
	active.set_outline(null)
	_set_target(null)
	_next_turn()


# --- Ввод ---

func _unhandled_input(event: InputEvent) -> void:
	var pinch := event as InputEventMagnifyGesture
	if pinch:
		_zoom_by((pinch.factor - 1.0) * ZOOM_PINCH, pinch.position)
		return
	var pan := event as InputEventPanGesture
	if pan:
		_pan_by(Vector3(pan.delta.x, 0.0, pan.delta.y) * PAN_GESTURE)
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		var metres := 2.0 * camera.position.distance_to(_cam_look + _pan) * tan(deg_to_rad(camera.fov * 0.5)) / get_viewport().get_visible_rect().size.y
		_pan_by(Vector3(-motion.relative.x, 0.0, -motion.relative.y) * metres)
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = click.pressed
		return
	if click and click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_by(ZOOM_WHEEL if click.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_WHEEL, click.position)
		return
	if turn != Turn.PLAYER or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var enemy := _enemy_under(click.position)
	if enemy:
		if active.ranged():
			_fire(active, enemy)
			return
		var from := _attack_hex(click.position, enemy)
		if from != NO_HEX:
			if _is_pair(active):
				var path: Array[Vector2i] = _raid_options(enemy)[from]
				_raid(active, enemy, path)
			else:
				_act(active, enemy, reachable[from])
		return
	var h := _hex_under(click.position)
	if reachable.has(h) and h != cells[active]:
		_act(active, null, reachable[h])


## Гекс атаки — как в арене: в какой клин вокруг гекса противника попадает точка под курсором,
## с того соседнего гекса и бьём. Сторона занята или вне хода — ближайшая по углу доступная.
## Стоим рядом с противником — свой гекс один из вариантов.
func _attack_hex(screen: Vector2, enemy: Creature) -> Vector2i:
	var target: Vector2i = cells[enemy]
	var center := _hex_center(target)
	var ground := _ground_point(screen)
	var pointer := Vector2(ground.x - center.x, ground.z - center.z)
	var best := NO_HEX
	var best_dot := -INF
	var options: Dictionary = _raid_options(enemy) if _is_pair(active) else reachable
	for n: Vector2i in options:
		if not _is_pair(active) and _formation_distance(active, enemy, n) != 1:
			continue
		var c := _hex_center(n)
		if _is_pair(active):
			c += Vector3(0, 0, RADIUS * 1.5)
		var side := Vector2(c.x - center.x, c.z - center.z).normalized()
		var dot := side.dot(pointer.normalized()) if pointer.length() > 0.01 else -float(_hex_distance(n, cells[active]))
		if dot > best_dot or (is_equal_approx(dot, best_dot) and options[n].size() < options.get(best, []).size()):
			best_dot = dot
			best = n
	return best


func _ground_point(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if dir.y >= 0.0:
		return origin
	return origin + dir * (-origin.y / dir.y)


func _hex_under(screen: Vector2) -> Vector2i:
	return _hex_at(_ground_point(screen))


## Противник под курсором: на его гексе или в экранной рамке по костям; из нескольких — ближний к камере.
func _enemy_under(screen: Vector2) -> Creature:
	var hex := _hex_under(screen)
	var best: Creature
	for c in _living(1):
		if (_footprint(c).has(hex) or _over_body(c, screen)) and (best == null or c.position.z > best.position.z):
			best = c
	return best


## Своё существо под курсором: на его гексе или в экранной рамке по костям.
func _ally_under(screen: Vector2) -> Creature:
	var hex := _hex_under(screen)
	var best: Creature
	for c in _living(0):
		if (_footprint(c).has(hex) or _over_body(c, screen)) and (best == null or c.position.z > best.position.z):
			best = c
	return best


func _over_body(c: Creature, screen: Vector2) -> bool:
	var box := Rect2(camera.unproject_position(c.bone_world(0)), Vector2.ZERO)
	for i in c.skeleton.get_bone_count():
		box = box.expand(camera.unproject_position(c.bone_world(i)))
	if _is_pair(c):
		var dog: Node3D = c.get("_dog_model")
		var rig: Skeleton3D = dog.find_children("*", "Skeleton3D", true, false)[0]
		var dog_box := Rect2(camera.unproject_position(dog.global_position), Vector2.ZERO)
		for i in rig.get_bone_count():
			dog_box = dog_box.expand(camera.unproject_position(rig.global_transform * rig.get_bone_global_pose(i).origin))
		if dog_box.grow(8.0).has_point(screen):
			return true
	return box.has_point(screen)


func _set_target(c: Creature) -> void:
	if c == _targeted:
		return
	if _targeted:
		_targeted.set_outline(null)
	_targeted = c
	if c:
		c.set_outline(TARGET)


# --- Отрисовка состояния ---

## Куда существо может дойти за свой ход.
func _range_of(c: Creature) -> Dictionary:
	var out := {}
	var paths := _paths_from(cells[c], c)
	for h: Vector2i in paths:
		if paths[h].size() <= c.get_meta("move"):
			out[h] = paths[h]
	return out


func _impact_cells(who: Creature, target: Creature, from: Vector2i) -> Array[Vector2i]:
	if who == null or target == null or who.melee_modes.is_empty() or from == NO_HEX:
		return []
	var contact: Vector2i = cells[target]
	for h in _footprint(target):
		if _hex_distance(from, h) < _hex_distance(from, contact):
			contact = h
	var zone: Array[Vector2i] = []
	for h in MELEE_AREA.zone(from, contact, who.wide_melee()):
		if tiles.has(h):
			zone.append(h)
	return zone


func _melee_victims(who: Creature, target: Creature, from: Vector2i) -> Array[Creature]:
	var result: Array[Creature] = []
	var zone := _impact_cells(who, target, from)
	for side in sides:
		for c: Creature in side:
			if c == who or not c.can_be_hit():
				continue
			for h in _footprint(c):
				if zone.has(h):
					result.append(c)
					break
	return result


func _choose_melee_mode(who: Creature, target: Creature) -> void:
	if who.melee_modes.is_empty():
		return
	who.set_melee_mode("area")
	var allies: Array = sides[0] if sides[0].has(who) else sides[1]
	for c in _melee_victims(who, target, cells[who]):
		if allies.has(c):
			who.set_melee_mode("point")
			return


func _paint() -> void:
	var zone: Array[Vector2i] = []
	if turn == Turn.PLAYER:
		zone = _impact_cells(active, _targeted, _attack_from)
	var shown := reachable
	var tint := PLAYER_TURN
	var center: Variant = cells[active] if active else null
	var preview := active
	if _inspected:
		preview = _inspected
		shown = _range_of(_inspected)
		tint = ENEMY_TURN if sides[1].has(_inspected) else PLAYER_TURN
		center = cells[_inspected]
	for h: Vector2i in tiles:
		var color := Color(tint, 0.0)
		if shown.has(h) and h != center:
			color.a = RANGE_ALPHA
			if h == _hovered:
				color.a = lerpf(RANGE_ALPHA, 1.0, 0.5)
		var attack_cells: Array[Vector2i] = []
		if _attack_from != NO_HEX:
			attack_cells = PAIR_PATHS.footprint(_attack_from, PAIR_PATHS.DOG) if _is_pair(active) else _footprint(active, _attack_from)
		if attack_cells.has(h):
			color = Color(TARGET, 0.8)
		elif active and _is_pair(active) and _footprint(active).has(h):
			color = Color(PLAYER_TURN if sides[0].has(active) else ENEMY_TURN, RANGE_ALPHA)
		elif preview and shown.has(_hovered) and _footprint(preview, _hovered).has(h):
			color = Color(tint, RANGE_ALPHA * 2.0)
		if zone.has(h):
			var occupant := _unit_on(h)
			var friendly := occupant != null and sides[0].has(occupant) == sides[0].has(active)
			color = Color(1.0, 0.18 if friendly else 0.5, 0.1, 0.8)
		tiles[h].visible = color.a > 0.0
		tiles[h].material_override.albedo_color = color


func _clear_hover() -> void:
	_pointer_inside = false
	_set_target(null)
	_attack_from = NO_HEX
	_hovered = NO_HEX
	_inspected = null
	_paint()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_hover_queue(delta)
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if keys != Vector2.ZERO:
		_pan_by(Vector3(keys.x, 0.0, keys.y) * PAN_KEYS * delta / Engine.time_scale)
	wait_button.disabled = turn != Turn.PLAYER or _wait_phase
	wait_button.modulate.a = 0.4 if wait_button.disabled else 1.0
	_zoom_idle += delta
	if _zoom_idle > ZOOM_HOLD:
		_zoom_target = 0.0
	if absf(_zoom - _zoom_target) > 0.001:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
		_apply_zoom()
	var mouse := get_viewport().get_mouse_position()
	var enemy := _enemy_under(mouse) if _pointer_inside else null
	var targeted := enemy if turn == Turn.PLAYER else null
	_set_target(targeted)
	var h := NO_HEX if enemy or not _pointer_inside else _hex_under(mouse)  # противник заслоняет гексы за собой
	var shooter := turn == Turn.PLAYER and active.ranged()
	var from := _attack_hex(mouse, targeted) if targeted and not shooter else NO_HEX
	var inspected: Creature = (enemy if enemy else _ally_under(mouse)) if _pointer_inside else null
	if turn == Turn.BUSY:  # гекс уже новый, а существо ещё идёт
		inspected = null
	if h != _hovered or from != _attack_from or inspected != _inspected:
		_hovered = h
		_attack_from = from
		_inspected = inspected
		_paint()
	sword.visible = from != NO_HEX
	if sword.visible:
		# Остриё в курсоре, меч смотрит от гекса атаки к противнику.
		var origin := _hex_center(from) + (Vector3(0, 0, RADIUS * 1.5) if _is_pair(active) else Vector3.ZERO)
		var a := camera.unproject_position(origin)
		var b := camera.unproject_position(_hex_center(cells[targeted]))
		sword.position = mouse
		sword.rotation = (b - a).angle()
	mode_button.visible = shooter
	melee_mode_button.visible = turn == Turn.PLAYER and not active.melee_modes.is_empty()
	if melee_mode_button.visible:
		melee_mode_button.text = "Атака: " + active.melee_title()
		melee_mode_button.tooltip_text = "3 гекса, включая своих" if active.wide_melee() else "Только выбранная цель"
	if shooter:
		var single: bool = active.allowed_shots(_enemy_adjacent(active)).size() < 2
		mode_button.disabled = single
		mode_button.modulate.a = 0.4 if single else 1.0
		mode_button.get_child(0).mode = active.shot_mode
		bow.mode = active.shot_mode
	bow.visible = shooter and targeted != null
	bow.position = mouse
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if bow.visible or sword.visible else Input.MOUSE_MODE_VISIBLE  # лук и меч заменяют курсор
	status.text = _status_text(inspected, from)


func _status_text(unit: Creature, from: Vector2i) -> String:
	if unit:
		var text := "%s: удары %d/%d" % [unit.get_meta("title"), unit.hits, Creature.HITS_TO_KILL]
		if unit == _targeted and not active.melee_modes.is_empty() and from != NO_HEX:
			text += " · " + active.melee_title()
			var allies := 0
			for c in _melee_victims(active, unit, from):
				if sides[0].has(c) == sides[0].has(active):
					allies += 1
			if allies > 0:
				text += " · Заденет своих: %d" % allies
		if unit == _targeted and from == NO_HEX and not active.ranged():
			text += ", не дотянуться"
		return text
	match turn:
		Turn.PLAYER:
			if not active.melee_modes.is_empty():
				return "%s: %s%s" % [active.get_meta("title"), active.melee_title(), " — задевает своих" if active.wide_melee() else " — только цель"]
			if _is_pair(active):
				return "Псарь с собакой: ход %d; атака на всё поле по свободному пути, собака возвращается" % active.get_meta("move")
			if active.ranged():
				return "%s: ход %d, %s" % [active.get_meta("title"), active.get_meta("move"), active.shots[active.shot_mode].title]
			return "%s: ход %d" % [active.get_meta("title"), active.get_meta("move")]
		Turn.OVER:
			return "Победа!" if not _living(0).is_empty() else "Поражение."
	return "Ходит: %s" % active.get_meta("title")
