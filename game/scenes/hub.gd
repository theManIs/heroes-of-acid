extends Control
## 180: главный экран — миниатюры сцен, клик открывает сцену. В каждой сцене кнопка «Назад» сюда.
## Новая сцена — новая строка в SCENES; миниатюра 640×360 в assets/ui/hub.

const SCENES := [
	{"title": "Тест существа", "scene": "res://scenes/creature_test.tscn", "thumb": "res://assets/ui/hub/creature_test.jpg"},
	{"title": "Бой", "scene": "res://scenes/battle_test.tscn", "thumb": "res://assets/ui/hub/battle_test.jpg"},
	{"title": "Витрина", "scene": "res://scenes/showcase.tscn", "thumb": "res://assets/ui/hub/showcase.jpg"},
]
const TILE := Vector2(480, 270)
const GAP := 28


func _ready() -> void:
	Engine.time_scale = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := ColorRect.new()
	page.color = Color(0.1, 0.09, 0.08)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	center.add_child(column)
	var title := Label.new()
	title.text = "Heroes of Acid — прогоны механик"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	column.add_child(grid)
	for entry: Dictionary in SCENES:
		grid.add_child(_tile(entry))


func _tile(entry: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = TILE + Vector2(16, 60)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): get_tree().change_scene_to_file(entry.scene))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var picture := TextureRect.new()
	picture.texture = load(entry.thumb)
	picture.custom_minimum_size = TILE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var label := Label.new()
	label.text = entry.title
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return button
