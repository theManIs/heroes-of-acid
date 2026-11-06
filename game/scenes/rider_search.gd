extends "res://scenes/rider_showcase.gd"
## Задача 158: неожиданные кандидаты из Mixamo для всадника, найденные поиском по каталогу.
## Все из сидячих клипов; правка — копьё под рукой и правая рука неподвижна, зеркало, обрезка.

const SEARCH_GAITS := [
	["Шаг: левая рука на руле — как поводья (Driving)", "s_driving", 1.6, 0.03, 18.0],
	["Бег: рысь, рука на поводьях (Driving)", "s_driving", 2.6, 0.07, 28.0],
]
## Подпись, клип, сколько секунд играть (0 — весь), с какой секунды.
const SEARCH_CELLS := [
	["Стойка: рука вперёд, как на штурвале (Piloting)", "s_piloting", 0.0, 0.0],
	["Отклик: «Вперёд!» — показывает левой (Pointing, зеркально)", "s_sitting_and_pointing_mirror", 0.0, 0.0],
	["Отклик: подзывает своих левой (Beckoning, зеркально)", "s_beckoning_mirror", 0.0, 0.0],
	["Отклик: победный жест левой (Victory, зеркально)", "s_sitting_victory_mirror", 0.0, 0.0],
	["Защита: пригнулся за шею коня (Ducking)", "s_ducking", 0.0, 0.0],
	["Защита: уклон влево (Sitting Dodges, 2,4–4,7 с)", "s_sitting_dodges", 2.3, 2.4],
	["Реакция: толкнули в седле (Shoved)", "s_shoved", 0.0, 0.0],
]
const SEARCH_DEATHS := [["Смерть: обмяк и сполз (Knocked Unconscious)", "s_knocked_unconscious", 0.55, 1.0, -1.1]]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	for gait: Array in SEARCH_GAITS:
		_make_ride_cell(grid, gait)
	for cell: Array in SEARCH_CELLS:
		var entry: Array = [cell[0], cell[1]]
		if cell[2] > 0.0:
			entry.append(cell[2])
			entry.append(cell[3])
		_make_fidget_cell(grid, entry)
	for death: Array in SEARCH_DEATHS:
		_make_death_cell(grid, death)
	get_viewport().size_changed.connect(_fit.bind(grid))
	_zoom_grid = grid
	_fit(grid)
	_finish()
