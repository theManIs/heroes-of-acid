extends "res://scenes/houndmaster_showcase.gd"
## Отдельный владелец миров и повторов: смена записи освобождает весь набор.

var selected := "houndmaster-pair"
var _grid: GridContainer


func _ready() -> void:
	columns = 4
	cell_size = 350
	_grid = _build_page()
	if selected in ["houndmaster", "hound", "houndmaster-pair"]:
		for i in CLIPS.size():
			if selected == "houndmaster":
				_make_master_cell(_grid, CLIPS[i][0], CLIPS[i][1], CLIPS[i][2])
			elif selected == "hound":
				_make_hound_cell(_grid, HOUND_LAB.CLIPS[i])
			else:
				_make_pair_cell(_grid, i)
	else:
		var cfg: Dictionary = ARENA.CREATURES[selected]
		var actions := [["Стойка", "idle", 0.0, 0.0], ["Ходьба", "walk", 0.0, 0.0],
			["Атака", cfg.attack, cfg.attack_from, 0.0], ["Реакция на удар", cfg.hurt, 0.0, cfg.hurt_len],
			["Защита", cfg.defend, cfg.defend_from, cfg.defend_len], ["Смерть", "fall", 0.0, 0.0]]
		for field in ["run", "fidget"]:
			if cfg.has(field):
				actions.append(["Бег" if field == "run" else "Отклик", cfg[field], 0.0, 0.0])
		for shot: Dictionary in cfg.get("shots", {}).values():
			if shot.anim != cfg.attack:
				actions.append([shot.title, shot.anim, 0.0, 0.0])
		for action in actions:
			_make_action(cfg, action)
	resized.connect(fit_cells)
	_finish()


func fit_cells() -> void:
	if not is_instance_valid(_grid):
		return
	var rows := ceili(float(_views.size()) / columns)
	cell_size = maxi(90, floori(minf((size.x - GAP * (columns + 1)) / columns, (size.y - GAP * (rows + 1)) / rows)) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * cell_size


func _make_action(cfg: Dictionary, action: Array) -> void:
	var cell := _make_frame(_grid, cfg.size * (1.2 if action[1] == "fall" else 1.0))
	var unit := Creature.new()
	cell.view.add_child(unit)
	unit.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	unit.defend_anim = cfg.defend
	unit.defend_pin = cfg.get("defend_pin", true)
	unit.turn_bones(cfg.get("bone_turn", {}))
	unit.scale_bones(cfg.defend, cfg.get("defend_calm", []), cfg.get("defend_calm_by", 1.0))
	unit.scale_bones(cfg.hurt, cfg.get("hurt_calm", []), cfg.get("hurt_calm_by", 1.0))
	var variant: Dictionary = cfg.get("variants", [{}])[-1]
	unit.set_textures(variant.get("textures", {}))
	if variant.has("glow"):
		unit.add_glow(variant.glow)
	if cfg.get("smoke", false):
		unit.add_smoke()
	unit.face(Vector3.BACK + Vector3.RIGHT)
	_make_label(cell.frame).text = action[0]
	if action[1] in ["idle", "walk", cfg.get("run", "")]:
		unit.anim.get_animation(action[1]).loop_mode = Animation.LOOP_LINEAR
		unit.anim.play(action[1])
	else:
		_repeat_action(unit, action)


func _repeat_action(unit: Creature, action: Array) -> void:
	while true:
		unit.dead = action[1] == "fall"
		var length := unit.anim.get_animation(action[1]).length
		unit.anim.play(action[1], 0.2)
		unit.anim.seek(length * action[2], true)
		await get_tree().create_timer(action[3] if action[3] > 0.0 else length * (1.0 - action[2])).timeout
		if unit.dead:
			await get_tree().create_timer(HOLD).timeout
		unit.dead = false
		unit.anim.play("idle", 0.3)
		await get_tree().create_timer(HOLD).timeout
