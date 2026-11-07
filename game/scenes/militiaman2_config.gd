extends RefCounted
## 184: ополченец по пайплайну creature-mixamo-first. Пока модели нет — манекен X Bot с заглушками топора и щита.
## Обычный режим — набор Mixamo «топор», стойка со щитом (186) — набор «меч и щит».

const ANIMS := "res://assets/creatures/militiaman2/anims/"
const UNIT := {
	"name": "Ополченец (манекен)", "icon": "res://assets/creatures/militiaman/icon.png",
	"scene": "res://assets/mannequin/xbot.glb",
	"extra": [ANIMS + "idle.glb", ANIMS + "walk.glb", ANIMS + "run.glb", ANIMS + "attack.glb", ANIMS + "hurt.glb",
		ANIMS + "defend.glb", ANIMS + "fall.glb", ANIMS + "fidget.glb", ANIMS + "shield_up.glb", ANIMS + "shield_idle.glb",
		ANIMS + "shield_walk.glb", ANIMS + "shield_hurt.glb", ANIMS + "shield_down.glb"],
	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0, "idle": "idle", "run": "run",
	"defend": "defend", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3,
	"fidget": "fidget", "fidget_on_hover": true,
	"size": 1.8, "walk_speed": 1.04,  # замер стопы в клипе шага
	"in_battle": false,  # манекен: в бой — с моделью
	# Отдельные топор и щит (weapon_grip.gd); пока заглушки, потом модели Tripo.
	"props": [{"hand": "Right", "mode": "fist", "shape": "axe", "length": 0.42, "grip_at": 0.12},
		{"hand": "Left", "mode": "forearm", "shape": "shield", "length": 0.34, "width": 0.26}],
	# 186: стойка со щитом — кнопка альтернативы; ход вдвое меньше; удар принимает в щит; атака выводит из стойки.
	"stance": {"title": "Щит перед собой", "enter": "shield_up", "idle": "shield_idle", "walk": "shield_walk",
		"hurt": "shield_hurt", "exit": "shield_down", "move": 0.5},
}
