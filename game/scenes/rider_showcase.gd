extends "res://scenes/showcase.gd"
## Витрина макета всадника (задача 157): квадрат на каждый сидячий клип Mixamo,
## тело молотобойца на условном коне. Отсмотр материала до генерации моделей.

const MOCK := preload("res://scenes/rider_mock.gd")
const CELL_TARGET := 460
const HOLD := 0.6


func _ready() -> void:
	columns = 4
	var grid := _build_page()
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
