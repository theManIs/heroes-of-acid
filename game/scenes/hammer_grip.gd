extends Node3D
## A rigid pole through both palm centers; animation supplies the two-handed grip.
## Added after Creature.setup fits the body, so the weapon cannot change body scale.

var _skeleton: Skeleton3D
var _weapon: Node3D
var _unit: Creature
var _previous_axis := Vector3.UP
var _right_grip := Basis.IDENTITY
var _calibrated := false
const AREA_ANIM := "attack"  # удар по площади
const AREA_BLEND := 0.15  # доля клипа на вход и выход из ориентации бойка
const FACE_MIN_SPEED := 1.0  # м/с поперёк рукояти, ниже — направление не обновлять
const FACE_FOLLOW := 18.0  # как быстро боёк догоняет направление взмаха
var _head_prev := Vector3.ZERO
var _head_seen := false
var _face := Vector3.ZERO


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
	var length_now := 1.5 * _unit.height / 1.9
	frame = _face_target(frame, axis, right + axis * length_now * 0.75, delta)
	# When the death clip opens the hands, retain the rigid attachment to the
	# right hand; the left hand is free to leave the shaft naturally.
	var release := smoothstep(0.38 * _unit.height / 1.9, 0.55 * _unit.height / 1.9, right.distance_to(left))
	frame = Basis(frame.get_rotation_quaternion().slerp((hand_frame * _right_grip).get_rotation_quaternion(), release))
	axis = frame.y
	var length := 1.5 * _unit.height / 1.9
	_weapon.global_transform = Transform3D(frame.scaled(Vector3.ONE * length), right - axis * length * 0.20)


## В ударе по площади боёк (локальная −Z молота, напротив клюва) смотрит туда,
## куда летит головка: перпендикулярно рукояти по ходу взмаха. Так в момент удара
## молот бьёт бойком по цели, а не боком. На медленных участках держит прежнее.
func _face_target(frame: Basis, axis: Vector3, head: Vector3, delta: float) -> Basis:
	var moving := _head_seen and delta > 0.0
	var velocity := (head - _head_prev) / delta if moving else Vector3.ZERO
	_head_prev = head
	_head_seen = true
	if _unit.anim.current_animation != AREA_ANIM:
		_face = Vector3.ZERO
		return frame
	var across := velocity - axis * velocity.dot(axis)
	if across.length() > FACE_MIN_SPEED * _unit.height / 1.9:
		var target := across.normalized()
		_face = target if _face == Vector3.ZERO else _face.slerp(target, minf(1.0, FACE_FOLLOW * delta)).normalized()
	if _face == Vector3.ZERO:
		return frame
	_face = (_face - axis * _face.dot(axis)).normalized()
	var length := _unit.anim.current_animation_length
	var t := _unit.anim.current_animation_position / maxf(length, 0.001)
	var weight := smoothstep(0.0, AREA_BLEND, t) * (1.0 - smoothstep(1.0 - AREA_BLEND, 1.0, t))
	var z := -_face
	var strike := Basis(axis.cross(z).normalized(), axis, z)
	return Basis(frame.get_rotation_quaternion().slerp(strike.get_rotation_quaternion(), weight))
