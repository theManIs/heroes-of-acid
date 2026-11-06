extends RefCounted
## Запись всадника (задача 166): конь ведёт анимации существа, рыцарь с копьём сидит на нём (rider_unit.gd).
const UNIT := {
	"name": "Всадник", "scene": "res://assets/creatures/rider/rider_unit.tscn", "extra": [],
	"attack": "attack_headbutt", "attack_label": "рывок с места", "attack_from": 0.0,  # удар собирает rider_unit.gd
	"hurt": "hurt_left", "hurt_len": 0.0, "idle": "idle_breathe", "run": "run",
	"defend": "idle_head_low", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3, "defend_pin": true,
	"fidget": "fidget_graze", "fidget_on_hover": true,
	"size": 1.615,  # 1,9 × 0,85 (rider_unit.SCALE)
	 "walk_speed": 1.5, "showcase_size": 3.6, "showcase_metal_light": true,
}
