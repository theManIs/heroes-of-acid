extends "res://scenes/showcase.gd"
## 181: витрина кандидатов Mixamo на манекене — первый шаг пайплайна creature-mixamo-first.
## Запуск: godot --path game res://scenes/mannequin_search.tscn -- --id=<существо>
## Список квадратов — creatures/<id>/mixamo/candidates.json:
##   {"body": модель манекена, "idle": стойка между повторами, "size": рост,
##    "props": [параметры weapon_grip.gd: hand, mode, shape, length, width, grip_at, roll],
##    "cells": [[подпись, клип, по кругу, своя стойка между повторами — необязательно], …]}
## Клипы — game/assets/creatures/<id>/anims/<клип>.glb (build_clips.py <id> на риге манекена).

const GRIP := preload("res://scenes/weapon_grip.gd")
const MANNEQUIN := "res://assets/mannequin/xbot.glb"  # 185: манекен Mixamo X Bot, родной скелет Mixamo
const HOLD := 1.0

var _id := ""
var _set: Dictionary = {}
var _grid: GridContainer


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--id="):
			_id = arg.trim_prefix("--id=")
	var path := ProjectSettings.globalize_path("res://").path_join("../creatures/%s/mixamo/candidates.json" % _id)
	_set = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	columns = 4
	cell_size = 360
	var grid := _build_page()
	_grid = grid
	for cell: Array in _set.get("cells", []):
		_make_candidate(grid, cell[0], cell[1], cell[2], cell[3] if cell.size() > 3 else _set.get("idle", "idle"))
	resized.connect(_fit_cells)
	_finish()
	_fit_cells()


## Сколько квадратов влезает в ширину окна — столько столбцов; квадраты растягиваются на всю ширину.
func _fit_cells() -> void:
	if not is_instance_valid(_grid):
		return
	var count := _grid.get_child_count()
	_grid.columns = clampi(floori((size.x - GAP) / (360 + GAP)), 1, maxi(1, count))
	cell_size = maxi(120, floori((size.x - GAP * (_grid.columns + 1)) / _grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * cell_size


func _anims() -> String:
	return "res://assets/creatures/%s/anims/" % _id


func _make_candidate(grid: GridContainer, title: String, clip: String, endless: bool, idle: String) -> void:
	var size: float = _set.get("size", 1.8)
	var cell := _make_frame(grid, size * 1.15)
	var unit := Creature.new()
	cell.view.add_child(unit)
	var files := [_anims() + idle + ".glb"]
	if clip != idle:
		files.append(_anims() + clip + ".glb")
	unit.setup(load(_set.get("body", MANNEQUIN)), files, clip, "", size, 0.0, idle)
	unit.face(unit.position + Vector3.BACK + Vector3.RIGHT)
	for prop: Dictionary in _set.get("props", []):
		var grip := GRIP.new()
		for key in prop:
			grip.set(key, prop[key])
		unit.model.add_child(grip)
	var label := _make_label(cell.frame)
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # длинная подпись не раздвигает квадрат
	if endless:
		unit.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		unit.anim.play(clip)
	else:
		_repeat(unit, clip, idle)


func _repeat(unit: Creature, clip: String, idle: String) -> void:
	var death := clip.contains("death") or clip.contains("fall")
	while is_instance_valid(unit):
		unit.dead = death  # смерть: Creature не возвращает в стойку, лежит до повтора
		unit.anim.play(clip, 0.2)
		await get_tree().create_timer(unit.anim.get_animation(clip).length).timeout
		if not is_instance_valid(unit):
			return
		if not death:
			unit.anim.play(idle, 0.3)
		await get_tree().create_timer(HOLD).timeout
