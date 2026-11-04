"""Привязать нашу модель к скелету донора с анимациями. Запуск в фоне, без окна:

blender -b --python pipelines/creature-quadruped/bind_donor.py -- <донор.glb> <наша.glb> <выход.glb>

Донор остаётся в своём размере. Наша модель масштабируется под него по длине, кости подгоняются под её габариты по осям,
веса считаются автоматически на сшитой копии и переносятся на модель. Анимации донора выгружаются все.
"""
import sys

import bmesh
import bpy
from mathutils import Vector

WELD = 0.0005  # доля длины модели: вершины ближе считаем одной


def bounds(objs):
    points = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector(min(p[a] for p in points) for a in range(3))
    hi = Vector(max(p[a] for p in points) for a in range(3))
    return lo, hi


donor, ours, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.import_scene.gltf(filepath=donor)
armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
donor_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
d_lo, d_hi = bounds(donor_meshes)
for o in donor_meshes:
    bpy.data.objects.remove(o)

before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=ours)
meshes = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
mesh = meshes[0]
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

m_lo, m_hi = bounds([mesh])
d_size, m_size = d_hi - d_lo, m_hi - m_lo
print("DONOR", [round(v, 3) for v in d_size], "OURS", [round(v, 3) for v in m_size])
long_axis = max(range(3), key=lambda a: d_size[a])
s = d_size[long_axis] / m_size[max(range(3), key=lambda a: m_size[a])]
mesh.scale = (s, s, s)
bpy.context.view_layer.update()
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
m_lo, m_hi = bounds([mesh])
center = (d_lo + d_hi) * 0.5
move = Vector((center.x - (m_lo.x + m_hi.x) * 0.5, center.y - (m_lo.y + m_hi.y) * 0.5, d_lo.z - m_lo.z))
mesh.location += move
bpy.context.view_layer.update()
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
m_lo, m_hi = bounds([mesh])
m_size = m_hi - m_lo
factors = Vector(m_size[a] / d_size[a] for a in range(3))
print("BONE FACTORS", [round(v, 3) for v in factors])

bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode="EDIT")
world = armature.matrix_world
inv = world.inverted()
base = Vector((center.x, center.y, d_lo.z))
for bone in armature.data.edit_bones:
    for end in ("head", "tail"):
        p = world @ getattr(bone, end)
        q = base + Vector((p - base)[a] * factors[a] for a in range(3))
        setattr(bone, end, inv @ q)
bpy.ops.object.mode_set(mode="OBJECT")

# Сетка Tripo разрезана по швам развёртки: веса считаем на сшитой копии, иначе куски разъезжаются.
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.duplicate()
welded = bpy.context.active_object
bm = bmesh.new()
bm.from_mesh(welded.data)
before_verts = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD * max(m_size))
print("WELD", before_verts, "->", len(bm.verts))
bm.to_mesh(welded.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
welded.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
for g in welded.vertex_groups:
    mesh.vertex_groups.new(name=g.name)
transfer = mesh.modifiers.new("weights", "DATA_TRANSFER")
transfer.object = welded
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "NEAREST"
bpy.ops.object.modifier_apply(modifier=transfer.name)
bpy.data.objects.remove(welded)
bones = mesh.modifiers.new("Armature", "ARMATURE")
bones.object = armature
mesh.parent = armature
mesh.matrix_parent_inverse = armature.matrix_world.inverted()
groups = [g.name for g in mesh.vertex_groups]
weighted = sum(1 for v in mesh.data.vertices if v.groups)
print("GROUPS", len(groups), "WEIGHTED", weighted, "/", len(mesh.data.vertices))

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=80, export_animations=True, export_animation_mode="ACTIONS", export_skins=True)
print("DONE", out)
