extends RefCounted
## The three neighboring cells in front of the attacker, centered on the target.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


static func zone(from: Vector2i, target: Vector2i, wide: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = [target]
	if not wide:
		return result
	var aim := _flat(target - from).normalized()
	var best := 0
	var score := -INF
	for i in DIRS.size():
		var dot := _flat(DIRS[i]).normalized().dot(aim)
		if dot > score:
			score = dot
			best = i
	result.clear()
	result.append(from + DIRS[best])
	result.append(from + DIRS[(best + 1) % 6])
	result.append(from + DIRS[(best + 5) % 6])
	return result


static func _flat(h: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (h.x + h.y * 0.5), 1.5 * h.y)
