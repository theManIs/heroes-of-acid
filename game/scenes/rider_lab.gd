extends Node3D
## Макет всадника (задача 157): тело молотобойца в сидячем клипе на условном коне.
## Общие части — rider_mock.gd. Отсмотр всех клипов — rider_showcase.tscn.

const MOCK := preload("res://scenes/rider_mock.gd")

var rider: Creature
var _views := []  # [камера, имя] для снимков


func _ready() -> void:
	_build_world()
	MOCK.build_horse(self)
	rider = MOCK.make_rider(self)
	rider.anim.get_animation("ride_still").loop_mode = Animation.LOOP_LINEAR
	rider.anim.play("ride_still")
	await get_tree().process_frame
	await get_tree().process_frame
	MOCK.sit(rider)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shots(arg.trim_prefix("--shot="))


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.31, 0.34)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(1.0, 2.2, 3.6)
	add_child(cam)
	cam.look_at(Vector3(0, 1.45, 0))
	cam.current = true
	_views.append([cam, "three_quarter"])
	for v in [[Vector3(0.0, 1.8, 3.0), "side"], [Vector3(3.0, 2.0, 0.0), "front"], [Vector3(0.0, 6.5, 6.0), "battle"]]:
		var c := Camera3D.new()
		c.position = v[0]
		add_child(c)
		c.look_at(Vector3(0, 1.45, 0))
		_views.append([c, v[1]])


func _shots(prefix: String) -> void:
	await get_tree().create_timer(1.0).timeout
	for v in _views:
		v[0].current = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s-%s.png" % [prefix, v[1]])
	get_tree().quit()
