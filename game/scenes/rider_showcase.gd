extends "res://scenes/showcase.gd"
## Витрина макета всадника (задача 157): квадрат на каждый сидячий клип Mixamo,
## тело молотобойца на условном коне. Отсмотр материала до генерации моделей.

const MOCK := preload("res://scenes/rider_mock.gd")
const CELL_TARGET := 460
const HOLD := 0.6
const RIDER_FOLLOW := 0.35  # какую долю подпрыгивания коня передаёт корпус всадника
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
	for gait: Array in GAITS:
		_make_ride_cell(grid, gait)
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


func _make_rider_cell(grid: GridContainer, clip: Array) -> void:
	var cell := _make_frame(grid, 3.1)
	var view: SubViewport = cell.view
	MOCK.build_horse(view)
	var rider := MOCK.make_rider(view)
	_make_label(cell.frame).text = clip[0]
	_repeat(rider, clip[1])


func _repeat(rider: Creature, clip: String) -> void:
	var length := rider.anim.get_animation(clip).length
	while true:
		rider.anim.play(clip, 0.0)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		await get_tree().create_timer(length).timeout
		await get_tree().create_timer(HOLD).timeout


func _make_ride_cell(grid: GridContainer, gait: Array) -> void:
	var cell := _make_frame(grid, 3.1)
	var view: SubViewport = cell.view
	var mount := Node3D.new()  # конь качается сам, всадник гасит тряску
	view.add_child(mount)
	var legs := MOCK.build_horse(mount)
	var rider := MOCK.make_rider(view)
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
		# Опытный наездник не трясётся: бёдра гасят толчки, корпус идёт ровнее коня.
		# На рыси привстаёт на каждый второй шаг — облегчённая рысь.
		var follow := mount.position.y * RIDER_FOLLOW
		var post := maxf(0.0, sin(phase * 0.5)) * gait[3] * 0.8 if gait[2] > 2.0 else 0.0
		rider.position.y = seat_y + follow + post
		for i in legs.size():
			# Диагональные пары ног движутся вместе, как у рыси.
			var pair := 1.0 if i == 0 or i == 3 else -1.0
			legs[i].rotation.z = sin(phase) * deg_to_rad(gait[4]) * pair

