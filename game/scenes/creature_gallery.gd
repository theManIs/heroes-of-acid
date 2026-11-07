extends Control
## Одна выбранная запись, все выбранные игровые действия одновременно.

const PAGE := preload("res://scenes/creature_gallery_page.gd")
const ARENA := preload("res://scenes/creature_test.gd")
const HUB_BACK := preload("res://scenes/hub_back.gd")  # 180: кнопка «Назад» на главный экран
var _ids: Array = []
var _selector := OptionButton.new()
var _page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18
	bar.offset_top = 10
	bar.offset_bottom = 54
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	var title := Label.new()
	title.text = "Витрина"
	title.add_theme_font_size_override("font_size", 26)
	bar.add_child(title)
	_ids = ["houndmaster-pair", "houndmaster", "hound"] + ARENA.CREATURES.keys()
	for id: String in PAGE.NEW_CREATURES:
		if not _ids.has(id):
			_ids.append(id)
	for id: String in _ids:
		_selector.add_item({"houndmaster-pair": "Псарь с собакой", "houndmaster": "Псарь", "hound": "Собака"}.get(id, ARENA.CREATURES.get(id, PAGE.NEW_CREATURES.get(id, {})).get("name", id)))
	_selector.custom_minimum_size = Vector2(300, 44)
	_selector.item_selected.connect(_select)
	bar.add_child(_selector)
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "←" if direction < 0 else "→"
		button.custom_minimum_size = Vector2(48, 44)
		button.pressed.connect(func():
			var index := posmod(_selector.selected + direction, _ids.size())
			_selector.select(index)
			_select(index))
		bar.add_child(button)
	var selected := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--creature=") and _ids.has(arg.trim_prefix("--creature=")):
			selected = _ids.find(arg.trim_prefix("--creature="))
	_selector.select(selected)
	_select(selected)
	HUB_BACK.add(self)  # 180


func _select(index: int) -> void:
	if is_instance_valid(_page):
		remove_child(_page)
		_page.queue_free()
	_page = PAGE.new()
	_page.selected = _ids[index]
	add_child(_page)
	_page.offset_top = 64
	_page.fit_cells()
