extends Control
## Иконка действия на кнопке боя: рисуется кодом, как меч у курсора.

enum Kind { WAIT, DEFEND, RESTART }

const STEEL := Color(0.86, 0.88, 0.92)
const OUTLINE := Color(0.05, 0.05, 0.06)
const WOOD := Color(0.62, 0.42, 0.22)
const SAND := Color(0.85, 0.68, 0.32)
const SHIELD_RED := Color(0.7, 0.16, 0.13)

var kind := Kind.WAIT


func _draw() -> void:
	var c := size * 0.5
	match kind:
		Kind.WAIT:
			_hourglass(c)
		Kind.DEFEND:
			_shield(c)
		Kind.RESTART:
			_restart(c)


func _shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), OUTLINE, 2.0, true)


func _hourglass(c: Vector2) -> void:
	_shape(PackedVector2Array([c + Vector2(-13, -18), c + Vector2(13, -18), c + Vector2(2, 0), c + Vector2(13, 18), c + Vector2(-13, 18), c + Vector2(-2, 0)]), Color(0.72, 0.8, 0.88, 0.5))
	_shape(PackedVector2Array([c + Vector2(-8, -10), c + Vector2(8, -10), c + Vector2(0, 0)]), SAND)
	_shape(PackedVector2Array([c + Vector2(-9, 16), c + Vector2(9, 16), c + Vector2(0, 7)]), SAND)
	for y: float in [-20.0, 20.0]:
		draw_line(c + Vector2(-16, y), c + Vector2(16, y), OUTLINE, 6.0, true)
		draw_line(c + Vector2(-15, y), c + Vector2(15, y), WOOD, 3.5, true)


## Вытянутый треугольник с выпуклыми краями, как щит ополченца.
func _shield(c: Vector2) -> void:
	var outer := PackedVector2Array([c + Vector2(-15, -19), c + Vector2(15, -19), c + Vector2(17, -8), c + Vector2(14, 4), c + Vector2(7, 14), c + Vector2(0, 22), c + Vector2(-7, 14), c + Vector2(-14, 4), c + Vector2(-17, -8)])
	_shape(outer, STEEL)
	var inner := PackedVector2Array([c + Vector2(-11, -15), c + Vector2(11, -15), c + Vector2(13, -7), c + Vector2(10, 3), c + Vector2(5, 11), c + Vector2(0, 16), c + Vector2(-5, 11), c + Vector2(-10, 3), c + Vector2(-13, -7)])
	draw_colored_polygon(inner, SHIELD_RED)
	draw_circle(c + Vector2(0, -3), 4.5, OUTLINE)
	draw_circle(c + Vector2(0, -3), 3.2, STEEL)


func _restart(c: Vector2) -> void:
	draw_arc(c, 15.0, -PI * 0.3, PI * 1.5, 32, OUTLINE, 7.0, true)
	draw_arc(c, 15.0, -PI * 0.3, PI * 1.5, 32, STEEL, 4.0, true)
	var tip := c + Vector2(15, 0).rotated(-PI * 0.3)
	_shape(PackedVector2Array([tip + Vector2(-9, -6), tip + Vector2(8, -6), tip + Vector2(1, 9)]), STEEL)
