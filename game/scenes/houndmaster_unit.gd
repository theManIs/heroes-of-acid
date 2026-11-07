extends Creature
## Один отряд, три клетки и одно здоровье. Сначала проходит собака,
## затем псарь; фигура занятых клеток не вращается вместе с моделями.
const DOG_SCENE := preload("res://assets/creatures/hound/hound.glb")
const DOG_IDLE := "idle_breathe"
const DOG_DEFEND_FROM := 0.8  # с; в клипе голова уходит вниз с 0,6 до 1,2 с из 4
const DOG_FIDGET := "fidget_sniff_ground"  # свой отклик собаки, без касания псаря
const DOG_HEIGHT := 1.2833  # 177: при псаре 1,8 собака 1,155 — +10 % к прежним 1,05
const BITE_IMPACT := 0.45
const BITE_STEP := 0.08  # короткий шаг корпуса, основной выпад уже есть в клипе
const BITE_GAP := 0.04
const UP_TILT := deg_to_rad(35.0)  # противник сверху: морда мимо своего псаря
const RAID_RUN_FROM := 2  # гексов: больше половины хода пары (3); ближе — шагом
const FEET: Array[String] = ["FF.L", "FF.R", "FFB.L", "FFB.R"]
enum MovePhase { NONE, DOG, MASTER, RAID_HOLD, RAID_OUT, RAID_BACK }
signal dog_route_finished
signal raid_impact

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
var _bite_reach := 1.0
var _raid_clip := "run"
var _gait_speed := {}  # клип -> метры в секунду при скорости клипа 1


func setup(scene: PackedScene, extra_anims: Array = [], attack := "slash", hurt := "", size := 2.0, attack_start := 0.0, idle := "idle") -> void:
	super.setup(scene, extra_anims, attack, hurt, size, attack_start, idle)
	add_child(_dog)
	_dog.top_level = true
	_dog_model = DOG_SCENE.instantiate()
	_dog.add_child(_dog_model)
	var box: AABB = _dog_model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	var fit := DOG_HEIGHT * (size / 2.0) / box.size.y
	_dog_model.scale = Vector3.ONE * fit
	_dog_model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	_dog_anim = _dog_model.find_child("AnimationPlayer", true, false)
	_measure_bite_reach(box)
	_gait_speed = {"walk": _measure_gait("walk"), "run": _measure_gait("run")}
	for clip in [DOG_IDLE, "walk", "run"]:
		_dog_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_dog_anim.animation_finished.connect(func(_clip: StringName):
		if not dead:
			_dog_play(DOG_IDLE))
	_dog_play(DOG_IDLE)
	_dog.global_position = global_position + _dog_offset


## Максимальный вынос морды самим клипом, в игровых метрах, с учётом рига ×100.
## Точка морды — передний край сетки в покое, привязанный к кости Head.
func _measure_bite_reach(box: AABB) -> void:
	var rig: Skeleton3D = _dog_model.find_children("*", "Skeleton3D", true, false)[0]
	var head := rig.find_bone("Head")
	var rest := rig.global_transform * rig.get_bone_global_rest(head)
	var front := _dog_model.to_global(Vector3(box.get_center().x, 0, box.end.z))
	var muzzle := rest.affine_inverse() * Vector3(rest.origin.x, rest.origin.y, front.z)
	_bite_reach = _dog.to_local(front).z
	var mode := _dog_anim.callback_mode_process
	_dog_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_dog_anim.play("bite_lunge", 0.0)
	var length := _dog_anim.get_animation("bite_lunge").length
	for i in 33:
		_dog_anim.seek(minf(length * float(i) / 32.0, length - 0.001), true)
		_dog_anim.advance(0.0)
		var pose := rig.global_transform * rig.get_bone_global_pose(head)
		_bite_reach = maxf(_bite_reach, _dog.to_local(pose * muzzle).z)
	_dog_anim.play(DOG_IDLE, 0.0)
	_dog_anim.advance(0.0)
	_dog_anim.callback_mode_process = mode


## Скорость земли под лапами в клипе: как быстро стопа в фазе опоры уходит назад.
## Считается на масштабе модели, поэтому верна в обеих аренах.
func _measure_gait(clip: String) -> float:
	const FRAMES := 64
	var rig: Skeleton3D = _dog_model.find_children("*", "Skeleton3D", true, false)[0]
	var length := _dog_anim.get_animation(clip).length
	var step := length / FRAMES
	var mode := _dog_anim.callback_mode_process
	_dog_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_dog_anim.play(clip, 0.0)
	var samples: Array[float] = []
	var track := {}
	for foot in FEET:
		track[foot] = []
	for i in FRAMES:
		_dog_anim.seek(step * i, true)
		_dog_anim.advance(0.0)
		for foot in FEET:
			track[foot].append(_dog.to_local(rig.global_transform * rig.get_bone_global_pose(rig.find_bone(foot)).origin))
	for foot in FEET:
		var low := INF
		var high := -INF
		for p: Vector3 in track[foot]:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		for i in FRAMES:
			var a: Vector3 = track[foot][i]
			var b: Vector3 = track[foot][(i + 1) % FRAMES]
			if a.y < low + (high - low) * 0.2 and b.z < a.z:
				samples.append((a.z - b.z) / step)
	_dog_anim.play(DOG_IDLE, 0.0)
	_dog_anim.advance(0.0)
	_dog_anim.callback_mode_process = mode
	if samples.is_empty():
		return 0.0
	samples.sort()
	return samples[samples.size() / 2]


func face(point: Vector3) -> void:
	super.face(point)
	# Только в стойке: при проходе маршрута собака смотрит вдоль своего шага.
	_dog_yaw = PI / 2.0 if point.x >= position.x else -PI / 2.0


## К противнику собака поворачивается сама, от своего места и на любой угол.
func face_foe(point: Vector3) -> void:
	super.face(point)
	var to := point - (get_parent() as Node3D).to_local(_dog.global_position)
	to.y = 0.0
	if to.length() <= 0.01:
		return
	var yaw := atan2(to.x, to.z)
	var from_up := wrapf(yaw - PI, -PI, PI)  # 0 — прямо вверх, там стоит свой псарь
	if absf(from_up) < UP_TILT:
		var side := signf(from_up) if absf(from_up) > 0.001 else (-1.0 if sin(_dog_yaw) >= 0.0 else 1.0)
		yaw = PI + side * UP_TILT
	_dog_yaw = yaw


func melee_point(from: Vector3) -> Vector3:
	var dog_position := (get_parent() as Node3D).to_local(_dog.global_position)
	return dog_position if from.distance_squared_to(dog_position) < from.distance_squared_to(position) else position


func walk_path(points: Array[Vector3]) -> void:
	if dead:
		return
	if points.is_empty():
		arrived.emit()
		return
	_strike_id += 1
	walking = false
	_path.clear()
	_gait = "run" if wants_run(points.size()) else "walk"  # 118: собака и псарь одним аллюром
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
		var raiding := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
		var clip := _raid_clip if raiding else _gait
		_dog_play(clip, walk_rate)
		# Вылазка идёт со скоростью лап своего клипа, чтобы собака не скользила.
		# Обычный ход: шаг — скорость псаря, бег — та же доля бега к шагу, что у лап собаки.
		var speed: float = _gait_speed[clip] if raiding else walk_speed * (_gait_speed["run"] / _gait_speed["walk"] if clip == "run" else 1.0)
		speed *= walk_rate
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


## Отклик при наведении: каждый играет своё, модели друг друга не касаются.
func set_fidget_hovered(hovered: bool) -> void:
	var entered := hovered and not _fidget_hovered
	super.set_fidget_hovered(hovered)
	if entered and not dead and not _escaping and _move_phase == MovePhase.NONE and _dog_anim.current_animation == DOG_IDLE:
		_dog_play(DOG_FIDGET)


func _dog_play(clip: String, speed := 1.0, from := 0.0) -> void:
	_dog_anim.speed_scale = speed
	if _dog_anim.current_animation != clip:
		_dog_anim.play(clip, 0.2)
		if from > 0.0:
			_dog_anim.seek(from, true)


func hit_delay() -> float:
	return BITE_IMPACT


func strike(target: Creature, _distance: float, _overlap: float, _collateral: Array[Creature] = []) -> void:
	# Совместимость с интерфейсом Creature для атаки уже стоящего рядом врага.
	raid(target, [] as Array[Vector3], target.position)


## Полная вылазка: команда, путь собаки, укус и обратный путь. Корень не двигается.
## points и contact заданы в координатах родителя, как у walk_path.
func raid(target: Creature, points: Array[Vector3], contact: Vector3) -> void:
	if dead:
		return
	var epoch := _epoch
	var home := _dog.global_position
	var goal := (get_parent() as Node3D).to_global(contact)
	var outbound: Array[Vector3] = []
	for point in points:
		outbound.append((get_parent() as Node3D).to_global(point) + _dog_offset)
	var approach: Vector3 = home if outbound.is_empty() else outbound[-1]
	var approach_direction := (goal - approach).normalized()
	var safe_distance := _bite_reach + target.front() + BITE_GAP + BITE_STEP
	if approach.distance_to(goal) < safe_distance:
		# Не добегать корпусом до центра клетки цели: морда достаёт издали.
		var stop := goal - approach_direction * safe_distance
		if outbound.is_empty():
			outbound.append(stop)
		else:
			outbound[-1] = stop
	_move_phase = MovePhase.RAID_HOLD
	walking = false
	_path.clear()
	face_foe(target.position)
	# Жертва смотрит туда, откуда её укусят, а не на псаря, который стоит на месте.
	target.face_foe((get_parent() as Node3D).to_local(home if outbound.is_empty() else outbound[-1]))
	play_once(attack_anim)
	_dog_play(DOG_IDLE)
	# Обычный поход к соседней клетке — шагом, дальний — бегом; обратно тем же ходом.
	_raid_clip = "run" if points.size() >= RAID_RUN_FROM else "walk"
	# Команда псаря и вылазка собаки начинаются одновременно.
	if not outbound.is_empty():
		_dog_route = outbound.duplicate()
		_move_phase = MovePhase.RAID_OUT
		await dog_route_finished
		if epoch != _epoch or dead or not is_instance_valid(target):
			return
	var launch := _dog.global_position
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
	get_tree().create_timer(BITE_IMPACT).timeout.connect(func():
		if epoch == _epoch and not dead:
			raid_impact.emit())
	var reaction_end := Time.get_ticks_msec() + int((BITE_IMPACT + 1.5) * 1000.0)
	var step := clampf(launch.distance_to(goal) - _bite_reach - target.front() - BITE_GAP, 0.0, BITE_STEP)
	_bite = create_tween()
	_bite.tween_property(_dog, "global_position", launch + direction * step, BITE_IMPACT).set_trans(Tween.TRANS_SINE)
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
	if clip == attack_anim:
		if dead:
			return
		walking = false
		_strike_id += 1
		var length := anim.get_animation(clip).length
		anim.play(clip, BLEND, _speed(length * (1.0 - attack_from)))
		anim.seek(length * attack_from, true)
		return  # команда целиком; общий ранний обрыв удара здесь не применяется
	super.play_once(clip)
	if is_instance_valid(_dog_anim) and not dead:
		if clip == hurt_anim:
			_dog_play("hurt_head_left")
		elif clip == defend_anim:
			_dog_play("defend_lower_head", 1.0, DOG_DEFEND_FROM)


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
	_dog_play("hurt_head_left")
	var reaction_time := _dog_anim.get_animation("hurt_head_left").length
	_escape = create_tween()
	_escape.tween_interval(reaction_time)
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
