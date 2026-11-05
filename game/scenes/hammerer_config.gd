extends RefCounted

const UNIT := {
	"name": "Молотобоец", "icon": "res://assets/creatures/hammerer/icon.png", "scene": "res://assets/creatures/hammerer/hammerer.tscn",
	"extra": ["res://assets/creatures/hammerer/anims/idle.glb", "res://assets/creatures/hammerer/anims/walk.glb",
		"res://assets/creatures/hammerer/anims/run.glb", "res://assets/creatures/hammerer/anims/attack.glb",
		"res://assets/creatures/hammerer/anims/hurt.glb", "res://assets/creatures/hammerer/anims/defend.glb",
		"res://assets/creatures/hammerer/anims/fall.glb", "res://assets/creatures/hammerer/anims/fidget.glb",
		"res://assets/creatures/hammerer/anims/attack_point.glb"],
	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0,
	"idle": "idle", "run": "run", "fidget": "fidget", "defend": "defend",
	"fidget_on_hover": true,
	"defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3,
	"size": 1.9, "walk_speed": 1.18, "showcase_size": 2.7, "showcase_metal_light": true,
	"melee_modes": {
		"area": {"title": "По площади", "anim": "attack", "area": true, "impact": 0.56122449, "reach": 1.25},
		"point": {"title": "Точечный", "anim": "attack_point", "area": false, "impact": 0.56122449, "reach": 1.25},
	},
}
