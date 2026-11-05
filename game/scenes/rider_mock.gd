extends RefCounted
## Общие части макета всадника (задача 157): условный конь, разведённые бёдра, посадка в седло.

const RIDER := "res://assets/creatures/hammerer/body.glb"  # макет: тело молотобойца без молота
const ANIMS := "res://assets/creatures/rider/anims/"
const RIDER_SIZE := 1.9
const SADDLE := 1.55  # высота спины коня под всадника ростом около 2 м
const LEG_SPREAD := 28.0  # градусов: бёдра в стороны, чтобы обхватить коня
const LEG_AXIS := Vector3(1, 0, 0)  # ось разведения в пространстве скелета
## Сидячий набор Mixamo «бой в машине»: подпись и имя клипа.
const CLIPS := [
	["Стойка: сидит спокойно", "ride_still"], ["Стойка: трясёт на кочках", "ride_idle"],
	["Удар: взмах сидя", "ride_swing"], ["Удар: взмах сидя, зеркально", "ride_swing_mirror"],
	["Удар: сбить врага трубой", "ride_strike"],
	["Защита: блок сверху", "ride_block"], ["Уклон вправо", "ride_dodge"],
	["Реакция: удар по голове", "ride_hurt"],
]


static func make_rider(parent: Node) -> Creature:
	var files: Array = []
	for clip in CLIPS:
		files.append(ANIMS + clip[1] + ".glb")
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


## Палка вместо копья: лежит под правой рукой остриём вперёд, вдоль коня.
## Держится за кисть, но направление задаёт конь, а не клип: копьё не крутится в руке.
const LANCE_LENGTH := 3.2
const LANCE_BACK := 0.9  # сколько палки остаётся за кистью
const LANCE_DOWN := 0.16  # наклон остриём вниз: цель ниже седла


static func add_lance(parent: Node) -> MeshInstance3D:
	var lance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.035
	cyl.height = LANCE_LENGTH
	lance.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.5, 0.33)
	lance.material_override = mat
	parent.add_child(lance)
	lance.top_level = true
	return lance


## pitch и yaw — раскачивание на весу, градусы: длинная палка качается при движении.
static func place_lance(lance: MeshInstance3D, rider: Creature, mount: Node3D, pitch := 0.0, yaw := 0.0) -> void:
	var hand: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_RightHand"))
	var local := Vector3(1.0, -LANCE_DOWN, 0.0).normalized()
	local = local.rotated(Vector3.BACK, deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
	var forward: Vector3 = (mount.global_basis * local).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	# Цилиндр Godot вытянут по Y: ось копья — Y, базис правый (z = x × y).
	lance.global_transform = Transform3D(Basis(side, forward, side.cross(forward)), hand + forward * (LANCE_LENGTH * 0.5 - LANCE_BACK))


## Копьё в кисти для ударов сидя: идёт за кистью, как молот в хвате.
## Сначала calibrate_hand_lance на первом кадре: копьё вдоль коня, остриём вперёд.
static func hand_frame(rider: Creature, hand_bone := "mixamorig_RightHand") -> Basis:
	var sk := rider.skeleton
	var hand := sk.find_bone(hand_bone)
	return (sk.global_transform * sk.get_bone_global_pose(hand)).basis.orthonormalized()


static func calibrate_hand_lance(rider: Creature, mount: Node3D, hand_bone := "mixamorig_RightHand") -> Vector3:
	var forward: Vector3 = (mount.global_basis * Vector3(1.0, -LANCE_DOWN, 0.0)).normalized()
	return hand_frame(rider, hand_bone).inverse() * forward


static func place_hand_lance(lance: MeshInstance3D, rider: Creature, local_dir: Vector3, hand_bone := "mixamorig_RightHand") -> void:
	var hand: Vector3 = rider.bone_world(rider.skeleton.find_bone(hand_bone))
	var forward := (hand_frame(rider, hand_bone) * local_dir).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.BACK
	lance.global_transform = Transform3D(Basis(side, forward, side.cross(forward)), hand + forward * (LANCE_LENGTH * 0.5 - LANCE_BACK))


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

