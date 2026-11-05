extends RefCounted
## Общая геометрия отряда и собаки для обеих арен. Дальность вылазки не ограничена.
const SINGLE: Array[Vector2i] = [Vector2i.ZERO]
const PAIR: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1, 1), Vector2i(0, 1)]
const DOG: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(0, 1)]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


static func footprint(anchor: Vector2i, shape: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in shape:
		out.append(anchor + offset)
	return out


static func distance(a: Array[Vector2i], b: Array[Vector2i]) -> int:
	var best := 999
	for x in a:
		for y in b:
			var d := x - y
			best = mini(best, (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2)
	return best


static func paths(from: Vector2i, shape: Array[Vector2i], tiles: Dictionary, blocked: Dictionary) -> Dictionary:
	var out := {from: [] as Array[Vector2i]}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_front()
		for d in DIRS:
			var n := h + d
			if out.has(n):
				continue
			var free := true
			for cell in footprint(n, shape):
				if not tiles.has(cell) or blocked.has(cell):
					free = false
			if not free:
				continue
			var path: Array[Vector2i] = out[h].duplicate()
			path.append(n)
			out[n] = path
			queue.append(n)
	return out


static func attacks(paths_to: Dictionary, target: Array[Vector2i]) -> Dictionary:
	var out := {}
	for h: Vector2i in paths_to:
		if distance(footprint(h, DOG), target) == 1:
			out[h] = paths_to[h]
	return out
