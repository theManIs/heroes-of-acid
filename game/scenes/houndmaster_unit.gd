extends Creature
## Один отряд, три клетки и одно здоровье. Сначала проходит собака,
## затем псарь; фигура занятых клеток не вращается вместе с моделями.
const DOG_SCENE := preload("res://assets/creatures/hound/hound.glb")
const DOG_IDLE := "idle_breathe"
const DOG_HEIGHT := 1.05
const COMMAND_LEAD := 0.85
const BITE_IMPACT := 0.45
enum MovePhase { NONE, DOG, MASTER, RAID_HOLD, RAID_OUT, RAID_BACK }
signal dog_route_finished

var _dog := Node3D.new()
var _dog_model: Node3D
var _dog_anim: AnimationPlayer
var _dog_yaw := PI / 2.0
var _epoch := 0
var _escape: Tween
var _bite: Tween
var _escaping := false
var _dog_offset := Vector3(0, 0, 0.9)  # середина двух нижних гексов радиуса 0,6
var _move_phase := MovePhase.NONE
var _dog_route: Array[Vector3] = []
var _master_route: Array[Vector3] = []


func setup(scene: PackedScene, extra_anims: Array = [], attack := "slash", hurt := "", size := 2.0, attack_start := 0.0, idle := "idle") -> void:
	super.setup(scene, extra_anims, attack, hurt, size, attack_start, idle)
	add_child(_dog)
	_dog.top_level = true
	_dog_model = DOG_SCENE.instantiate()
	_dog.add_child(_dog_model)
	var box: AABB = _dog_model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	var fit := DOG_HEIGHT / box.size.y
	_dog_model.scale = Vector3.ONE * fit
	_dog_model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	_dog_anim = _dog_model.find_child("AnimationPlayer", true, false)
	for clip in [DOG_IDLE, "walk", "run"]:
		_dog_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_dog_anim.animation_finished.connect(func(_clip: StringName):
		if not dead:
			_dog_play(DOG_IDLE))
	_dog_play(DOG_IDLE)
	_dog.global_position = global_position + _dog_offset


func face(point: Vector3) -> void:
	super.face(point)
	# Только в стойке: при проходе маршрута собака смотрит вдоль своего шага.
	_dog_yaw = PI / 2.0 if point.x >= position.x else -PI / 2.0


func walk_path(points: Array[Vector3]) -> void:
	if dead:
		return
	if points.is_empty():
		arrived.emit()
		return
	_strike_id += 1
	walking = false
	_path.clear()
	_master_route = points.duplicate()
	_dog_route.clear()
	for point in points:
		_dog_route.append((get_parent() as Node3D).to_global(point) + _dog_offset)
	_move_phase = MovePhase.DOG
	_play("idle")
	_dog_play(DOG_IDLE)


func _physics_process(delta: float) -> void:
	if _move_phase in [MovePhase.DOG, MovePhase.RAID_OUT, MovePhase.RAID_BACK]:
		var to := _dog_route[0] - _dog.global_position
		to.y = 0.0
		if to.length() < 0.02:
			_dog.global_position = _dog_route.pop_front()
			if _dog_route.is_empty():
				_dog_play(DOG_IDLE)
				if _move_phase == MovePhase.DOG:
					_move_phase = MovePhase.MASTER
					# Сигнал arrived придёт от базового движения только после псаря.
					super.walk_path(_master_route)
				else:
					_move_phase = MovePhase.RAID_HOLD
					dog_route_finished.emit()
			return
		var heading := atan2(to.x, to.z)
		_dog.rotation.y = rotate_toward(_dog.rotation.y, heading, TURN_SPEED * delta)
		if absf(wrapf(heading - _dog.rotation.y, -PI, PI)) > 0.04:
			# На повороте стоит, а не скользит боком с играющей ходьбой.
			_dog_play(DOG_IDLE)
			return
		var running := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
		_dog_play("run" if running else "walk", walk_rate)
		var speed := walk_speed * walk_rate * (2.0 if running else 1.0)
		_dog.global_position += to.normalized() * minf(speed * delta, to.length())
		return
	super._physics_process(delta)
	if _move_phase == MovePhase.MASTER and not walking:
		_move_phase = MovePhase.NONE
		_master_route.clear()


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_dog_anim):
		return
	if _move_phase == MovePhase.NONE and not _escaping and not is_instance_valid(_bite):
		_dog.global_position = global_position + _dog_offset
		_dog.rotation.y = lerp_angle(_dog.rotation.y, _dog_yaw, minf(1.0, TURN_SPEED * delta))


func _dog_play(clip: String, speed := 1.0) -> void:
	_dog_anim.speed_scale = speed
	if _dog_anim.current_animation != clip:
		_dog_anim.play(clip, 0.2)


func hit_delay() -> float:
	return COMMAND_LEAD + BITE_IMPACT


func strike(target: Creature, _distance: float, _overlap: float) -> void:
	# Совместимость с интерфейсом Creature для атаки уже стоящего рядом врага.
	raid(target, [] as Array[Vector3], target.position)


## Полная вылазка: команда, путь собаки, укус и обратный путь. Корень не двигается.
## points и contact заданы в координатах родителя, как у walk_path.
func raid(target: Creature, points: Array[Vector3], contact: Vector3) -> void:
	if dead:
		return
	var epoch := _epoch
	var home := _dog.global_position
	var outbound: Array[Vector3] = []
	for point in points:
		outbound.append((get_parent() as Node3D).to_global(point) + _dog_offset)
	_move_phase = MovePhase.RAID_HOLD
	walking = false
	_path.clear()
	face(target.position)
	target.face(position)
	play_once(attack_anim)
	_dog_play(DOG_IDLE)
	await get_tree().create_timer(COMMAND_LEAD).timeout
	if epoch != _epoch or dead or not is_instance_valid(target):
		return
	if not outbound.is_empty():
		_dog_route = outbound.duplicate()
		_move_phase = MovePhase.RAID_OUT
		await dog_route_finished
		if epoch != _epoch or dead or not is_instance_valid(target):
			return
	var launch := _dog.global_position
	var goal := (get_parent() as Node3D).to_global(contact)
	var direction := (goal - launch).normalized()
	var turn := wrapf(atan2(direction.x, direction.z) - _dog.rotation.y, -PI, PI)
	var turn_time := maxf(0.01, absf(turn) / TURN_SPEED)
	_bite = create_tween()
	_bite.tween_property(_dog, "rotation:y", _dog.rotation.y + turn, turn_time)
	await get_tree().create_timer(turn_time).timeout
	if epoch != _epoch or dead or not is_instance_valid(target):
		return
	_dog_play("bite_lunge")
	# Удар засчитывается у цели при контакте, после пробежки, а не при команде.
	target.take_hit(BITE_IMPACT)
	var reaction_end := Time.get_ticks_msec() + int((BITE_IMPACT + 1.5) * 1000.0)
	_bite = create_tween()
	_bite.tween_property(_dog, "global_position", launch + direction * maxf(0.0, launch.distance_to(goal) - 0.85), BITE_IMPACT).set_trans(Tween.TRANS_SINE)
	_bite.tween_property(_dog, "global_position", launch, 0.65).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(BITE_IMPACT + 0.65).timeout
	if epoch != _epoch or dead:
		return
	if is_instance_valid(_bite):
		_bite.kill()
	_bite = null
	_dog.global_position = launch
	_dog_play(DOG_IDLE)
	if not outbound.is_empty():
		_dog_route = outbound.duplicate()
		_dog_route.reverse()
		_dog_route.pop_front()  # уже стоим у конца маршрута после выпада
		_dog_route.append(home)
		_move_phase = MovePhase.RAID_BACK
		await dog_route_finished
		if epoch != _epoch or dead:
			return
	var recover := float(reaction_end - Time.get_ticks_msec()) / 1000.0
	if recover > 0.0:
		await get_tree().create_timer(recover).timeout
		if epoch != _epoch or dead:
			return
	_dog.global_position = home
	_move_phase = MovePhase.NONE
	_dog_play(DOG_IDLE)


func play_once(clip: String) -> void:
	super.play_once(clip)
	if is_instance_valid(_dog_anim) and not dead:
		if clip == hurt_anim:
			_dog_play("hurt_head_left")
		elif clip == defend_anim:
			_dog_play("defend_lower_head")


func take_hit(delay: float) -> void:
	if not can_be_hit():
		return
	var epoch := _epoch
	var blocked := defending
	if not blocked:
		hits += 1
	var fatal := hits >= HITS_TO_KILL
	await get_tree().create_timer(maxf(0.01, delay - defend_lead) if blocked else delay).timeout
	if epoch != _epoch or dead:
		return
	walking = false
	if fatal:
		die()
	else:
		play_once(defend_anim if blocked else hurt_anim)


func die() -> void:
	if dead:
		return
	_epoch += 1
	var cancel_route := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
	_move_phase = MovePhase.NONE
	_dog_route.clear()
	_master_route.clear()
	super.die()
	_escaping = true
	if is_instance_valid(_bite):
		_bite.kill()
		_bite = null
	var away := Vector3(-1 if sin(_dog_yaw) > 0.0 else 1, 0, 0.35).normalized()
	_escape = create_tween()
	_escape.tween_interval(0.55)
	_escape.tween_property(_dog, "rotation:y", _dog.rotation.y + wrapf(atan2(away.x, away.z) - _dog.rotation.y, -PI, PI), 0.35)
	_escape.tween_callback(_dog_play.bind("run"))
	_escape.tween_property(_dog, "global_position", _dog.global_position + away * 12.0, 2.5)
	_escape.tween_callback(_dog.hide)
	if cancel_route:
		dog_route_finished.emit()


func revive() -> void:
	_epoch += 1
	_strike_id += 1
	var cancel_route := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
	_move_phase = MovePhase.NONE
	_dog_route.clear()
	_master_route.clear()
	if cancel_route:
		dog_route_finished.emit()
	walking = false
	_path.clear()
	for tween in [_escape, _bite]:
		if is_instance_valid(tween):
			tween.kill()
	_escape = null
	_bite = null
	_escaping = false
	defending = false
	super.revive()
	dead = false
	model.position = _model_base
	model.rotation.z = 0.0
	anim.play("idle", 0.2)
	_dog.show()
	_dog.global_position = global_position + _dog_offset
	_dog_play(DOG_IDLE)


func set_outline(color: Variant) -> void:
	super.set_outline(color)
	if not is_instance_valid(_dog_model):
		return
	for mesh: MeshInstance3D in _dog_model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			if color == null:
				mesh.set_surface_override_material(i, null)
			else:
				var mat := mesh.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
				mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
				mat.stencil_color = color
				# У донора Armature имеет масштаб 100: контур считается
				# в пространстве mesh, учитываем всю цепочку узлов.
				mat.stencil_outline_thickness = OUTLINE_WIDTH / mesh.global_basis.get_scale().x
				mesh.set_surface_override_material(i, mat)
