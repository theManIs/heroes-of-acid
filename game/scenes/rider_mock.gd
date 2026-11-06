extends RefCounted
## Общие части макета всадника (задача 157): условный конь, разведённые бёдра, посадка в седло.

const RIDER := "res://assets/creatures/rider/body.glb"  # всадник (задача 163): своя модель Tripo, риг Mixamo
const ANIMS := "res://assets/creatures/rider/anims/"
const RIDER_SIZE := 1.9
const SADDLE := 1.55  # высота спины коня под всадника ростом около 2 м
const LEG_SPREAD := 28.0  # градусов: бёдра в стороны, чтобы обхватить коня
const LEG_AXIS := Vector3(1, 0, 0)  # ось разведения в пространстве скелета
## Сидячий набор Mixamo «бой в машине»: подпись и имя клипа. В витрине только заявленные
## действия; прочие пробы (тряска, взмахи, уклон) лежат в файлах, см. creatures/rider/README.md.
const CLIPS := [
	["Реакция: удар по голове", "ride_hurt"],
]
## Все собранные клипы, которые грузит макет.
const ALL_CLIPS := ["ride_still", "ride_idle", "ride_swing", "ride_swing_mirror", "ride_strike", "ride_block", "ride_dodge", "ride_hurt", "ride_death_pulled", "ride_death_crouch", "ride_fidget_look", "ride_fidget_yell",
	# Задача 158 — найденные кандидаты:
	"s_piloting", "s_driving", "s_sitting_and_pointing_mirror", "s_sitting_victory_mirror", "s_beckoning_mirror",
	"s_ducking", "s_sitting_dodges", "s_shoved", "s_knocked_unconscious"]


static func make_rider(parent: Node) -> Creature:
	var files: Array = []
	for clip in ALL_CLIPS:
		files.append(ANIMS + clip + ".glb")
	var rider := Creature.new()
	parent.add_child(rider)
	rider.setup(load(RIDER), files, "ride_swing", "ride_hurt", RIDER_SIZE, 0.0, "ride_still")
	spread_legs(rider, LEG_SPREAD)
	return rider


## Один постоянный разворот бёдер для всех клипов, как поворот молота в кисти.
static func spread_legs(rider: Creature, degrees: float) -> void:
	var anim := rider.anim
	var sk := rider.skeleton
	var root_path := anim.get_node(anim.root_node).get_path_to(sk)
	for side in [["mixamorig_LeftUpLeg", 1.0], ["mixamorig_RightUpLeg", -1.0]]:
		var index := sk.find_bone(side[0])
		var rest := sk.get_bone_global_rest(index).basis.get_rotation_quaternion()
		var turn := rest.inverse() * Quaternion(LEG_AXIS, deg_to_rad(degrees * side[1])) * rest
		var path := NodePath("%s:%s" % [root_path, side[0]])
		for clip_name in anim.get_animation_list():
			var a := anim.get_animation(clip_name)
			var t := a.find_track(path, Animation.TYPE_ROTATION_3D)
			for k in (a.track_get_key_count(t) if t >= 0 else 0):
				a.track_set_key_value(t, k, (a.track_get_key_value(t, k) * turn).normalized())


## Таз всадника на седло: сдвиг корня по текущей позе.
static func sit(rider: Creature) -> void:
	var hips: Vector3 = rider.to_local(rider.bone_world(rider.skeleton.find_bone("mixamorig_Hips")))
	rider.position = Vector3(-hips.x, SADDLE + 0.08 - hips.y, -hips.z)


## Условный конь: корпус, шея, голова, ноги и седло; смотрит по +X, как модели Tripo.
static func build_horse(parent: Node) -> Array[Node3D]:
	var legs: Array[Node3D] = []
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.22)
	var parts := [
		[Vector3(1.9, 0.7, 0.62), Vector3(0, SADDLE - 0.35, 0), 0.0],
		[Vector3(0.35, 0.9, 0.3), Vector3(1.05, SADDLE + 0.05, 0), -35.0],
		[Vector3(0.6, 0.3, 0.28), Vector3(1.4, SADDLE + 0.45, 0), 0.0],
	]
	for p in parts:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = p[0]
		m.mesh = box
		m.material_override = mat
		m.position = p[1]
		m.rotation_degrees.z = p[2]
		parent.add_child(m)
	for leg in [Vector3(0.75, 0, 0.2), Vector3(0.75, 0, -0.2), Vector3(-0.75, 0, 0.2), Vector3(-0.75, 0, -0.2)]:
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.07
		cyl.height = SADDLE - 0.7
		m.mesh = cyl
		m.material_override = mat
		var hip := Node3D.new()  # нога качается от бедра
		hip.position = leg + Vector3(0, SADDLE - 0.7, 0)
		parent.add_child(hip)
		m.position = Vector3(0, -(SADDLE - 0.7) * 0.5, 0)
		hip.add_child(m)
		legs.append(hip)
	var saddle := MeshInstance3D.new()
	var s := BoxMesh.new()
	s.size = Vector3(0.6, 0.06, 0.66)
	saddle.mesh = s
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.12, 0.08)
	saddle.material_override = smat
	saddle.position = Vector3(-0.1, SADDLE + 0.03, 0)
	parent.add_child(saddle)
	return legs


## Копьё всадника — модель Tripo (задача 162), `assets/creatures/rider/lance.glb`, длина 1 по оси Y:
## остриё в y = 0, торец в y = 1, рукоять за воронкой около y = 0,62. Направление задаёт всадник, не клип.
const LANCE_MODEL := "res://assets/creatures/rider/lance.glb"
const LANCE_LENGTH := 3.2
const LANCE_GRIP := 0.605  # доля длины от острия до руки: кулак на кожаной обмотке
const LANCE_BACK := LANCE_LENGTH * (1.0 - LANCE_GRIP)  # сколько копья за кистью
const LANCE_THICK := 0.55  # толщина модели относительно длины, иначе древко 20 см
const LANCE_DOWN := 0.16  # наклон остриём вниз: цель ниже седла


static func add_lance(parent: Node) -> Node3D:
	var lance: Node3D = load(LANCE_MODEL).instantiate()
	parent.add_child(lance)
	lance.top_level = true
	return lance


## Остриё копья в мире.
static func tip(lance: Node3D) -> Vector3:
	return lance.global_transform.origin


## Поставить копьё: forward — куда смотрит остриё, hand — точка хвата, slide — сдвиг вдоль древка.
static func set_lance(lance: Node3D, forward: Vector3, hand: Vector3, slide := 0.0) -> void:
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.BACK
	var along := -forward  # ось Y модели идёт от острия к торцу
	var basis := Basis(side * LANCE_LENGTH * LANCE_THICK, along * LANCE_LENGTH, side.cross(along).normalized() * LANCE_LENGTH * LANCE_THICK)
	lance.global_transform = Transform3D(basis, hand + forward * (LANCE_LENGTH * LANCE_GRIP + slide))


## pitch и yaw — раскачивание на весу, градусы: длинная палка качается при движении.
## slide — сдвиг копья вдоль древка (м): назад для замаха, вперёд для укола.
static func place_lance(lance: Node3D, rider: Creature, mount: Node3D, pitch := 0.0, yaw := 0.0, slide := 0.0) -> void:
	var hand: Vector3 = fist(rider)
	var local := Vector3(1.0, -LANCE_DOWN, 0.0).normalized()
	local = local.rotated(Vector3.BACK, deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
	var forward: Vector3 = (mount.global_basis.orthonormalized() * local).normalized()
	set_lance(lance, forward, hand, slide)


## Копьё в кисти для ударов сидя: идёт за кистью, как молот в хвате.
## Сначала calibrate_hand_lance на первом кадре: копьё вдоль коня, остриём вперёд.
static func hand_frame(rider: Creature, hand_bone := "mixamorig_RightHand") -> Basis:
	var sk := rider.skeleton
	var hand := sk.find_bone(hand_bone)
	return (sk.global_transform * sk.get_bone_global_pose(hand)).basis.orthonormalized()


static func calibrate_hand_lance(rider: Creature, mount: Node3D, hand_bone := "mixamorig_RightHand") -> Vector3:
	var forward: Vector3 = (mount.global_basis * Vector3(1.0, -LANCE_DOWN, 0.0)).normalized()
	return hand_frame(rider, hand_bone).inverse() * forward


## Остриё не уходит на другую сторону от коня: поперечная часть направления
## не меньше LANCE_OUT наружу от своей руки. Взмах остаётся сбоку, над головой коня не проходит.
const LANCE_OUT := 0.12


static func place_hand_lance(lance: Node3D, rider: Creature, local_dir: Vector3, hand_bone := "mixamorig_RightHand", mount: Node3D = null) -> void:
	var hand: Vector3 = rider.bone_world(rider.skeleton.find_bone(hand_bone))
	var forward := (hand_frame(rider, hand_bone) * local_dir).normalized()
	if mount != null:
		var out := 1.0 if hand_bone.contains("Right") else -1.0  # конь смотрит по +X: правая сторона — +Z
		var d: Vector3 = mount.global_basis.inverse() * forward
		if d.z * out < LANCE_OUT:
			d.z = LANCE_OUT * out
			forward = (mount.global_basis * d).normalized()
	set_lance(lance, forward, hand)


## Смягчить размах клипа один раз для всех кадров: повороты корпуса и рук
## тянутся к первому кадру. factor 1 — как в клипе, 0 — неподвижно.
const UPPER_BODY := ["Spine", "Spine1", "Spine2", "Neck", "Head", "RightShoulder", "RightArm", "RightForeArm",
	"RightHand", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"]


static func damp_clip(rider: Creature, clip: String, factor: float) -> void:
	var anim := rider.anim
	var root_path := anim.get_node(anim.root_node).get_path_to(rider.skeleton)
	var a := anim.get_animation(clip)
	for bone: String in UPPER_BODY:
		var t := a.find_track(NodePath("%s:mixamorig_%s" % [root_path, bone]), Animation.TYPE_ROTATION_3D)
		if t < 0 or a.track_get_key_count(t) == 0:
			continue
		var ref: Quaternion = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, ref.slerp(a.track_get_key_value(t, k), factor))


## Заморозить кости на позе первого кадра во всём клипе: рука с копьём не участвует в движении.
const RIGHT_ARM := ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]


static func freeze_bones(rider: Creature, clip: String, bones: Array) -> void:
	var anim := rider.anim
	var root_path := anim.get_node(anim.root_node).get_path_to(rider.skeleton)
	var a := anim.get_animation(clip)
	for bone: String in bones:
		var t := a.find_track(NodePath("%s:mixamorig_%s" % [root_path, bone]), Animation.TYPE_ROTATION_3D)
		if t < 0 or a.track_get_key_count(t) == 0:
			continue
		var first: Quaternion = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, first)


## Ноги в седле не участвуют в движении клипа, таз не сдвигается: всадник не подпрыгивает и не отъезжает.
const LEGS := ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]


## Посадка одна на все клипы — из спокойной стойки: тогда и переходы между клипами не дёргают ноги.
static func pin_seat(rider: Creature, clip: String, ref := "ride_still") -> void:
	pin_to(rider, clip, LEGS + ["Hips"], ref)


## Кости во всём клипе — в позе первого кадра клипа ref (по умолчанию спокойная стойка).
static func pin_to(rider: Creature, clip: String, bones: Array, ref := "ride_still") -> void:
	var anim := rider.anim
	var root_path := anim.get_node(anim.root_node).get_path_to(rider.skeleton)
	var a := anim.get_animation(clip)
	var r := anim.get_animation(ref)
	for bone: String in bones:
		var path := NodePath("%s:mixamorig_%s" % [root_path, bone])
		for kind in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
			var t := a.find_track(path, kind)
			var rt := r.find_track(path, kind)
			if t < 0 or rt < 0 or r.track_get_key_count(rt) == 0:
				continue
			var value: Variant = r.track_get_key_value(rt, 0)
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, value)


## Постоянно отвести руку с копьём от корпуса: поворот плеча в пространстве скелета, одинаково во всех клипах.
## out — вбок наружу (вокруг оси «вперёд»), up — вверх-вперёд (вокруг оси «вбок»).
static func arm_out(rider: Creature, clip: String, out: float, up: float, bone := "mixamorig_RightArm") -> void:
	var anim := rider.anim
	var sk := rider.skeleton
	var root_path := anim.get_node(anim.root_node).get_path_to(sk)
	var index := sk.find_bone(bone)
	var rest := sk.get_bone_global_rest(index).basis.get_rotation_quaternion()
	var around := Quaternion(Vector3(1, 0, 0), deg_to_rad(out)) * Quaternion(Vector3(0, 0, 1), deg_to_rad(up))
	var turn := rest.inverse() * around * rest
	var a := anim.get_animation(clip)
	var t := a.find_track(NodePath("%s:%s" % [root_path, bone]), Animation.TYPE_ROTATION_3D)
	for k in (a.track_get_key_count(t) if t >= 0 else 0):
		a.track_set_key_value(t, k, (a.track_get_key_value(t, k) * turn).normalized())


## Середина ладони: туда кладётся древко, чтобы кисть его обхватывала, а не проваливалась.
static func palm(rider: Creature, side := "Right") -> Vector3:
	var wrist: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_%sHand" % side))
	var middle: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_%sHandMiddle1" % side))
	return wrist.lerp(middle, 0.8)



## Поза кости в клипе на первом кадре, в пространстве скелета (родители — тоже по клипу или по покою).
static func _clip_global(rider: Creature, a: Animation, bone: int) -> Transform3D:
	var sk := rider.skeleton
	var root_path := rider.anim.get_node(rider.anim.root_node).get_path_to(sk)
	var path := NodePath("%s:%s" % [root_path, sk.get_bone_name(bone)])
	var local := sk.get_bone_rest(bone)
	var rt := a.find_track(path, Animation.TYPE_ROTATION_3D)
	if rt >= 0 and a.track_get_key_count(rt) > 0:
		local.basis = Basis(a.track_get_key_value(rt, 0)).scaled(local.basis.get_scale())
	var pt := a.find_track(path, Animation.TYPE_POSITION_3D)
	if pt >= 0 and a.track_get_key_count(pt) > 0:
		local.origin = a.track_get_key_value(pt, 0)
	var parent := sk.get_bone_parent(bone)
	return local if parent < 0 else _clip_global(rider, a, parent) * local


## Повернуть кость на turn (в пространстве скелета) во всех ключах клипа.
static func _turn_bone(rider: Creature, a: Animation, bone: int, turn: Quaternion) -> void:
	var sk := rider.skeleton
	var root_path := rider.anim.get_node(rider.anim.root_node).get_path_to(sk)
	var path := NodePath("%s:%s" % [root_path, sk.get_bone_name(bone)])
	var t := a.find_track(path, Animation.TYPE_ROTATION_3D)
	if t < 0:
		return
	var parent := _clip_global(rider, a, sk.get_bone_parent(bone)).basis.get_rotation_quaternion()
	var local_turn := parent.inverse() * turn * parent
	for k in a.track_get_key_count(t):
		a.track_set_key_value(t, k, (local_turn * a.track_get_key_value(t, k)).normalized())


const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## Кости кисти, которые держат древко: кисть и пальцы — их копируют во все клипы с копьём.
static func grip_bones(side := "Right") -> Array:
	var bones := ["%sHand" % side]
	for finger in FINGERS + ["Thumb"]:
		for i in [1, 2, 3]:
			bones.append("%sHand%s%d" % [side, finger, i])
	return bones


## Хват палки: кисть поворачивается так, чтобы линия костяшек шла вдоль древка (forward — в пространстве скелета),
## пальцы сгибаются вокруг него на curl градусов в каждом суставе.
static func grip_hand(rider: Creature, clip: String, forward: Vector3, curl: float, side := "Right") -> void:
	var sk := rider.skeleton
	var a := rider.anim.get_animation(clip)
	var bone := func(n: String) -> int: return sk.find_bone("mixamorig_%s%s" % [side, n])
	var at := func(n: String) -> Vector3: return _clip_global(rider, a, bone.call(n)).origin
	var hand: int = bone.call("Hand")
	var knuckles: Vector3 = (at.call("HandIndex1") - at.call("HandPinky1")).normalized()
	_turn_bone(rider, a, hand, Quaternion(knuckles, forward.normalized()))
	curl_fingers(rider, clip, curl, side)


## Кулак без поворота кисти: только пальцы согнуты на curl градусов в каждом суставе вокруг линии костяшек.
static func curl_fingers(rider: Creature, clip: String, curl: float, side := "Right") -> void:
	var sk := rider.skeleton
	var a := rider.anim.get_animation(clip)
	var bone := func(n: String) -> int: return sk.find_bone("mixamorig_%s%s" % [side, n])
	var at := func(n: String) -> Vector3: return _clip_global(rider, a, bone.call(n)).origin
	var axis: Vector3 = (at.call("HandIndex1") - at.call("HandPinky1")).normalized()
	# Знак сгиба: кончик среднего пальца должен идти к большому, то есть в ладонь.
	var tip: Vector3 = at.call("HandMiddle4") - at.call("HandMiddle1")
	var toward: Vector3 = at.call("HandThumb1") - at.call("HandMiddle1")
	var sign := 1.0 if (Quaternion(axis, 0.3) * tip).dot(toward) > tip.dot(toward) else -1.0
	for finger: String in FINGERS:
		for i in [1, 2, 3]:
			_turn_bone(rider, a, bone.call("Hand%s%d" % [finger, i]), Quaternion(axis, deg_to_rad(curl * sign)))


## Центр кулака: середина кольца среднего пальца — через него идёт ось древка.
static func fist(rider: Creature, side := "Right") -> Vector3:
	var sum := Vector3.ZERO
	for i in [1, 2, 3, 4]:
		sum += rider.bone_world(rider.skeleton.find_bone("mixamorig_%sHandMiddle%d" % [side, i]))
	return sum / 4.0


## Канал кулака в мире: от мизинца к указательному — так через кулак идёт палка, остриём вперёд.
static func fist_axis(rider: Creature, side := "Right") -> Vector3:
	var sk := rider.skeleton
	var index: Vector3 = rider.bone_world(sk.find_bone("mixamorig_%sHandIndex1" % side))
	var pinky: Vector3 = rider.bone_world(sk.find_bone("mixamorig_%sHandPinky1" % side))
	return (index - pinky).normalized()
