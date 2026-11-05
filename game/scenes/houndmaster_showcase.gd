extends "res://scenes/showcase.gd"
## Витрина псаря: восемь анимаций в отдельных квадратах, как у собаки.
## Запуск: godot --path game res://scenes/houndmaster_showcase.tscn

const HOLD := 1.0
const CLIPS := [
	["Стойка", "idle", true], ["Ходьба", "walk", true], ["Бег", "run", true],
	["Команда «фас»", "command_attack", false],
	["Реакция на удар", "hurt", false], ["Защита", "defend", false],
	["Смерть", "fall", false], ["Отклик: погладить", "fidget_pet", false],
]


func _ready() -> void:
	columns = 4
	cell_size = 380
	var grid := _build_page()
	for clip: Array in CLIPS:
		_make_clip_cell(grid, clip[0], clip[1], clip[2])
	_finish()


func _make_clip_cell(grid: GridContainer, title: String, clip: String, endless: bool) -> void:
	var cfg: Dictionary = NEW_CREATURES["houndmaster"]
	var cell := _make_frame(grid, cfg.size)
	var unit := Creature.new()
	cell.view.add_child(unit)
	unit.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	unit.defend_anim = cfg.defend
	unit.face(unit.position + Vector3.BACK + Vector3.RIGHT)
	_make_label(cell.frame).text = title
	if endless:
		unit.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		unit.anim.play(clip)
	else:
		_repeat(unit, clip)


func _repeat(unit: Creature, clip: String) -> void:
	while true:
		unit.dead = clip == "fall"
		unit.anim.play(clip, 0.2)
		await get_tree().create_timer(unit.anim.get_animation(clip).length).timeout
		if clip == "fall":
			await get_tree().create_timer(HOLD).timeout
		unit.dead = false
		unit.anim.play("idle", 0.3)
		await get_tree().create_timer(HOLD).timeout
