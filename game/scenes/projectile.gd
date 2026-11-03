class_name Projectile
extends Node3D
## Снаряд дальней атаки: летит по дуге от руки к цели. Стрела и брошенный фонарь рисуются простыми формами.

const LANTERN_COLOR := Color(1.0, 0.55, 0.12)

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _arc := 0.0
var _spin := false


## kind: "arrow" или "lantern". Удаляет себя по прилёте; фонарь разбивается вспышкой.
static func launch(parent: Node, kind: String, from: Vector3, to: Vector3, seconds: float, arc: float) -> void:
	var p := Projectile.new()
	parent.add_child(p)
	p._from = from
	p._to = to
	p._arc = arc
	p._spin = kind == "lantern"
	if kind == "lantern":
		p._build_lantern()
	else:
		p._build_arrow()
	p.global_position = from
	var tween := p.create_tween()
	tween.tween_method(p._fly, 0.0, 1.0, seconds)
	tween.tween_callback(p._land.bind(kind))


func _at(t: float) -> Vector3:
	return _from.lerp(_to, t) + Vector3.UP * _arc * 4.0 * t * (1.0 - t)


func _fly(t: float) -> void:
	var here := _at(t)
	if _spin:
		rotate_x(0.25)
		global_position = here
		return
	var ahead := _at(minf(t + 0.02, 1.0)) - here
	global_position = here
	if ahead.length() > 0.001:
		look_at(here + ahead)


func _land(kind: String) -> void:
	if kind == "lantern":
		_burst()
	queue_free()


func _material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.2
	return mat


## Стрела лежит вдоль -Z: так её разворачивает look_at.
func _build_arrow() -> void:
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.012
	cylinder.bottom_radius = 0.012
	cylinder.height = 0.7
	shaft.mesh = cylinder
	shaft.material_override = _material(Color(0.45, 0.28, 0.14))
	shaft.rotation_degrees.x = 90.0
	add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.03
	cone.height = 0.09
	head.mesh = cone
	head.material_override = _material(Color(0.75, 0.75, 0.78))
	head.rotation_degrees.x = -90.0
	head.position.z = -0.39
	add_child(head)
	var feather := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.005, 0.14)
	feather.mesh = box
	feather.material_override = _material(Color(0.95, 0.93, 0.88))
	feather.position.z = 0.3
	add_child(feather)


func _build_lantern() -> void:
	var glass := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.1, 0.15, 0.1)
	glass.mesh = body
	glass.material_override = _material(LANTERN_COLOR, true)
	add_child(glass)
	var cap := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.02
	top.bottom_radius = 0.08
	top.height = 0.05
	cap.mesh = top
	cap.material_override = _material(Color(0.72, 0.56, 0.25))
	cap.position.y = 0.1
	add_child(cap)
	var light := OmniLight3D.new()
	light.light_color = LANTERN_COLOR
	light.light_energy = 1.5
	light.omni_range = 2.0
	add_child(light)


## Вспышка огня там, где фонарь разбился: живёт отдельно от снаряда.
func _burst() -> void:
	var fire := GPUParticles3D.new()
	fire.one_shot = true
	fire.explosiveness = 0.95
	fire.amount = 40
	fire.lifetime = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.25, 1.0))
	fade.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = fade
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
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
	fire.draw_pass_1 = quad
	get_parent().add_child(fire)
	fire.global_position = global_position
	fire.emitting = true
	fire.finished.connect(fire.queue_free)
