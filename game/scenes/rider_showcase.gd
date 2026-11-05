extends "res://scenes/showcase.gd"
## Витрина макета всадника (задача 157): квадрат на каждый сидячий клип Mixamo,
## тело молотобойца на условном коне. Отсмотр материала до генерации моделей.

const MOCK := preload("res://scenes/rider_mock.gd")
const CELL_TARGET := 460
const HOLD := 0.6
const LANCE_CLIPS := ["ride_swing", "ride_strike"]  # удары сидя: копьё в кисти
const LANCE_DAMP := {"ride_swing": 0.45}  # с копьём взмах аккуратнее: доля размаха клипа
## Езда без клипа езды: всадник в сидячей стойке, конь-макет идёт на месте,
## качается корпусом и переставляет ноги. Подпись, клип всадника, шагов в секунду,
## подъём корпуса (м), размах ног (градусы).
const GAITS := [
	["Едет шагом (сидит спокойно)", "ride_still", 1.6, 0.03, 18.0],
	["Едет рысью (облегчается в седле)", "ride_still", 2.6, 0.07, 28.0],
]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	_make_charge_cell(grid)
	for gait: Array in GAITS:
		_make_ride_cell(grid, gait)
	for clip: Array in MOCK.CLIPS:
		if clip[1] in LANCE_CLIPS:
			_make_rider_cell(grid, clip, true)
	for clip: Array in MOCK.CLIPS:
		_make_rider_cell(grid, clip)
	get_viewport().size_changed.connect(_fit.bind(grid))
	_fit(grid)
	_finish()


## Крупные квадраты по ширине окна, остальное прокручивается.
func _fit(grid: GridContainer) -> void:
	var width := get_viewport_rect().size.x
	grid.columns = clampi(floori((width - GAP) / (CELL_TARGET + GAP)), 1, columns)
	var side := maxi(90, floori((width - GAP * (grid.columns + 1)) / grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * side


func _make_rider_cell(grid: GridContainer, clip: Array, with_lance := false) -> void:
	var cell := _make_frame(grid, 3.1 if not with_lance else 4.2)
	var view: SubViewport = cell.view
	var mount := Node3D.new()
	view.add_child(mount)
	MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance: MeshInstance3D = MOCK.add_lance(mount) if with_lance else null
	if with_lance and LANCE_DAMP.has(clip[1]):
		MOCK.damp_clip(rider, clip[1], LANCE_DAMP[clip[1]])
	_make_label(cell.frame).text = clip[0] + (" с копьём" if with_lance else "")
	_repeat(rider, clip[1], lance, mount)


func _repeat(rider: Creature, clip: String, lance: MeshInstance3D = null, mount: Node3D = null) -> void:
	var length := rider.anim.get_animation(clip).length
	while true:
		rider.anim.play(clip, 0.0)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		if lance == null:
			await get_tree().create_timer(length).timeout
		else:
			var local := MOCK.calibrate_hand_lance(rider, mount)
			var left := length
			while left > 0.0:
				MOCK.place_hand_lance(lance, rider, local)
				await get_tree().process_frame
				left -= get_process_delta_time()
		await get_tree().create_timer(HOLD).timeout


func _make_ride_cell(grid: GridContainer, gait: Array) -> void:
	var cell := _make_frame(grid, 3.1)
	var view: SubViewport = cell.view
	var mount := Node3D.new()  # конь и всадник качаются вместе, всадник сидит в седле
	view.add_child(mount)
	var legs := MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = gait[0]
	rider.anim.get_animation(gait[1]).loop_mode = Animation.LOOP_LINEAR
	rider.anim.play(gait[1])
	rider.anim.advance(0.0)
	await get_tree().process_frame
	MOCK.sit(rider)
	var seat_y := rider.position.y
	var time := 0.0
	while is_instance_valid(mount):
		await get_tree().process_frame
		time += get_process_delta_time()
		var phase: float = time * gait[2] * TAU
		mount.position.y = absf(sin(phase)) * gait[3]
		mount.rotation.z = sin(phase) * deg_to_rad(1.5)
		# Всадник в седле движется вместе с конём; на рыси вдобавок мягко
		# привстаёт на каждый второй шаг — облегчённая рысь. Без клипа «спокойно сидит».
		var post: float = maxf(0.0, sin(phase * 0.5)) * gait[3] * 0.6 if gait[2] > 2.0 else 0.0
		rider.position.y = seat_y + post
		# Остриё запаздывает за толчком корпуса и чуть гуляет вбок.
		MOCK.place_lance(lance, rider, mount, sin(phase - 0.9) * gait[3] * 30.0, sin(phase * 0.5 + 0.4) * gait[3] * 12.0)
		for i in legs.size():
			# Диагональные пары ног движутся вместе, как у рыси.
			var pair := 1.0 if i == 0 or i == 3 else -1.0
			legs[i].rotation.z = sin(phase) * deg_to_rad(gait[4]) * pair


## Таранный удар: копьё неподвижно под рукой, бьёт разгон коня. Цель — столб.
const CHARGE_FROM := -3.4
const CHARGE_HIT := -1.2  # где корень коня, когда остриё доходит до столба
const CHARGE_TIME := 0.9
const CHARGE_BACK := 1.6


func _make_charge_cell(grid: GridContainer) -> void:
	var cell := _make_frame(grid, 4.6)
	var view: SubViewport = cell.view
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 2.2, 0.3)
	post.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.2, 0.15)
	post.material_override = mat
	post.position = Vector3(CHARGE_HIT + 1.0 + MOCK.LANCE_LENGTH - MOCK.LANCE_BACK - 0.2, 1.1, 0.35)
	view.add_child(post)
	var mount := Node3D.new()
	view.add_child(mount)
	var legs := MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = "Таран копьём: разгон на цель"
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.anim.play("ride_still")
	rider.anim.advance(0.0)
	await get_tree().process_frame
	MOCK.sit(rider)
	var time := 0.0
	var placed := false
	while is_instance_valid(mount):
		await get_tree().process_frame
		var delta := get_process_delta_time()
		time = fmod(time + delta, CHARGE_TIME + 0.5 + CHARGE_BACK + 0.6)
		var x := CHARGE_FROM
		var speed := 0.0
		if time < CHARGE_TIME:
			var t := time / CHARGE_TIME
			x = lerpf(CHARGE_FROM, CHARGE_HIT, t * t)  # разгон
			speed = 1.0
		elif time < CHARGE_TIME + 0.5:
			x = CHARGE_HIT  # удар и короткая остановка
			if not placed:
				# Столб ровно там, куда пришло остриё.
				var tip: Vector3 = lance.global_transform * Vector3(0, MOCK.LANCE_LENGTH * 0.5, 0)
				post.global_position = Vector3(tip.x + 0.15, 1.1, tip.z)
				placed = true
			post.rotation.z = -deg_to_rad(8.0) * (1.0 - (time - CHARGE_TIME) / 0.5)
		elif time < CHARGE_TIME + 0.5 + CHARGE_BACK:
			x = lerpf(CHARGE_HIT, CHARGE_FROM, smoothstep(0.0, 1.0, (time - CHARGE_TIME - 0.5) / CHARGE_BACK))
			speed = 0.4
		mount.position.x = x
		var phase := time * 3.2 * TAU
		mount.position.y = absf(sin(phase)) * 0.08 * speed
		mount.rotation.z = sin(phase) * deg_to_rad(2.0) * speed
		for i in legs.size():
			var pair := 1.0 if i < 2 else -1.0  # галоп: передние и задние вместе
			legs[i].rotation.z = sin(phase) * deg_to_rad(32.0) * pair * speed
		var jolt := 0.0
		if time >= CHARGE_TIME and time < CHARGE_TIME + 0.5:
			# Отдача от удара: остриё дёргается вверх и затухает.
			var after := time - CHARGE_TIME
			jolt = 2.0 * exp(-after * 6.0) * cos(after * 14.0)  # тяжёлое копьё: малый размах, медленно
		MOCK.place_lance(lance, rider, mount, sin(phase - 0.9) * 2.6 * speed + jolt, sin(phase * 0.5 + 0.4) * 1.0 * speed)

