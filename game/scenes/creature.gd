class_name Creature
extends Node3D
## Существо: модель из пайплайна Tripo, анимации, ходьба, удар, получение удара, смерть.
## Всё играется из idle и возвращается в idle; падение держит последний кадр до revive().

signal arrived

const WALK_SPEED := 1.0  # подогнано под шаг анимации walk, иначе ноги скользят
const TURN_SPEED := 8.0
const FRONT_YAW := -PI / 2.0  # модель Tripo смотрит по +X, а не по +Z
const MAX_ONESHOT := 3.0  # разовая анимация не длиннее, секунд
const BLEND := 0.2
const LOOPED := ["idle", "walk"]
const LIMB_RADIUS := 0.12  # от кости до поверхности тела снизу у лежащего, метров
const FLINCH_PUSH := 0.15  # насколько отбрасывает назад при ударе
const FLINCH_TILT := 0.17  # наклон назад, радиан
const FLINCH_HIT := 0.15  # резкий толчок назад в момент попадания, секунд
const BLOCK_PUSH := 0.07  # удар в защиту: лёгкий толчок назад, метров
const BLOCK_TILT := 0.07  # и наклон, радиан
const BLOCK_RECOVER := 0.45
const RECOIL := 0.3  # после попадания рука сразу возвращается: через столько секунд — в idle
const RECOIL_BLEND := 0.35
const HITS_TO_KILL := 3  # пока вместо здоровья: столько ударов выдерживает существо
const OUTLINE_WIDTH := 0.025  # толщина обводки по контуру, метров

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var dead := false
var walking := false
var walk_rate := 1.0  # ускорение ходьбы: анимация и движение вместе, чтобы ноги не скользили
var impact := 0.5  # момент попадания, доля проигрываемой части удара
var _strike_id := 0
var reach := 1.0  # вынос кулака вперёд в момент попадания, метров
var height := 2.0  # рост существа, метров
var attack_anim := "slash"  # анимация удара этого существа
var attack_from := 0.0  # с какой доли длины играть удар: срезать долгий замах
var hurt_anim := ""  # анимация получения удара; пусто — программный толчок flinch()
var hurt_len := 0.0  # сколько секунд реакции играть (0 — целиком); дальше — плавно в idle
var defend_anim := ""  # анимация защиты: играется вместо реакции, если существо защищается
var defend_from := 0.0  # с какой доли длины играть защиту
var defend_len := 0.0  # сколько секунд защиты играть (0 — до конца); дальше — плавно в idle
var defend_lead := 0.3  # защита стартует раньше попадания: к удару поза уже принята
var defend_pin := true  # держать таз на месте во время защиты (false — уклон: тело должно уходить вбок)
var defending := false  # выбрана «Защита»: удары не засчитываются до своего следующего хода
var jolt := 0.0  # текущий толчок назад от удара в защиту (метров), учитывается в _pin_hip
var smoke: GPUParticles3D  # дым из трубы (котельщик); null — нет
var _smoke_anchor: Node3D
var hits := 0  # полученные удары

var _model_base := Vector3.ZERO
var _target := Vector3.ZERO
var _path: Array[Vector3] = []  # оставшиеся точки маршрута после _target
var _yaw := 0.0
var _rest_min_y := 0.0
var _body_depth := 0.0
var _hip_bone := -1
var _head_bone := -1


func setup(scene: PackedScene, extra_anims: Array = [], attack := "slash", hurt := "", size := 2.0, attack_start := 0.0, idle := "idle") -> void:
	attack_anim = attack
	attack_from = attack_start
	hurt_anim = hurt
	height = size
	model = scene.instantiate()
	add_child(model)
	_fit()
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.find_child("AnimationPlayer", true, false)
	if anim == null:  # файл рига без анимаций: всё подмешается из extra_anims
		anim = AnimationPlayer.new()
		model.add_child(anim)
		anim.root_node = anim.get_path_to(model)
		anim.add_animation_library(&"", AnimationLibrary.new())
	for path: String in extra_anims:
		_merge_extra_animations(path)
	if idle != "idle" and anim.has_animation(idle):
		# Своя стойка: подменяем idle выбранной анимацией, остальной код знает только «idle».
		var library := anim.get_animation_library(&"")
		library.remove_animation("idle")
		library.add_animation("idle", anim.get_animation(idle).duplicate())
	for anim_name in anim.get_animation_list():
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPED else Animation.LOOP_NONE
	_align_hips()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.animation_finished.connect(_on_animation_finished)
	_play("idle")
	anim.advance(0.0)
	_center_on_hip()
	_measure_rest()
	_find_impact()
	_yaw = rotation.y


func _fit() -> void:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	box = global_transform.affine_inverse() * box
	var s := height / box.size.y
	model.scale = Vector3.ONE * s
	model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
	_model_base = model.position
	_body_depth = minf(box.size.x, box.size.z) * s  # толщина тела, а не размах рук


func _merge_extra_animations(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var extra: Node = load(path).instantiate()
	var source: AnimationPlayer = extra.find_child("AnimationPlayer", true, false)
	var library := anim.get_animation_library(&"")
	# Пути треков во втором файле другие: переводим их на скелет основной модели.
	var skeleton_path := anim.get_node(anim.root_node).get_path_to(skeleton)
	var source_skeleton: Skeleton3D = extra.find_children("*", "Skeleton3D", true, false)[0]
	for anim_name in source.get_animation_list():
		if library.has_animation(anim_name):
			continue
		var a: Animation = source.get_animation(anim_name).duplicate()
		for t in a.get_track_count():
			var bone := a.track_get_path(t).get_concatenated_subnames()
			a.track_set_path(t, NodePath("%s:%s" % [skeleton_path, bone]))
			_adapt_track(a, t, source_skeleton, bone)
		library.add_animation(anim_name, a)
	extra.free()


## Анимация из другого рига: поза покоя у него своя (кисти отличаются до 30°). Ключи хранят позу
## целиком, поэтому переносим отклонение от покоя: иначе оружие в руке поворачивается.
func _adapt_track(a: Animation, t: int, source: Skeleton3D, bone: String) -> void:
	var from := source.find_bone(bone)
	var to := skeleton.find_bone(bone)
	if from < 0 or to < 0:
		return
	if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
		var delta := skeleton.get_bone_rest(to).basis.get_rotation_quaternion() * source.get_bone_rest(from).basis.get_rotation_quaternion().inverse()
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, (delta * a.track_get_key_value(t, k)).normalized())
	elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
		var shift := skeleton.get_bone_rest(to).origin - source.get_bone_rest(from).origin
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, a.track_get_key_value(t, k) + shift)


## У Tripo таз в анимациях смещён относительно idle (в run было больше метра в мире): при переходах
## тело «доезжает» на место. Сдвигаем трек таза к позиции из idle:
## циклические — по среднему, разовые — по первому ключу (движение внутри анимации сохраняется).
func _align_hips() -> void:
	var idle := anim.get_animation("idle")
	var hip_track := NodePath("%s:Hip" % anim.get_node(anim.root_node).get_path_to(skeleton))
	var idle_track := idle.find_track(hip_track, Animation.TYPE_POSITION_3D)
	if idle_track < 0:
		return
	var home: Vector3 = idle.track_get_key_value(idle_track, 0)
	for anim_name in anim.get_animation_list():
		if anim_name == "idle":
			continue
		var a := anim.get_animation(anim_name)
		var t := a.find_track(hip_track, Animation.TYPE_POSITION_3D)
		if t < 0:
			continue
		var anchor: Vector3 = a.track_get_key_value(t, 0)
		if anim_name in LOOPED:
			anchor = Vector3.ZERO
			for k in a.track_get_key_count(t):
				anchor += a.track_get_key_value(t, k)
			anchor /= a.track_get_key_count(t)
		var shift := home - anchor
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, a.track_get_key_value(t, k) + shift)


## После выравнивания таз в idle стоит не над началом координат (у голема — 0,27 м вбок):
## двигаем модель так, чтобы таз был над точкой существа, иначе тела противников разъезжаются.
func _center_on_hip() -> void:
	var hip := to_local(bone_world(skeleton.find_bone("Hip")))
	_model_base -= Vector3(hip.x, 0.0, hip.z)
	model.position = _model_base


## Передняя поверхность тела от точки существа: половина толщины тела.
func front() -> float:
	return _body_depth * 0.5


func _measure_rest() -> void:
	_hip_bone = skeleton.find_bone("Hip")
	var top := -INF
	_rest_min_y = INF
	for i in skeleton.get_bone_count():
		var y := to_local(bone_world(i)).y
		_rest_min_y = minf(_rest_min_y, y)
		if y > top:
			top = y
			_head_bone = i


## Момент попадания в анимации удара: кадр самого быстрого выброса кисти вперёд (+X модели).
func _find_impact() -> void:
	var hands: Array[int] = []
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with("Hand"):
			hands.append(i)
	var slash := anim.get_animation(attack_anim)
	var start := slash.length * attack_from
	var played := slash.length - start
	var best := -INF
	var prev := {}
	anim.play(attack_anim)
	for step in 121:
		var t := start + played * step / 120.0
		anim.seek(t, true)
		for i in hands:
			var forward := to_local(bone_world(i)).x
			# Попадание — самый быстрый выброс кисти вперёд, а не самая дальняя точка:
			# у широких замахов (pitch_baseball) дальше всего рука уходит в провисе после удара.
			if prev.has(i) and forward - prev[i] > best:
				best = forward - prev[i]
				impact = (t - start) / played  # доля проигрываемой части
				reach = forward
			prev[i] = forward
	anim.play("idle")
	anim.advance(0.0)


## Обводка по внешнему контуру (стенсил Godot: рисуется только вокруг силуэта, без линий внутри);
## null — убрать.
func set_outline(color: Variant) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			if color == null:
				mesh.set_surface_override_material(i, null)
				continue
			var mat := mesh.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
			mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
			mat.stencil_color = color
			mat.stencil_outline_thickness = OUTLINE_WIDTH / model.scale.x
			mesh.set_surface_override_material(i, mat)


## Высота макушки над землёй в текущей позе.
func size_top() -> float:
	var top := 0.0
	for i in skeleton.get_bone_count():
		top = maxf(top, to_local(bone_world(i)).y)
	return top


## Дым из самой высокой точки модели (верх трубы котла): частицы ездят за ближайшей костью.
func add_smoke() -> void:
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var to_skel := skeleton.global_transform.affine_inverse() * mesh.global_transform
	var top := Vector3(0, -INF, 0)
	for surface in mesh.mesh.get_surface_count():
		for v: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p := to_skel * v
			if p.y > top.y:
				top = p
	var bone := 0
	var best := INF
	for i in skeleton.get_bone_count():
		var d := skeleton.get_bone_global_rest(i).origin.distance_to(top)
		if d < best:
			best = d
			bone = i
	var attach := BoneAttachment3D.new()
	attach.bone_idx = bone
	skeleton.add_child(attach)
	_smoke_anchor = Node3D.new()
	_smoke_anchor.position = skeleton.get_bone_global_rest(bone).affine_inverse() * top
	attach.add_child(_smoke_anchor)

	smoke = GPUParticles3D.new()
	smoke.top_level = true  # без масштаба модели: размеры дыма в метрах
	smoke.amount = 48
	smoke.lifetime = 2.4
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0.05, 0.15, 0)  # тёплый дым поднимается и чуть сносится
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.6))
	pm.scale_curve = CurveTexture.new()
	pm.scale_curve.curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.32, 0.31, 0.3, 0.55))
	fade.set_color(1, Color(0.4, 0.4, 0.4, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = fade
	smoke.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var puff := GradientTexture2D.new()  # мягкое круглое пятно
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	mat.albedo_texture = puff
	quad.material = mat
	smoke.draw_pass_1 = quad
	add_child(smoke)


## Клуб дыма: на короткое время котёл дымит втрое сильнее (удар, получение удара).
func puff_smoke() -> void:
	if smoke == null:
		return
	var tween := create_tween()
	tween.tween_property(smoke, "speed_scale", 3.0, 0.08)
	tween.tween_property(smoke, "speed_scale", 1.0, 0.6)


func bone_world(i: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin


## Пройти по точкам маршрута (центры гексов) одну за другой; в конце — сигнал arrived.
func walk_path(points: Array[Vector3]) -> void:
	if points.is_empty():
		arrived.emit()
		return
	_path = points.duplicate()
	walk_to(_path.pop_front())


func walk_to(point: Vector3) -> void:
	if dead:
		return
	_target = Vector3(point.x, 0.0, point.z)
	walking = true
	_play("walk")


func face(point: Vector3) -> void:
	var to := point - position
	if to.length() > 0.01:
		_yaw = atan2(to.x, to.z) + FRONT_YAW


func play_once(anim_name: String) -> void:
	if dead:
		return
	walking = false
	var length := anim.get_animation(anim_name).length
	var start := length * _start_of(anim_name)
	var cut := _len_of(anim_name)
	if cut > 0.0:
		# Кусок анимации с обычной скоростью, потом плавно в idle: длинная защита (fold_arms — 17 с),
		# укороченная реакция (у голема hit_to_body_01 шатается — берём первую половину).
		anim.play(anim_name, BLEND, 1.0)
		anim.seek(start, true)
		var id := _strike_id
		await get_tree().create_timer(cut).timeout
		if id == _strike_id and not dead and anim.current_animation == anim_name:
			anim.play("idle", RECOIL_BLEND)
		return
	anim.play(anim_name, BLEND, _speed(length - start))
	anim.seek(start, true)
	if anim_name == attack_anim:
		# Не досматривать удар до конца (существо «позирует»): вскоре после попадания — в idle.
		_strike_id += 1
		var id := _strike_id
		await get_tree().create_timer(hit_delay() + RECOIL).timeout
		if id == _strike_id and not dead and anim.current_animation == attack_anim:
			anim.play("idle", RECOIL_BLEND)


## Частичные анимации: с какой доли длины играть.
func _start_of(anim_name: String) -> float:
	if anim_name == attack_anim:
		return attack_from
	if anim_name == defend_anim:
		return defend_from
	return 0.0


## Сколько секунд анимации играть (0 — целиком).
func _len_of(anim_name: String) -> float:
	if anim_name == defend_anim:
		return defend_len
	if anim_name == hurt_anim:
		return hurt_len
	return 0.0


func _speed(played: float) -> float:
	return maxf(1.0, played / MAX_ONESHOT)


## Секунд от начала удара до попадания (с учётом обрезки и ускорения).
func hit_delay() -> float:
	var played := anim.get_animation(attack_anim).length * (1.0 - attack_from)
	return impact * played / _speed(played)


## Получение удара — зеркало slash бьющего: ждём момента попадания, резкий толчок назад
## с наклоном, плавный возврат; всё вместе — MAX_ONESHOT, как сам удар.
func flinch(delay: float) -> void:
	if dead:
		return
	walking = false
	_play("idle")
	var tween := create_tween().set_parallel()
	var recover := maxf(0.3, MAX_ONESHOT - delay - FLINCH_HIT)
	tween.tween_interval(delay)
	tween.chain().tween_property(model, "position:x", _model_base.x - FLINCH_PUSH, FLINCH_HIT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(model, "rotation:z", FLINCH_TILT, FLINCH_HIT).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(model, "position:x", _model_base.x, recover).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(model, "rotation:z", 0.0, recover).set_trans(Tween.TRANS_SINE)


## Удар по существу; delay — секунд до попадания в анимации бьющего (его hit_delay()).
## Последний удар убивает в момент попадания, остальные — получение удара.
func take_hit(delay: float) -> void:
	if dead or hits >= HITS_TO_KILL:
		return
	if defending:
		# Удар в защиту не засчитывается: закрывается к моменту попадания.
		walking = false
		_play("idle")
		if defend_anim != "" and anim.has_animation(defend_anim):
			get_tree().create_timer(maxf(0.01, delay - defend_lead)).timeout.connect(play_once.bind(defend_anim))
		# В момент попадания — вздрогнул: короткий толчок назад с наклоном, удар всё-таки пришёлся.
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "jolt", BLOCK_PUSH, 0.08).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(model, "rotation:z", BLOCK_TILT, 0.08).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "jolt", 0.0, BLOCK_RECOVER).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(model, "rotation:z", 0.0, BLOCK_RECOVER).set_trans(Tween.TRANS_SINE)
		return
	hits += 1
	if hits >= HITS_TO_KILL:
		get_tree().create_timer(delay).timeout.connect(die)
	elif hurt_anim != "" and anim.has_animation(hurt_anim):
		walking = false
		_play("idle")
		get_tree().create_timer(delay).timeout.connect(play_once.bind(hurt_anim))
	else:
		flinch(delay)


## Ослабить движение костей: только доля amount пути от позы стойки, тело играет полностью.
## Обрезать по времени нельзя: пресеты делают основной размах в первой четверти длины.
func scale_bones(anim_name: String, bones: Array, amount: float) -> void:
	if bones.is_empty() or not anim.has_animation(anim_name):
		return
	var a := anim.get_animation(anim_name)
	var idle := anim.get_animation("idle")
	var root_path := anim.get_node(anim.root_node).get_path_to(skeleton)
	for bone: String in bones:
		var path := NodePath("%s:%s" % [root_path, bone])
		var t := a.find_track(path, Animation.TYPE_ROTATION_3D)
		var from := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if t < 0 or from < 0:
			continue
		var rest: Quaternion = idle.track_get_key_value(from, 0)
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, rest.slerp(a.track_get_key_value(t, k), amount))


## Сменить анимацию удара: заново ищем момент попадания и дальность.
func set_attack(anim_name: String) -> void:
	attack_anim = anim_name
	_find_impact()


## Ударить цель, стоящую на distance (центр к центру). Кулак не достаёт — выпад вперёд,
## достаёт с запасом — отклон назад; к моменту попадания, потом возврат.
func strike(target: Creature, distance: float, overlap: float) -> void:
	face(target.position)
	target.face(position)
	play_once(attack_anim)
	target.take_hit(hit_delay())
	get_tree().create_timer(hit_delay()).timeout.connect(puff_smoke)
	get_tree().create_timer(hit_delay()).timeout.connect(target.puff_smoke)
	var lunge := distance - (reach + target.front() - overlap)
	if absf(lunge) > 0.01:
		var tween := create_tween()
		tween.tween_property(model, "position:x", _model_base.x + lunge, hit_delay()).set_trans(Tween.TRANS_SINE)
		tween.tween_property(model, "position:x", _model_base.x, RECOIL + RECOIL_BLEND).set_trans(Tween.TRANS_SINE)


func can_be_hit() -> bool:
	return not dead and hits < HITS_TO_KILL


func die() -> void:
	if dead:
		return
	play_once("fall")
	dead = true


func revive() -> void:
	hits = 0
	if dead:
		dead = false
		_play("idle")


func _play(anim_name: String) -> void:
	if anim.current_animation != anim_name:
		anim.play(anim_name, BLEND, walk_rate if anim_name == "walk" else 1.0)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"fall" and not dead:
		_play("idle")


func _process(delta: float) -> void:
	anim.advance(delta)
	if smoke:
		smoke.global_position = _smoke_anchor.global_position
	_pin_hip()
	_keep_above_ground()
	rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, TURN_SPEED * delta))


## Защита и смерть на месте: некоторые пресеты (football_save — прыжок вратаря, fall без «на месте»)
## уносят таз с гекса. Пока они играются, таз держим над точкой существа по горизонтали.
func _pin_hip() -> void:
	var pinned := dead or (defend_anim != "" and defend_pin and anim.current_animation == defend_anim)
	if not pinned:
		if model.position.z != _model_base.z:
			model.position.z = _model_base.z
		if jolt > 0.0:
			model.position.x = _model_base.x - jolt
		return
	model.position.x = _model_base.x
	model.position.z = _model_base.z
	var hip := to_local(bone_world(_hip_bone))
	model.position.x -= hip.x + jolt  # модель смотрит по +X: толчок назад — минус X
	model.position.z -= hip.z


## Только для мёртвого: нижняя кость не опускается ниже своей высоты в стойке (стоя),
## а у лежащего — ниже радиуса конечности, чтобы тело легло на землю, а не в неё.
func _keep_above_ground() -> void:
	model.position.y = _model_base.y
	if not dead:
		return
	var lowest := INF
	for i in skeleton.get_bone_count():
		lowest = minf(lowest, to_local(bone_world(i)).y)
	var spine := bone_world(_head_bone) - bone_world(_hip_bone)
	var lying := 1.0 - clampf(spine.normalized().dot(Vector3.UP), 0.0, 1.0)
	var floor_y := lerpf(_rest_min_y, LIMB_RADIUS, lying)
	model.position.y = _model_base.y + maxf(0.0, floor_y - lowest)


func _physics_process(delta: float) -> void:
	if not walking:
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.05:
		if not _path.is_empty():
			_target = _path.pop_front()
			return
		walking = false
		_play("idle")
		arrived.emit()
		return
	position += to.normalized() * minf(WALK_SPEED * walk_rate * delta, to.length())
	face(_target)
