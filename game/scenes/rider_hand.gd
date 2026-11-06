extends "res://scenes/showcase.gd"
## Витрина кисти всадника: только рыцарь, без коня и копья. Рука как в витрине пары, пальцы в кулак,
## палка идёт по кулаку; в каждом квадрате кулак повёрнут «как при выливании воды» на свой угол.
## Запуск: godot --path game res://scenes/rider_hand.tscn

const MOCK := preload("res://scenes/rider_mock.gd")
const PAIR := preload("res://scenes/rider_pair.gd")
const POURS := [-60.0, -70.0, -80.0]  # кандидаты: остриё 6°, 10°, 13° вниз (замер)
const LOOK := Vector3(0.35, 0.25, 1.0)  # камера снаружи справа, чуть спереди и сверху
const WIDTH := 0.8  # ширина кадра у кулака, метров
const STICK_RADIUS := 0.02  # палка в кулаке вместо копья: видно, как её держит кисть
const STICK_LENGTH := 1.6
var _sticks: Array = []


func _ready() -> void:
	columns = 3
	cell_size = 520
	var grid := _build_page()
	for angle: float in POURS:
		_make_hand_cell(grid, angle)
	_finish()


func _make_hand_cell(grid: GridContainer, angle: float) -> void:
	var cell := _make_frame(grid, MOCK.RIDER_SIZE)
	_make_label(cell.frame).text = "Поворот %d°" % int(angle)
	preload("res://scenes/metal_lighting.gd").apply(cell.view)  # как в витрине пары
	var rider := MOCK.make_rider(cell.view)
	MOCK.freeze_bones(rider, "ride_still", MOCK.RIGHT_ARM)
	MOCK.arm_out(rider, "ride_still", PAIR.ARM_OUT, PAIR.ARM_UP)  # рука как в витрине пары
	MOCK.pour(rider, "ride_still", angle)
	MOCK.curl_fingers(rider, "ride_still", PAIR.GRIP_CURL)
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
	_aim.call_deferred(cell.view, rider)


## Камера на кулак: ждём, пока поза применится.
func _aim(view: SubViewport, rider: Creature) -> void:
	for i in 3:
		await get_tree().process_frame
	var focus := MOCK.fist(rider)
	var camera: Camera3D = view.find_children("*", "Camera3D", true, false)[0]
	camera.near = 0.02
	var distance := WIDTH * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(focus + LOOK.normalized() * distance, focus)


## Палка идёт за кулаком: центр — в кулаке, ось — канал кулака (кисть ведёт палку, а не наоборот).
func _process(delta: float) -> void:
	super._process(delta)
	for pair: Array in _sticks:
		var stick: MeshInstance3D = pair[0]
		var axis := MOCK.fist_axis(pair[1])
		var side := axis.cross(Vector3.UP).normalized()
		stick.global_transform = Transform3D(Basis(side, axis, side.cross(axis)), MOCK.fist(pair[1]))
