extends Control
## Иконка действия на кнопке боя: один цвет на чёрной кляксе. Рисуется кодом.

enum Kind { WAIT, DEFEND, RESTART }

const INK := Color(0.86, 0.73, 0.47)  # светлая бронза
const DARK := Color(0.04, 0.035, 0.03)  # клякса и вырезы в иконке
const HOVER := Color(0.2, 0.15, 0.09)  # клякса под курсором
const BLOT_POINTS := 40

var kind := Kind.WAIT


func _ready() -> void:
	var button := get_parent() as Button
	button.mouse_entered.connect(queue_redraw)
	button.mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var c := size * 0.5
	var color := HOVER if (get_parent() as Button).is_hovered() else DARK
	_blot(c, color)
	match kind:
		Kind.WAIT:
			_hourglass(c)
		Kind.DEFEND:
			_shield(c)
		Kind.RESTART:
			_restart(c)


## Клякса: круг с неровным краем и брызги рядом; форма своя у каждого вида иконки и не меняется.
func _blot(c: Vector2, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + kind * 7
	var points := PackedVector2Array()
	var phase := rng.randf() * TAU
	for i in BLOT_POINTS:
		var a := TAU * i / BLOT_POINTS
		var r := 28.0 + 2.5 * sin(a * 3.0 + phase) + rng.randf_range(-3.0, 3.5)
		if rng.randf() < 0.12:
			r += rng.randf_range(2.0, 6.0)  # потёк
		points.append(c + Vector2(r, 0).rotated(a))
	draw_colored_polygon(points, color)
	for i in 5:
		var spot := c + Vector2(rng.randf_range(33.0, 39.0), 0).rotated(rng.randf() * TAU)
		draw_circle(spot, rng.randf_range(0.9, 2.2), color)


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
