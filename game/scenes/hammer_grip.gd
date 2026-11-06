extends Node3D
## A rigid pole through both palm centers; animation supplies the two-handed grip.
## Added after Creature.setup fits the body, so the weapon cannot change body scale.

var _skeleton: Skeleton3D
var _weapon: Node3D
var _unit: Creature
var _previous_axis := Vector3.UP
var _right_grip := Basis.IDENTITY
var _calibrated := false
## Постоянный поворот молота в кисти вокруг рукояти. 171: плоский боёк (локальная −Z, напротив клюва)
## смотрит от владельца — замер в стойке: −97° от прежних 59°. Крутить молот по ходу клипа нельзя (153, 167).
const HEAD_ROLL := deg_to_rad(-38.0)
## Где на рукояти правая кисть, доля длины от навершия. 0,2 — хват меча, руки рядом у навершия.
## Хват по листу (задача 167): руки врозь ближе к середине рукояти — 0,62.
var right_at := 0.62
## Клипы, в которых молот жёстко в правой кисти, как в стойке (калибровка — первый кадр):
## руки в клипе свои, молот не перекладывается под них. Переход — плавно.
var rigid_clips: Array = ["attack_point"]  # прежний удар сверху: руки клипа под хват меча
var _rigid := 0.0
const RIGID_BLEND := 8.0


func _ready() -> void:
	process_priority = 20
	call_deferred("_attach")


func _attach() -> void:
	_skeleton = get_parent().find_children("*", "Skeleton3D", true, false)[0]
	_unit = get_parent().get_parent() as Creature
	_weapon = preload("res://assets/creatures/hammerer/hammer.glb").instantiate()
	add_child(_weapon)
	_weapon.top_level = true
	_process(0.0)


func _bone(suffix: String) -> int:
	return _skeleton.find_bone("mixamorig_" + suffix)


func _point(suffix: String) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone(suffix))).origin


func _palm(side: String) -> Vector3:
	return _point(side + "Hand").lerp(_point(side + "HandMiddle1"), 0.75)


func _process(delta: float) -> void:
	if not is_instance_valid(_weapon):
		return
	var want_rigid := 1.0 if String(_unit.anim.current_animation) in rigid_clips else 0.0
	_rigid = lerpf(_rigid, want_rigid, 1.0 - exp(-RIGID_BLEND * delta))
	var right := _palm("Right")
	var left := _palm("Left")
	var axis := (right - left).normalized()
	if right.distance_to(left) < 0.035:
		axis = _previous_axis
	_previous_axis = axis
	# The hammer head lies in the palm's longitudinal plane, without spinning
	# around the shaft when both hands pass through a vertical pose.
	var knuckles := _point("RightHandIndex1") - _point("RightHandPinky1")
	var normal := axis.cross(knuckles).normalized()
	if normal.length_squared() < 0.1:
		normal = axis.cross(Vector3.FORWARD).normalized()
	var across := axis.cross(normal).normalized()
	var frame := Basis(across, axis, normal)
	var hand_frame := (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone("RightHand"))).basis.orthonormalized()
	if not _calibrated:
		_right_grip = hand_frame.inverse() * frame
		_calibrated = true
	# When the death clip opens the hands, retain the rigid attachment to the
	# right hand; the left hand is free to leave the shaft naturally.
	var release := maxf(_rigid, smoothstep(0.38 * _unit.height / 1.9, 0.55 * _unit.height / 1.9, right.distance_to(left)))
	frame = Basis(frame.get_rotation_quaternion().slerp((hand_frame * _right_grip).get_rotation_quaternion(), release))
	frame = frame * Basis(Vector3.UP, HEAD_ROLL)
	axis = frame.y
	var length := 1.5 * _unit.height / 1.9
	_weapon.global_transform = Transform3D(frame.scaled(Vector3.ONE * length), right - axis * length * right_at)
