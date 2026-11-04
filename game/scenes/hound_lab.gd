extends "res://scenes/showcase.gd"
## Лаборатория собаки на время работы над пайплайном: одна модель с разными скелетами и анимациями, квадратами как в витрине.
## Новый вариант — строка в VARIANTS. Анимации файла играют по кругу, нет анимаций — стоит в позе файла.
## Запуск: godot --path game res://scenes/hound_lab.tscn

const LAB := "res://assets/creatures/hound/lab/"
const HEIGHT := 1.3
const CAMERA_SIZE := 1.6  # собака длиннее, чем выше
const VARIANTS := [
	["Лисица, веса со сшитой копии: озирается", "hound-on-fox-welded.glb", "Survey"],
	["Лисица, веса со сшитой копии: ходьба", "hound-on-fox-welded.glb", "Walk"],
	["Лисица, веса со сшитой копии: бег", "hound-on-fox-welded.glb", "Run"],
	["Скелет лисицы: озирается", "hound-on-fox.glb", "Survey"],
	["Скелет лисицы: ходьба", "hound-on-fox.glb", "Walk"],
	["Скелет лисицы: бег", "hound-on-fox.glb", "Run"],
	["API quadruped: ходьба", "api-walk.glb"],
	["API quadruped: без анимации", "api-rig.glb"],
	["Studio Other: без анимации, выгрузка Free", "studio-other.glb"],
	["Без рига", "no-rig.glb"],
]


func _ready() -> void:
	var grid := _build_page()
	for variant: Array in VARIANTS:
		_make_variant(grid, variant[0], LAB + variant[1], variant[2] if variant.size() > 2 else "")
	_finish()


func _make_variant(grid: GridContainer, title: String, path: String, only := "") -> void:
	var cell := _make_frame(grid, CAMERA_SIZE)
	var model: Node3D = load(path).instantiate()
	cell.view.add_child(model)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var fit := HEIGHT / box.size.y
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	var label := _make_label(cell.frame)
	label.text = title
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player and not player.get_animation_list().is_empty():
		_play_all(player, title, label, only)


func _play_all(player: AnimationPlayer, title: String, label: Label, only: String) -> void:
	var clips: Array = [only] if only != "" else Array(player.get_animation_list())
	for clip in clips:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR  # из файла приходят без повтора: клип замирал на последнем кадре
	while true:
		for clip in clips:
			label.text = "%s (%s)" % [title, clip]
			player.play(clip, 0.2)
			await get_tree().create_timer(player.get_animation(clip).length * 2.0).timeout
