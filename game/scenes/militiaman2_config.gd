extends RefCounted
## 184: ополченец по пайплайну creature-mixamo-first. Пока модели нет — манекен X Bot с заглушками топора и щита.
## Обычный режим — набор Mixamo «топор», стойка со щитом (186) — набор «меч и щит».

const ANIMS := "res://assets/creatures/militiaman2/anims/"
const SHIELD_ARM := ["mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"]
const UNIT := {
	"name": "Ополченец (манекен)", "icon": "res://assets/creatures/militiaman/icon.png",
	"scene": "res://assets/mannequin/xbot.glb",
	"extra": [ANIMS + "idle.glb", ANIMS + "walk.glb", ANIMS + "run.glb", ANIMS + "attack.glb", ANIMS + "hurt.glb",
		ANIMS + "fall.glb", ANIMS + "fidget.glb", ANIMS + "shield_up.glb", ANIMS + "shield_idle.glb",
		ANIMS + "shield_walk.glb", ANIMS + "shield_hurt.glb", ANIMS + "shield_down.glb", ANIMS + "shield_brace.glb", ANIMS + "shield_attack.glb"],
	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0, "idle": "idle", "run": "run",
	# 187: защита — удар в поднятый щит (тот же клип, что в стойке), а не «закрывается руками»;
	# старт на 0,35 с раньше удара: щит поднимается к попаданию.
	"defend": "shield_hurt", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.35,
	"fidget": "fidget", "fidget_on_hover": true,
	"size": 1.8, "walk_speed": 0.97,  # замер стопы в клипе шага (unarmed walk forward)
	"reach": 1.0,  # кисть 0,28 + топор ≈ 0,67 при росте 1,8 (×рост/1,9); без него удар заходит в цель на 0,7 м
	# 192: в реакции и смерти рука со щитом — четверть размаха от стойки (как у прежнего ополченца, M08):
	# иначе щит машет и заходит в соседа.
	"hurt_calm": SHIELD_ARM, "hurt_calm_by": 0.25, "fall_calm": SHIELD_ARM, "fall_calm_by": 0.25,
	"in_battle": false,  # манекен: в бой — с моделью
	# Отдельные топор и щит (weapon_grip.gd); пока заглушки, потом модели Tripo.
	"props": [{"hand": "Right", "mode": "fist", "shape": "axe", "length": 0.42, "grip_at": 0.12},
		{"hand": "Left", "mode": "forearm", "shape": "shield", "length": 0.34, "width": 0.26,
			"forward_limit": 0.35}],  # 189: щит не дальше 0,35 роста (≈0,63 м, край гекса 0,52) — ни в ударе, ни в защите; правка клипов заранее
	# 186: стойка со щитом — кнопка альтернативы; ход вдвое меньше; удар принимает в щит; после атаки снова в стойке.
	"stance": {"title": "Щит перед собой", "enter": "shield_up", "idle": "shield_idle", "walk": "shield_walk",
		"hurt": "shield_hurt", "exit": "shield_down", "move": 0.5,
		"defend": "shield_brace", "attack": "shield_attack"},  # 191: в стойке — короткий удар (1,0 с)  # «Защита» в стойке: приседает за щит и принимает удар (Crouch Blocked Impact), не тот же клип, что получение удара
}
