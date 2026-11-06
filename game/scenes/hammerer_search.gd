extends "res://scenes/showcase.gd"
## Задача 167: кандидаты Mixamo для молотобойца под хват по листу — две руки врозь, молот поперёк тела.
## Запуск: godot --path game res://scenes/hammerer_search.tscn
## Между повторами разовых — прежняя стойка (меч) с новым хватом, поэтому молот в ней стоит криво.

const UNIT := preload("res://scenes/hammerer_config.gd").UNIT
const ANIMS := "res://assets/creatures/hammerer/anims/"
const RIGHT_AT := 0.8  # правая кисть у бойка, левая дальше по рукояти
const HOLD := 1.0
## Подпись, клип, идёт по кругу.
const CELLS := [
	["Стойка: винтовка опущена (Rifle Idle, lowered)", "c_rifle_idle_low", true],
	["Стойка: винтовка у пояса (Rifle Idle, two hand)", "c_rifle_idle", true],
	["Стойка: двуручное оружие (2hand Idle)", "c_2hand_idle", true],
	["Ходьба с винтовкой у пояса", "c_rifle_walk", true],
	["Бег, винтовка опущена", "c_rifle_run", true],
	["Удар: прикладом или посохом (Smash)", "c_smash", false],
	["Удар: тяжёлый взмах двумя руками", "c_heavy_swing", false],
	["Удар: серия двуручной дубиной", "c_club_combo", false],
	["Защита: блок винтовкой", "c_block_rifle", false],
	["Защита: блок винтовкой 2", "c_rifle_block", false],
	["Отклик: озирается с винтовкой", "c_rifle_look", false],
	["Смерть: вперёд (Rifle)", "c_death_front", false],
	["Смерть: справа (Rifle)", "c_death_right", false],
]


func _ready() -> void:
	columns = 5
	cell_size = 330
	var grid := _build_page()
	for cell: Array in CELLS:
		_make_candidate(grid, cell[0], cell[1], cell[2])
	_finish()


func _make_candidate(grid: GridContainer, title: String, clip: String, endless: bool) -> void:
	var cell := _make_frame(grid, UNIT.showcase_size)
	_configure_lighting(cell.view, UNIT)
	var unit := Creature.new()
	cell.view.add_child(unit)
	unit.setup(load(UNIT.scene), [ANIMS + "idle.glb", ANIMS + clip + ".glb"], clip, UNIT.hurt, UNIT.size, 0.0, "idle")
	unit.face(unit.position + Vector3.BACK + Vector3.RIGHT)
	for grip in unit.find_children("*", "Node3D", true, false):
		if "right_at" in grip:
			grip.right_at = RIGHT_AT
	_make_label(cell.frame).text = title
	if endless:
		unit.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		unit.anim.play(clip)
	else:
		_repeat(unit, clip)


func _repeat(unit: Creature, clip: String) -> void:
	var death := clip.begins_with("c_death")
	while is_instance_valid(unit):
		unit.dead = death  # смерть: Creature не возвращает в стойку, лежит до повтора
		unit.anim.play(clip, 0.2)
		await get_tree().create_timer(unit.anim.get_animation(clip).length).timeout
		if not death:
			unit.anim.play("idle", 0.3)
		await get_tree().create_timer(HOLD).timeout
