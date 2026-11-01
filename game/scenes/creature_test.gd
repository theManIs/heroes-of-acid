extends Node3D
## Тестовая арена: пошаговый бой двух одинаковых существ на гексах (проверка существа из пайплайна).
## Твой ход: клик по подсвеченному гексу — идти (до MOVE гексов), клик по противнику — подойти и ударить.
## Потом ходит противник: подходит и бьёт. Обводка по контуру того, кто ходит: синяя — твой боец, красная — противник.
## Отладка: godot --path game -- --shot=<префикс> — кадр арены <префикс>-arena.png.

# Проверяемое существо: оба бойца — оно. Новое существо — добавить запись в CREATURES; выбор — пиктограммы слева.
const TESTED := "militiaman"  # с кого начинать
const CREATURES := {
	"ghoul": {
		"name": "Упырь", "icon": "res://assets/creatures/ghoul/icon.png",
		"scene": "res://assets/creatures/ghoul/ghoul.glb",
		"extra": ["res://assets/creatures/ghoul/ghoul-anims2.glb", "res://assets/creatures/ghoul/ghoul-anims3.glb",
			"res://assets/creatures/ghoul/ghoul-anims5.glb", "res://assets/creatures/ghoul/ghoul-anims6.glb"],
		"attack": "pitch_baseball", "attack_from": 0.33,  # с 33 %: сразу выброс руки, без долгого замаха
		"hurt": "hit_to_body_01", "hurt_len": 0.0, "idle": "look_around", "defend": "afraid", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3, "size": 1.6,
	},
	"boilerman": {
		"name": "Котельщик", "icon": "res://assets/creatures/boilerman/icon.png", "icon_up": 0.03, "icon_dist": 1.4,  # маска-купол выше кости головы
		"scene": "res://assets/creatures/boilerman/boilerman.glb",
		"extra": ["res://assets/creatures/boilerman/boilerman-anims2.glb", "res://assets/creatures/boilerman/boilerman-anims3.glb",
			"res://assets/creatures/boilerman/boilerman-anims5.glb"],
		"attack": "box_01", "attack_from": 0.0,  # один прямой выпад, пик на 0,65 с
		"hurt": "hit_to_head", "hurt_len": 0.0, "idle": "idle",  # hit_to_head — лучшая реакция на удар
		"defend": "scared_01", "defend_from": 0.27, "defend_len": 1.4, "defend_lead": 0.3, "size": 1.9,  # кусок 0,9–2,3 с: руки у лица, отшатнулся
		"smoke": true,  # дым из трубы котла
	},
	"vampire": {
		"name": "Вампир", "icon": "res://assets/creatures/vampire/icon.png",
		"scene": "res://assets/creatures/vampire/vampire.glb",
		"extra": ["res://assets/creatures/vampire/vampire-anims2.glb", "res://assets/creatures/vampire/vampire-anims3.glb"],
		"attack": "slash", "attack_from": 0.0,  # удар когтями наотмашь с выпадом корпусом
		"hurt": "hit_to_head", "hurt_len": 0.0, "idle": "standing_relax",
		"defend": "hit_to_side", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.4, "defend_pin": false,  # уклон вбок
		"size": 1.95,
	},
	"militiaman": {
		"name": "Ополченец", "icon": "res://assets/creatures/militiaman/icon.png",
		"scene": "res://assets/creatures/militiaman/militiaman.glb",
		"extra": ["res://assets/creatures/militiaman/militiaman-anims2.glb", "res://assets/creatures/militiaman/militiaman-anims3.glb"],
		"attack": "chop", "attack_from": 0.0,  # замах и рубящий удар топором сверху
		"hurt": "hit_to_head", "hurt_len": 0.0, "idle": "idle",
		"defend": "scared_01", "defend_from": 0.0, "defend_len": 1.3, "defend_lead": 0.3,  # руки со щитом подняты перед лицом
		"size": 1.85,
	},
	"flesh-golem": {
		"name": "Голем", "icon": "res://assets/creatures/flesh-golem/icon.png",
		"scene": "res://assets/creatures/flesh-golem/flesh-golem.glb",
		"extra": ["res://assets/creatures/flesh-golem/flesh-golem-anims2.glb", "res://assets/creatures/flesh-golem/flesh-golem-anims4.glb"],
		"attack": "slash", "attack_from": 0.0,
		"hurt": "hit_to_body_01", "hurt_len": 0.65, "idle": "idle", "defend": "fold_arms", "defend_from": 0.102, "defend_len": 1.6, "defend_lead": 1.0, "size": 2.0,  # кусок 1,75–3,35 с: руки скрещиваются
	},
}
const COLS := 6
const ROWS := 4
const MOVE := 3  # гексов за ход
const OVERLAP := 0.1  # кулак входит в тело врага, метров
const TILE_HEIGHT := 0.12
const TILE_GAP := 0.94  # доля радиуса: щель между плитками
const PLAYER_TURN := Color(0.25, 0.55, 1.0)
const ENEMY_TURN := Color(1.0, 0.25, 0.2)
const TARGET := Color(0.3, 0.95, 0.35)  # противник под курсором — можно ударить
const SWORD := preload("res://scenes/sword_cursor.gd")
const NO_HEX := Vector2i(999, 999)
const CAMERA_REF_RADIUS := 0.445  # радиус гекса, под который выставлялась камера (кадр упыря)
const HEX_RADIUS := 0.6  # поле одно для всех существ; дальность удара добирается выпадом
const CAMERA_ZOOM := 0.75  # меньше — камера ближе
const ZOOM_NEAR := 0.2  # насколько сокращается дистанция при полном приближении
const ZOOM_PINCH := 0.5  # чувствительность щипка
const ZOOM_WHEEL := 0.12  # шаг колеса мыши
const ZOOM_HOLD := 0.5  # жест молчит столько секунд — считаем, что пальцы отпущены
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

enum Turn { PLAYER, ENEMY, BUSY, OVER }

var player: Creature
var enemy: Creature
var board := Node3D.new()  # плитки и основание
var tested: String = TESTED
var _cache: Array[Resource] = []  # все модели и анимации держим загруженными: смена существа без перезагрузки
var _roster_group := ButtonGroup.new()
var camera := Camera3D.new()
var status := Label.new()
var radius := 0.85  # радиус гекса: соседние центры — ровно на дистанции удара
var tiles := {}  # Vector2i (осевые координаты) -> MeshInstance3D
var turn := Turn.PLAYER
var reachable := {}  # Vector2i -> путь (Array[Vector2i]) для текущего хода игрока
var _hovered := Vector2i(999, 999)
var _targeted := false  # на противнике зелёная обводка
var _attack_from := Vector2i(999, 999)  # гекс, с которого будет удар (выбран сектором под курсором)
var sword: Control
var _cam_base := Vector3.ZERO  # камера общего плана
var _cam_look := Vector3.ZERO
var _zoom := 0.0  # 0 — общий план, 1 — вплотную
var _zoom_target := 0.0
var _zoom_focus := Vector3.ZERO  # на что смотрим при приближении
var _zoom_idle := INF  # секунд с последнего движения жеста


func _ready() -> void:
	for cfg: Dictionary in CREATURES.values():
		_cache.append(load(cfg.scene))
		for path: String in cfg.extra:
			_cache.append(load(path))
	player = _make()
	enemy = _make()
	_fit_radius()
	add_child(board)
	_build_world()
	_build_board()
	_build_hud()
	_reset()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _make() -> Creature:
	var c := Creature.new()
	add_child(c)
	var cfg: Dictionary = CREATURES[tested]
	c.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	c.defend_anim = cfg.defend
	c.defend_from = cfg.defend_from
	c.defend_len = cfg.defend_len
	c.defend_lead = cfg.defend_lead
	c.hurt_len = cfg.hurt_len
	c.defend_pin = cfg.get("defend_pin", true)
	if cfg.get("smoke", false):
		c.add_smoke()
	return c


## Сменить проверяемое существо: сцена и поле те же, пересоздаются только бойцы.
func _switch(id: String) -> void:
	if id == tested or turn == Turn.BUSY or turn == Turn.ENEMY:
		return
	tested = id
	player.queue_free()
	enemy.queue_free()
	player = _make()
	enemy = _make()
	_reset()


func _fit_radius() -> void:
	radius = HEX_RADIUS


## Размер гекса зависит от дальности удара существа — камера отъезжает пропорционально,
## чтобы поле в кадре выглядело одинаково для любого существа.
func _place_camera() -> void:
	var k := radius / CAMERA_REF_RADIUS * CAMERA_ZOOM
	_cam_base = Vector3(0, 2.6, 3.6) * k
	_cam_look = Vector3(0, 0.5, 0) * k
	_apply_zoom()


## Щипок и колесо: камера едет к точке под курсором; отпустил пальцы — вернулась на общий план.
func _apply_zoom() -> void:
	var look := _cam_look.lerp(_zoom_focus, _zoom)
	camera.position = look + (_cam_base - _cam_look) * (1.0 - _zoom * ZOOM_NEAR)
	camera.look_at(look)


func _zoom_by(amount: float, screen: Vector2) -> void:
	if _zoom_target <= 0.001:  # начало жеста: выбрать, куда приближаемся
		_zoom_focus = _focus_under(screen)
	_zoom_target = clampf(_zoom_target + amount, 0.0, 1.0)
	_zoom_idle = 0.0


## Существо под курсором — середина его тела, иначе точка на земле.
func _focus_under(screen: Vector2) -> Vector3:
	var hex := _hex_at(_ground_point(screen))
	if _on_enemy(screen) or hex == _hex_of(enemy):
		return enemy.position + Vector3.UP * enemy.height * 0.6
	if hex == _hex_of(player):
		return player.position + Vector3.UP * player.height * 0.6
	return _ground_point(screen)


func _hex_spacing() -> float:
	return radius * sqrt(3.0)


# --- Гексы (pointy-top, осевые координаты q, r) ---

func _hex_center(h: Vector2i) -> Vector3:
	var x := radius * sqrt(3.0) * (h.x + h.y * 0.5)
	var z := radius * 1.5 * h.y
	return Vector3(x, 0.0, z) - _board_offset()


func _board_offset() -> Vector3:
	var w := radius * sqrt(3.0) * (COLS - 0.5)
	var d := radius * 1.5 * (ROWS - 1)
	return Vector3(w * 0.5, 0.0, d * 0.5)


## Клетка по колонке и ряду прямоугольного поля → осевые координаты.
func _cell(col: int, row: int) -> Vector2i:
	return Vector2i(col - floori(row / 2.0), row)


func _cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in ROWS:
		for c in COLS:
			out.append(_cell(c, r))
	return out


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


func _hex_at(point: Vector3) -> Vector2i:
	var best := Vector2i(999, 999)
	var best_d := INF
	for h: Vector2i in tiles:
		var d := _hex_center(h).distance_to(Vector3(point.x, 0.0, point.z))
		if d < best_d:
			best_d = d
			best = h
	return best if best_d < radius else Vector2i(999, 999)


## Кратчайшие пути от from по свободным гексам: гекс -> путь без стартового гекса.
func _paths_from(from: Vector2i, blocked: Vector2i) -> Dictionary:
	var paths := {from: [] as Array[Vector2i]}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_front()
		for d in DIRS:
			var n := h + d
			if not tiles.has(n) or n == blocked or paths.has(n):
				continue
			var p: Array[Vector2i] = paths[h].duplicate()
			p.append(n)
			paths[n] = p
			queue.append(n)
	return paths


func _to_points(path: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for h: Vector2i in path:
		out.append(_hex_center(h))
	return out


# --- Сцена ---

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	camera.fov = 55.0  # фигурки крупно, крайние гексы видны частично
	add_child(camera)
	_place_camera()


func _build_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * TILE_GAP
	mesh.bottom_radius = radius * TILE_GAP
	mesh.height = TILE_HEIGHT
	mesh.radial_segments = 6
	mesh.rings = 1
	for h in _cells():
		var tile := MeshInstance3D.new()
		tile.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _stone(rng)
		mat.roughness = 0.9
		tile.material_override = mat
		tile.set_meta("base", mat.albedo_color)
		tile.position = _hex_center(h) - Vector3(0, TILE_HEIGHT * 0.5, 0)
		board.add_child(tile)
		tiles[h] = tile

	# Основание под плитками: тёмная плита, в щелях между гексами видна она.
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	var off := _board_offset()
	box.size = Vector3(off.x * 2.0 + radius * 2.4, 0.25, off.z * 2.0 + radius * 2.6)
	base.mesh = box
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.09, 0.09, 0.1)
	base.material_override = base_mat
	base.position = Vector3(0, -TILE_HEIGHT - 0.125 + 0.02, 0)
	board.add_child(base)


func _stone(rng: RandomNumberGenerator) -> Color:
	var v := rng.randf_range(-0.03, 0.03)
	return Color(0.33 + v, 0.33 + v, 0.31 + v)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	status.position = Vector2(16, 12)
	hud.add_child(status)
	sword = Control.new()
	sword.set_script(SWORD)
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword.visible = false
	hud.add_child(sword)

	# Слева — пиктограммы существ: клик меняет проверяемое существо.
	var roster := VBoxContainer.new()
	roster.position = Vector2(16, 48)
	roster.add_theme_constant_override("separation", 8)
	hud.add_child(roster)
	for id: String in CREATURES:
		var b := Button.new()
		b.icon = load(CREATURES[id].icon)
		b.text = CREATURES[id].name
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(96, 116)
		for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, _icon_style(state))
		b.toggle_mode = true
		b.button_pressed = id == tested
		b.button_group = _roster_group
		b.pressed.connect(_switch.bind(id))
		roster.add_child(b)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -64
	bar.offset_bottom = -16
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)
	for item in [["Защита", _defend], ["Пропустить ход", _skip], ["Заново", _reset]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(160, 48)
		button.pressed.connect(item[1])
		bar.add_child(button)



## Рамка пиктограммы: при наведении — белая обводка, выбранная — тонкая серая.
func _icon_style(state: String) -> StyleBox:
	if state == "focus":
		return StyleBoxEmpty.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(4)
	var width := 0
	if state.begins_with("hover"):
		width = 3
		box.border_color = Color.WHITE
	elif state == "pressed":
		width = 1
		box.border_color = Color(0.6, 0.6, 0.65)
	box.set_border_width_all(width)
	return box


func _reset() -> void:
	player.revive()
	enemy.revive()
	player.position = _hex_center(_cell(1, 1))  # как в Героях: свой — слева
	enemy.position = _hex_center(_cell(COLS - 2, 2))  # противник — справа, на ряд ближе к зрителю
	player.face(enemy.position)
	enemy.face(player.position)
	_start_player_turn()


func _hex_of(c: Creature) -> Vector2i:
	return _hex_at(c.position)


func _start_player_turn() -> void:
	if player.dead or enemy.dead:
		_game_over()
		return
	turn = Turn.PLAYER
	player.defending = false
	enemy.set_outline(null)
	player.set_outline(PLAYER_TURN)
	reachable.clear()
	var paths := _paths_from(_hex_of(player), _hex_of(enemy))
	for h: Vector2i in paths:
		if paths[h].size() <= MOVE:
			reachable[h] = paths[h]
	_paint()


func _start_enemy_turn() -> void:
	if player.dead or enemy.dead:
		_game_over()
		return
	turn = Turn.ENEMY
	player.set_outline(null)
	enemy.set_outline(ENEMY_TURN)
	reachable.clear()
	_paint()
	await get_tree().create_timer(0.6).timeout
	var path := _approach(enemy, player)
	_move_and_maybe_strike(enemy, player, path, _start_player_turn)


func _game_over() -> void:
	turn = Turn.OVER
	player.set_outline(null)
	enemy.set_outline(null)
	reachable.clear()
	_paint()


## Защита, как в Героях: ход заканчивается, до своего следующего хода удары не засчитываются.
func _defend() -> void:
	if turn != Turn.PLAYER:
		return
	player.defending = true
	player.set_outline(null)
	_start_enemy_turn()


func _skip() -> void:
	if turn == Turn.PLAYER:
		_start_enemy_turn()


## Путь к ближайшему свободному соседу цели; не дальше MOVE (тогда — часть пути).
func _approach(who: Creature, target: Creature) -> Array[Vector2i]:
	var goal := _hex_of(target)
	var start := _hex_of(who)
	if _hex_distance(start, goal) == 1:
		return []
	var paths := _paths_from(start, goal)
	var best: Array[Vector2i] = []
	var found := false
	for h: Vector2i in paths:
		if _hex_distance(h, goal) == 1 and (not found or paths[h].size() < best.size()):
			best = paths[h]
			found = true
	return best.slice(0, MOVE)


## Пройти путь; если в конце стоим рядом с целью — ударить. Потом next.
func _move_and_maybe_strike(who: Creature, target: Creature, path: Array[Vector2i], next: Callable) -> void:
	turn = Turn.BUSY
	_targeted = false
	who.set_outline(null)
	target.set_outline(null)  # обводка — пока выбирается действие; выбрал — убираем
	reachable.clear()
	_paint()
	if not path.is_empty():
		who.walk_path(_to_points(path))
		await who.arrived
	if _hex_distance(_hex_of(who), _hex_of(target)) == 1:
		who.strike(target, _hex_spacing(), OVERLAP)
		await get_tree().create_timer(who.hit_delay() + 1.5).timeout  # попадание + реакция цели
	else:
		who.face(target.position)
	next.call()


func _unhandled_input(event: InputEvent) -> void:
	var pinch := event as InputEventMagnifyGesture
	if pinch:
		_zoom_by((pinch.factor - 1.0) * ZOOM_PINCH, pinch.position)
		return
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_by(ZOOM_WHEEL if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_WHEEL, wheel.position)
		return
	var click := event as InputEventMouseButton
	if turn != Turn.PLAYER or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _on_enemy(click.position) or _hex_at(_ground_point(click.position)) == _hex_of(enemy):
		var from := _attack_hex(click.position)
		if from != NO_HEX and enemy.can_be_hit():
			var path: Array[Vector2i] = [] if from == _hex_of(player) else reachable[from]
			_move_and_maybe_strike(player, enemy, path, _start_enemy_turn)
		return
	var h := _hex_under(click.position)
	if reachable.has(h) and h != _hex_of(player):
		_move_and_maybe_strike(player, enemy, reachable[h], _start_enemy_turn)


## Гекс атаки — от гекса, а не от модели: 6 треугольников гекса противника, продлённых за его
## края; в какой клин на земле попадает точка под курсором, с того соседнего гекса и бьём.
## Тело существа только перекрывает эти клинья на экране. Сторона занята, за краем поля
## или вне хода — ближайшая по углу доступная.
func _attack_hex(screen: Vector2) -> Vector2i:
	var target := _hex_of(enemy)
	var mine := _hex_of(player)
	var center := _hex_center(target)
	var ground := _ground_point(screen)
	var pointer := Vector2(ground.x - center.x, ground.z - center.z)
	var best := NO_HEX
	var best_dot := -INF
	for d in DIRS:
		var n := target + d
		if not tiles.has(n) or not (n == mine or reachable.has(n)):
			continue
		var c := _hex_center(n)
		var side := Vector2(c.x - center.x, c.z - center.z).normalized()
		var dot := side.dot(pointer.normalized()) if pointer.length() > 0.01 else -float(_hex_distance(n, mine))
		if dot > best_dot:
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
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if dir.y >= 0.0:
		return Vector2i(999, 999)
	return _hex_at(origin + dir * (-origin.y / dir.y))


## Курсор над врагом: экранная рамка по всем костям в текущей позе плюс толщина тела.
func _on_enemy(screen: Vector2) -> bool:
	var box := Rect2(camera.unproject_position(enemy.bone_world(0)), Vector2.ZERO)
	for i in enemy.skeleton.get_bone_count():
		box = box.expand(camera.unproject_position(enemy.bone_world(i)))
	var center := enemy.position + Vector3.UP * enemy.height * 0.5
	var pad := camera.unproject_position(center + camera.global_basis.x * 0.25).x - camera.unproject_position(center).x
	return box.grow(absf(pad)).has_point(screen)


# --- Отрисовка состояния ---

func _paint() -> void:
	for h: Vector2i in tiles:
		var mat: StandardMaterial3D = tiles[h].material_override
		var color: Color = tiles[h].get_meta("base")
		if reachable.has(h) and h != _hex_of(player):
			color = color.lerp(PLAYER_TURN, 0.25)
			if h == _hovered:
				color = color.lerp(PLAYER_TURN, 0.35)
		if h == _attack_from:
			color = color.lerp(TARGET, 0.55)
		mat.albedo_color = color


func _process(delta: float) -> void:
	_zoom_idle += delta
	if _zoom_idle > ZOOM_HOLD:
		_zoom_target = 0.0
	if absf(_zoom - _zoom_target) > 0.001:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
		_apply_zoom()
	var mouse := get_viewport().get_mouse_position()
	var over_enemy := not player.dead and (_on_enemy(mouse) or _hex_at(_ground_point(mouse)) == _hex_of(enemy))
	var targeted := turn == Turn.PLAYER and over_enemy and enemy.can_be_hit()
	if targeted != _targeted:
		_targeted = targeted
		enemy.set_outline(TARGET if targeted else null)
	var h := NO_HEX if over_enemy else _hex_under(mouse)  # противник заслоняет гексы за собой
	var from := _attack_hex(mouse) if targeted else NO_HEX
	if h != _hovered or from != _attack_from:
		_hovered = h
		_attack_from = from
		_paint()
	sword.visible = from != NO_HEX
	if sword.visible:
		# Остриё в курсоре, меч смотрит от гекса атаки к противнику.
		var a := camera.unproject_position(_hex_center(from))
		var b := camera.unproject_position(_hex_center(_hex_of(enemy)))
		sword.position = mouse
		sword.rotation = (b - a).angle()
	var text := ""
	match turn:
		Turn.PLAYER:
			text = "Твой ход: гекс — идти (до %d), противник — подойти и ударить, «Защита» — ждать удара" % MOVE
		Turn.ENEMY, Turn.BUSY:
			text = "Ход…" if turn == Turn.BUSY else "Ход противника"
		Turn.OVER:
			text = "Победа!" if enemy.dead else "Поражение."
	if over_enemy:
		text = "Противник: удары %d/%d" % [enemy.hits, Creature.HITS_TO_KILL]
		if targeted and from == NO_HEX:
			text += ". Не дотянуться: нет свободной стороны в пределах хода"
	status.text = text


func _shoot(prefix: String) -> void:
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-arena.png")
	# Упырь вплотную бьёт голема: кадр в момент попадания.
	enemy.position = _hex_center(_hex_of(player) + Vector2i(1, 0))
	player.defending = true  # кадр показывает защиту
	enemy.strike(player, _hex_spacing(), OVERLAP)
	await get_tree().create_timer(enemy.hit_delay() + 0.05).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-hit.png")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "-hit2.png")
	get_tree().quit()
