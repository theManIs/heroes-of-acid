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
## 184: в спокойных клипах (опущенная кисть) рукоять не вдоль костяшек, а наклонена вниз на carry_tilt градусов —
## иначе топор в опущенной руке торчит вперёд горизонтально (0,8 м). В бою и в стойке со щитом — хват кулаком.
## 184: жёсткий хват. Предмет сидит в кисти неподвижно: его положение относительно кисти считается ОДИН раз
## по эталонной позе (первый кадр клипа calibrate) и дальше только следует за кистью. Крутить предмет по ходу
## клипа нельзя (153) — пользователь: «зачем ты его крутишь». Пусто — прежний расчёт каждый кадр.
@export var calibrate := ""
## 195: в этих клипах предмет не заходит в своё тело: заранее, покадрово, плечо отводит руку наружу ровно настолько,
## чтобы до поверхности корпуса и ног оставалось body_clear (доля роста). Предмет относительно кисти не крутится.
@export var body_clear := 0.0
@export var clear_clips: Array = ["hurt"]
const CLEAR_MAX := deg_to_rad(40.0)
## Сдвиг щита вдоль его длинной оси, доля высоты щита (минус — к острию): кулак за умбоном (184).
@export var slide := 0.0
var _offset := Transform3D()
var _rigid := false
## 184: из какого клипа взять пальцы этой кисти для всех клипов — кулак на рукояти (в спокойных клипах рука раскрыта,
## рукоять шла по ладони, топор «висел рядом с кистью»). Пусто — пальцы клипов как есть.
@export var fingers_from := ""
@export var carry_tilt := 0.0
@export var carry_clips: Array = ["idle", "walk", "run", "fidget"]
var _carry := 0.0
const CARRY_BLEND := 6.0
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
	if fingers_from != "" and _unit and _unit.anim.has_animation(fingers_from):
		_hold_fingers()
	if calibrate != "" and _unit and _unit.anim.has_animation(calibrate):
		_calibrate()
	_process(0.0)
	if forward_limit > 0.0 and _unit:
		_bake_limit()
	if body_clear > 0.0 and _unit:
		_bake_clear()


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


func _hand_frame() -> Transform3D:
	var t := _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("mixamorig_" + hand + "Hand"))
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Положение предмета относительно кисти по эталонной позе — один раз.
func _calibrate() -> void:
	var anim := _unit.anim
	var was := anim.current_animation
	anim.play(calibrate)
	anim.seek(0.0, true)
	_skeleton.force_update_all_bone_transforms()
	_rigid = false
	_place()
	_offset = _hand_frame().affine_inverse() * _item.global_transform
	_rigid = true
	if was != "":
		anim.play(was)


func _process(_delta: float) -> void:
	if not is_instance_valid(_item):
		return
	if _rigid:
		_item.global_transform = _hand_frame() * _offset
		return
	_place()


## Расчёт положения по кисти и предплечью (для эталона и без калибровки).
func _place() -> void:
	var _delta := 0.0
	var height: float = _unit.height if _unit else 1.8
	var palm := _point(hand + "Hand").lerp(_point(hand + "HandMiddle1"), 0.75)
	var knuckles := (_point(hand + "HandIndex1") - _point(hand + "HandPinky1")).normalized()
	var fingers := (_point(hand + "HandMiddle1") - _point(hand + "Hand")).normalized()
	if mode == "forearm":
		var fore := (_point(hand + "Hand") - _point(hand + "ForeArm")).normalized()
		# Щит держат предплечьем поперёк: длинная ось — по линии костяшек (остриё вниз), лицо — поперёк
		# предплечья наружу (в защитной стойке — вперёд, к противнику). 189/«плашмя»: прежде длинная ось шла вдоль руки.
		var top := knuckles if hand == "Left" else -knuckles
		var face := top.cross(fore).normalized()
		if face.dot(palm - _point("Spine2")) < 0.0 and face.dot(_unit.model.global_basis.x if _unit else Vector3.RIGHT) < 0.0:
			face = -face
		top = (top - face * top.dot(face)).normalized()
		var guard := Basis(top.cross(face), top, face)
		# Рука висит (предплечье вниз): щит висит вдоль руки остриём вниз, лицом наружу от тела.
		var out := fore.cross(knuckles).normalized()
		if out.dot(palm - _point("Spine2")) < 0.0:
			out = -out
		var up := -fore
		var hang := Basis(up.cross(out), up, out)
		var hanging := smoothstep(0.4, 0.85, -fore.y)
		var basis := Basis(guard.get_rotation_quaternion().slerp(hang.get_rotation_quaternion(), hanging)).rotated(fore, 0.0)
		basis = basis.rotated(basis.z, deg_to_rad(roll))
		var size := Vector3(width, length, 1.0) * height
		var centre := palm + basis.z * 0.035 * height + basis.y * slide * size.y  # кулак за умбоном; изнанкой на руке
		# Модель (prepare_shield.py: высота 1, центр в нуле) — равномерно по высоте; заглушка — по ширине и высоте.
		var scale := Vector3.ONE * size.y if model != "" else Vector3(size.x, size.y, size.x)
		_item.global_transform = Transform3D(basis.scaled_local(scale), centre)
		return
	var axis := knuckles
	var edge := (fingers - axis * fingers.dot(axis)).normalized()  # костяшки — туда же лезвие
	var calm := carry_tilt != 0.0 and _unit != null and not _unit.in_stance and String(_unit.anim.current_animation) in carry_clips
	var want := 1.0 if calm else 0.0
	_carry = want if _delta <= 0.0 else lerpf(_carry, want, 1.0 - exp(-CARRY_BLEND * _delta))
	if _carry > 0.0:  # наклон рукояти к пальцам (вниз в опущенной руке) вокруг оси, поперечной ладони
		var side := axis.cross(edge).normalized()
		axis = axis.rotated(side, deg_to_rad(carry_tilt) * _carry)
		edge = edge.rotated(side, deg_to_rad(carry_tilt) * _carry)
	var basis := Basis(axis.cross(edge), axis, edge).rotated(axis, deg_to_rad(roll))
	var span := length * height
	_item.global_transform = Transform3D(basis.scaled_local(Vector3.ONE * span), palm - axis * span * grip_at)


## Пальцы кисти во всех клипах — поза первого кадра клипа fingers_from (тот же набор: хват оружия).
func _hold_fingers() -> void:
	var anim := _unit.anim
	var root_path := anim.get_node(anim.root_node).get_path_to(_skeleton)
	var source := anim.get_animation(fingers_from)
	var poses := {}
	for finger in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		for joint in [1, 2, 3]:
			var path := NodePath("%s:mixamorig_%sHand%s%d" % [root_path, hand, finger, joint])
			var t := source.find_track(path, Animation.TYPE_ROTATION_3D)
			if t >= 0:
				poses[path] = source.track_get_key_value(t, 0)
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		for path: NodePath in poses:
			var t := a.find_track(path, Animation.TYPE_ROTATION_3D)
			if t < 0:
				continue
			for k in a.track_get_key_count(t):
				var q: Quaternion = poses[path]
				if q.dot(a.track_get_key_value(t, k)) < 0.0:
					q = -q
				a.track_set_key_value(t, k, q)


var _samples := {}  # сетка -> до 400 её вершин (своих координат)


## Точки предмета в мире: вершины его сеток (до 400 на сетку), не углы рамки — у повёрнутого
## выпуклого щита в углах рамки пусто, граница по рамке врёт на 0,1–0,2 м.
func _item_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m: MeshInstance3D in _item.find_children("*", "MeshInstance3D", true, false):
		if not _samples.has(m):
			var verts := PackedVector3Array()
			for surface in m.mesh.get_surface_count():
				verts.append_array(m.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			var step := maxi(1, verts.size() / 400)
			var picked: Array[Vector3] = []
			for i in range(0, verts.size(), step):
				picked.append(verts[i])
			_samples[m] = picked
		for v: Vector3 in _samples[m]:
			out.append(m.global_transform * v)
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


func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0))


## Насколько точки предмета ближе всего к поверхности тела (минус — внутри): корпус и обе ноги капсулами.
func _clearance(points: Array, body: Array) -> float:
	var worst := INF
	for p: Vector3 in points:
		for c: Array in body:
			worst = minf(worst, _segment_distance(p, c[0], c[1]) - c[2])
	return worst


## 195: покадрово отвести руку наружу (вокруг оси «вперёд» у плеча), чтобы предмет не заходил в тело.
func _bake_clear() -> void:
	var anim := _unit.anim
	var arm := _skeleton.find_bone("mixamorig_" + hand + "Arm")
	var parent := _skeleton.get_bone_parent(arm)
	var k := _unit.height / 1.8
	var margin := body_clear * _unit.height
	var forward := _unit.model.global_basis.x.normalized()
	var to_sk := _skeleton.global_basis.inverse()
	var track_path := NodePath("%s:%s" % [anim.get_node(anim.root_node).get_path_to(_skeleton), _skeleton.get_bone_name(arm)])
	var bone := func(n: String) -> Vector3: return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("mixamorig_" + n))).origin
	var was := anim.current_animation
	for clip in clear_clips:
		if not anim.has_animation(clip):
			continue
		var a := anim.get_animation(clip)
		var t := a.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if t < 0:
			continue
		var frames := []
		for key in a.track_get_key_count(t):
			anim.play(clip)
			anim.seek(a.track_get_key_time(t, key), true)
			_skeleton.force_update_all_bone_transforms()
			_process(0.0)
			var body := [[bone.call("Hips"), bone.call("Spine2"), 0.14 * k], [bone.call("Spine2"), bone.call("Neck"), 0.13 * k],
				[bone.call("LeftUpLeg"), bone.call("LeftLeg"), 0.09 * k], [bone.call("RightUpLeg"), bone.call("RightLeg"), 0.09 * k],
				[bone.call("LeftLeg"), bone.call("LeftFoot"), 0.06 * k], [bone.call("RightLeg"), bone.call("RightFoot"), 0.06 * k]]
			frames.append([bone.call(hand + "Arm"), _item_points(), body,
				_skeleton.get_bone_global_pose(parent).basis.orthonormalized(), _skeleton.get_bone_global_pose(arm).basis.orthonormalized()])
		# Сторона отвода одна на весь клип: та, где предмет в сумме дальше от тела.
		var best_side := 1.0
		var best_sum := -INF
		for side in [1.0, -1.0]:
			var sum := 0.0
			for f: Array in frames:
				sum += _clearance(_turned(f[0], f[1], forward, side * 0.2), f[2])
			if sum > best_sum:
				best_sum = sum
				best_side = side
		var angles: Array[float] = []
		for f: Array in frames:
			var angle := 0.0
			if _clearance(f[1], f[2]) < margin:
				for step in 30:
					angle = CLEAR_MAX * (step + 1) / 30.0
					if _clearance(_turned(f[0], f[1], forward, best_side * angle), f[2]) >= margin:
						break
			angles.append(angle)
		var keys := angles.size()
		for key in keys:
			var peak := 0.0
			var sum := 0.0
			for j in range(maxi(0, key - SMOOTH), mini(keys, key + SMOOTH + 1)):
				sum += angles[j]
				peak = maxf(peak, angles[j])
			var angle: float = (sum / float(mini(keys, key + SMOOTH + 1) - maxi(0, key - SMOOTH)) + peak) * 0.5
			if angle <= 0.0:
				continue
			var turn_sk := Basis((to_sk * Basis(forward, best_side * angle) * to_sk.inverse()).get_rotation_quaternion())
			var q: Quaternion = (frames[key][3].inverse() * turn_sk * frames[key][4]).get_rotation_quaternion()
			var old: Quaternion = a.track_get_key_value(t, key)
			if q.dot(old) < 0.0:
				q = -q
			a.track_set_key_value(t, key, q)
	if was != "":
		anim.play(was)


func _turned(joint: Vector3, points: Array, axis: Vector3, angle: float) -> Array:
	var rot := Basis(axis, angle)
	return points.map(func(p): return joint + rot * (p - joint))


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
