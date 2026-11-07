extends Node3D
## 181: отдельное одноручное оружие или щит в кисти — общий хват пайплайна creature-mixamo-first.
## Ставится дочерним узлом модели существа (рядом со скелетом), как hammer_grip у молотобойца.
## Оружие не крутится по ходу клипа: поворот задан один раз (roll), дальше идёт за кистью (M02, 153).
##
## mode "fist" — рукоять через кулак: ось рукояти вдоль линии костяшек (мизинец → указательный),
##   рабочая сторона (лезвие) — туда, куда смотрят костяшки. grip_at — где кулак, доля длины от торца.
## mode "forearm" — щит плашмя на внешней стороне предплечья, кисть на рукояти в центре (ARTIFACTS 43).
## Модель — model (glb) или заглушка shape: "axe", "shield", "stick".

@export var hand := "Right"
@export var mode := "fist"
@export var model := ""
@export var shape := "axe"
## Длина оружия (или щита вдоль предплечья) в долях роста существа.
@export var length := 0.42
## Ширина щита в долях роста.
@export var width := 0.3
@export var grip_at := 0.12
## Постоянный поворот вокруг рукояти (или вокруг нормали щита), градусы.
@export var roll := 0.0
## 189: дальше этого вперёд (доля роста от центра гекса) предмет не выходит ни в одном клипе — не залезает в соседа.
## Траектория правится заранее, при загрузке: в кадрах, где предмет дальше, плечо разворачивается
## (ось — та, где предмет быстрее всего уходит назад) ровно настолько, чтобы предмет встал на границу. Поправка вписана в клип, тело не двигается. 0 — выкл.
@export var forward_limit := 0.0

var _skeleton: Skeleton3D
var _unit: Creature
var _item: Node3D


func _ready() -> void:
	process_priority = 20
	call_deferred("_attach")


func _attach() -> void:
	_skeleton = get_parent().find_children("*", "Skeleton3D", true, false)[0]
	_unit = get_parent().get_parent() as Creature
	_item = load(model).instantiate() if model != "" else _placeholder()
	add_child(_item)
	_item.top_level = true
	_process(0.0)
	if forward_limit > 0.0 and _unit:
		_bake_limit()


## Заглушка на манекене: размер и хват как у будущего оружия, без модели.
func _placeholder() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.18)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.6
	if shape == "shield":
		var disc := CylinderMesh.new()  # ось цилиндра — нормаль щита (+Z после поворота)
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.06
		disc.material = wood
		var node := MeshInstance3D.new()
		node.mesh = disc
		node.rotation_degrees.x = 90.0
		root.add_child(node)
		return root
	var shaft := CylinderMesh.new()  # рукоять вдоль +Y от 0 до 1
	shaft.top_radius = 0.02
	shaft.bottom_radius = 0.02
	shaft.height = 1.0
	shaft.material = wood
	var stick := MeshInstance3D.new()
	stick.mesh = shaft
	stick.position.y = 0.5
	root.add_child(stick)
	if shape == "axe":
		var blade := BoxMesh.new()  # голова у верхнего конца, лезвие в +Z
		blade.size = Vector3(0.03, 0.22, 0.2)
		blade.material = steel
		var head := MeshInstance3D.new()
		head.mesh = blade
		head.position = Vector3(0.0, 0.88, 0.1)
		root.add_child(head)
	return root


func _point(suffix: String) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("mixamorig_" + suffix))).origin


func _process(_delta: float) -> void:
	if not is_instance_valid(_item):
		return
	var height: float = _unit.height if _unit else 1.8
	var palm := _point(hand + "Hand").lerp(_point(hand + "HandMiddle1"), 0.75)
	var knuckles := (_point(hand + "HandIndex1") - _point(hand + "HandPinky1")).normalized()
	var fingers := (_point(hand + "HandMiddle1") - _point(hand + "Hand")).normalized()
	if mode == "forearm":
		var fore := (_point(hand + "Hand") - _point(hand + "ForeArm")).normalized()
		var out := fore.cross(knuckles).normalized()  # тыльная сторона кисти
		if out.dot(palm - _point("Spine2")) < 0.0:
			out = -out
		var up := fore.cross(out).normalized()
		var basis := Basis(up, fore, out).rotated(out, deg_to_rad(roll))
		var size := Vector3(width, length, 1.0) * height
		var centre := _point(hand + "ForeArm").lerp(_point(hand + "Hand"), 0.6) + out * 0.06 * height
		_item.global_transform = Transform3D(basis.scaled_local(Vector3(size.x, size.y, size.x)), centre)
		return
	var axis := knuckles
	var edge := (fingers - axis * fingers.dot(axis)).normalized()  # костяшки — туда же лезвие
	var basis := Basis(axis.cross(edge), axis, edge).rotated(axis, deg_to_rad(roll))
	var span := length * height
	_item.global_transform = Transform3D(basis.scaled_local(Vector3.ONE * span), palm - axis * span * grip_at)


## Точки предмета в мире: углы рамок его сеток.
func _item_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m: MeshInstance3D in _item.find_children("*", "MeshInstance3D", true, false):
		var box := m.get_aabb()
		for c in 8:
			out.append(m.global_transform * (box.position + box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)))
	return out


## 189: заранее ограничить вынос предмета вперёд в стоячих клипах: стойка, удар, реакция, защита, отклик.
## Две постоянные оси плеча: вертикаль (щит уходит вбок-назад), затем поперечная (вниз-назад). Угол не больше
## TURN_MAX, по кадрам сглажен — без рывков; выход за границу меньше TOLERANCE не трогаем.
const TURN_MAX := deg_to_rad(50.0)
const TURN_MAX_ATTACK := deg_to_rad(90.0)  # 193: в ударе корпус уходит вперёд — плечу нужен больший разворот
const TOLERANCE := 0.015
const SMOOTH := 2  # кадров в каждую сторону


func _bake_limit() -> void:
	var anim := _unit.anim
	var arm := _skeleton.find_bone("mixamorig_" + hand + "Arm")
	var parent := _skeleton.get_bone_parent(arm)
	if arm < 0 or parent < 0:
		return
	var limit := forward_limit * _unit.height
	var forward := _unit.model.global_basis.x.normalized()  # модель смотрит по +X
	var up := _unit.model.global_basis.y.normalized()
	var across := forward.cross(up).normalized()
	var centre := _unit.global_position
	var to_sk := _skeleton.global_basis.inverse()
	var track_path := NodePath("%s:%s" % [anim.get_node(anim.root_node).get_path_to(_skeleton), _skeleton.get_bone_name(arm)])
	var was := anim.current_animation
	# Сначала кадры всех клипов, потом одни стороны поворота на всё существо: поправки разных клипов
	# согласованы, и переход между клипами не проводит щит через вынос вперёд (было 0,85 м в переходе).
	var jobs := []  # [клип, трек, кадры, предел поворота]
	for clip in anim.get_animation_list():
		if clip == "fall" or clip == "RESET" or clip.contains("walk") or clip.contains("run"):
			continue  # на ходу сосед не впереди; в шаге поворот плеча уводил щит в сторону, как флаг
		var a := anim.get_animation(clip)
		var t := a.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if t < 0 or a.has_meta("forward_limited"):
			continue
		a.set_meta("forward_limited", true)
		var frames := []  # [сустав, точки, базис родителя, базис плеча]
		for k in a.track_get_key_count(t):
			anim.play(clip)
			anim.seek(a.track_get_key_time(t, k), true)
			_skeleton.force_update_all_bone_transforms()
			_process(0.0)
			frames.append([(_skeleton.global_transform * _skeleton.get_bone_global_pose(arm)).origin, _item_points(),
				_skeleton.get_bone_global_pose(parent).basis.orthonormalized(), _skeleton.get_bone_global_pose(arm).basis.orthonormalized()])
		var attack: bool = clip == _unit.attack_anim or clip == _unit.stance.get("attack", "-")
		jobs.append([a, t, frames, TURN_MAX_ATTACK if attack else TURN_MAX])
	var best_signs := Vector2.ONE
	var best_over := INF
	for signs in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var over := 0.0
		for job: Array in jobs:
			for f: Array in job[2]:
				var turn := _solve(f[0], f[1], centre, forward, up, across, limit, job[3], signs)
				over += maxf(0.0, _front(f[0], f[1], centre, forward, up, across, turn) - limit) + absf(turn.x) * 0.001 + absf(turn.y) * 0.001
		if over < best_over:
			best_over = over
			best_signs = signs
	for job: Array in jobs:
		var a: Animation = job[0]
		var t: int = job[1]
		var frames: Array = job[2]
		var keys := frames.size()
		var turns: Array = []
		for f: Array in frames:
			turns.append(_solve(f[0], f[1], centre, forward, up, across, limit, job[3], best_signs))
		if turns.all(func(x): return x == Vector2.ZERO):
			continue
		for k in keys:
			var sum := Vector2.ZERO
			var peak := Vector2.ZERO
			for j in range(maxi(0, k - SMOOTH), mini(keys, k + SMOOTH + 1)):
				sum += turns[j]
				if absf(turns[j].x) > absf(peak.x): peak.x = turns[j].x
				if absf(turns[j].y) > absf(peak.y): peak.y = turns[j].y
			var turn: Vector2 = (sum / float(mini(keys, k + SMOOTH + 1) - maxi(0, k - SMOOTH)) + peak) * 0.5
			if turn == Vector2.ZERO:
				continue
			var world := Basis(across, turn.y) * Basis(up, turn.x)
			var turn_sk := Basis((to_sk * world * to_sk.inverse()).get_rotation_quaternion())
			var q: Quaternion = (frames[k][2].inverse() * turn_sk * frames[k][3]).get_rotation_quaternion()
			var old: Quaternion = a.track_get_key_value(t, k)
			if q.dot(old) < 0.0:
				q = -q  # тот же поворот в одном полушарии с исходным ключом: иначе смешивание клипов ломает позу
			a.track_set_key_value(t, k, q)
	if was != "":
		anim.play(was)


## Вынос предмета вперёд при повороте плеча turn (вертикаль, поперечная).
func _front(joint: Vector3, points: Array, centre: Vector3, forward: Vector3, up: Vector3, across: Vector3, turn: Vector2) -> float:
	var rot := Basis(across, turn.y) * Basis(up, turn.x)
	var most := -INF
	for p: Vector3 in points:
		most = maxf(most, (joint + rot * (p - joint) - centre).dot(forward))
	return most


## Углы плеча (вертикаль, поперечная) со сторонами signs, при которых предмет не дальше границы;
## каждый не больше cap. Сначала вертикаль, затем поперечная; наименьший нужный поворот.
func _solve(joint: Vector3, points: Array, centre: Vector3, forward: Vector3, up: Vector3, across: Vector3, limit: float, cap: float, signs: Vector2) -> Vector2:
	if _front(joint, points, centre, forward, up, across, Vector2.ZERO) <= limit + TOLERANCE:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_front := _front(joint, points, centre, forward, up, across, best)
	for axis in [0, 1]:
		for step in 30:
			var turn := best
			turn[axis] = signs[axis] * cap * (step + 1) / 30.0
			var f := _front(joint, points, centre, forward, up, across, turn)
			if f < best_front - 0.001:
				best_front = f
				best = turn
			if f <= limit:
				return best
	return best
