extends "res://scenes/hammerer_overlay.gd"
## Задача 167: недостающие действия под выбранную стойку — защита, смерть, точечный удар.
## Запуск: godot --path game res://scenes/hammerer_rest.tscn

## Прежние клипы молотобойца (меч, руки рядом): при переходе руки скользят по рукояти.
const REST := [
	["Стойка: 2hand Idle (выбрана)", "c_2hand_idle", true],
	["Защита: прежняя (блок мечом)", "defend", false],
	["Точечный удар: прежний (сверху вниз)", "attack_point", false],
	["Смерть: прежняя", "fall", false],
]
const OLD := ["defend", "attack_point", "fall"]


func _columns() -> int:
	return 2


func _cells() -> Array:
	return REST


func _grips() -> Dictionary:
	var out := {"c_2hand_idle": RIGHT_AT, "idle": RIGHT_AT}
	for clip: String in OLD:
		out[clip] = 0.2
	return out
