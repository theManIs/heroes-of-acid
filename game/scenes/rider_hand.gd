extends "res://scenes/showcase.gd"
## Витрина кисти всадника: только рыцарь, без коня и копья. Кисть как в клипе, пальцы в кулак, палка по каналу кулака.
## Запуск: godot --path game res://scenes/rider_hand.tscn

const MOCK := preload("res://scenes/rider_mock.gd")
const PAIR := preload("res://scenes/rider_pair.gd")
## Подпись, откуда смотрит камера (от кулака), ширина кадра в метрах; пустое направление — весь рыцарь.
const VIEWS := [
	["Рыцарь целиком", Vector3.ZERO, 0.0],
	["Кисть снаружи", Vector3(0.0, 0.15, 1.0), 0.6],
	["Кисть сверху снаружи", Vector3(0.1, 1.0, 0.8), 0.6],
	["Кисть спереди снаружи", Vector3(1.0, 0.2, 0.7), 0.6],
]


const STICK_RADIUS := 0.02  # палка в кулаке вместо копья: видно, как её держит кисть
const STICK_LENGTH := 1.0
## Направления в осях всадника: +X вперёд, +Y вверх, +Z — его правый бок.
const ARM_DIR := Vector3(-0.1, -1.0, 0.75)  # плечо вниз вдоль бока, локоть чуть назад и наружу
const FOREARM_DIR := Vector3(1.0, 0.1, 0.3)  # предплечье вперёд почти горизонтально: кулак над коленом
const LANCE_DIR := Vector3(1.0, -0.15, 0.15)  # остриё вперёд и чуть вниз: колоть, а не как удочка
const WRIST_LIMIT := 30.0  # запястье к мизинцу не больше, градусов
var _sticks: Array = []


func _ready() -> void:
	columns = 2
	cell_size = 460
	var grid := _build_page()
	for v: Array in VIEWS:
		_make_hand_cell(grid, v[0], v[1], v[2])
	_finish()


func _make_hand_cell(grid: GridContainer, title: String, from: Vector3, width: float) -> void:
	var cell := _make_frame(grid, MOCK.RIDER_SIZE)
	_make_label(cell.frame).text = title
	preload("res://scenes/metal_lighting.gd").apply(cell.view)  # как в витрине пары
	var rider := MOCK.make_rider(cell.view)
	MOCK.freeze_bones(rider, "ride_still", MOCK.RIGHT_ARM)
	# Копьё вдоль тела: плечо вниз вдоль бока, предплечье чуть вперёд, кулак большим пальцем вперёд.
	var to_skeleton := (rider.global_basis.orthonormalized().inverse() * rider.skeleton.global_basis.orthonormalized()).inverse()
	MOCK.aim_bone(rider, "ride_still", "RightArm", "RightForeArm", to_skeleton * ARM_DIR)
	MOCK.aim_bone(rider, "ride_still", "RightForeArm", "RightHand", to_skeleton * FOREARM_DIR)
	MOCK.roll_fist(rider, "ride_still", to_skeleton * LANCE_DIR)
	MOCK.bend_wrist(rider, "ride_still", to_skeleton * LANCE_DIR, WRIST_LIMIT)
	MOCK.curl_fingers(rider, "ride_still", PAIR.GRIP_CURL)  # кисть как в клипе, согнуты только пальцы
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.anim.play("ride_still", 0.0)
	var stick := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = STICK_RADIUS
	mesh.bottom_radius = STICK_RADIUS
	mesh.height = STICK_LENGTH
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.55, 0.35, 0.18)
	mesh.material = paint
	stick.mesh = mesh
	cell.view.add_child(stick)
	_sticks.append([stick, rider])
	if width > 0.0:
		_aim.call_deferred(cell.view, rider, from, width)


## Камера на кулак: ждём, пока поза применится, и ставим её по направлению from.
func _aim(view: SubViewport, rider: Creature, from: Vector3, width: float) -> void:
	for i in 3:
		await get_tree().process_frame
	var focus := MOCK.fist(rider)
	var camera: Camera3D = view.find_children("*", "Camera3D", true, false)[0]
	camera.near = 0.02
	var distance := width * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(focus + from.normalized() * distance, focus)


## Палка идёт за кулаком: центр — в кулаке, ось — канал кулака.
func _process(delta: float) -> void:
	super._process(delta)
	for pair: Array in _sticks:
		var stick: MeshInstance3D = pair[0]
		var axis := MOCK.fist_axis(pair[1])
		var side := axis.cross(Vector3.UP).normalized()
		stick.global_transform = Transform3D(Basis(side, axis, side.cross(axis)), MOCK.fist(pair[1]))
