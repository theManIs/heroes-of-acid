extends Creature
## Один отряд, три клетки и одно здоровье. Собака следует за верхним якорем,
## но не вращает занятую фигуру вместе с поворотом псаря.
const DOG_SCENE := preload("res://assets/creatures/hound/hound.glb")
const DOG_IDLE := "idle_breathe"
const DOG_HEIGHT := 1.05
const COMMAND_LEAD := 0.85
const BITE_IMPACT := 0.45

var _dog := Node3D.new()
var _dog_model: Node3D
var _dog_anim: AnimationPlayer
var _dog_yaw := PI / 2.0
var _epoch := 0
var _escape: Tween
var _bite: Tween
var _escaping := false
var _dog_offset := Vector3(0, 0, 0.9)  # середина двух нижних гексов радиуса 0,6


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
	# Вытянутая собака остаётся вдоль своих двух нижних клеток.
	_dog_yaw = PI / 2.0 if point.x >= position.x else -PI / 2.0


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_dog_anim):
		return
	if not _escaping and not is_instance_valid(_bite):
		_dog.global_position = global_position + _dog_offset
		_dog.rotation.y = lerp_angle(_dog.rotation.y, _dog_yaw, minf(1.0, TURN_SPEED * delta))
	if walking and not dead:
		_dog_play("walk", _dog_anim.get_animation("walk").length / anim.get_animation("walk").length * walk_rate)
	elif not dead and _dog_anim.current_animation == &"walk":
		_dog_play(DOG_IDLE)


func _dog_play(clip: String, speed := 1.0) -> void:
	_dog_anim.speed_scale = speed
	if _dog_anim.current_animation != clip:
		_dog_anim.play(clip, 0.2)


func hit_delay() -> float:
	return COMMAND_LEAD + BITE_IMPACT


func strike(target: Creature, _distance: float, _overlap: float) -> void:
	if dead:
		return
	face(target.position)
	target.face(position)
	play_once(attack_anim)
	target.take_hit(hit_delay())
	var epoch := _epoch
	await get_tree().create_timer(COMMAND_LEAD).timeout
	if epoch != _epoch or dead or not is_instance_valid(target):
		return
	var home := global_position + _dog_offset
	var goal := target.global_position + _dog_offset
	var direction := (goal - home).normalized()
	_dog.rotation.y = atan2(direction.x, direction.z)
	_dog_play("bite_lunge")
	_bite = create_tween()
	_bite.tween_property(_dog, "global_position", home + direction * maxf(0.0, home.distance_to(goal) - 1.05), BITE_IMPACT).set_trans(Tween.TRANS_SINE)
	_bite.tween_property(_dog, "global_position", home, 0.65).set_trans(Tween.TRANS_SINE)
	await _bite.finished
	_bite = null


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


func revive() -> void:
	_epoch += 1
	_strike_id += 1
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
