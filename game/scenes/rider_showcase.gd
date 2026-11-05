extends "res://scenes/showcase.gd"
## Витрина макета всадника (задача 157): квадрат на каждый сидячий клип Mixamo,
## тело молотобойца на условном коне. Отсмотр материала до генерации моделей.

const MOCK := preload("res://scenes/rider_mock.gd")
const CELL_TARGET := 460
const HOLD := 0.6
const LANCE_CLIPS := ["ride_swing", "ride_swing_mirror", "ride_strike"]  # удары сидя: копьё в кисти
const LANCE_DAMP := {"ride_swing": 0.45, "ride_swing_mirror": 0.45}  # с копьём взмах аккуратнее: доля размаха клипа
const LEFT_HAND_CLIPS := ["ride_swing_mirror"]  # зеркальный клип бьёт левой рукой — копьё в левой
## Езда без клипа езды: всадник в сидячей стойке, конь-макет идёт на месте,
## качается корпусом и переставляет ноги. Подпись, клип всадника, шагов в секунду,
## подъём корпуса (м), размах ног (градусы).
const GAITS := [
	["Шаг", "ride_still", 1.6, 0.03, 18.0],
	["Бег: рысь, облегчается в седле", "ride_still", 2.6, 0.07, 28.0],
]


func _ready() -> void:
	columns = 4
	var grid := _build_page()
	# Заявленные действия: стойка, шаг, рысь (бег), таран (атака), реакция, защита.
	_make_fidget_cell(grid, ["Стойка: сидит спокойно", "ride_still"])
	for gait: Array in GAITS:
		_make_ride_cell(grid, gait)
	_make_charge_cell(grid)
	_make_charge_cell(grid, "Атака впритык: выпад конём", CHARGE_HIT - LUNGE, LUNGE_TIME, 0.3)
	# Реакция: в клипе удар и откат головы — первые 2,2 с, дальше 4 с почти без движения.
	_make_fidget_cell(grid, ["Реакция: удар по голове", "ride_hurt", HURT_LEN])
	for death: Array in DEATHS:
		_make_death_cell(grid, death)
	for defend: Array in DEFENDS:
		_make_fidget_cell(grid, defend)
	for fidget: Array in FIDGETS:
		_make_fidget_cell(grid, fidget)
	get_viewport().size_changed.connect(_fit.bind(grid))
	_fit(grid)
	_finish()


## Крупные квадраты по ширине окна, остальное прокручивается.
func _fit(grid: GridContainer) -> void:
	var width := get_viewport_rect().size.x
	grid.columns = clampi(floori((width - GAP) / (CELL_TARGET + GAP)), 1, columns)
	var side := maxi(90, floori((width - GAP * (grid.columns + 1)) / grid.columns) - 6)
	for pair: Array in _views:
		pair[0].custom_minimum_size = Vector2.ONE * side


## Подписи длинные: переносим по словам, иначе они распирают квадрат и сетка вылезает за окно.
func _make_label(frame: Control) -> Label:
	var label := super._make_label(frame)
	label.add_theme_font_size_override("font_size", 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	return label


func _make_rider_cell(grid: GridContainer, clip: Array, with_lance := false) -> void:
	var cell := _make_frame(grid, 3.1 if not with_lance else 4.2)
	var view: SubViewport = cell.view
	var mount := Node3D.new()
	view.add_child(mount)
	MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance: MeshInstance3D = MOCK.add_lance(mount) if with_lance else null
	if with_lance and LANCE_DAMP.has(clip[1]):
		MOCK.damp_clip(rider, clip[1], LANCE_DAMP[clip[1]])
	_make_label(cell.frame).text = clip[0] + (" с копьём" if with_lance else "")
	var hand := "mixamorig_LeftHand" if clip[1] in LEFT_HAND_CLIPS else "mixamorig_RightHand"
	_repeat(rider, clip[1], lance, mount, hand)


func _repeat(rider: Creature, clip: String, lance: MeshInstance3D = null, mount: Node3D = null, hand := "mixamorig_RightHand") -> void:
	var length := rider.anim.get_animation(clip).length
	while true:
		rider.anim.play(clip, 0.0)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		if lance == null:
			await get_tree().create_timer(length).timeout
		else:
			var local := MOCK.calibrate_hand_lance(rider, mount, hand)
			var left := length
			while left > 0.0:
				MOCK.place_hand_lance(lance, rider, local, hand, mount)
				await get_tree().process_frame
				left -= get_process_delta_time()
		await get_tree().create_timer(HOLD).timeout


func _make_ride_cell(grid: GridContainer, gait: Array) -> void:
	var cell := _make_frame(grid, 3.1)
	var view: SubViewport = cell.view
	var mount := Node3D.new()  # конь и всадник качаются вместе, всадник сидит в седле
	view.add_child(mount)
	var legs := MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = gait[0]
	if gait[1] in FROZEN_ARM:
		MOCK.freeze_bones(rider, gait[1], MOCK.RIGHT_ARM)
	rider.anim.get_animation(gait[1]).loop_mode = Animation.LOOP_LINEAR
	rider.anim.play(gait[1])
	rider.anim.advance(0.0)
	await get_tree().process_frame
	MOCK.sit(rider)
	var seat_y := rider.position.y
	var time := 0.0
	while is_instance_valid(mount):
		await get_tree().process_frame
		time += get_process_delta_time()
		var phase: float = time * gait[2] * TAU
		mount.position.y = absf(sin(phase)) * gait[3]
		mount.rotation.z = sin(phase) * deg_to_rad(1.5)
		# Всадник в седле движется вместе с конём; на рыси вдобавок мягко
		# привстаёт на каждый второй шаг — облегчённая рысь. Без клипа «спокойно сидит».
		var post: float = maxf(0.0, sin(phase * 0.5)) * gait[3] * 0.6 if gait[2] > 2.0 else 0.0
		rider.position.y = seat_y + post
		# Остриё запаздывает за толчком корпуса и чуть гуляет вбок.
		MOCK.place_lance(lance, rider, mount, sin(phase - 0.9) * gait[3] * 30.0, sin(phase * 0.5 + 0.4) * gait[3] * 12.0)
		for i in legs.size():
			# Диагональные пары ног движутся вместе, как у рыси.
			var pair := 1.0 if i == 0 or i == 3 else -1.0
			legs[i].rotation.z = sin(phase) * deg_to_rad(gait[4]) * pair


## Таранный удар: копьё неподвижно под рукой, бьёт разгон коня. Цель — столб.
const CHARGE_FROM := -3.4
const CHARGE_HIT := -1.2  # где корень коня, когда остриё доходит до столба
const CHARGE_TIME := 0.9
const CHARGE_BACK := 1.6


## Впритык разгона нет: конь делает короткий выпад на полшага, копьё под рукой, как в таране.
const HURT_LEN := 2.2
## Копьё под рукой: правая рука неподвижна во всех таких клипах, двигается остальное тело.
const FROZEN_ARM := ["ride_still", "ride_hurt", "ride_fidget_look", "ride_dodge",
	"s_piloting", "s_driving", "s_sitting_and_pointing_mirror", "s_sitting_victory_mirror", "s_beckoning_mirror",
	"s_ducking", "s_sitting_dodges", "s_shoved", "s_knocked_unconscious"]
const LUNGE := 0.5
const LUNGE_TIME := 0.35


func _make_charge_cell(grid: GridContainer, label := "Атака: таран копьём", from := CHARGE_FROM, run := CHARGE_TIME, gallop := 1.0) -> void:
	var cell := _make_frame(grid, 4.6)
	var view: SubViewport = cell.view
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 2.2, 0.3)
	post.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.2, 0.15)
	post.material_override = mat
	post.position = Vector3(CHARGE_HIT + 1.0 + MOCK.LANCE_LENGTH - MOCK.LANCE_BACK - 0.2, 1.1, 0.35)
	view.add_child(post)
	var mount := Node3D.new()
	view.add_child(mount)
	var legs := MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = label
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.anim.play("ride_still")
	rider.anim.advance(0.0)
	await get_tree().process_frame
	MOCK.sit(rider)
	var time := 0.0
	var placed := false
	while is_instance_valid(mount):
		await get_tree().process_frame
		var delta := get_process_delta_time()
		var back := CHARGE_BACK * (from - CHARGE_HIT) / (CHARGE_FROM - CHARGE_HIT)
		time = fmod(time + delta, run + 0.5 + back + 0.6)
		var x := from
		var speed := 0.0
		if time < run:
			var t := time / run
			x = lerpf(from, CHARGE_HIT, t * t)  # разгон
			speed = gallop
		elif time < run + 0.5:
			x = CHARGE_HIT  # удар и короткая остановка
			if not placed:
				# Столб ровно там, куда пришло остриё.
				var tip: Vector3 = lance.global_transform * Vector3(0, MOCK.LANCE_LENGTH * 0.5, 0)
				post.global_position = Vector3(tip.x + 0.15, 1.1, tip.z)
				placed = true
			post.rotation.z = -deg_to_rad(8.0 * gallop) * (1.0 - (time - run) / 0.5)
		elif time < run + 0.5 + back:
			x = lerpf(CHARGE_HIT, from, smoothstep(0.0, 1.0, (time - run - 0.5) / back))
			speed = 0.4
		mount.position.x = x
		var phase := time * 3.2 * TAU
		mount.position.y = absf(sin(phase)) * 0.08 * speed
		mount.rotation.z = sin(phase) * deg_to_rad(2.0) * speed
		for i in legs.size():
			var pair := 1.0 if i < 2 else -1.0  # галоп: передние и задние вместе
			legs[i].rotation.z = sin(phase) * deg_to_rad(32.0) * pair * speed
		var jolt := 0.0
		if time >= run and time < run + 0.5:
			# Отдача от удара: остриё дёргается вверх и затухает.
			var after := time - run
			jolt = 2.0 * gallop * exp(-after * 6.0) * cos(after * 14.0)  # тяжёлое копьё: малый размах, медленно
		MOCK.place_lance(lance, rider, mount, sin(phase - 0.9) * 2.6 * speed + jolt, sin(phase * 0.5 + 0.4) * 1.0 * speed)


## Смерть: сидячей нет. Кандидаты: выдернут с места пилота (тот же набор) и смерть из приседа.
## Всадник падает с коня на землю: сначала уходит вбок с седла, потом опускается.
## Подпись, клип, доли клипа начала и конца падения, сдвиг вбок (у «сдёрнут» клип сам уводит тело).
## «Из приседа» (ride_death_crouch, сдвиг вбок 1,15) отклонён пользователем, клип лежит в файлах.
const DEATHS := [["Смерть: сдёрнут с седла", "ride_death_pulled", 0.15, 0.6, 0.0]]


func _make_death_cell(grid: GridContainer, death: Array) -> void:
	var cell := _make_frame(grid, 3.4)
	var view: SubViewport = cell.view
	var mount := Node3D.new()
	view.add_child(mount)
	MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	_make_label(cell.frame).text = death[0]
	var clip: String = death[1]
	var length := rider.anim.get_animation(clip).length
	while is_instance_valid(rider):
		# Повтор витрины: лежащего не тащим обратно в седло на глазах — прячем, сажаем, показываем.
		rider.visible = false
		rider.anim.speed_scale = 1.0
		rider.anim.play("ride_still", 0.0)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		await get_tree().process_frame
		rider.visible = true
		var seat := rider.position
		await get_tree().create_timer(1.0).timeout
		rider.anim.play(clip, 0.2)
		var time := 0.0
		while time < length + 1.2:
			await get_tree().process_frame
			time += get_process_delta_time()
			# Лежит до конца паузы: клип не доигрываем до конца, иначе Creature сам ставит стойку
			# и мёртвый на секунду садится на землю.
			if time >= length - 0.05 and rider.anim.speed_scale > 0.0:
				rider.anim.seek(length - 0.05, true)
				rider.anim.speed_scale = 0.0
			var t := clampf((time / length - death[2]) / (death[3] - death[2]), 0.0, 1.0)
			var side := smoothstep(0.0, 0.45, t)
			var drop := clampf((t - 0.3) / 0.7, 0.0, 1.0)
			rider.position = Vector3(seat.x, lerpf(seat.y, 0.0, drop * drop), seat.z + death[4] * side)


## Отклик при наведении — кандидаты из сидячего набора, копьё лежит под рукой, как в стойке.
## Защита — кандидаты из сидячего набора. Копьё держится в руке: идёт за кистью, лежит вдоль коня.
## Выбор пользователя: «уклон вправо»; блок сверху (ride_block) лежит в файлах.
const DEFENDS := [["Защита: уклон вправо", "ride_dodge"]]
## Выбор пользователя: отклик — «осматривается». Клич и «воткнуть копьё» (_make_plant_cell) не используются.
const FIDGETS := [["Отклик: осматривается", "ride_fidget_look"]]
## Отклик «воткнуть копьё и крикнуть»: копьё поворачивается в кисти остриём вверх и древком
## втыкается в землю у правого бока коня, всадник кричит, потом берёт копьё обратно.
const PLANT_TIME := 0.7
const PLANT_SIDE := 0.25  # насколько дальше кисти от коня встаёт копьё
const PLANT_DEPTH := 0.12  # насколько древко уходит в землю


func _make_fidget_cell(grid: GridContainer, fidget: Array) -> void:
	var cell := _make_frame(grid, 4.2)
	var view: SubViewport = cell.view
	var mount := Node3D.new()
	view.add_child(mount)
	MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = fidget[0]
	var clip: String = fidget[1]
	if clip in FROZEN_ARM:
		MOCK.freeze_bones(rider, clip, MOCK.RIGHT_ARM)
	# Третье поле — сколько секунд клипа играть, дальше плавно в стойку; четвёртое — с какой секунды.
	var length: float = fidget[2] if fidget.size() > 2 else rider.anim.get_animation(clip).length
	var from: float = fidget[3] if fidget.size() > 3 else 0.0
	while is_instance_valid(rider):
		rider.anim.play(clip, 0.2)
		if from > 0.0:
			rider.anim.seek(from, true)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		var left := length + HOLD
		var back := false
		while left > 0.0:
			if not back and left <= HOLD and fidget.size() > 2:
				rider.anim.play("ride_still", 0.4)
				back = true
			MOCK.place_lance(lance, rider, mount)
			await get_tree().process_frame
			left -= get_process_delta_time()


func _make_plant_cell(grid: GridContainer) -> void:
	var cell := _make_frame(grid, 4.4)
	var view: SubViewport = cell.view
	var mount := Node3D.new()
	view.add_child(mount)
	MOCK.build_horse(mount)
	var rider := MOCK.make_rider(mount)
	var lance := MOCK.add_lance(mount)
	_make_label(cell.frame).text = "Отклик: втыкает копьё и кричит"
	var yell := rider.anim.get_animation("ride_fidget_yell").length
	while is_instance_valid(rider):
		rider.anim.play("ride_still", 0.2)
		rider.anim.advance(0.0)
		await get_tree().process_frame
		MOCK.sit(rider)
		await _hold_couched(lance, rider, mount, 1.2)
		# Втыкает: из-под руки — вертикально, древком в землю у бока коня.
		var start := lance.global_transform
		var hand: Vector3 = rider.bone_world(rider.skeleton.find_bone("mixamorig_RightHand"))
		var side: Vector3 = mount.global_basis * Vector3(0, 0, 1)
		var butt := Vector3(hand.x, -PLANT_DEPTH, hand.z) + side * PLANT_SIDE
		var planted := Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), butt + Vector3.UP * MOCK.LANCE_LENGTH * 0.5)
		await _move_lance(lance, start, planted, PLANT_TIME, true)
		rider.anim.play("ride_fidget_yell", 0.25)
		await get_tree().create_timer(yell).timeout
		rider.anim.play("ride_still", 0.3)
		await get_tree().create_timer(0.3).timeout
		# Берёт обратно и укладывает под руку.
		MOCK.place_lance(lance, rider, mount)
		var back := lance.global_transform
		lance.global_transform = planted
		await _move_lance(lance, planted, back, PLANT_TIME, false)
		await _hold_couched(lance, rider, mount, HOLD)


func _hold_couched(lance: MeshInstance3D, rider: Creature, mount: Node3D, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		MOCK.place_lance(lance, rider, mount)
		await get_tree().process_frame
		left -= get_process_delta_time()


## Плавный перенос копья; в конце втыкания — короткий толчок вниз, будто вошло в землю.
func _move_lance(lance: MeshInstance3D, from: Transform3D, to: Transform3D, seconds: float, stab: bool) -> void:
	var time := 0.0
	while time < seconds:
		await get_tree().process_frame
		time += get_process_delta_time()
		var t := smoothstep(0.0, 1.0, minf(time / seconds, 1.0))
		var basis := Basis(from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t))
		var origin := from.origin.lerp(to.origin, t)
		if stab and t > 0.8:
			origin.y -= sin((t - 0.8) / 0.2 * PI) * 0.05
		lance.global_transform = Transform3D(basis, origin)
	lance.global_transform = to

