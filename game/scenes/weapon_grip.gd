extends Node3D
## 181: отдельное одноручное оружие или щит в кисти — общий хват пайплайна creature-mixamo-first.
## Ставится дочерним узлом модели существа (рядом со скелетом), как hammer_grip у молотобойца.
## Оружие не крутится по ходу клипа: поворот задан один раз (roll), дальше идёт за кистью (M02, 153).
##
## mode "fist" — рукоять через кулак: ось рукояти вдоль линии костяшек (мизинец → указательный),
##   рабочая сторона (лезвие) — туда, куда смотрят костяшки. grip_at — где кулак, доля длины от торца.
## mode "forearm" — щит плашмя на внешней стороне предплечья, кисть на рукояти в центре (ARTIFACTS 43).
## Модель — model (glb) или заглушка shape: "axe", "shield", "stick".

@export var hand := "Right"
@export var mode := "fist"
@export var model := ""
@export var shape := "axe"
## Длина оружия (или щита вдоль предплечья) в долях роста существа.
@export var length := 0.42
## Ширина щита в долях роста.
@export var width := 0.3
@export var grip_at := 0.12
## Постоянный поворот вокруг рукояти (или вокруг нормали щита), градусы.
@export var roll := 0.0

var _skeleton: Skeleton3D
var _unit: Creature
var _item: Node3D


func _ready() -> void:
	process_priority = 20
	call_deferred("_attach")


func _attach() -> void:
	_skeleton = get_parent().find_children("*", "Skeleton3D", true, false)[0]
	_unit = get_parent().get_parent() as Creature
	_item = load(model).instantiate() if model != "" else _placeholder()
	add_child(_item)
	_item.top_level = true
	_process(0.0)


## Заглушка на манекене: размер и хват как у будущего оружия, без модели.
func _placeholder() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.18)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.6
	if shape == "shield":
		var disc := CylinderMesh.new()  # ось цилиндра — нормаль щита (+Z после поворота)
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.06
		disc.material = wood
		var node := MeshInstance3D.new()
		node.mesh = disc
		node.rotation_degrees.x = 90.0
		root.add_child(node)
		return root
	var shaft := CylinderMesh.new()  # рукоять вдоль +Y от 0 до 1
	shaft.top_radius = 0.02
	shaft.bottom_radius = 0.02
	shaft.height = 1.0
	shaft.material = wood
	var stick := MeshInstance3D.new()
	stick.mesh = shaft
	stick.position.y = 0.5
	root.add_child(stick)
	if shape == "axe":
		var blade := BoxMesh.new()  # голова у верхнего конца, лезвие в +Z
		blade.size = Vector3(0.03, 0.22, 0.2)
		blade.material = steel
		var head := MeshInstance3D.new()
		head.mesh = blade
		head.position = Vector3(0.0, 0.88, 0.1)
		root.add_child(head)
	return root


func _point(suffix: String) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("mixamorig_" + suffix))).origin


func _process(_delta: float) -> void:
	if not is_instance_valid(_item):
		return
	var height: float = _unit.height if _unit else 1.8
	var palm := _point(hand + "Hand").lerp(_point(hand + "HandMiddle1"), 0.75)
	var knuckles := (_point(hand + "HandIndex1") - _point(hand + "HandPinky1")).normalized()
	var fingers := (_point(hand + "HandMiddle1") - _point(hand + "Hand")).normalized()
	if mode == "forearm":
		var fore := (_point(hand + "Hand") - _point(hand + "ForeArm")).normalized()
		var out := fore.cross(knuckles).normalized()  # тыльная сторона кисти
		if out.dot(palm - _point("Spine2")) < 0.0:
			out = -out
		var up := fore.cross(out).normalized()
		var basis := Basis(up, fore, out).rotated(out, deg_to_rad(roll))
		var size := Vector3(width, length, 1.0) * height
		var centre := _point(hand + "ForeArm").lerp(_point(hand + "Hand"), 0.6) + out * 0.06 * height
		_item.global_transform = Transform3D(basis.scaled_local(Vector3(size.x, size.y, size.x)), centre)
		return
	var axis := knuckles
	var edge := (fingers - axis * fingers.dot(axis)).normalized()  # костяшки — туда же лезвие
	var basis := Basis(axis.cross(edge), axis, edge).rotated(axis, deg_to_rad(roll))
	var span := length * height
	_item.global_transform = Transform3D(basis.scaled_local(Vector3.ONE * span), palm - axis * span * grip_at)
