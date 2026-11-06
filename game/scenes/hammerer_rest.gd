extends "res://scenes/hammerer_overlay.gd"
## Задача 167: недостающие действия под выбранную стойку — защита, смерть, точечный удар.
## Запуск: godot --path game res://scenes/hammerer_rest.tscn

const REST := [
	["Стойка: 2hand Idle (выбрана)", "c_2hand_idle", true],
	["Защита: блок винтовкой", "c_block_rifle", false],
	["Защита: блок винтовкой 2", "c_rifle_block", false],
	["Точечный удар: тычок (Smash)", "c_smash", false],
	["Смерть: вперёд", "c_death_front", false],
	["Смерть: справа", "c_death_right", false],
]


func _ready() -> void:
	columns = 3
	super._ready()


func _cells() -> Array:
	return REST
