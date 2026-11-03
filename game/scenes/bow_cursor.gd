extends Control
## Лук вместо курсора для дальней атаки: у выстрела нет стороны, поэтому не поворачивается, центр рисунка в точке курсора.

const ARROW := 54.0
const BOW_X := -46.0  # центр дуги лука на стреле
const BOW_R := 28.0
const SWEEP := 1.15  # половина дуги лука, радиан


func _draw() -> void:
	# Рисуем вдоль +X: наконечник в (0, 0), оперение сзади; сдвиг ставит середину стрелы в точку курсора.
	draw_set_transform(Vector2(ARROW * 0.5, 0))
	var outline := Color(0.05, 0.05, 0.06)
	var wood := Color(0.93, 0.72, 0.36)
	var tip_a := Vector2(BOW_X, 0) + Vector2.from_angle(-SWEEP) * BOW_R
	var tip_b := Vector2(BOW_X, 0) + Vector2.from_angle(SWEEP) * BOW_R
	draw_arc(Vector2(BOW_X, 0), BOW_R, -SWEEP, SWEEP, 24, outline, 8.0, true)
	draw_arc(Vector2(BOW_X, 0), BOW_R, -SWEEP, SWEEP, 24, wood, 5.0, true)
	draw_line(tip_a, Vector2(-ARROW, 0), Color(0.9, 0.9, 0.85), 1.0, true)
	draw_line(tip_b, Vector2(-ARROW, 0), Color(0.9, 0.9, 0.85), 1.0, true)
	draw_line(Vector2(-ARROW, 0), Vector2(-7, 0), outline, 4.5, true)
	draw_line(Vector2(-ARROW, 0), Vector2(-7, 0), Color(0.86, 0.88, 0.92), 2.0, true)
	var head := PackedVector2Array([Vector2(0, 0), Vector2(-10, -4.5), Vector2(-10, 4.5)])
	draw_colored_polygon(head, Color(0.86, 0.88, 0.92))
	draw_polyline(head + PackedVector2Array([head[0]]), outline, 1.5, true)
