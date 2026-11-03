extends Control
## Курсор дальней атаки вместо обычного: лук или фонарь, по режиму огня. У выстрела нет стороны,
## поэтому не поворачивается, центр рисунка в точке курсора.

const ARROW := 54.0
const BOW_X := -46.0  # центр дуги лука на стреле
const BOW_R := 28.0
const SWEEP := 1.15  # половина дуги лука, радиан

var mode := "arrow":
	set(value):
		mode = value
		queue_redraw()


func _draw() -> void:
	if mode == "lantern":
		_draw_lantern()
		return
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


func _draw_lantern() -> void:
	var outline := Color(0.05, 0.05, 0.06)
	var brass := Color(0.93, 0.72, 0.36)
	var glass := Rect2(-11, -13, 22, 28)
	draw_arc(Vector2(0, -24), 7.0, 0.0, TAU, 20, outline, 5.0, true)
	draw_arc(Vector2(0, -24), 7.0, 0.0, TAU, 20, brass, 2.5, true)
	draw_rect(glass.grow(2.5), outline)
	draw_rect(glass, Color(1.0, 0.6, 0.12))
	draw_line(glass.position, glass.end, brass, 2.0, true)
	draw_line(Vector2(glass.end.x, glass.position.y), Vector2(glass.position.x, glass.end.y), brass, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -13), Vector2(15, -13), Vector2(5, -21), Vector2(-5, -21)]), brass)
	draw_rect(Rect2(-14, 15, 28, 5), brass)
