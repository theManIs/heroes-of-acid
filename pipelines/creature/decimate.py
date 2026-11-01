"""Упростить сетку готовой модели в Blender: риг, веса и UV сохраняются.

Запуск: blender -b --python pipelines/creature/decimate.py -- <вход.glb> <выход.glb> <треугольников> [noimages]
noimages: файл без текстур, для витрины уровней детализации с общей текстурой.
"""

import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, target = args[0], args[1], int(args[2])
image_format = "NONE" if "noimages" in args else "AUTO"

bpy.ops.wm.read_factory_settings(use_empty=True)
# BLENDER: кости не переориентируются, поза покоя остаётся как в исходном файле.
bpy.ops.import_scene.gltf(filepath=src, bone_heuristic="BLENDER")

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
ratio = min(1.0, target / total)
for obj in meshes:
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)

after = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=False, export_skins=True, export_yup=True, export_image_format=image_format)
print(f"DECIMATED {total} -> {after}")
