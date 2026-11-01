extends Control
## Иконка действия на кнопке боя: один цвет, как в Героях 3. Рисуется кодом.

enum Kind { WAIT, DEFEND, RESTART }

const INK := Color(0.86, 0.73, 0.47)  # светлая бронза
const DARK := Color(0.12, 0.08, 0.05)  # цвет кнопки: вырезы в иконке

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


func _hourglass(c: Vector2) -> void:
	for y: float in [-20.0, 20.0]:
		draw_line(c + Vector2(-15, y), c + Vector2(15, y), INK, 4.0, true)
	var frame := PackedVector2Array([c + Vector2(-11, -18), c + Vector2(-1.5, 0), c + Vector2(-11, 18), c + Vector2(11, 18), c + Vector2(1.5, 0), c + Vector2(11, -18), c + Vector2(-11, -18)])
	draw_polyline(frame, INK, 2.5, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -12), c + Vector2(7, -12), c + Vector2(0, -1)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 17), c + Vector2(8, 17), c + Vector2(0, 8)]), INK)


## Вытянутый треугольник с выпуклыми краями, как щит ополченца.
func _shield(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-15, -19), c + Vector2(15, -19), c + Vector2(17, -8), c + Vector2(14, 4), c + Vector2(7, 14), c + Vector2(0, 22), c + Vector2(-7, 14), c + Vector2(-14, 4), c + Vector2(-17, -8)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -15), c + Vector2(11, -15), c + Vector2(13, -7), c + Vector2(10, 3), c + Vector2(5, 11), c + Vector2(0, 16), c + Vector2(-5, 11), c + Vector2(-10, 3), c + Vector2(-13, -7)]), DARK)
	draw_circle(c + Vector2(0, -3), 5.0, INK)


func _restart(c: Vector2) -> void:
	draw_arc(c, 15.0, -PI * 0.3, PI * 1.5, 32, INK, 4.5, true)
	var tip := c + Vector2(15, 0).rotated(-PI * 0.3)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -6), tip + Vector2(8, -6), tip + Vector2(1, 9)]), INK)
