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
## Рука с копьём отведена от корпуса вправо (плечо −35° наружу, без подъёма): копьё ниже, не на весу; над коленом ~0,2 м.
const ARM_OUT := -35.0
const ARM_UP := 0.0
## Пальцы в кулак вокруг древка, градусов на сустав.
const GRIP_CURL := 45.0
## Кулак повёрнут предплечьем, как при выливании воды из стаканчика: остриё вперёд и чуть вниз (витрина rider_hand).
const POUR := -70.0
const LANCE_PITCH := -8.0  # остриё к горизонту мира, градусов: чуть вниз, чтобы колоть
const LANCE_YAW := 3.0  # остриё чуть наружу от линии коня: мимо его головы
const HOLD := 1.0
const BACK_BLEND := 1.0  # возврат в стойку после разового действия, секунд (было 0,3 — руки дёргались)
const FROZEN := ["ride_still", "ride_hurt", "ride_fidget_look", "ride_dodge"]
const HANG_LEGS := ["ride_fidget_look"]  # конь щиплет траву и сильно наклоняется: ноги свисают
## Подпись, клип коня, клип всадника, по кругу без остановки.
const CELLS := [
	["Стойка", "idle_breathe", "ride_still", true],
	["Шаг", "walk", "ride_still", true],
	["Галоп", "run", "ride_still", true],
	["Реакция", "hurt_left", "ride_hurt", false],
	["Защита: уклон, конь пригнулся", "idle_head_low", "ride_dodge", false],
	["Отклик: озирается, конь щиплет траву", "fidget_graze", "ride_fidget_look", false],
]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	for cell: Array in CELLS:
		_make_pair_cell(grid, cell)
		if cell[1] == "run":
			_make_strike_cell(grid, true)
			_make_strike_cell(grid, false)
	_make_death_cell(grid)
	get_viewport().size_changed.connect(_fit.bind(grid))
	_zoom_grid = grid
	_fit(grid)
	_finish()


func _fit(grid: GridContainer) -> void:
	var width := get_viewport_rect().size.x
	grid.columns = clampi(floori((width - GAP) / (CELL_TARGET * cell_zoom + GAP)), 1, columns)
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
	preload("res://scenes/metal_lighting.gd").apply(view)  # латы и броня коня: без отражений сталь почти чёрная
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
	MOCK.freeze_bones(rider, "ride_still", MOCK.RIGHT_ARM)
	MOCK.arm_out(rider, "ride_still", ARM_OUT, ARM_UP)
	MOCK.pour(rider, "ride_still", POUR)
	MOCK.curl_fingers(rider, "ride_still", GRIP_CURL)
	for clip in FROZEN:
		if clip != "ride_still":
			# Рука с копьём и посадка — как в стойке: иначе копьё отъезжает при смене клипа.
			MOCK.pin_to(rider, clip, MOCK.RIGHT_ARM + MOCK.grip_bones())
			MOCK.pin_seat(rider, clip)
	MOCK.pin_seat(rider, "idle")  # копия стойки, которую Creature включает сам
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.rotation.y = TURN - PI / 2.0  # модель смотрит по +X, конь — по своему +Z
	rider.set("_yaw", rider.rotation.y)
	var lance := MOCK.add_lance(view)
	# Наклонился всадник или конь — кулак доворачивается, остриё всегда чуть вниз.
	var keeper := MOCK.LanceKeeper.new()
	keeper.rider = rider
	keeper.pitch = LANCE_PITCH
	keeper.yaw = LANCE_YAW
	rider.skeleton.add_child(keeper)
	return {"horse": horse, "player": player, "rider": rider, "lance": lance, "sk": sk, "bone": sk.find_bone(SADDLE_BONE), "offset": Transform3D.IDENTITY, "keeper": keeper}


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
func _follow(pair: Dictionary, slide := 0.0, pitch := 0.0) -> void:
	var rider: Creature = pair.rider
	rider.global_transform = _bone_frame(pair) * pair.offset
	rider.set("_yaw", rider.rotation.y)
	MOCK.place_fist_lance(pair.lance, rider, pitch, slide, pair.keeper)


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
	if cell[2] in HANG_LEGS:
		var hang := LegHang.new()
		hang.rider = rider
		hang.horse_sk = pair.sk
		frame.view.add_child(hang)
		hang.set_rest()
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
		rider.anim.speed_scale = 1.0
		var horse_len: float = player.get_animation(cell[1]).length
		var rider_len: float = 2.2 if cell[2] == "ride_hurt" else rider.anim.get_animation(cell[2]).length
		var length: float = maxf(horse_len, rider_len)
		var time := 0.0
		var back := false
		var stretched := false
		while time < length + HOLD:
			# Клип всадника короче клипа коня: последние 5 % растягиваются до конца клипа коня,
			# иначе Creature сам ставит стойку без перехода и руки прыгают.
			if not stretched and rider_len < horse_len and time >= rider_len * 0.95:
				rider.anim.speed_scale = (rider_len * 0.05) / maxf(horse_len - rider_len * 0.95, 0.01)
				stretched = true
			if not back and time >= length:
				rider.anim.speed_scale = 1.0
				player.play("idle_breathe", BACK_BLEND)
				rider.anim.play("ride_still", BACK_BLEND)
				back = true
			_follow(pair)
			await get_tree().process_frame
			time += get_process_delta_time()


## Смерть, вариант 1: конь падает на бок, всадник прикреплён к седлу и падает вместе с ним.
func _make_death_cell(grid: GridContainer) -> void:
	var frame := _make_frame(grid, 3.4)
	var pair := _make_pair(frame.view)
	_make_label(frame.frame).text = "Смерть: падают вместе"
	pair.keeper.active = false  # падают на бок: держать копьё ровно уже незачем
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


## Атака. С разбега: галоп на столб, копьё неподвижно под рукой, бьёт разгон.
## С места: конь делает полшага назад и короткий рывок галопом в цель.
const CHARGE_FROM := -3.2
const CHARGE_TIME := 0.9
const STEP_BACK := 0.6  # с места: полшага назад перед рывком
const STEP_BACK_TIME := 0.6
const LUNGE_TIME := 0.35


func _make_post(view: SubViewport) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 2.2, 0.3)
	post.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.2, 0.15)
	post.material_override = mat
	view.add_child(post)
	post.visible = false
	return post


func _tip(lance: Node3D) -> Vector3:
	return MOCK.tip(lance)


func _make_strike_cell(grid: GridContainer, charge: bool) -> void:
	var frame := _make_frame(grid, 5.2 if charge else 3.6)
	var pair := _make_pair(frame.view)
	_make_label(frame.frame).text = "Атака: таран с разбега" if charge else "Атака с места: полшага назад и рывок"
	var post := _make_post(frame.view)
	# Цель впереди коня: камеру сдвигаем вперёд, чтобы столб попадал в кадр.
	for cam: Camera3D in frame.view.find_children("*", "Camera3D", true, false):
		cam.position.x += 1.0 if charge else 1.1
	var player: AnimationPlayer = pair.player
	var horse: Node3D = pair.horse
	var home: Vector3 = horse.position
	await _settle(pair)
	var placed := false
	while is_instance_valid(horse):
		if charge:
			# Разгон: конь галопом с отступа на место удара.
			player.get_animation("run").loop_mode = Animation.LOOP_LINEAR
			player.play("run", 0.2)
			var time := 0.0
			while time < CHARGE_TIME:
				var t := time / CHARGE_TIME
				horse.position = home + Vector3(lerpf(CHARGE_FROM, 0.0, t * t), 0, 0)
				_follow(pair)
				await get_tree().process_frame
				time += get_process_delta_time()
			horse.position = home
			_follow(pair)
			if not placed:
				var tip := _tip(pair.lance)
				post.global_position = Vector3(tip.x + 0.15, 1.1, tip.z)
				post.visible = true
				placed = true
			player.play("idle_breathe", 0.25)
			time = 0.0
			while time < 0.6:
				post.rotation.z = -deg_to_rad(8.0) * (1.0 - time / 0.6)
				_follow(pair, 0.0, 2.0 * exp(-time * 6.0) * cos(time * 14.0))
				await get_tree().process_frame
				time += get_process_delta_time()
			# Отход шагом назад к началу разбега.
			player.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
			player.play("walk", 0.3)
			time = 0.0
			while time < 1.8:
				horse.position = home + Vector3(lerpf(0.0, CHARGE_FROM, smoothstep(0.0, 1.0, time / 1.8)), 0, 0)
				_follow(pair)
				await get_tree().process_frame
				time += get_process_delta_time()
			player.play("idle_breathe", 0.3)
			time = 0.0
			while time < 0.6:
				_follow(pair)
				await get_tree().process_frame
				time += get_process_delta_time()
		else:
			# С места: полшага назад шагом, затем короткий рывок галопом в цель.
			player.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
			player.play("walk", 0.2)
			player.speed_scale = -1.0  # шаг назад
			var time := 0.0
			while time < STEP_BACK_TIME:
				horse.position = home + Vector3(-STEP_BACK * smoothstep(0.0, 1.0, time / STEP_BACK_TIME), 0, 0)
				_follow(pair)
				await get_tree().process_frame
				time += get_process_delta_time()
			player.speed_scale = 1.0
			player.get_animation("run").loop_mode = Animation.LOOP_LINEAR
			player.play("run", 0.15)
			time = 0.0
			while time < LUNGE_TIME:
				var t := time / LUNGE_TIME
				horse.position = home + Vector3(lerpf(-STEP_BACK, 0.0, t * t), 0, 0)
				_follow(pair)
				await get_tree().process_frame
				time += get_process_delta_time()
			horse.position = home
			_follow(pair)
			if not placed:
				var tip := _tip(pair.lance)
				post.global_position = Vector3(tip.x + 0.15, 1.1, tip.z)
				post.visible = true
				placed = true
			player.play("idle_breathe", 0.25)
			time = 0.0
			while time < 0.5 + HOLD:
				if time < 0.5:
					post.rotation.z = -deg_to_rad(6.0) * (1.0 - time / 0.5)
				_follow(pair, 0.0, 1.5 * exp(-time * 6.0) * cos(time * 14.0) if time < 0.5 else 0.0)
				await get_tree().process_frame
				time += get_process_delta_time()


## Ноги опускаются, когда конь опускает голову: корпус коня уходит вперёд-вниз, и колени со стопами
## всадника должны уйти вниз вместе с ним. Доля — насколько опущена голова коня. Работает после анимации.
class LegHang extends Node:
	var rider: Creature
	var horse_sk: Skeleton3D
	var head := -1
	var rest_y := 0.0
	var drop := 0.6  # на сколько метров голова опускается в клипе травы
	var thigh := 22.0  # градусов: бёдра вниз при полностью опущенной голове
	var shin := 18.0  # градусов: голени назад-вниз
	var sign := -1.0  # замер: при +1 колени поднимались

	func _ready() -> void:
		process_priority = 100
		head = horse_sk.find_bone("Head")

	func set_rest() -> void:
		rest_y = (horse_sk.global_transform * horse_sk.get_bone_global_pose(head).origin).y

	func _process(_delta: float) -> void:
		if not is_instance_valid(rider) or head < 0:
			return
		var y: float = (horse_sk.global_transform * horse_sk.get_bone_global_pose(head).origin).y
		var w := clampf((rest_y - y) / drop, 0.0, 1.0)
		if w <= 0.001:
			return
		var sk := rider.skeleton
		var side: Vector3 = (sk.global_basis.inverse() * rider.global_basis.z).normalized()
		for leg in ["Left", "Right"]:
			for part in [["UpLeg", thigh], ["Leg", -shin]]:
				var i := sk.find_bone("mixamorig_%s%s" % [leg, part[0]])
				var g := sk.get_bone_global_pose(i)
				sk.set_bone_global_pose(i, Transform3D(Basis(side, deg_to_rad(part[1]) * w * sign) * g.basis, g.origin))
