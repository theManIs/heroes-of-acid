extends SceneTree
## Автопроверка существа-гуманоида на скелете Mixamo (задача 182). Ловит ошибки из ERRORS.md
## замером костей, без окна и без пользователя. Запуск из корня репозитория:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
##     --script "$PWD/pipelines/creature-mixamo-first/check_clips.gd" -- --id=<существо> [--clips=a,b] [--extra=res://…glb,…] [--verbose=1]
##   …или кандидаты на манекене: -- --set=<существо> (creatures/<id>/mixamo/candidates.json)
## Существо берётся из записей арены (CREATURES в creature_test.gd, конфиги молотобойца, псаря).
## Итог: строки «ОК / ПРОВАЛ / ВНИМАНИЕ» с номером ошибки из ERRORS.md; код выхода 1 при провале.

const ARENA := preload("res://scenes/creature_test.gd")
const HEX_RADIUS := 0.6
const SAMPLES := 40
## Обязательный набор клипов гуманоида (имена в игре).
const REQUIRED := ["idle", "walk", "attack", "hurt", "defend", "fall", "fidget"]
const LOCOMOTION := ["walk", "run"]
## Пороги для роста 1,8 м, откалиброваны на принятых существах (молотобоец, фонарщик, псарь):
## берётся их наибольшее значение с запасом. Числа — в README пайплайна.
const LIMITS := {"hip": 0.2, "slide": 0.3, "below": 0.05, "wrist": 90.0, "palms": 0.15, "gap": 0.03, "seam": 0.06, "facing": 30.0, "reach_out": 0.75}

var _fails := 0
var _warns := 0
var _c: Creature
var _sk: Skeleton3D
var _h := 1.8  # рост


func _initialize() -> void:
	_run.call_deferred()


func _configs() -> Dictionary:
	var all: Dictionary = ARENA.CREATURES.duplicate()
	all["houndmaster"] = load("res://scenes/houndmaster_config.gd").MASTER
	return all


func _arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return fallback


func _report(level: String, code: String, text: String) -> void:
	print("%s  [%s] %s" % [level, code, text])
	if level == "ПРОВАЛ":
		_fails += 1
	elif level == "ВНИМАНИЕ":
		_warns += 1


## Режим манекена (--set=<id>): кандидаты из creatures/<id>/mixamo/candidates.json, тело манекена,
## все собранные клипы и заглушки оружия — отсеять кандидатов до показа пользователю.
func _mannequin(id: String) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join("../creatures/%s/mixamo/candidates.json" % id)
	if not FileAccess.file_exists(path):
		return {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var extra := []
	var cells := []
	for cell: Array in data.get("cells", []):
		extra.append("res://assets/creatures/%s/anims/%s.glb" % [id, cell[1]])
		cells.append(cell[1])
		if cell.size() > 3 and not extra.has("res://assets/creatures/%s/anims/%s.glb" % [id, cell[3]]):
			extra.append("res://assets/creatures/%s/anims/%s.glb" % [id, cell[3]])
	var idle: String = data.get("idle", "idle")
	if not cells.has(idle):
		extra.append("res://assets/creatures/%s/anims/%s.glb" % [id, idle])
	return {"scene": data.get("body", "res://assets/mannequin/xbot.glb"), "extra": extra, "attack": cells[0],
		"hurt": "", "size": data.get("size", 1.8), "attack_from": 0.0, "idle": idle, "props": data.get("props", []),
		"cells": cells, "weapon_face": data.get("weapon_face", {})}


func _run() -> void:
	var id := _arg("id")
	var cfgs := _configs()
	if _arg("set") != "":
		id = _arg("set")
		cfgs[id] = _mannequin(id)
	if not cfgs.has(id):
		print("нет существа ", id, "; есть: ", cfgs.keys())
		quit(2)
		return
	var cfg: Dictionary = cfgs[id]
	var holder := Node3D.new()
	root.add_child(holder)
	_c = Creature.new()
	holder.add_child(_c)
	var extra: Array = cfg.get("extra", []).duplicate()
	if _arg("extra") != "":
		extra.append_array(_arg("extra").split(","))  # пробные клипы-кандидаты сверх записи
	_c.setup(load(cfg.scene), extra, cfg.attack, cfg.hurt, cfg.size, cfg.attack_from, cfg.idle)
	for prop: Dictionary in cfg.get("props", []):
		var grip: Node3D = load("res://scenes/weapon_grip.gd").new()
		for key in prop:
			grip.set(key, prop[key])
		_c.model.add_child(grip)
	await process_frame
	await process_frame
	_h = _c.height
	_sk = _c.model.find_children("*", "Skeleton3D", true, false)[0]
	print("== ", id, ": рост ", snappedf(_h, 0.01), ", костей ", _sk.get_bone_count())
	if _sk.find_bone("mixamorig_Hips") < 0:
		_report("ПРОВАЛ", "E01", "скелет не Mixamo: проверка рассчитана на кости mixamorig_*")
		quit(1)
		return
	var mannequin := cfg.has("cells")
	if not mannequin:
		_check_assets(cfg)
		_check_required(cfg)
	_check_rest_legs()
	var clips := _arg("clips")
	var names: Array = Array(clips.split(",")) if clips != "" else (cfg.cells if mannequin else _game_clips(cfg))
	for clip: String in names:
		if _c.anim.has_animation(clip):
			_check_clip(clip, cfg)
	_check_weapon_face(cfg)
	if not mannequin:
		_check_footprint()
	print("== итог: провалов %d, внимания %d" % [_fails, _warns])
	quit(1 if _fails > 0 else 0)


## Клипы, которые игра реально играет: роли записи, режимы ближнего боя и выстрелы.
func _game_clips(cfg: Dictionary) -> Array:
	var out := []
	for clip in [cfg.get("idle", "idle"), "walk", "run", cfg.attack, cfg.hurt, cfg.get("defend", ""), "fall", cfg.get("fidget", "")]:
		if clip != "" and not out.has(clip):
			out.append(clip)
	for mode: Dictionary in cfg.get("melee_modes", {}).values():
		if not out.has(mode.anim):
			out.append(mode.anim)
	for shot: Dictionary in cfg.get("shots", {}).values():
		if not out.has(shot.anim):
			out.append(shot.anim)
	return out


# --- кости -----------------------------------------------------------------

func _p(bone: String) -> Vector3:
	var i := _sk.find_bone("mixamorig_" + bone)
	return (_sk.global_transform * _sk.get_bone_global_pose(i)).origin if i >= 0 else Vector3.INF


func _palm(side: String) -> Vector3:
	return _p(side + "Hand").lerp(_p(side + "HandMiddle1"), 0.75)


func _pose(clip: String, t: float) -> void:
	_c.anim.play(clip)
	_c.anim.seek(t, true)
	_c.anim.speed_scale = 0.0
	_sk.force_update_all_bone_transforms()
	# Хваты оружия (hammer_grip и подобные) ставят модель оружия в своём _process.
	for n in _c.find_children("*", "Node3D", true, false):
		if n.get_script() and n.has_method("_process") and not n is Creature:
			n._process(0.0)


## Неподвижные меши без кожи под существом — оружие и щиты (отдельные модели).
func _weapons() -> Array:
	var out := []
	for mi: MeshInstance3D in _c.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null and mi.is_visible_in_tree():
			out.append(mi)
	return out


## Отрезок вдоль длинной оси меша в мире.
func _segment(mi: MeshInstance3D) -> Array:
	var box := mi.get_aabb()
	var axis := 0
	for k in 3:
		if box.size[k] > box.size[axis]:
			axis = k
	var a := box.get_center()
	var b := a
	a[axis] = box.position[axis]
	b[axis] = box.end[axis]
	return [mi.global_transform * a, mi.global_transform * b]


func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- проверки ---------------------------------------------------------------

func _check_assets(cfg: Dictionary) -> void:
	var tris := 0
	for mi: MeshInstance3D in _c.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
	if String(cfg.scene).contains("mannequin"):
		_report("ОК", "E02", "манекен (%d треугольников) — проверка сетки после модели" % tris)
	elif tris > 20000:
		_report("ПРОВАЛ", "E02", "треугольников тела %d > 20 000" % tris)
	else:
		_report("ОК", "E02", "треугольников тела %d" % tris)


func _check_required(cfg: Dictionary) -> void:
	var names := {"idle": cfg.get("idle", "idle"), "walk": "walk", "attack": cfg.attack, "hurt": cfg.hurt,
		"defend": cfg.get("defend", ""), "fall": "fall", "fidget": cfg.get("fidget", "")}
	var missing := []
	for role: String in REQUIRED:
		var clip: String = names[role]
		if clip == "" or not _c.anim.has_animation(clip):
			missing.append(role)
	if missing.is_empty():
		_report("ОК", "E03", "полный набор клипов")
	else:
		_report("ПРОВАЛ", "E03", "нет клипов: " + ", ".join(missing))
	if not _c.anim.has_animation("run"):
		_report("ВНИМАНИЕ", "E03", "нет бега: длинный путь пойдёт шагом (118)")


## E04: бёдра в покое разведены сильнее Mixamo — стойка выйдет широкой (псарь, 123).
func _check_rest_legs() -> void:
	var worst := 0.0
	for side in ["Left", "Right"]:
		var i := _sk.find_bone("mixamorig_%sUpLeg" % side)
		var j := _sk.find_bone("mixamorig_%sLeg" % side)
		var a := (_sk.get_bone_global_rest(i)).origin
		var b := (_sk.get_bone_global_rest(j)).origin
		worst = maxf(worst, rad_to_deg((b - a).normalized().angle_to(Vector3.DOWN)))
	if worst > 12.0:
		_report("ВНИМАНИЕ", "E04", "бёдра в покое разведены на %d° (Mixamo ~5°): `_match_leg_rest: true`" % int(worst))
	else:
		_report("ОК", "E04", "бёдра в покое %d°" % int(worst))


func _check_clip(clip: String, cfg: Dictionary) -> void:
	var len := _c.anim.get_animation(clip).length
	var k := _h / 1.8  # пороги заданы для роста 1,8 м
	var hips0 := Vector3.ZERO
	var hip_travel := 0.0
	var slide := 0.0  # наибольший сдвиг стопы за одну фазу опоры
	var below := 0.0
	var wrist := 0.0
	var wrist_t := 0.0
	var gap := INF  # ближе всего оружие к костям корпуса и бёдер
	var gap_t := 0.0
	var spans: Array[float] = []
	var facing := 0.0  # средний разворот груди от «вперёд» (+X модели), градусы
	var reach_out := -INF  # дальше всего вперёд оружие и щит от центра гекса
	var contact := {}
	var weapons := _weapons()
	var first := {}
	var last := {}
	for i in SAMPLES + 1:
		var t := len * i / SAMPLES
		_pose(clip, t)
		var hips := _p("Hips")
		if i == 0:
			hips0 = hips
		hip_travel = maxf(hip_travel, Vector2(hips.x - hips0.x, hips.z - hips0.z).length())
		for foot in ["LeftToeBase", "RightToeBase"]:
			var p := _p(foot)
			below = minf(below, p.y)
			if p.y < 0.06 * k:
				if not contact.has(foot):
					contact[foot] = p
				slide = maxf(slide, Vector2(p.x - contact[foot].x, p.z - contact[foot].z).length())
			else:
				contact.erase(foot)
		var chest := Vector3.UP.cross(_p("RightShoulder") - _p("LeftShoulder"))
		facing += absf(rad_to_deg(atan2(chest.z, chest.x))) / (SAMPLES + 1)
		for side in ["Left", "Right"]:
			var fore := (_p(side + "Hand") - _p(side + "ForeArm")).normalized()
			var hand := (_p(side + "HandMiddle1") - _p(side + "Hand")).normalized()
			var bend := rad_to_deg(fore.angle_to(hand))
			if bend > wrist:
				wrist = bend
				wrist_t = t
		for mi: MeshInstance3D in weapons:
			var box := mi.get_aabb()
			for c in 8:
				reach_out = maxf(reach_out, (mi.global_transform * (box.position + box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))).x)
			var seg := _segment(mi)
			if mi == weapons[0] and _dist_to_segment(_palm("Left"), seg[0], seg[1]) < 0.1 * k \
					and _dist_to_segment(_palm("Right"), seg[0], seg[1]) < 0.1 * k:
				spans.append(_palm("Left").distance_to(_palm("Right")))
			for j in range(1, 8):
				var q: Vector3 = seg[0].lerp(seg[1], j / 8.0)
				for pair in [["Hips", "Spine2"], ["Spine2", "Neck"], ["LeftUpLeg", "LeftLeg"], ["RightUpLeg", "RightLeg"]]:
					var d := _dist_to_segment(q, _p(pair[0]), _p(pair[1]))
					if d < gap:
						gap = d
						gap_t = t
		var snap := {}
		for bone in ["Hips", "LeftHand", "RightHand", "Head", "LeftFoot", "RightFoot"]:
			snap[bone] = _p(bone)
		if i == 0:
			first = snap
		last = snap
	var jump := 0.0
	for bone in first:
		if not (bone == "Hips" and _moving(clip)):
			jump = maxf(jump, first[bone].distance_to(last[bone]))
	var span_range: float = (spans.max() - spans.min()) if spans.size() > 2 else 0.0
	var tag := "%s (%.2f с)" % [clip, len]
	if _arg("verbose") != "":
		print("      %s: таз %.2f, стопа %.2f, низ %.2f, кисть %d°, ладони %.2f (%d кадров), оружие %.2f, шов %.2f" % [
			tag, hip_travel / k, slide / k, below / k, int(wrist), span_range / k, spans.size(), gap / k, jump / k])
	var before := _fails + _warns
	var standing := not _moving(clip) and not clip.contains("fall") and not clip.contains("death")
	var dodge: bool = clip == cfg.get("defend", "") and not cfg.get("defend_pin", true)  # уклон уводит тело намеренно
	if standing and not dodge and hip_travel > LIMITS.hip * k:
		_report("ВНИМАНИЕ", "E05", "%s: таз уходит на %.2f м — клип таскает тело" % [tag, hip_travel])
	if standing and not dodge and slide > LIMITS.slide * k:
		_report("ВНИМАНИЕ", "E06", "%s: опорная стопа проезжает %.2f м" % [tag, slide])
	if below < -LIMITS.below * k and not clip.contains("fall"):
		_report("ПРОВАЛ", "E07", "%s: стопа под землёй на %.2f м" % [tag, -below])
	if wrist > LIMITS.wrist:
		_report("ВНИМАНИЕ", "E08", "%s: кисть согнута на %d° к предплечью в %.2f с" % [tag, int(wrist), wrist_t])
	if span_range > LIMITS.palms * k:
		_report("ПРОВАЛ", "E09", "%s: обе руки на древке, расстояние между ладонями гуляет на %.2f м — оружие катается" % [tag, span_range])
	if gap < LIMITS.gap * k and standing:
		_report("ВНИМАНИЕ", "E10", "%s: оружие в %.2f м от оси корпуса или бедра в %.2f с — проходит сквозь тело" % [tag, gap, gap_t])
	# E15: стоит или ходит боком — грудь в стойке и на ходу развёрнута от направления (модель смотрит по +X).
	if (clip == cfg.get("idle", "idle") or _moving(clip)) and facing > LIMITS.facing:
		_report("ВНИМАНИЕ", "E15", "%s: грудь развёрнута на %d° от «вперёд» — стоит или ходит боком" % [tag, int(facing)])
	# E16: оружие или щит выходит вперёд за свой гекс дальше допуска в стоячих клипах — залезает в соседа.
	var attacks: Array = [cfg.attack] + cfg.get("melee_modes", {}).values().map(func(m): return m.anim)
	if standing and not clip in attacks and reach_out > LIMITS.reach_out * k:  # удар должен доставать цель
		_report("ВНИМАНИЕ", "E16", "%s: оружие или щит на %.2f м вперёд от центра гекса — залезает в соседа (forward_limit)" % [tag, reach_out])
	if (clip == cfg.get("idle", "idle") or _moving(clip)) and jump > LIMITS.seam * k:
		_report("ПРОВАЛ", "E11", "%s: шов цикла, скачок %.2f м" % [tag, jump])
	if _fails + _warns == before:
		print("ОК    [клип] ", tag)


## E13: куда смотрит рабочая сторона оружия в стойке. В записи существа
## "weapon_face": {"axis": локальная ось стороны в модели оружия, "idle": "out"} — «от владельца» (171).
func _check_weapon_face(cfg: Dictionary) -> void:
	var face: Dictionary = cfg.get("weapon_face", {})
	var weapons := _weapons()
	if face.is_empty() or weapons.is_empty():
		if not weapons.is_empty():
			_report("ВНИМАНИЕ", "E13", "есть отдельное оружие, но нет `weapon_face` в записи — поворот не проверен")
		return
	_pose(cfg.get("idle", "idle"), 0.0)
	var mi: MeshInstance3D = weapons[0]
	var seg := _segment(mi)
	var palm := _palm("Right")
	var head: Vector3 = seg[0] if seg[0].distance_to(palm) > seg[1].distance_to(palm) else seg[1]
	var shaft: Vector3 = (seg[1] - seg[0]).normalized()
	var axis: Vector3 = (mi.global_basis.orthonormalized() * face.axis).normalized()
	var out := head - _p("Spine2")
	out = (out - shaft * out.dot(shaft)).normalized()
	var flat := (axis - shaft * axis.dot(shaft)).normalized()
	var angle := rad_to_deg(flat.angle_to(out))
	if angle > 45.0:
		_report("ПРОВАЛ", "E13", "в стойке рабочая сторона оружия отклонена от «наружу» на %d° — поворот в кисти (HEAD_ROLL)" % int(angle))
	else:
		_report("ОК", "E13", "в стойке рабочая сторона оружия наружу, отклонение %d°" % int(angle))


## Шаг и бег: в режиме манекена у кандидатов имена вида c_walk_*, c_run_*.
func _moving(clip: String) -> bool:
	return clip in LOCOMOTION or clip.contains("walk") or clip.contains("run")


## E12: фигура в стойке вписывается в свой гекс.
func _check_footprint() -> void:
	_pose(_c.anim.get_animation_list()[0] if not _c.anim.has_animation("idle") else "idle", 0.0)
	var pts: Array[Vector3] = []
	for i in _sk.get_bone_count():
		pts.append((_sk.global_transform * _sk.get_bone_global_pose(i)).origin)
	var hips := _p("Hips")
	var reach := 0.0
	for p in pts:
		reach = maxf(reach, Vector2(p.x - hips.x, p.z - hips.z).length())
	var inner := HEX_RADIUS * sqrt(3.0) / 2.0
	if reach > inner * 1.35:
		_report("ВНИМАНИЕ", "E12", "в стойке кости выходят на %.2f м от таза при гексе %.2f — фигура вылезает за гекс (175)" % [reach, inner])
	else:
		_report("ОК", "E12", "в стойке до %.2f м от таза, гекс %.2f" % [reach, inner])
