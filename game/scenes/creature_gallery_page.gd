extends "res://scenes/houndmaster_showcase.gd"
## Отдельный владелец миров и повторов: смена записи освобождает весь набор.

var selected := "houndmaster-pair"
var _grid: GridContainer


func _ready() -> void:
	columns = 3 if selected == "hammerer" else 4
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
		var cfg: Dictionary = ARENA.CREATURES.get(selected, NEW_CREATURES.get(selected, {}))
		var actions := [["Стойка", "idle", 0.0, 0.0], ["Ходьба", "walk", 0.0, 0.0],
			["Атака", cfg.attack, cfg.attack_from, 0.0], ["Реакция на удар", cfg.hurt, 0.0, cfg.hurt_len],
			["Защита", cfg.defend, cfg.defend_from, cfg.defend_len], ["Смерть", "fall", 0.0, 0.0]]
		if cfg.has("melee_modes"):
			actions[2][0] = "Удар по площади"
			for mode: Dictionary in cfg.melee_modes.values():
				if mode.anim != cfg.attack:
					actions.insert(3, [mode.title + " удар", mode.anim, mode.get("from", 0.0), 0.0])
		for field in ["run", "fidget"]:
			if cfg.has(field):
				actions.append(["Бег" if field == "run" else "Отклик", cfg[field], 0.0, 0.0])
		for extra: Array in cfg.get("showcase_extra", []):  # пробные клипы только для витрины
			actions.append([extra[0], extra[1], 0.0, 0.0])
		for shot: Dictionary in cfg.get("shots", {}).values():
			if shot.anim != cfg.attack:
				actions.append([shot.title, shot.anim, 0.0, 0.0])
		var stance: Dictionary = cfg.get("stance", {})
		if not stance.is_empty():  # 186: альтернативная стойка; пятое поле — играть из стойки
			actions.append_array([["Стойка: поднять щит", stance.enter, 0.0, 0.0, false],
				["Стойка: " + stance.title.to_lower(), stance.idle, 0.0, 0.0, true],
				["Стойка: шаг", stance.walk, 0.0, 0.0, true], ["Стойка: удар в щит", stance.hurt, 0.0, 0.0, true],
				["Стойка: опустить щит", stance.exit, 0.0, 0.0, true]])
		for action in actions:
			_make_action(cfg, action)
	resized.connect(fit_cells)
	_finish()


const CELL_TARGET := 460  # желаемый размер квадрата витрины, пикселей


func fit_cells() -> void:
	if not is_instance_valid(_grid):
		return
	# Крупные квадраты по ширине окна, остальное прокручивается: всё на один экран было слишком мелко.
	_grid.columns = clampi(floori((size.x - GAP) / (CELL_TARGET + GAP)), 1, columns)
	cell_size = maxi(90, floori((size.x - GAP * (_grid.columns + 1)) / _grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * cell_size


func _make_action(cfg: Dictionary, action: Array) -> void:
	var cell := _make_frame(_grid, cfg.get("showcase_size", cfg.size) * (1.2 if action[1] == "fall" else 1.0))
	_configure_lighting(cell.view, cfg)
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
	for prop: Dictionary in cfg.get("props", []):  # 184: отдельные оружие и щит
		var grip: Node3D = preload("res://scenes/weapon_grip.gd").new()
		for key in prop:
			grip.set(key, prop[key])
		unit.model.add_child(grip)
	var stance: Dictionary = cfg.get("stance", {})
	if action.size() > 4 and action[4]:
		unit.configure_stance(stance)
		unit.set_stance(true, false)  # «idle» — стойка со щитом, к ней возвращаются повторы
	_make_label(cell.frame).text = action[0]
	if action[1] in ["idle", "walk", cfg.get("run", ""), stance.get("idle", "-"), stance.get("walk", "-")]:
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
