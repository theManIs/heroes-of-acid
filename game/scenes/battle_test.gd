extends Node3D
## Тест боя: поле 15×11 как в Героях 3, все существа слева против всех справа.
## Игровой ход: каждое существо ходит один раз, порядок — по инициативе, он показан в шкале сверху.
## Твоя сторона — левая: клик по подсвеченному гексу — идти (дальность своя у каждого, MOVES), клик по противнику — подойти и ударить.
## Запуск: godot --path game res://scenes/battle_test.tscn
## Отладка: -- --auto — обе стороны играют сами, ускоренно; -- --shot=<префикс> — кадры <префикс>-start.png, -end.png.

const ARENA := preload("res://scenes/creature_test.gd")  # записи существ — там
const SWORD := preload("res://scenes/sword_cursor.gd")
const ACTION_ICON := preload("res://scenes/action_icon.gd")
const COLS := 15
const ROWS := 11
const START_ROWS: Array[int] = [1, 3, 5, 7, 9]  # ряды, где стоят существа в начале боя
const MOVES := {"ghoul": 8, "vampire": 7, "militiaman": 6, "boilerman": 5, "flesh-golem": 4}  # гексов за ход: чем массивнее, тем меньше
const WALK_RATE := 2.0  # ходьба вдвое быстрее, чем в арене
const OVERLAP := 0.1  # кулак входит в тело врага, метров
const TILE_HEIGHT := 0.12
const TILE_GAP := 0.94  # доля радиуса: щель между плитками
const RADIUS := 0.6
const PLAYER_TURN := Color(0.25, 0.55, 1.0)
const ENEMY_TURN := Color(1.0, 0.25, 0.2)
const TARGET := Color(0.3, 0.95, 0.35)  # противник под курсором — можно ударить
const NO_HEX := Vector2i(999, 999)
const QUEUE_ICON := 44.0  # размер пиктограммы в шкале инициативы
const CAMERA_DIR := Vector3(0, 1.0, 1.0)  # камера под 45° к земле
const CAMERA_CLOSE := 0.8  # ближе, чем нужно для всего поля: крайние гексы могут не влезать
const ZOOM_NEAR := 0.2  # насколько сокращается дистанция при полном приближении
const ZOOM_PINCH := 0.5  # чувствительность щипка
const ZOOM_WHEEL := 0.12  # шаг колеса мыши
const ZOOM_HOLD := 0.5  # жест молчит столько секунд — считаем, что пальцы отпущены
const GAME_SPEED := 2.0  # вся игра быстрее: анимации, ходьба и паузы
const AUTO_SPEED := 5.0  # ускорение при --auto
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

enum Turn { PLAYER, ENEMY, BUSY, OVER }

var sides: Array[Array] = [[], []]  # 0 — левая (твоя), 1 — правая
var cells := {}  # Creature -> гекс
var active: Creature  # кто сейчас ходит
var board := Node3D.new()
var camera := Camera3D.new()
var status := Label.new()
var tiles := {}  # Vector2i (осевые координаты) -> MeshInstance3D
var turn := Turn.PLAYER
var reachable := {}  # Vector2i -> путь (Array[Vector2i]) для текущего хода игрока
var sword: Control
var queue_bar := HBoxContainer.new()  # шкала инициативы
var wait_button: Button
var round_no := 0  # номер игрового хода
var _queue: Array[Creature] = []  # кто ещё не ходил в этом игровом ходу
var _waiting: Array[Creature] = []  # нажали «Ждать»: сходят в конце игрового хода
var _wait_phase := false  # очередь ожидавших: ждать второй раз нельзя
var _hovered := NO_HEX
var _attack_from := NO_HEX  # гекс, с которого будет удар
var _targeted: Creature  # противник с зелёной обводкой
var _inspected: Creature  # существо под курсором: показываем его дальность хода
var _auto := false
var _shot := ""
var _cam_base := Vector3.ZERO  # камера общего плана
var _cam_look := Vector3(0, 0.5, 0)
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
		for id: String in ARENA.CREATURES:
			side.append(_make(id))
	add_child(board)
	_build_world()
	_build_board()
	_build_hud()
	_place_camera()
	get_viewport().size_changed.connect(_place_camera)
	_reset()
	if _shot != "":
		await get_tree().create_timer(0.8 * Engine.time_scale).timeout
		get_viewport().get_texture().get_image().save_png(_shot + "-start.png")


func _make(id: String) -> Creature:
	var c := Creature.new()
	add_child(c)
	var cfg: Dictionary = ARENA.CREATURES[id]
	c.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	c.defend_anim = cfg.defend
	c.defend_from = cfg.defend_from
	c.defend_len = cfg.defend_len
	c.defend_lead = cfg.defend_lead
	c.hurt_len = cfg.hurt_len
	c.defend_pin = cfg.get("defend_pin", true)
	c.scale_bones(cfg.defend, cfg.get("defend_calm", []), cfg.get("defend_calm_by", 1.0))
	c.walk_rate = WALK_RATE
	c.set_meta("move", MOVES[id])
	c.set_meta("title", cfg.name)
	c.set_meta("icon", cfg.icon)
	if cfg.get("smoke", false):
		c.add_smoke()
	return c


# --- Камера ---

## Камера отъезжает, пока в кадр не войдёт всё поле с головами в дальнем ряду, затем подъезжает на CAMERA_CLOSE.
func _place_camera() -> void:
	var off := _board_offset()
	var points: Array[Vector3] = [
		Vector3(-off.x - RADIUS, 2.2, -off.z - RADIUS), Vector3(off.x + RADIUS, 2.2, -off.z - RADIUS),
		Vector3(-off.x - RADIUS, 0.0, off.z + RADIUS * 3.0), Vector3(off.x + RADIUS, 0.0, off.z + RADIUS * 3.0),
	]
	var dir := CAMERA_DIR.normalized()
	var dist := 4.0
	while dist < 60.0:
		_cam_base = _cam_look + dir * dist
		camera.position = _cam_base
		camera.look_at(_cam_look)
		if points.all(func(p: Vector3) -> bool: return camera.is_position_in_frustum(p)):
			break
		dist += 0.25
	_cam_base = _cam_look + dir * dist * CAMERA_CLOSE
	_apply_zoom()


## Щипок и колесо: камера едет к точке под курсором; отпустил пальцы — вернулась на общий план.
func _apply_zoom() -> void:
	var look := _cam_look.lerp(_zoom_focus, _zoom)
	camera.position = look + (_cam_base - _cam_look) * (1.0 - _zoom * ZOOM_NEAR)
	camera.look_at(look)


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


## Кратчайшие пути от from по свободным гексам: гекс -> путь без стартового гекса. Мёртвые не мешают.
func _paths_from(from: Vector2i) -> Dictionary:
	var blocked := {}
	for side in sides:
		for c: Creature in side:
			if c.can_be_hit():
				blocked[cells[c]] = true
	var paths := {from: [] as Array[Vector2i]}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_front()
		for d in DIRS:
			var n := h + d
			if not tiles.has(n) or blocked.has(n) or paths.has(n):
				continue
			var p: Array[Vector2i] = paths[h].duplicate()
			p.append(n)
			paths[n] = p
			queue.append(n)
	return paths


func _unit_on(h: Vector2i) -> Creature:
	for side in sides:
		for c: Creature in side:
			if c.can_be_hit() and cells[c] == h:
				return c
	return null


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

	camera.fov = 55.0
	add_child(camera)


func _build_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * TILE_GAP
	mesh.bottom_radius = RADIUS * TILE_GAP
	mesh.height = TILE_HEIGHT
	mesh.radial_segments = 6
	mesh.rings = 1
	for r in ROWS:
		for c in COLS:
			var h := _cell(c, r)
			var tile := MeshInstance3D.new()
			tile.mesh = mesh
			var mat := StandardMaterial3D.new()
			var v := rng.randf_range(-0.03, 0.03)
			mat.albedo_color = Color(0.33 + v, 0.33 + v, 0.31 + v)
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
	box.size = Vector3(off.x * 2.0 + RADIUS * 2.4, 0.25, off.z * 2.0 + RADIUS * 2.6)
	base.mesh = box
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.09, 0.09, 0.1)
	base.material_override = base_mat
	base.position = Vector3(0, -TILE_HEIGHT - 0.125 + 0.02, 0)
	board.add_child(base)


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

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -80
	bar.offset_bottom = -16
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	hud.add_child(bar)
	for item in [["Ждать", _wait, ACTION_ICON.Kind.WAIT], ["Защита", _defend, ACTION_ICON.Kind.DEFEND], ["Заново", _reset, ACTION_ICON.Kind.RESTART]]:
		var button := Button.new()
		button.tooltip_text = item[0]
		button.custom_minimum_size = Vector2(64, 64)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())  # подложка — клякса в иконке
		button.pressed.connect(item[1])
		var icon := Control.new()
		icon.set_script(ACTION_ICON)
		icon.kind = item[2]
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		bar.add_child(button)
	wait_button = bar.get_child(0)

	queue_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	queue_bar.offset_top = 40
	queue_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_bar.add_theme_constant_override("separation", 6)
	queue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(queue_bar)


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
			queue_bar.add_child(_queue_slot(c, false))
	if _waiting.any(func(c: Creature) -> bool: return c.can_be_hit()):
		queue_bar.add_child(_queue_label("Ждут"))
		for i in range(_waiting.size() - 1, -1, -1):
			if _waiting[i].can_be_hit():
				queue_bar.add_child(_queue_slot(_waiting[i], false))
	queue_bar.add_child(_queue_label("Ход %d" % (round_no + 1)))
	for c in _round_order():
		queue_bar.add_child(_queue_slot(c, false))


func _queue_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## Пиктограмма в шкале: рамка цвета стороны, у того, кто ходит сейчас, — крупнее.
func _queue_slot(c: Creature, current: bool) -> Control:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	box.border_color = PLAYER_TURN if sides[0].has(c) else ENEMY_TURN
	box.set_border_width_all(3)
	box.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", box)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := TextureRect.new()
	icon.texture = load(c.get_meta("icon"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2.ONE * (QUEUE_ICON * 1.3 if current else QUEUE_ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame


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
			cells[c] = _cell(0 if s == 0 else COLS - 1, START_ROWS[i])
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
	_show_queue()
	var left: bool = sides[0].has(active)
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


## Ходит сам: рядом есть враг — бьёт, иначе идёт к ближайшему и бьёт, если дошёл.
func _ai_move(enemy_side: int) -> void:
	var enemies := _living(enemy_side)
	for e: Creature in enemies:
		if _hex_distance(cells[active], cells[e]) == 1:
			_act(active, e, [] as Array[Vector2i])
			return
	var paths := _paths_from(cells[active])
	var best: Array[Vector2i] = []
	var target: Creature
	for h: Vector2i in paths:
		for e: Creature in enemies:
			if _hex_distance(h, cells[e]) == 1 and (target == null or paths[h].size() < best.size()):
				best = paths[h]
				target = e
	_act(active, target, best.slice(0, active.get_meta("move")))


## Пройти путь; если есть цель и стоим рядом с ней — ударить. Потом следующий ход.
func _act(who: Creature, target: Creature, path: Array[Vector2i]) -> void:
	turn = Turn.BUSY
	_set_target(null)
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
	if target and _hex_distance(cells[who], cells[target]) == 1:
		who.strike(target, _hex_spacing(), OVERLAP)
		await get_tree().create_timer(who.hit_delay()).timeout
		_show_queue()  # убитый уходит из шкалы в момент попадания
		await get_tree().create_timer(1.5).timeout  # реакция цели
	elif target:
		who.face(target.position)
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
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_by(ZOOM_WHEEL if click.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_WHEEL, click.position)
		return
	if turn != Turn.PLAYER or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var enemy := _enemy_under(click.position)
	if enemy:
		var from := _attack_hex(click.position, enemy)
		if from != NO_HEX:
			_act(active, enemy, reachable[from])
		return
	var h := _hex_under(click.position)
	if reachable.has(h) and h != cells[active]:
		_act(active, null, reachable[h])


## Гекс атаки — как в арене: в какой клин вокруг гекса противника попадает точка под курсором,
## с того соседнего гекса и бьём. Сторона занята или вне хода — ближайшая по углу доступная.
## Если уже стоим рядом с противником, не двигаемся.
func _attack_hex(screen: Vector2, enemy: Creature) -> Vector2i:
	var target: Vector2i = cells[enemy]
	if _hex_distance(cells[active], target) == 1:
		return cells[active]  # уже рядом: бьём с места
	var center := _hex_center(target)
	var ground := _ground_point(screen)
	var pointer := Vector2(ground.x - center.x, ground.z - center.z)
	var best := NO_HEX
	var best_dot := -INF
	for d in DIRS:
		var n := target + d
		if not reachable.has(n):
			continue
		var c := _hex_center(n)
		var side := Vector2(c.x - center.x, c.z - center.z).normalized()
		var dot := side.dot(pointer.normalized()) if pointer.length() > 0.01 else -float(_hex_distance(n, cells[active]))
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
	return _hex_at(_ground_point(screen))


## Противник под курсором: на его гексе или в экранной рамке по костям; из нескольких — ближний к камере.
func _enemy_under(screen: Vector2) -> Creature:
	var hex := _hex_under(screen)
	var best: Creature
	for c in _living(1):
		if (cells[c] == hex or _over_body(c, screen)) and (best == null or c.position.z > best.position.z):
			best = c
	return best


## Своё существо под курсором: на его гексе или в экранной рамке по костям.
func _ally_under(screen: Vector2) -> Creature:
	var hex := _hex_under(screen)
	var best: Creature
	for c in _living(0):
		if (cells[c] == hex or _over_body(c, screen)) and (best == null or c.position.z > best.position.z):
			best = c
	return best


func _over_body(c: Creature, screen: Vector2) -> bool:
	var box := Rect2(camera.unproject_position(c.bone_world(0)), Vector2.ZERO)
	for i in c.skeleton.get_bone_count():
		box = box.expand(camera.unproject_position(c.bone_world(i)))
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
	var paths := _paths_from(cells[c])
	for h: Vector2i in paths:
		if paths[h].size() <= c.get_meta("move"):
			out[h] = paths[h]
	return out


func _paint() -> void:
	var shown := reachable
	var tint := PLAYER_TURN
	var center: Variant = cells[active] if active else null
	if _inspected:
		shown = _range_of(_inspected)
		tint = ENEMY_TURN if sides[1].has(_inspected) else PLAYER_TURN
		center = cells[_inspected]
	for h: Vector2i in tiles:
		var mat: StandardMaterial3D = tiles[h].material_override
		var color: Color = tiles[h].get_meta("base")
		if shown.has(h) and h != center:
			color = color.lerp(tint, 0.25)
			if h == _hovered:
				color = color.lerp(tint, 0.35)
		if h == _attack_from:
			color = color.lerp(TARGET, 0.55)
		mat.albedo_color = color


func _process(delta: float) -> void:
	wait_button.disabled = turn != Turn.PLAYER or _wait_phase
	wait_button.modulate.a = 0.4 if wait_button.disabled else 1.0
	_zoom_idle += delta
	if _zoom_idle > ZOOM_HOLD:
		_zoom_target = 0.0
	if absf(_zoom - _zoom_target) > 0.001:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
		_apply_zoom()
	var mouse := get_viewport().get_mouse_position()
	var enemy := _enemy_under(mouse)
	var targeted := enemy if turn == Turn.PLAYER else null
	_set_target(targeted)
	var h := NO_HEX if enemy else _hex_under(mouse)  # противник заслоняет гексы за собой
	var from := _attack_hex(mouse, targeted) if targeted else NO_HEX
	var inspected := enemy if enemy else _ally_under(mouse)
	if h != _hovered or from != _attack_from or inspected != _inspected:
		_hovered = h
		_attack_from = from
		_inspected = inspected
		_paint()
	sword.visible = from != NO_HEX
	if sword.visible:
		# Остриё в курсоре, меч смотрит от гекса атаки к противнику.
		var a := camera.unproject_position(_hex_center(from))
		var b := camera.unproject_position(_hex_center(cells[targeted]))
		sword.position = mouse
		sword.rotation = (b - a).angle()
	status.text = _status_text(inspected, from)


func _status_text(unit: Creature, from: Vector2i) -> String:
	if unit:
		var text := "%s: удары %d/%d" % [unit.get_meta("title"), unit.hits, Creature.HITS_TO_KILL]
		if unit == _targeted and from == NO_HEX:
			text += ". Не дотянуться: нет свободной стороны в пределах хода"
		return text
	match turn:
		Turn.PLAYER:
			return "Твой ход, %s: гекс — идти (до %d), противник — подойти и ударить, «Защита» — ждать удара" % [active.get_meta("title"), active.get_meta("move")]
		Turn.OVER:
			return "Победа!" if not _living(0).is_empty() else "Поражение."
	return "Ходит: %s" % active.get_meta("title")
