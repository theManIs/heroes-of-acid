extends "res://scenes/showcase.gd"
## Три набора по восемь анимаций: псарь, собака, оба вместе.
## Запуск: godot --path game res://scenes/houndmaster_showcase.tscn
## Кадр раздела: -- --section=pair --shot=<префикс> (master, hound, pair).

const HOUND_LAB := preload("res://scenes/hound_lab.gd")
const HOLD := 1.0
const PAIR_CAMERA_SIZE := 2.9
const CLIPS := [
	["Стойка", "idle", true], ["Ходьба", "walk", true], ["Бег", "run", true],
	["Команда «фас»", "command_attack", false],
	["Реакция на удар", "hurt", false], ["Защита", "defend", false],
	["Смерть", "fall", false], ["Отклик: погладить", "fidget_pet", false],
]

var _petters: Array[Dictionary] = []


func _ready() -> void:
	columns = 1
	cell_size = 380
	var page := _build_page()
	var headers := {}
	for section: Array in [["master", "Псарь"], ["hound", "Собака"], ["pair", "Вместе"]]:
		var heading := Label.new()
		heading.text = section[1]
		heading.add_theme_font_size_override("font_size", 30)
		page.add_child(heading)
		headers[section[0]] = heading
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		page.add_child(grid)
		for i in CLIPS.size():
			if section[0] == "master":
				_make_master_cell(grid, CLIPS[i][0], CLIPS[i][1], CLIPS[i][2])
			elif section[0] == "hound":
				_make_hound_cell(grid, HOUND_LAB.CLIPS[i])
			else:
				_make_pair_cell(grid, i)
	await get_tree().process_frame
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			var section := arg.trim_prefix("--section=")
			if headers.has(section):
				var scroll: ScrollContainer = page.get_parent().get_parent().get_parent()
				scroll.scroll_vertical = int(headers[section].position.y)
	_finish()


func _make_master(view: SubViewport) -> Creature:
	var cfg: Dictionary = NEW_CREATURES["houndmaster"]
	var unit := Creature.new()
	view.add_child(unit)
	unit.setup(load(cfg.scene), cfg.extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	unit.defend_anim = cfg.defend
	return unit


func _make_hound(view: SubViewport) -> Dictionary:
	var model: Node3D = load(HOUND_LAB.HOUND).instantiate()
	view.add_child(model)
	var box: AABB = model.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
	var fit: float = HOUND_LAB.HEIGHT / box.size.y
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.get_animation(HOUND_LAB.IDLE).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(func(clip: StringName):
		if clip != &"death_fall_on_side":
			player.play(HOUND_LAB.IDLE, 0.2)
	)
	player.play(HOUND_LAB.IDLE)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	return {"model": model, "player": player, "skeleton": skeleton}


func _make_master_cell(grid: GridContainer, title: String, clip: String, endless: bool) -> void:
	var cell := _make_frame(grid, NEW_CREATURES.houndmaster.size)
	if clip == "fall":
		_reframe(cell.view, 2.3, 0.8)
	var unit := _make_master(cell.view)
	unit.face(unit.position + Vector3.BACK + Vector3.RIGHT)
	_make_label(cell.frame).text = title
	if endless:
		unit.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		unit.anim.play(clip)
	else:
		_repeat_master(unit, clip)


func _make_hound_cell(grid: GridContainer, clip: Array) -> void:
	var cell := _make_frame(grid, 1.9)  # запас для вытянутого тела при падении
	_reframe(cell.view, 1.9, HOUND_LAB.HEIGHT * 0.5)
	var hound := _make_hound(cell.view)
	_make_label(cell.frame).text = clip[0]
	if clip[2]:
		hound.player.get_animation(clip[1]).loop_mode = Animation.LOOP_LINEAR
		hound.player.play(clip[1])
	else:
		_repeat_hound(hound.player, clip[1])


func _make_pair_cell(grid: GridContainer, index: int) -> void:
	var cell := _make_frame(grid, PAIR_CAMERA_SIZE)
	_reframe(cell.view, PAIR_CAMERA_SIZE, 1.0)
	var unit := _make_master(cell.view)
	unit.position = Vector3(0.45, 0, 0)
	unit.face(unit.position + Vector3.BACK)
	var hound := _make_hound(cell.view)
	hound.model.position += Vector3(-0.45, 0, -0.4)
	var title: String = CLIPS[index][0]
	if index == 3:
		title = "Команда и укус"
	elif index == 7:
		title = "Поглаживание"
		_add_petting_target(cell.view, unit, hound)
	_make_label(cell.frame).text = title
	_repeat_pair(unit, hound.player, index)


func _reframe(view: SubViewport, frame_size: float, center_y: float) -> void:
	for child in view.get_children():
		if child is Camera3D:
			var look := Vector3(0, center_y, 0)
			child.position = look + CAMERA_DIR.normalized() * frame_size * FRAME * 0.5 / tan(deg_to_rad(CAMERA_FOV * 0.5))
			child.look_at(look)
		elif child is MeshInstance3D and child.mesh is PlaneMesh:
			child.mesh.size = Vector2.ONE * 200.0


func _repeat_master(unit: Creature, clip: String) -> void:
	while true:
		unit.dead = clip == "fall"
		unit.anim.play(clip, 0.2)
		await get_tree().create_timer(unit.anim.get_animation(clip).length).timeout
		if clip == "fall":
			await get_tree().create_timer(HOLD).timeout
		unit.dead = false
		unit.anim.play("idle", 0.3)
		await get_tree().create_timer(HOLD).timeout


func _repeat_hound(player: AnimationPlayer, clip: String) -> void:
	while true:
		player.play(clip, 0.2)
		await get_tree().create_timer(player.get_animation(clip).length).timeout
		if clip == "death_fall_on_side":
			await get_tree().create_timer(HOLD).timeout
		player.play(HOUND_LAB.IDLE, 0.3)
		await get_tree().create_timer(HOLD).timeout


func _repeat_pair(unit: Creature, dog: AnimationPlayer, index: int) -> void:
	var master_clip: String = CLIPS[index][1]
	var dog_clip: String = HOUND_LAB.CLIPS[index][1]
	var master_time: float = unit.anim.get_animation(master_clip).length
	if CLIPS[index][2]:
		unit.anim.get_animation(master_clip).loop_mode = Animation.LOOP_LINEAR
		dog.get_animation(dog_clip).loop_mode = Animation.LOOP_LINEAR
		# Обоим один период ходьбы/бега: повторяются вместе без накопления сдвига.
		dog.speed_scale = dog.get_animation(dog_clip).length / master_time
		unit.anim.play(master_clip)
		dog.play(dog_clip)
		return
	while true:
		unit.dead = master_clip == "fall"
		unit.anim.play(master_clip, 0.2)
		if index == 3:
			# Сначала псарь указывает цель, затем собака бросается вперёд.
			var lead := master_time * 0.35
			await get_tree().create_timer(lead).timeout
			dog.play(dog_clip, 0.15)
			await get_tree().create_timer(maxf(master_time - lead, dog.get_animation(dog_clip).length)).timeout
		elif index == 7:
			# Принимает поглаживание стоя, а не нюхает землю.
			dog.play(HOUND_LAB.IDLE, 0.2)
			await get_tree().create_timer(master_time).timeout
		else:
			dog.play(dog_clip, 0.2)
			await get_tree().create_timer(maxf(master_time, dog.get_animation(dog_clip).length)).timeout
		if unit.dead:
			await get_tree().create_timer(HOLD).timeout
		unit.dead = false
		unit.anim.play("idle", 0.3)
		dog.play(HOUND_LAB.IDLE, 0.3)
		await get_tree().create_timer(HOLD).timeout


func _add_petting_target(view: SubViewport, unit: Creature, hound: Dictionary) -> void:
	var target := Node3D.new()
	view.add_child(target)
	var ik := SkeletonIK3D.new()
	ik.root_bone = &"mixamorig_RightArm"
	ik.tip_bone = &"mixamorig_RightHand"
	ik.override_tip_basis = false
	unit.skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.influence = 0.0
	ik.start()
	_petters.append({"unit": unit, "dog": hound.skeleton, "head": hound.skeleton.find_bone("Head"), "target": target, "ik": ik})


func _process(delta: float) -> void:
	super._process(delta)
	for pair in _petters:
		var unit: Creature = pair.unit
		var dog: Skeleton3D = pair.dog
		var head: Vector3 = dog.global_transform * dog.get_bone_global_pose(pair.head).origin
		var time := unit.anim.current_animation_position
		pair.target.global_position = head + Vector3(0, 0.08, sin(time * 3.0) * 0.06)
		var weight := 0.0
		if unit.anim.current_animation == &"fidget_pet":
			var length := unit.anim.get_animation("fidget_pet").length
			weight = smoothstep(0.5, 1.5, time) * (1.0 - smoothstep(length - 1.2, length - 0.2, time))
		pair.ik.influence = weight
