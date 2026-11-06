extends "res://scenes/showcase.gd"
## Витрина кисти всадника: только рыцарь, без коня и копья. Поза стойки с хватом, как в витрине пары.
## Запуск: godot --path game res://scenes/rider_hand.tscn

const MOCK := preload("res://scenes/rider_mock.gd")
const PAIR := preload("res://scenes/rider_pair.gd")
## Подпись, откуда смотрит камера (от кулака), ширина кадра в метрах; пустое направление — весь рыцарь.
const VIEWS := [
	["Рыцарь целиком", Vector3.ZERO, 0.0],
	["Кисть сбоку (снаружи)", Vector3(0.0, 0.15, 1.0), 0.35],
	["Кисть сверху", Vector3(0.05, 1.0, 0.15), 0.35],
	["Кисть спереди", Vector3(1.0, 0.15, 0.1), 0.35],
]


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
	MOCK.arm_out(rider, "ride_still", PAIR.ARM_OUT, PAIR.ARM_UP)
	var to_skeleton := (rider.global_basis.orthonormalized().inverse() * rider.skeleton.global_basis.orthonormalized()).inverse()
	var forward := Vector3(1.0, -MOCK.LANCE_DOWN, 0.0).rotated(Vector3.UP, deg_to_rad(PAIR.LANCE_YAW))
	MOCK.grip_hand(rider, "ride_still", to_skeleton * forward, PAIR.GRIP_CURL)
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.anim.play("ride_still", 0.0)
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
