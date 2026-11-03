"""FBX клипа Mixamo → GLB. Запуск: blender -b --python fbx2glb.py -- <вход.fbx> <выход.glb>"""
import sys

import bpy

src, dst = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=True, export_skins=True,
                          export_yup=True, export_optimize_animation_size=False)
