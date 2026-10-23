extends Control
## Меч у курсора, как в Героях: остриё в точке курсора, повёрнут в сторону удара.

const BLADE := 30.0
const GUARD := 9.0
const GRIP := 10.0


func _draw() -> void:
	# Рисуем вдоль +X: остриё в (0, 0), рукоять сзади.
	var outline := Color(0.05, 0.05, 0.06)
	var steel := Color(0.86, 0.88, 0.92)
	var blade := PackedVector2Array([Vector2(0, 0), Vector2(-6, -3), Vector2(-BLADE, -3), Vector2(-BLADE, 3), Vector2(-6, 3)])
	draw_colored_polygon(blade, steel)
	draw_polyline(blade + PackedVector2Array([blade[0]]), outline, 1.5, true)
	draw_line(Vector2(-BLADE, -GUARD), Vector2(-BLADE, GUARD), outline, 5.0, true)
	draw_line(Vector2(-BLADE, -GUARD + 1), Vector2(-BLADE, GUARD - 1), Color(0.8, 0.62, 0.25), 3.0, true)
	draw_line(Vector2(-BLADE - 1, 0), Vector2(-BLADE - GRIP, 0), outline, 5.0, true)
	draw_line(Vector2(-BLADE - 1, 0), Vector2(-BLADE - GRIP, 0), Color(0.42, 0.26, 0.14), 3.0, true)
	draw_circle(Vector2(-BLADE - GRIP - 2, 0), 3.0, Color(0.8, 0.62, 0.25))
