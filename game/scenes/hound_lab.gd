extends "res://scenes/showcase.gd"
## Витрина собаки: каждая анимация в своём квадрате, все сразу на экране.
## Запуск: godot --path game res://scenes/hound_lab.tscn

const HOUND := "res://assets/creatures/hound/hound.glb"
const IDLE := "idle_breathe"
const HEIGHT := 1.3
const CAMERA_SIZE := 1.6  # собака длиннее, чем выше
const HOLD := 1.0  # пауза между повторами разовой анимации, секунд
const CLIPS := [  # подпись, клип, идёт без остановки
	["Стойка", IDLE, true], ["Ходьба", "walk", true], ["Бег", "run", true], ["Укус", "bite_lunge", false],
	["Реакция на удар", "hurt_head_left", false], ["Защита", "defend_lower_head", false],
	["Смерть", "death_fall_on_side", false], ["Отклик", "fidget_sniff_ground", false],
]


func _ready() -> void:
	columns = 4
	cell_size = 380
	var grid := _build_page()
	for clip: Array in CLIPS:
		_make_clip_cell(grid, clip[0], clip[1], clip[2])
	_finish()


func _make_clip_cell(grid: GridContainer, title: String, clip: String, endless: bool) -> void:
	var cell := _make_frame(grid, CAMERA_SIZE)
	var model: Node3D = load(HOUND).instantiate()
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
