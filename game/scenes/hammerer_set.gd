extends "res://scenes/hammerer_search.gd"
## Задача 167, второй круг: полный набор под выбранную стойку «2hand Idle» и удар «тяжёлый взмах».
## c2_* — ноги и корпус своего клипа, руки с молотом из первого кадра стойки (build_clips.py: arms_from).
## Разовые клипы возвращаются в выбранную стойку — видно переход.
## Запуск: godot --path game res://scenes/hammerer_set.tscn

const SET := [
	["Стойка: 2hand Idle (выбрана)", "c_2hand_idle", true],
	["Ходьба: шаг с винтовкой, руки из стойки", "c2_walk_rifle", true],
	["Ходьба: прежний шаг, руки из стойки", "c2_walk_sword", true],
	["Бег: с винтовкой, руки из стойки", "c2_run_rifle", true],
	["Бег: прежний, руки из стойки", "c2_run_sword", true],
	["Удар: тяжёлый взмах (выбран)", "c_heavy_swing", false],
	["Удар точечный: прикладом (Smash)", "c_smash", false],
	["Реакция: прежняя, руки из стойки", "c2_hurt", false],
	["Защита: блок винтовкой", "c_block_rifle", false],
	["Защита: блок винтовкой 2", "c_rifle_block", false],
	["Отклик: озирается, руки из стойки", "c2_look", false],
	["Отклик: озирается с винтовкой", "c_rifle_look", false],
	["Смерть: вперёд", "c_death_front", false],
	["Смерть: справа", "c_death_right", false],
]


func _cells() -> Array:
	return SET


func _idle_clip() -> String:
	return "c_2hand_idle"
