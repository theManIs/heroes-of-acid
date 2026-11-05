extends "res://scenes/showcase.gd"
## Витрина пары (задача 161): настоящий конь и макет всадника, прикреплённый к седлу.
## Всадник стоит по кости спины коня каждый кадр: качается от движений коня и при смерти падает вместе с ним.
## Запуск: godot --path game res://scenes/rider_pair.tscn

const MOCK := preload("res://scenes/rider_mock.gd")
const HORSE := "res://assets/creatures/horse/horse.glb"
const HORSE_HEIGHT := 1.9  # спина коня под всадника около 2 м
const SADDLE_BONE := "Torso2"
## Точка посадки в долях роста коня: над седлом, чуть позади кости спины (замер по сетке в покое).
const SEAT := Vector3(0.0, 0.85, -0.10)
const CELL_TARGET := 460
const TURN := PI / 2.0  # конь смотрит по +X, как остальные существа
const HOLD := 1.0
const FROZEN := ["ride_still", "ride_hurt", "ride_fidget_look", "ride_dodge"]
## Подпись, клип коня, клип всадника, по кругу без остановки.
const CELLS := [
	["Стойка", "idle_breathe", "ride_still", true],
	["Шаг", "walk", "ride_still", true],
	["Галоп", "run", "ride_still", true],
	["Атака впритык: бросок головой коня", "attack_headbutt", "ride_still", false],
	["Реакция", "hurt_left", "ride_hurt", false],
	["Защита: уклон, конь пригнулся", "idle_head_low", "ride_dodge", false],
	["Отклик: озирается, конь щиплет траву", "fidget_graze", "ride_fidget_look", false],
]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	for cell: Array in CELLS:
		_make_pair_cell(grid, cell)
	_make_death_cell(grid)
	get_viewport().size_changed.connect(_fit.bind(grid))
	_fit(grid)
	_finish()


func _fit(grid: GridContainer) -> void:
	var width := get_viewport_rect().size.x
	grid.columns = clampi(floori((width - GAP) / (CELL_TARGET + GAP)), 1, columns)
	var side := maxi(90, floori((width - GAP * (grid.columns + 1)) / grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * side


func _make_label(frame: Control) -> Label:
	var label := super._make_label(frame)
	label.add_theme_font_size_override("font_size", 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Конь, всадник на седле и копьё под рукой. Возвращает {horse, player, rider, lance, sk, bone, offset}.
func _make_pair(view: SubViewport) -> Dictionary:
	var horse: Node3D = load(HORSE).instantiate()
	view.add_child(horse)
	var box: AABB = horse.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	var fit := HORSE_HEIGHT / box.size.y
	horse.scale = Vector3.ONE * fit
	horse.rotation.y = TURN  # боком к камере витрины
	horse.position = Basis(Vector3.UP, TURN) * (-Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit)
	var player: AnimationPlayer = horse.find_child("AnimationPlayer", true, false)
	player.get_animation("idle_breathe").loop_mode = Animation.LOOP_LINEAR
	player.play("idle_breathe")
	var sk: Skeleton3D = horse.find_children("*", "Skeleton3D", true, false)[0]
	var rider := MOCK.make_rider(view)
	for clip in FROZEN:
		MOCK.freeze_bones(rider, clip, MOCK.RIGHT_ARM)
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.rotation.y = TURN - PI / 2.0  # модель смотрит по +X, конь — по своему +Z
	rider.set("_yaw", rider.rotation.y)
	var lance := MOCK.add_lance(view)
	return {"horse": horse, "player": player, "rider": rider, "lance": lance, "sk": sk, "bone": sk.find_bone(SADDLE_BONE), "offset": Transform3D.IDENTITY}


func _bone_frame(pair: Dictionary) -> Transform3D:
	var sk: Skeleton3D = pair.sk
	var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(pair.bone)
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Посадка: таз всадника в точку над седлом, запоминаем положение относительно кости спины.
func _seat(pair: Dictionary) -> void:
	var rider: Creature = pair.rider
	var hips: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_Hips"))
	var seat: Vector3 = Basis(Vector3.UP, TURN) * (SEAT * HORSE_HEIGHT)
	rider.global_position += seat + Vector3(0, 0.08, 0) - hips
	pair.offset = _bone_frame(pair).affine_inverse() * rider.global_transform


## Каждый кадр: всадник по кости спины, его поворот не трогает Creature, копьё под рукой.
func _follow(pair: Dictionary) -> void:
	var rider: Creature = pair.rider
	rider.global_transform = _bone_frame(pair) * pair.offset
	rider.set("_yaw", rider.rotation.y)
	MOCK.place_lance(pair.lance, rider, rider)


func _settle(pair: Dictionary) -> void:
	# После смерти всадник лежит на боку: перед новой посадкой — снова прямо.
	var rider: Creature = pair.rider
	rider.global_transform = Transform3D(Basis(Vector3.UP, TURN - PI / 2.0), Vector3.ZERO)
	rider.set("_yaw", rider.rotation.y)
	pair.player.play("idle_breathe", 0.0)
	pair.player.advance(0.0)
	pair.rider.anim.play("ride_still", 0.0)
	pair.rider.anim.advance(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_seat(pair)


func _make_pair_cell(grid: GridContainer, cell: Array) -> void:
	var frame := _make_frame(grid, 3.4)
	var pair := _make_pair(frame.view)
	_make_label(frame.frame).text = cell[0]
	await _settle(pair)
	var player: AnimationPlayer = pair.player
	var rider: Creature = pair.rider
	if cell[3]:
		player.get_animation(cell[1]).loop_mode = Animation.LOOP_LINEAR
		player.play(cell[1], 0.2)
		rider.anim.play(cell[2], 0.2)
		while is_instance_valid(rider):
			_follow(pair)
			await get_tree().process_frame
		return
	while is_instance_valid(rider):
		player.play(cell[1], 0.2)
		rider.anim.play(cell[2], 0.2)
		var length: float = maxf(player.get_animation(cell[1]).length, 2.2 if cell[2] == "ride_hurt" else rider.anim.get_animation(cell[2]).length)
		var time := 0.0
		var back := false
		while time < length + HOLD:
			if not back and time >= length:
				player.play("idle_breathe", 0.3)
				rider.anim.play("ride_still", 0.3)
				back = true
			_follow(pair)
			await get_tree().process_frame
			time += get_process_delta_time()


## Смерть, вариант 1: конь падает на бок, всадник прикреплён к седлу и падает вместе с ним.
func _make_death_cell(grid: GridContainer) -> void:
	var frame := _make_frame(grid, 3.4)
	var pair := _make_pair(frame.view)
	_make_label(frame.frame).text = "Смерть: падают вместе"
	var player: AnimationPlayer = pair.player
	var rider: Creature = pair.rider
	var length := player.get_animation("death_fall_on_side").length
	while is_instance_valid(rider):
		rider.visible = false
		pair.lance.visible = false
		player.speed_scale = 1.0
		rider.anim.speed_scale = 1.0
		await _settle(pair)
		rider.visible = true
		pair.lance.visible = true
		var time := 0.0
		while time < 1.0:
			_follow(pair)
			await get_tree().process_frame
			time += get_process_delta_time()
		player.play("death_fall_on_side", 0.15)
		time = 0.0
		while time < length + 1.5:
			if time >= length - 0.03 and player.speed_scale > 0.0:
				player.seek(length - 0.03, true)
				player.speed_scale = 0.0  # лежит до повтора, без возврата в стойку на глазах
			_follow(pair)
			await get_tree().process_frame
			time += get_process_delta_time()
