extends Creature
## Всадник как одно существо. Анимации ведёт конь (модель Creature), рыцарь — свой Creature,
## едет на кости спины коня; копьё в кулаке рыцаря. Клип коня включает клип рыцаря.
const MOCK := preload("res://scenes/rider_mock.gd")
const PAIR := preload("res://scenes/rider_pair.gd")
## Клип коня → клип рыцаря.
const RIDER_CLIPS := {"idle": "ride_still", "walk": "ride_still", "run": "ride_still", "attack": "ride_still",
	"hurt_left": "ride_hurt", "idle_head_low": "ride_dodge", "fidget_graze": "ride_fidget_look", "fall": "ride_still"}
## Удар с места, как в витрине пары: полшага назад шагом, рывок галопом, стойка.
const STEP_BACK := 0.6
const STEP_BACK_TIME := 0.6
const LUNGE_TIME := 0.35
const SETTLE_TIME := 0.5
const BAKE_FPS := 30.0
## Всадник в бою меньше, чем в витрине пары: конь 2,46 м в длину, вплотную между носами около 0,5 м.
## Рост коня в записи (rider_config) уже умножен; здесь — рыцарь и копьё.
const SCALE := 0.85

var rider: Creature
var lance: Node3D
var keeper: MOCK.LanceKeeper
var _hang: Node
var _saddle := -1
var _offset := Transform3D.IDENTITY
var _rider_len := 0.0  # клип рыцаря короче клипа коня: хвост растягивается
var _horse_len := 0.0
var _clip_time := 0.0
var _stretched := false
var _attack_time := -1.0
## Два гекса в ряд, как двухклеточные в Героях: точка существа — левый гекс, тело — посередине пары.
## Сдвиг тела в мире задаёт арена (полшага гекса по +X); конь смотрит только влево или вправо.
var body_shift := Vector3.ZERO
var _fit_base := Vector3.ZERO  # положение модели, при котором низ коня по центру в точке существа


func setup(scene: PackedScene, extra_anims: Array = [], attack := "slash", hurt := "", size := 2.0, attack_start := 0.0, idle := "idle") -> void:
	super.setup(scene, extra_anims, attack, hurt, size, attack_start, idle)
	var library := anim.get_animation_library(&"")
	library.add_animation("fall", anim.get_animation("death_fall_on_side").duplicate())
	library.add_animation("attack", _bake_attack())
	attack_anim = "attack"
	attack_from = 0.0
	impact = (STEP_BACK_TIME + LUNGE_TIME) / anim.get_animation("attack").length
	no_backstep = true
	for clip in ["run"]:
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_saddle = skeleton.find_bone(PAIR.SADDLE_BONE)
	rider = MOCK.make_rider(self, MOCK.RIDER_SIZE * SCALE)
	PAIR.prepare_lancer(rider)
	rider.top_level = true
	rider.anim.play("ride_still", 0.0)
	rider.anim.advance(0.0)
	lance = MOCK.add_lance(self)
	keeper = PAIR.add_keeper(rider)
	_hang = PAIR.LegHang.new()
	_hang.rider = rider
	_hang.horse_sk = skeleton
	add_child(_hang)
	_hang.drop *= SCALE
	_hang.set_rest()
	_hang.set_process(false)
	_seat()
	reach = to_local(MOCK.tip(lance)).x
	anim.current_animation_changed.connect(_on_horse_clip)
	arrived.connect(_on_arrived)


## Рост по сетке коня, как в витрине пары: рамка сетки со скелетом в глобальных координатах у коня неверная.
func _fit() -> void:
	var box: AABB = model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	var s := height / box.size.y
	model.scale = Vector3.ONE * s
	model.position = Basis(Vector3.UP, PI / 2.0) * (-Vector3(box.get_center().x, box.position.y, box.get_center().z) * s)
	_model_base = model.position
	_fit_base = model.position
	_body_depth = minf(box.size.x, box.size.z) * s


## Посадка: таз рыцаря над седлом, запоминаем положение относительно кости спины коня.
func _seat() -> void:
	var seat: Vector3 = to_global(model.position - _fit_base + Basis(Vector3.UP, PI / 2.0) * (PAIR.SEAT * height))
	rider.global_transform = Transform3D(global_basis.orthonormalized(), rider.global_position)
	var hips: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_Hips"))
	rider.global_position += seat + Vector3(0, 0.08 * SCALE, 0) - hips
	_offset = _saddle_frame().affine_inverse() * rider.global_transform
	_follow()


func _saddle_frame() -> Transform3D:
	var t: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_saddle)
	return Transform3D(t.basis.orthonormalized(), t.origin)


func _process(delta: float) -> void:
	super._process(delta)
	var lunge := 0.0
	if _attack_time >= 0.0:
		_attack_time += delta
		lunge = _lunge_shift(_attack_time)
	var local := global_basis.orthonormalized().inverse() * body_shift
	var pinned := dead or (defend_anim != "" and defend_pin and anim.current_animation == defend_anim)
	if not pinned:
		model.position.x = _model_base.x + lunge - jolt
		model.position.z = _model_base.z
	model.position.x += local.x
	model.position.z += local.z
	_clip_time += delta
	if not _stretched and _rider_len < _horse_len and _clip_time >= _rider_len * 0.95:
		rider.anim.speed_scale = (_rider_len * 0.05) / maxf(_horse_len - _rider_len * 0.95, 0.01)
		_stretched = true
	_follow()


func _follow() -> void:
	rider.global_transform = _saddle_frame() * _offset
	rider.set("_yaw", rider.rotation.y)
	MOCK.place_fist_lance(lance, rider, 0.0, 0.0, keeper, SCALE)


## Клип коня сменился — рыцарь играет свой; разовые короче — хвост растянут до конца клипа коня.
func _on_horse_clip(clip: StringName) -> void:
	var name := String(clip)
	if name == "":
		return
	var mine: String = RIDER_CLIPS.get(name, "ride_still")
	rider.anim.speed_scale = 1.0
	_stretched = false
	_clip_time = 0.0
	_horse_len = anim.get_animation(name).length if anim.has_animation(name) else 0.0
	_rider_len = rider.anim.get_animation(mine).length
	if mine == "ride_still":
		_rider_len = INF  # стойка идёт по кругу
	rider.anim.play(mine, PAIR.BACK_BLEND if name == "idle" else 0.2)
	_hang.set_process(name == "fidget_graze")
	keeper.active = name != "fall"
	if name == "attack":
		_attack_time = 0.0
	elif _attack_time >= 0.0:
		_attack_time = -1.0


## Сдвиг коня вперёд-назад в ударе: полшага назад, рывок в цель, стоит.
func _lunge_shift(t: float) -> float:
	if t < STEP_BACK_TIME:
		return -STEP_BACK * smoothstep(0.0, 1.0, t / STEP_BACK_TIME)
	if t < STEP_BACK_TIME + LUNGE_TIME:
		var u := (t - STEP_BACK_TIME) / LUNGE_TIME
		return lerpf(-STEP_BACK, 0.0, u * u)
	return 0.0


## Клип удара из клипов коня: шаг назад (шаг задом наперёд), рывок (галоп), стойка.
func _bake_attack() -> Animation:
	var parts := [["walk", STEP_BACK_TIME, -1.0], ["run", LUNGE_TIME, 1.0], ["idle", SETTLE_TIME, 1.0]]
	var out := Animation.new()
	var idle_clip := anim.get_animation("idle")
	out.length = STEP_BACK_TIME + LUNGE_TIME + SETTLE_TIME
	for t in idle_clip.get_track_count():
		var kind := idle_clip.track_get_type(t)
		if kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_POSITION_3D:
			continue
		var path := idle_clip.track_get_path(t)
		var nt := out.add_track(kind)
		out.track_set_path(nt, path)
		var start := 0.0
		for part: Array in parts:
			var src := anim.get_animation(part[0])
			var st := src.find_track(path, kind)
			var frames := int(ceil(part[1] * BAKE_FPS))
			for f in frames + 1:
				var local := minf(f / BAKE_FPS, part[1])
				var at: float = fposmod(local * part[2], src.length)
				var value: Variant
				if st < 0:
					value = idle_clip.rotation_track_interpolate(t, 0.0) if kind == Animation.TYPE_ROTATION_3D else idle_clip.position_track_interpolate(t, 0.0)
				elif kind == Animation.TYPE_ROTATION_3D:
					value = src.rotation_track_interpolate(st, at)
				else:
					value = src.position_track_interpolate(st, at)
				out.track_insert_key(nt, start + local, value)
			start += part[1]
	return out


## Середина двух гексов в мире.
func center() -> Vector3:
	return position + body_shift


## Конь стоит по середине своей рамки, а не по кости таза: таз у него сзади, тело уезжало вперёд на соседа.
func _center_on_hip() -> void:
	pass


## На ходу — по движению в любую сторону. Стоя — только влево или вправо (два гекса в ряд),
## от середины пары; цель строго над или под — не поворачиваться.
func face(point: Vector3) -> void:
	if walking or body_shift == Vector3.ZERO:
		super.face(point)
		return
	var to := point - center()
	if absf(to.x) < 0.05:
		return
	super.face(position + Vector3(signf(to.x), 0.0, 0.0))


## Дошёл — встаёт вдоль ряда, в ту сторону, куда ближе смотрел.
func _on_arrived() -> void:
	var ahead := global_basis.orthonormalized().x
	if absf(ahead.x) > 0.01:
		super.face(position + Vector3(signf(ahead.x), 0.0, 0.0))


func die() -> void:
	super.die()
	keeper.active = false


func revive() -> void:
	super.revive()
	keeper.active = true


## Обводка: толщина по масштабу каждой сетки — у коня внутри файла свой масштаб, общий даёт обводку во весь экран.
func set_outline(color: Variant) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			if color == null:
				mesh.set_surface_override_material(i, null)
				continue
			var mat := mesh.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
			mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
			mat.stencil_color = color
			mat.stencil_outline_thickness = OUTLINE_WIDTH / (mesh.global_basis.get_scale().x / global_basis.get_scale().x)
			mesh.set_surface_override_material(i, mat)
	rider.set_outline(color)
