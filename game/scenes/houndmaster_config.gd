extends RefCounted
## Общая запись псаря: витрина и тест отряда используют одни файлы.
const ANIMS := "res://assets/creatures/houndmaster/anims/"
const MASTER := {
	"name": "Псарь", "scene": "res://assets/creatures/houndmaster/houndmaster.glb", "size": 2.0,
	"extra": [ANIMS + "idle.glb", ANIMS + "walk.glb", ANIMS + "run.glb", ANIMS + "command_attack.glb",
		ANIMS + "hurt.glb", ANIMS + "defend.glb", ANIMS + "fall.glb", ANIMS + "fidget_pet.glb"],
	"attack": "command_attack", "attack_label": "команда «фас»", "attack_from": 0.0,
	"hurt": "hurt", "hurt_len": 0.0, "idle": "idle", "defend": "defend", "defend_from": 0.0,
	"defend_len": 0.0, "defend_lead": 0.3, "run": "run", "fidget": "fidget_pet", "walk_speed": 1.2,
}
