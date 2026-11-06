extends "res://scenes/hammerer_search.gd"
## Задача 167: только клипы с наложенными руками из стойки «2hand Idle» (build_clips.py: arms_from)
## и выбранные стойка и удар. Разовые возвращаются в стойку.
## Запуск: godot --path game res://scenes/hammerer_overlay.tscn

const OVERLAY := [
	["Стойка: 2hand Idle", "c_2hand_idle", true],
	["Удар: тяжёлый взмах", "c_heavy_swing", false],
	["Точечный: прежний, молот жёстко в правой", "attack_point", false],
	["Ходьба: прежний шаг + руки стойки", "c2_walk_sword", true],
	["Бег: прежний + руки стойки", "c2_run_sword", true],
	["Реакция: прежняя + руки стойки", "c2_hurt", false],
	["Отклик: озирается + руки стойки", "c2_look", false],
	["Защита: прежняя + руки стойки", "c2_defend", false],
	["Смерть: прежняя + руки стойки", "c2_fall", false],
]


func _ready() -> void:
	if columns == 2:  # по умолчанию showcase; подкласс задаёт своё до super._ready()
		columns = 4
	cell_size = 300
	var grid := _build_page()
	for cell: Array in _cells():
		_make_candidate(grid, cell[0], cell[1], cell[2])
	get_viewport().size_changed.connect(_fit.bind(grid))
	_zoom_grid = grid
	_fit(grid)
	_finish()


## Все квадраты в окне: сторона по ширине и высоте окна; щипок увеличивает (cell_zoom).
func _fit(grid: GridContainer) -> void:
	var view := get_viewport_rect().size
	var rows := ceili(float(_cells().size()) / columns)
	var side := mini(floori((view.x - GAP * (columns + 1)) / columns), floori((view.y - GAP * (rows + 1)) / rows)) - 6
	side = maxi(90, floori(side * cell_zoom))
	grid.columns = columns if cell_zoom <= 1.0 else clampi(floori(view.x / (side + GAP)), 1, columns)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * side


func _cells() -> Array:
	return OVERLAY


func _idle_clip() -> String:
	return "c_2hand_idle"


## Длинная подпись переносится, а не растягивает квадрат за край окна.
func _make_label(frame: Control) -> Label:
	var label := super._make_label(frame)
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 60
	return label
