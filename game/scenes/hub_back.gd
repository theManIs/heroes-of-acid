extends RefCounted
## 180: кнопка «Назад» на главный экран — правый верхний угол, поверх всего.

const HUB := "res://scenes/hub.tscn"


static func add(owner: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var button := Button.new()
	button.text = "Назад"
	button.add_theme_font_size_override("font_size", 18)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -136
	button.offset_right = -16
	button.offset_top = 12
	button.offset_bottom = 54
	button.pressed.connect(func():
		Engine.time_scale = 1.0
		owner.get_tree().change_scene_to_file(HUB))
	layer.add_child(button)
	owner.add_child(layer)
