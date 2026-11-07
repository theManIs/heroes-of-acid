extends RefCounted

const UNIT := {
	"name": "Молотобоец", "icon": "res://assets/creatures/hammerer2/icon.png", "scene": "res://assets/creatures/hammerer2/hammerer.tscn",
	"extra": ["res://assets/creatures/hammerer2/anims/idle.glb", "res://assets/creatures/hammerer2/anims/walk.glb",
		"res://assets/creatures/hammerer2/anims/run.glb", "res://assets/creatures/hammerer2/anims/attack.glb",
		"res://assets/creatures/hammerer2/anims/hurt.glb", "res://assets/creatures/hammerer2/anims/defend.glb",
		"res://assets/creatures/hammerer2/anims/fall.glb", "res://assets/creatures/hammerer2/anims/fidget.glb",
		"res://assets/creatures/hammerer2/anims/attack_point.glb"],
	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0,
	"idle": "idle", "run": "run", "fidget": "fidget", "defend": "defend",
	"fidget_on_hover": true,
	"defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3,
	"size": 1.955, "walk_speed": 1.2155,  # 175: 85 % от 2,3 — вмещается в свой гекс; шаг в той же доле
	"variants": [{"title": "бронза"}, {"title": "светлая сталь", "textures": {"albedo": "res://assets/creatures/hammerer2/generations/silver/albedo.jpg", "normal": "res://assets/creatures/hammerer2/generations/silver/normal.jpg", "orm": "res://assets/creatures/hammerer2/generations/silver/orm.png"}}],  # 170
	"showcase_size": 3.2, "showcase_metal_light": true,
	"melee_modes": {
		"area": {"title": "По площади", "anim": "attack", "area": true, "impact": 0.383, "reach": 1.13, "full_clip": true, "no_backstep": true},  # 167: тяжёлый взмах
		"point": {"title": "Точечный", "anim": "attack_point", "area": false, "impact": 0.333, "reach": 1.6, "no_backstep": true},  # 153: не отъезжать назад на 0,67 м
	},
}
