extends Node3D
## 179: тетива фонарщика кодом. Лук слит с телом и привязан к пальцам левой кисти;
## концы лука — крайние по высоте вершины этих пальцев, их положение считается по скиннингу
## каждый кадр. Нить идёт от верхнего конца к нижнему; когда правая кисть тянет —
## через правую кисть.

## Толщина нити, доля роста.
const THICKNESS := 0.004
## Наибольший натяг, доля роста: дальше кисть тетиву не держит. В клипе выстрела натяг до 0,48,
## после выпуска кисть уходит назад дальше 0,56 — тетива срывается и становится прямой.
const MAX_DRAW := 0.52

var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _unit: Creature
var _tips: Array = []  # [{v: Vector3, binds: [..], weights: [..]}] — верх, низ
var _upper: MeshInstance3D
var _lower: MeshInstance3D


func _ready() -> void:
	process_priority = 20
	call_deferred("_attach")


func _attach() -> void:
	_skeleton = get_parent().find_children("*", "Skeleton3D", true, false)[0]
	_unit = get_parent().get_parent() as Creature
	for mi: MeshInstance3D in get_parent().find_children("*", "MeshInstance3D", true, false):
		if mi.skin:
			_mesh = mi
			break
	_find_tips()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.78, 0.68)
	material.roughness = 0.9
	_upper = _segment(material)
	_lower = _segment(material)
	_process(0.0)


func _segment(material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.rings = 1
	cylinder.material = material
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.top_level = true
	return node


## Верх и низ лука: самая высокая и самая низкая вершины, у которых главная кость — палец левой кисти.
func _find_tips() -> void:
	var arrays := _mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / verts.size()
	var top := -1
	var bottom := -1
	for i in verts.size():
		var best := 0
		for k in per:
			if weights[i * per + k] > weights[i * per + best]:
				best = k
		if not String(_mesh.skin.get_bind_name(bones[i * per + best])).begins_with("mixamorig_LeftHand"):
			continue
		if top < 0 or verts[i].y > verts[top].y:
			top = i
		if bottom < 0 or verts[i].y < verts[bottom].y:
			bottom = i
	for i in [top, bottom]:
		var tip := {"v": verts[i], "binds": [], "weights": []}
		for k in per:
			if weights[i * per + k] > 0.0:
				var bind := bones[i * per + k]
				tip.binds.append([_skeleton.find_bone(_mesh.skin.get_bind_name(bind)), _mesh.skin.get_bind_pose(bind)])
				tip.weights.append(weights[i * per + k])
		_tips.append(tip)


func _skinned(tip: Dictionary) -> Vector3:
	var local := Vector3.ZERO
	for k in tip.weights.size():
		var bone: int = tip.binds[k][0]
		var bind: Transform3D = tip.binds[k][1]
		local += (_skeleton.get_bone_global_pose(bone) * bind * tip.v) * tip.weights[k]
	return _skeleton.global_transform * local


func _palm() -> Vector3:
	var hand := _skeleton.find_bone("mixamorig_RightHand")
	var middle := _skeleton.find_bone("mixamorig_RightHandMiddle1")
	var a := (_skeleton.global_transform * _skeleton.get_bone_global_pose(hand)).origin
	var b := (_skeleton.global_transform * _skeleton.get_bone_global_pose(middle)).origin
	return a.lerp(b, 0.75)


func _process(_delta: float) -> void:
	if _tips.size() < 2 or not is_instance_valid(_upper):
		return
	var top := _skinned(_tips[0])
	var bottom := _skinned(_tips[1])
	var mid := (top + bottom) * 0.5
	var nock := mid
	if String(_unit.anim.current_animation) == "shoot":
		var palm := _palm()
		var along := (top - bottom).normalized()
		var offset := palm - mid
		if (offset - along * offset.dot(along)).length() < MAX_DRAW * _unit.height:
			nock = palm
	var radius := THICKNESS * _unit.height * 0.5
	_place(_upper, top, nock, radius)
	_place(_lower, nock, bottom, radius)


func _place(node: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		node.visible = false
		return
	node.visible = true
	var y := dir / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	node.global_transform = Transform3D(Basis(x * radius, y * length, z * radius), (a + b) * 0.5)
