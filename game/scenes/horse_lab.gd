extends "res://scenes/showcase.gd"
## Витрина коня всадника (задача 160): каждая анимация донора в своём квадрате, все сразу.
## Запуск: godot --path game res://scenes/horse_lab.tscn

const HORSE := "res://assets/creatures/horse/horse.glb"
const IDLE := "idle_breathe"
const HEIGHT := 1.7  # конь под всадника ростом около 2 м
const CAMERA_SIZE := 2.4  # конь длиннее, чем выше
const HOLD := 1.0
const CELL_TARGET := 420
const CLIPS := [  # подпись, клип, идёт без остановки
	["Стойка", IDLE, true], ["Стойка: озирается", "idle_look_around", true], ["Стойка: голова вниз", "idle_head_low", true],
	["Отклик: щиплет траву", "fidget_graze", false], ["Шаг", "walk", true], ["Галоп", "run", true],
	["Удар головой", "attack_headbutt", false], ["Удар копытами", "attack_kick", false],
	["Реакция: слева", "hurt_left", false], ["Реакция: справа", "hurt_right", false],
	["Смерть: на бок", "death_fall_on_side", false], ["Прыжок", "jump_leap", false], ["Приземление", "jump_land", false],
]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	for clip: Array in CLIPS:
		_make_clip_cell(grid, clip[0], clip[1], clip[2])
	get_viewport().size_changed.connect(_fit.bind(grid))
	_fit(grid)
	_finish()


## Квадраты по ширине окна, остальное прокручивается.
func _fit(grid: GridContainer) -> void:
	var width := get_viewport_rect().size.x
	grid.columns = clampi(floori((width - GAP) / (CELL_TARGET + GAP)), 1, columns)
	var side := maxi(90, floori((width - GAP * (grid.columns + 1)) / grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * side


func _make_clip_cell(grid: GridContainer, title: String, clip: String, endless: bool) -> void:
	var cell := _make_frame(grid, CAMERA_SIZE)
	var model: Node3D = load(HORSE).instantiate()
	cell.view.add_child(model)
	var box: AABB = model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()  # сетка со скелетом: трансформ узла не действует
	var fit := HEIGHT / box.size.y
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	_make_label(cell.frame).text = title
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	if endless:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play(clip)
	else:
		_repeat(player, clip)


func _repeat(player: AnimationPlayer, clip: String) -> void:
	while true:
		player.play(clip, 0.2)
		await get_tree().create_timer(player.get_animation(clip).length).timeout
		if not clip.begins_with("death"):
			player.play(IDLE, 0.3)
		await get_tree().create_timer(HOLD).timeout
		if clip.begins_with("death"):
			player.play(IDLE, 0.0)
